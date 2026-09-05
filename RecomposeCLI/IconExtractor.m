#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>

#import "IconExtractor.h"

@interface CoreUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)appearanceNames;
- (id)iconLayerStackWithName:(NSString *)name
                 scaleFactor:(double)scale
                 deviceIdiom:(NSInteger)idiom
               deviceSubtype:(NSUInteger)subtype
                displayGamut:(NSUInteger)gamut
              appearanceName:(NSString *)appearance
                      locale:(NSString *)locale;
@end

@interface CoreUINamedLookup : NSObject
- (NSString *)name;
- (NSString *)renditionName;
- (NSString *)appearance;
- (NSInteger)appearanceIdentifier;
- (double)scale;
- (NSInteger)idiom;
- (NSInteger)displayGamut;
- (id)_rendition;
@end

@interface CoreUIThemeRendition : NSObject
- (NSData *)data;
- (NSData *)srcData;
- (NSString *)utiType;
- (NSDictionary *)properties;
- (NSInteger)type;
- (NSInteger)subtype;
- (NSInteger)objectVersion;
- (BOOL)isVectorBased;
- (BOOL)isOpaque;
- (BOOL)isTintable;
- (double)opacity;
- (int)blendMode;
@end

@interface CoreUIIconLayerStack : CoreUINamedLookup
- (NSArray *)layers;
- (CGSize)size;
- (NSUInteger)sourceObjectVersion;
- (NSDictionary *)renderingProperties;
- (NSData *)dataRepresentationWithError:(NSError **)error;
@end

@interface CoreUIIconLayerGroup : CoreUINamedLookup
- (NSArray *)layers;
- (int)blendMode;
- (double)blurStrength;
- (CGColorRef)color;
- (id)gradient;
- (NSString *)gradientOrColorName;
- (BOOL)gathersSpecularByElement;
- (BOOL)hasLightingEffects;
- (BOOL)hasSpecular;
- (double)opacity;
- (double)refractionHeight;
- (double)refractionStrength;
- (double)shadowOpacity;
- (NSInteger)shadowStyle;
- (NSInteger)specularPlacement;
- (double)translucency;
@end

@interface CoreUILayer : CoreUINamedLookup
- (int)blendMode;
- (double)blurStrength;
- (CGColorRef)color;
- (id)gradient;
- (NSString *)gradientOrColorName;
- (BOOL)hasLightingEffects;
- (double)opacity;
- (CGRect)frame;
@end

@interface CoreUILayerImage : CoreUILayer
- (BOOL)fixedFrame;
- (CGSize)size;
- (CGImageRef)image;
@end

@interface CoreUILayerVectorSVGImage : CoreUILayer
- (void *)svgDocument;
@end

@interface CoreUINamedColor : CoreUINamedLookup
- (CGColorRef)cgColor;
- (BOOL)substituteWithSystemColor;
- (NSString *)systemColorName;
@end

@interface CoreUINamedGradient : CoreUINamedLookup
- (NSArray *)colors;
- (NSArray *)colorStops;
- (CGPoint)gradientStartPoint;
- (CGPoint)gradientEndPoint;
- (NSInteger)gradientType;
@end

static NSString *SanitizeFilename(NSString *input) {
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString:@"._-"];
    NSMutableString *result = [NSMutableString stringWithCapacity:input.length];
    for (NSUInteger index = 0; index < input.length; index++) {
        unichar character = [input characterAtIndex:index];
        if ([allowed characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        } else {
            [result appendString:@"_"];
        }
    }
    return result.length > 0 ? result : @"asset";
}

static NSData *ExportedAssetData(CoreUINamedLookup *lookup, NSError **error) {
    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedLayerVectorSVGImage")]) {
        void *document = [(CoreUILayerVectorSVGImage *)lookup svgDocument];
        if (document == NULL) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Vector layer did not provide an SVG document"}];
            }
            return nil;
        }
        void *symbol = dlsym(RTLD_DEFAULT, "CGSVGDocumentWriteToData");
        if (symbol == NULL) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:11 userInfo:@{NSLocalizedDescriptionKey: @"CGSVGDocumentWriteToData is unavailable"}];
            }
            return nil;
        }
        NSMutableData *data = [NSMutableData data];
        typedef void (*WriteSVGFunction)(void *, CFMutableDataRef, CFDictionaryRef);
        ((WriteSVGFunction)symbol)(document, (__bridge CFMutableDataRef)data, NULL);
        if (data.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Apple SVG serializer returned no data"}];
            }
            return nil;
        }
        return data;
    }

    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedLayerImage")]) {
        CGImageRef image = [(CoreUILayerImage *)lookup image];
        if (image == NULL) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:13 userInfo:@{NSLocalizedDescriptionKey: @"Raster layer did not provide a CGImage"}];
            }
            return nil;
        }
        NSMutableData *data = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
        if (destination == NULL) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:14 userInfo:@{NSLocalizedDescriptionKey: @"Unable to create PNG destination"}];
            }
            return nil;
        }
        CGImageDestinationAddImage(destination, image, NULL);
        BOOL finalized = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        if (!finalized || data.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"CoreUIIconExtract" code:15 userInfo:@{NSLocalizedDescriptionKey: @"Apple ImageIO could not encode the raster layer"}];
            }
            return nil;
        }
        return data;
    }

    return nil;
}

static NSDictionary *PointDictionary(CGPoint point) {
    return @{@"x": @(point.x), @"y": @(point.y)};
}

static NSDictionary *SizeDictionary(CGSize size) {
    return @{@"width": @(size.width), @"height": @(size.height)};
}

static NSDictionary *RectDictionary(CGRect rect) {
    return @{@"origin": PointDictionary(rect.origin), @"size": SizeDictionary(rect.size)};
}

static NSDictionary *SVGImageSize(NSData *data) {
    NSString *source = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (source.length == 0) {
        return nil;
    }
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"\\bviewBox\\s*=\\s*[\"']\\s*([^\"']+?)\\s*[\"']"
                              options:NSRegularExpressionCaseInsensitive
                                error:nil];
    NSTextCheckingResult *match = [expression firstMatchInString:source
                                                         options:0
                                                           range:NSMakeRange(0, source.length)];
    if (match.numberOfRanges < 2) {
        return nil;
    }
    NSString *viewBox = [source substringWithRange:[match rangeAtIndex:1]];
    NSArray<NSString *> *rawParts = [viewBox componentsSeparatedByCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@" ,\t\r\n"]];
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:4];
    for (NSString *part in rawParts) {
        if (part.length > 0) [parts addObject:part];
    }
    if (parts.count != 4) {
        return nil;
    }
    double width = parts[2].doubleValue;
    double height = parts[3].doubleValue;
    if (!isfinite(width) || !isfinite(height) || width <= 0.0 || height <= 0.0) {
        return nil;
    }
    return @{ @"width": @(width), @"height": @(height) };
}

static NSDictionary *ColorDictionary(CGColorRef color) {
    if (color == NULL) {
        return nil;
    }
    CGColorSpaceRef colorSpace = CGColorGetColorSpace(color);
    CFStringRef colorSpaceName = colorSpace ? CGColorSpaceCopyName(colorSpace) : NULL;
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:count];
    for (size_t index = 0; index < count; index++) {
        [values addObject:@(components[index])];
    }
    NSDictionary *result = @{
        @"colorSpace": colorSpaceName ? (__bridge NSString *)colorSpaceName : @"",
        @"components": values
    };
    if (colorSpaceName) {
        CFRelease(colorSpaceName);
    }
    return result;
}

static id JSONSafe(id value) {
    if (value == nil) {
        return [NSNull null];
    }
    if ([value isKindOfClass:[NSString class]] ||
        [value isKindOfClass:[NSNumber class]] ||
        [value isKindOfClass:[NSNull class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[value count]];
        for (id item in value) {
            [result addObject:JSONSafe(item)];
        }
        return result;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) {
            result[[key description]] = JSONSafe(value[key]);
        }
        return result;
    }
    if (CFGetTypeID((__bridge CFTypeRef)value) == CGColorGetTypeID()) {
        return ColorDictionary((__bridge CGColorRef)value);
    }
    return @{ @"class": NSStringFromClass([value class]), @"description": [value description] ?: @"" };
}

static NSDictionary *GradientDictionary(id gradient) {
    if (gradient == nil) {
        return nil;
    }
    NSMutableArray *colors = [NSMutableArray array];
    if ([gradient respondsToSelector:@selector(colors)]) {
        for (id color in [gradient colors]) {
            if (CFGetTypeID((__bridge CFTypeRef)color) == CGColorGetTypeID()) {
                [colors addObject:ColorDictionary((__bridge CGColorRef)color)];
            } else if ([color respondsToSelector:@selector(cgColor)]) {
                [colors addObject:ColorDictionary([color cgColor]) ?: [NSNull null]];
            } else {
                [colors addObject:JSONSafe(color)];
            }
        }
    }
    return @{
        @"colors": colors,
        @"stops": [gradient respondsToSelector:@selector(colorStops)] ? JSONSafe([gradient colorStops]) : @[],
        @"start": [gradient respondsToSelector:@selector(gradientStartPoint)] ? PointDictionary([gradient gradientStartPoint]) : @{},
        @"end": [gradient respondsToSelector:@selector(gradientEndPoint)] ? PointDictionary([gradient gradientEndPoint]) : @{},
        @"type": [gradient respondsToSelector:@selector(gradientType)] ? @([gradient gradientType]) : @0
    };
}

static NSDictionary *RenditionDictionary(id rendition) {
    if (rendition == nil) {
        return @{};
    }
    CoreUIThemeRendition *typedRendition = (CoreUIThemeRendition *)rendition;
    NSData *data = [rendition respondsToSelector:@selector(data)] ? [typedRendition data] : nil;
    NSData *sourceData = [rendition respondsToSelector:@selector(srcData)] ? [typedRendition srcData] : nil;
    return @{
        @"class": NSStringFromClass([rendition class]),
        @"dataLength": @(data.length),
        @"sourceDataLength": @(sourceData.length),
        @"utiType": [rendition respondsToSelector:@selector(utiType)] ? ([typedRendition utiType] ?: @"") : @"",
        @"type": [rendition respondsToSelector:@selector(type)] ? @([typedRendition type]) : @0,
        @"subtype": [rendition respondsToSelector:@selector(subtype)] ? @([typedRendition subtype]) : @0,
        @"objectVersion": [rendition respondsToSelector:@selector(objectVersion)] ? @([typedRendition objectVersion]) : @0,
        @"isVectorBased": [rendition respondsToSelector:@selector(isVectorBased)] ? @([typedRendition isVectorBased]) : @NO,
        @"isOpaque": [rendition respondsToSelector:@selector(isOpaque)] ? @([typedRendition isOpaque]) : @NO,
        @"isTintable": [rendition respondsToSelector:@selector(isTintable)] ? @([typedRendition isTintable]) : @NO,
        @"opacity": [rendition respondsToSelector:@selector(opacity)] ? @([typedRendition opacity]) : @1,
        @"blendMode": [rendition respondsToSelector:@selector(blendMode)] ? @([typedRendition blendMode]) : @0,
        @"properties": [rendition respondsToSelector:@selector(properties)] ? JSONSafe([typedRendition properties]) : @{}
    };
}

@interface ExtractionContext : NSObject
@property(nonatomic, copy) NSString *assetDirectory;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *assetDataByLogicalName;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *filenameByLogicalName;
@property(nonatomic) NSUInteger filenameCounter;
@end

@implementation ExtractionContext
@end

static NSString *SaveSourceData(CoreUINamedLookup *lookup,
                                NSString *appearance,
                                ExtractionContext *context,
                                NSData **exportedData,
                                NSError **error) {
    NSData *sourceData = ExportedAssetData(lookup, error);
    if (sourceData.length == 0) {
        return nil;
    }
    if (exportedData) {
        *exportedData = sourceData;
    }

    NSString *logicalName = [lookup name] ?: [lookup renditionName] ?: @"asset";
    NSData *existing = context.assetDataByLogicalName[logicalName];
    if (existing != nil && [existing isEqualToData:sourceData]) {
        return context.filenameByLogicalName[logicalName];
    }

    NSString *uniqueLogicalName = logicalName;
    if (existing != nil) {
        uniqueLogicalName = [NSString stringWithFormat:@"%@__%@", logicalName, appearance ?: @"variant"];
    }
    NSString *extension = [[lookup renditionName] pathExtension];
    if (extension.length == 0) {
        extension = [lookup isKindOfClass:NSClassFromString(@"CUINamedLayerVectorSVGImage")] ? @"svg" : @"png";
    }
    context.filenameCounter += 1;
    NSString *filename = [NSString stringWithFormat:@"%03lu_%@.%@",
                          (unsigned long)context.filenameCounter,
                          SanitizeFilename(uniqueLogicalName),
                          extension];
    NSString *path = [context.assetDirectory stringByAppendingPathComponent:filename];
    if (![sourceData writeToFile:path options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    context.assetDataByLogicalName[uniqueLogicalName] = sourceData;
    context.filenameByLogicalName[uniqueLogicalName] = filename;
    if (existing == nil) {
        context.assetDataByLogicalName[logicalName] = sourceData;
        context.filenameByLogicalName[logicalName] = filename;
    }
    return filename;
}

static NSMutableDictionary *BaseLookupDictionary(CoreUINamedLookup *lookup) {
    id rendition = [lookup respondsToSelector:@selector(_rendition)] ? [lookup _rendition] : nil;
    return [@{
        @"class": NSStringFromClass([lookup class]),
        @"name": [lookup respondsToSelector:@selector(name)] ? ([lookup name] ?: @"") : @"",
        @"renditionName": [lookup respondsToSelector:@selector(renditionName)] ? ([lookup renditionName] ?: @"") : @"",
        @"appearance": [lookup respondsToSelector:@selector(appearance)] ? ([lookup appearance] ?: @"") : @"",
        @"appearanceIdentifier": [lookup respondsToSelector:@selector(appearanceIdentifier)] ? @([lookup appearanceIdentifier]) : @0,
        @"scale": [lookup respondsToSelector:@selector(scale)] ? @([lookup scale]) : @1,
        @"idiom": [lookup respondsToSelector:@selector(idiom)] ? @([lookup idiom]) : @0,
        @"displayGamut": [lookup respondsToSelector:@selector(displayGamut)] ? @([lookup displayGamut]) : @0,
        @"rendition": RenditionDictionary(rendition)
    } mutableCopy];
}

static NSDictionary *DescribeLookup(CoreUINamedLookup *lookup, NSString *appearance, ExtractionContext *context, NSError **error) {
    NSMutableDictionary *record = BaseLookupDictionary(lookup);

    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedColor")]) {
        CoreUINamedColor *color = (CoreUINamedColor *)lookup;
        record[@"color"] = ColorDictionary([color cgColor]) ?: [NSNull null];
        record[@"substituteWithSystemColor"] = @([color substituteWithSystemColor]);
        record[@"systemColorName"] = [color systemColorName] ?: @"";
        return record;
    }

    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedGradient")]) {
        record[@"gradient"] = GradientDictionary(lookup) ?: @{};
        return record;
    }

    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedIconLayerGroup")]) {
        CoreUIIconLayerGroup *group = (CoreUIIconLayerGroup *)lookup;
        record[@"blendMode"] = @([group blendMode]);
        record[@"blurStrength"] = @([group blurStrength]);
        record[@"fillName"] = [group gradientOrColorName] ?: @"";
        record[@"color"] = ColorDictionary([group color]) ?: [NSNull null];
        record[@"gradient"] = GradientDictionary([group gradient]) ?: [NSNull null];
        record[@"gathersSpecularByElement"] = @([group gathersSpecularByElement]);
        record[@"hasLightingEffects"] = @([group hasLightingEffects]);
        record[@"hasSpecular"] = @([group hasSpecular]);
        record[@"opacity"] = @([group opacity]);
        record[@"refractionHeight"] = @([group refractionHeight]);
        record[@"refractionStrength"] = @([group refractionStrength]);
        record[@"shadowOpacity"] = @([group shadowOpacity]);
        record[@"shadowStyle"] = @([group shadowStyle]);
        record[@"specularPlacement"] = @([group specularPlacement]);
        record[@"translucency"] = @([group translucency]);
        NSMutableArray *layers = [NSMutableArray array];
        for (CoreUINamedLookup *layer in [group layers]) {
            NSDictionary *child = DescribeLookup(layer, appearance, context, error);
            if (child == nil) {
                return nil;
            }
            [layers addObject:child];
        }
        record[@"layers"] = layers;
        return record;
    }

    if ([lookup isKindOfClass:NSClassFromString(@"CUINamedLayerImage")] ||
        [lookup isKindOfClass:NSClassFromString(@"CUINamedLayerVectorSVGImage")]) {
        CoreUILayer *layer = (CoreUILayer *)lookup;
        record[@"blendMode"] = @([layer blendMode]);
        record[@"blurStrength"] = @([layer blurStrength]);
        record[@"fillName"] = [layer gradientOrColorName] ?: @"";
        record[@"color"] = ColorDictionary([layer color]) ?: [NSNull null];
        record[@"gradient"] = GradientDictionary([layer gradient]) ?: [NSNull null];
        record[@"hasLightingEffects"] = @([layer hasLightingEffects]);
        record[@"opacity"] = @([layer opacity]);
        record[@"frame"] = RectDictionary([layer frame]);
        if ([lookup isKindOfClass:NSClassFromString(@"CUINamedLayerImage")]) {
            CoreUILayerImage *imageLayer = (CoreUILayerImage *)lookup;
            record[@"fixedFrame"] = @([imageLayer fixedFrame]);
            record[@"imageSize"] = SizeDictionary([imageLayer size]);
        }
        NSData *sourceData = nil;
        NSString *filename = SaveSourceData(lookup, appearance, context, &sourceData, error);
        if (filename == nil && *error != nil) {
            return nil;
        }
        if ([lookup isKindOfClass:NSClassFromString(@"CUINamedLayerVectorSVGImage")]) {
            NSDictionary *imageSize = SVGImageSize(sourceData);
            if (imageSize == nil) {
                if (error) {
                    *error = [NSError errorWithDomain:@"CoreUIIconExtract"
                                                 code:16
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                 @"Serialized SVG did not provide a usable viewBox"}];
                }
                return nil;
            }
            record[@"imageSize"] = imageSize;
        }
        record[@"assetFile"] = filename ?: [NSNull null];
        return record;
    }

    return record;
}

int RCExtractIcon(NSString *catalogPath, NSString *assetName, NSString *outputDirectory) {
    @autoreleasepool {
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            fprintf(stderr, "Unable to load CoreUI: %s\n", dlerror());
            return 1;
        }

        NSString *assetDirectory = [outputDirectory stringByAppendingPathComponent:@"Assets"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:assetDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            fprintf(stderr, "Unable to create output directory: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }

        Class catalogClass = NSClassFromString(@"CUICatalog");
        CoreUICatalog *catalog = [[catalogClass alloc] initWithURL:[NSURL fileURLWithPath:catalogPath] error:&error];
        if (catalog == nil) {
            fprintf(stderr, "Unable to open catalog: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }

        ExtractionContext *context = [ExtractionContext new];
        context.assetDirectory = assetDirectory;
        context.assetDataByLogicalName = [NSMutableDictionary dictionary];
        context.filenameByLogicalName = [NSMutableDictionary dictionary];

        NSArray<NSDictionary *> *targetAppearances = @[
            @{
                @"manifestKey": @"UIAppearanceLight",
                @"catalogNames": @[ @"UIAppearanceLight", @"NSAppearanceNameAqua" ]
            },
            @{
                @"manifestKey": @"UIAppearanceDark",
                @"catalogNames": @[ @"UIAppearanceDark", @"NSAppearanceNameDarkAqua" ]
            },
            @{
                @"manifestKey": @"ISAppearanceTintable",
                @"catalogNames": @[ @"ISAppearanceTintable" ]
            }
        ];
        NSMutableDictionary *appearanceRecords = [NSMutableDictionary dictionary];
        for (NSDictionary *target in targetAppearances) {
            NSString *manifestAppearance = target[@"manifestKey"];
            NSString *catalogAppearance = nil;
            CoreUIIconLayerStack *stack = nil;
            for (NSString *candidate in target[@"catalogNames"]) {
                stack = [catalog iconLayerStackWithName:assetName
                                            scaleFactor:1.0
                                            deviceIdiom:0
                                          deviceSubtype:0
                                           displayGamut:0
                                         appearanceName:candidate
                                                 locale:nil];
                if (stack != nil) {
                    catalogAppearance = candidate;
                    break;
                }
            }
            if (stack == nil) {
                fprintf(stderr, "No icon layer stack named %s for normalized appearance %s\n",
                        assetName.UTF8String, manifestAppearance.UTF8String);
                dlclose(handle);
                return 2;
            }

            NSMutableDictionary *stackRecord = BaseLookupDictionary(stack);
            stackRecord[@"catalogAppearanceName"] = catalogAppearance;
            stackRecord[@"size"] = SizeDictionary([stack size]);
            stackRecord[@"sourceObjectVersion"] = @([stack sourceObjectVersion]);
            stackRecord[@"renderingProperties"] = JSONSafe([stack renderingProperties]);
            NSMutableArray *layers = [NSMutableArray array];
            for (CoreUINamedLookup *layer in [stack layers]) {
                NSDictionary *child = DescribeLookup(layer, manifestAppearance, context, &error);
                if (child == nil) {
                    fprintf(stderr, "Unable to extract %s: %s\n",
                            manifestAppearance.UTF8String, error.localizedDescription.UTF8String);
                    dlclose(handle);
                    return 1;
                }
                [layers addObject:child];
            }
            stackRecord[@"layers"] = layers;

            NSData *representation = [stack dataRepresentationWithError:&error];
            if (representation != nil) {
                NSString *filename = [NSString stringWithFormat:@"%@__%@.dataRep",
                                      SanitizeFilename(assetName), manifestAppearance];
                NSString *path = [outputDirectory stringByAppendingPathComponent:filename];
                if (![representation writeToFile:path options:NSDataWritingAtomic error:&error]) {
                    fprintf(stderr, "Unable to save data representation: %s\n", error.localizedDescription.UTF8String);
                    dlclose(handle);
                    return 1;
                }
                stackRecord[@"dataRepresentationFile"] = filename;
            }
            appearanceRecords[manifestAppearance] = stackRecord;
        }

        NSDictionary *manifest = @{
            @"formatVersion": @1,
            @"source": @{
                @"catalog": [catalogPath lastPathComponent],
                @"assetName": assetName,
                @"extractor": @"recompose extract (Apple CoreUI runtime)"
            },
            @"appearances": appearanceRecords
        };
        NSData *json = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (json == nil) {
            fprintf(stderr, "Unable to encode manifest: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }
        NSString *manifestPath = [outputDirectory stringByAppendingPathComponent:@"manifest.json"];
        if (![json writeToFile:manifestPath options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "Unable to save manifest: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }
        dlclose(handle);
    }
    return 0;
}
