#import "IconStackDiscovery.h"
#import "IconAssembler.h"

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>

static NSString *const RCDiscoveryErrorDomain = @"RecomposeDiscovery";

typedef NS_ENUM(NSUInteger, RCIconRendererPlatform) {
    RCIconRendererPlatformMacOS = 1,
};

typedef NS_ENUM(NSInteger, RCIconRendererAppearance) {
    RCIconRendererAppearanceDefault = 0,
    RCIconRendererAppearanceDark = 1,
};

typedef NS_ENUM(NSInteger, RCIconRendererAppearanceVariant) {
    RCIconRendererAppearanceVariantDefault = 0,
    RCIconRendererAppearanceVariantTinted = 2,
};

@interface RCDiscoveryCatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (void)enumerateNamedLookupsUsingBlock:(void (^)(id lookup, BOOL *stop))block;
- (id)iconLayerStackWithName:(NSString *)name
                 scaleFactor:(double)scale
                 deviceIdiom:(NSInteger)idiom
               deviceSubtype:(NSUInteger)subtype
                displayGamut:(NSUInteger)gamut
              appearanceName:(NSString *)appearance
                      locale:(NSString *)locale;
@end

@interface RCDiscoveryLookup : NSObject
- (NSString *)name;
- (NSString *)renditionName;
@end

@interface RCDiscoveryIconLayerStack : NSObject
- (NSArray *)layers;
- (id)_IF_ImageWithSize:(CGSize)size
                  scale:(NSInteger)scale
               platform:(NSUInteger)platform
             appearance:(NSInteger)appearance
      appearanceVariant:(NSInteger)appearanceVariant
              tintColor:(id)tintColor
     encapsulationShape:(id)encapsulationShape;
@end

@interface RCDiscoveryIconLayerGroup : NSObject
- (BOOL)hasSpecular;
- (double)refractionHeight;
- (double)refractionStrength;
- (NSInteger)specularPlacement;
@end

@interface RCDiscoveryRenderedIcon : NSObject
- (CGImageRef)CGImage;
@end

static NSError *RCDiscoveryError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:RCDiscoveryErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

BOOL RCWriteIconPreview(NSString *catalogPath,
                        NSString *assetName,
                        NSString *outputPath,
                        RCIconPreviewAppearance previewAppearance,
                        NSError **error) {
    void *coreUIHandle = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW | RTLD_LOCAL);
    if (coreUIHandle == NULL) {
        if (error) {
            *error = RCDiscoveryError(6, [NSString stringWithFormat:@"Unable to load CoreUI: %s", dlerror()]);
        }
        return NO;
    }

    void *iconFoundationHandle = dlopen(
        "/System/Library/PrivateFrameworks/IconFoundation.framework/IconFoundation",
        RTLD_NOW | RTLD_LOCAL
    );
    if (iconFoundationHandle == NULL) {
        if (error) {
            *error = RCDiscoveryError(7, [NSString stringWithFormat:@"Unable to load IconFoundation: %s", dlerror()]);
        }
        dlclose(coreUIHandle);
        return NO;
    }

    NSError *catalogError = nil;
    Class catalogClass = NSClassFromString(@"CUICatalog");
    RCDiscoveryCatalog *catalog = [[catalogClass alloc]
        initWithURL:[NSURL fileURLWithPath:catalogPath]
              error:&catalogError];
    if (catalog == nil) {
        if (error) {
            *error = catalogError ?: RCDiscoveryError(8, @"Unable to open asset catalog");
        }
        dlclose(iconFoundationHandle);
        dlclose(coreUIHandle);
        return NO;
    }

    RCDiscoveryRenderedIcon *renderedIcon = nil;
    CGImageRef image = NULL;
    @try {
        NSArray<NSString *> *appearanceAliases = nil;
        RCIconRendererAppearance rendererAppearance = RCIconRendererAppearanceDefault;
        RCIconRendererAppearanceVariant rendererVariant = RCIconRendererAppearanceVariantDefault;
        switch (previewAppearance) {
            case RCIconPreviewAppearanceDefault:
                appearanceAliases = @[ @"UIAppearanceLight", @"NSAppearanceNameAqua" ];
                break;
            case RCIconPreviewAppearanceDark:
                appearanceAliases = @[ @"UIAppearanceDark", @"NSAppearanceNameDarkAqua",
                                       @"UIAppearanceLight", @"NSAppearanceNameAqua" ];
                rendererAppearance = RCIconRendererAppearanceDark;
                break;
            case RCIconPreviewAppearanceTinted:
                appearanceAliases = @[ @"ISAppearanceTintable",
                                       @"UIAppearanceLight", @"NSAppearanceNameAqua" ];
                rendererVariant = RCIconRendererAppearanceVariantTinted;
                break;
        }

        RCDiscoveryIconLayerStack *stack = nil;
        for (NSString *appearance in appearanceAliases) {
            stack = [catalog iconLayerStackWithName:assetName
                                       scaleFactor:1.0
                                       deviceIdiom:0
                                     deviceSubtype:0
                                      displayGamut:0
                                    appearanceName:appearance
                                            locale:nil];
            if (stack != nil) {
                break;
            }
        }

        SEL renderSelector = @selector(_IF_ImageWithSize:scale:platform:appearance:appearanceVariant:tintColor:encapsulationShape:);
        if ([stack respondsToSelector:renderSelector]) {
            renderedIcon = [stack _IF_ImageWithSize:CGSizeMake(256, 256)
                                              scale:2
                                           platform:RCIconRendererPlatformMacOS
                                         appearance:rendererAppearance
                                  appearanceVariant:rendererVariant
                                          tintColor:nil
                                 encapsulationShape:nil];
        }
        image = [renderedIcon respondsToSelector:@selector(CGImage)] ? [renderedIcon CGImage] : NULL;
    } @catch (NSException *exception) {
        if (error) {
            *error = RCDiscoveryError(
                9,
                [NSString stringWithFormat:@"Unable to render %@: %@",
                 assetName, exception.reason ?: exception.name]
            );
        }
        dlclose(iconFoundationHandle);
        dlclose(coreUIHandle);
        return NO;
    }

    if (image == NULL) {
        if (error) {
            *error = RCDiscoveryError(9, [NSString stringWithFormat:@"Unable to render the icon layer stack for %@", assetName]);
        }
        dlclose(iconFoundationHandle);
        dlclose(coreUIHandle);
        return NO;
    }

    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)data,
        CFSTR("public.png"),
        1,
        NULL
    );
    if (destination == NULL) {
        if (error) {
            *error = RCDiscoveryError(10, @"Unable to create the preview image destination");
        }
        dlclose(iconFoundationHandle);
        dlclose(coreUIHandle);
        return NO;
    }
    CGImageDestinationAddImage(destination, image, NULL);
    BOOL finalized = CGImageDestinationFinalize(destination);
    CFRelease(destination);

    NSError *writeError = nil;
    BOOL wrote = finalized && [data writeToFile:outputPath options:NSDataWritingAtomic error:&writeError];
    if (!wrote && error) {
        *error = writeError ?: RCDiscoveryError(11, @"Unable to encode the preview image");
    }
    dlclose(iconFoundationHandle);
    dlclose(coreUIHandle);
    return wrote;
}

static NSString *RCLogicalIconName(NSString *name) {
    if (name.length == 0) {
        return nil;
    }
    if ([[name.pathExtension lowercaseString] isEqualToString:@"iconstack"]) {
        return [name stringByDeletingPathExtension];
    }
    return name;
}

static void RCAddCandidate(NSMutableSet<NSString *> *candidates, NSString *name) {
    NSString *logicalName = RCLogicalIconName(name);
    if (logicalName.length > 0) {
        [candidates addObject:logicalName];
    }
}

NSArray<NSDictionary *> *RCDiscoverIconStackRecords(NSString *catalogPath, NSError **error) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        if (error) {
            *error = RCDiscoveryError(1, [NSString stringWithFormat:@"Unable to load CoreUI: %s", dlerror()]);
        }
        return nil;
    }

    Class catalogClass = NSClassFromString(@"CUICatalog");
    if (catalogClass == Nil) {
        if (error) {
            *error = RCDiscoveryError(2, @"CoreUI did not provide CUICatalog");
        }
        dlclose(handle);
        return nil;
    }

    NSError *catalogError = nil;
    RCDiscoveryCatalog *catalog = [[catalogClass alloc]
        initWithURL:[NSURL fileURLWithPath:catalogPath]
              error:&catalogError];
    if (catalog == nil) {
        if (error) {
            *error = catalogError ?: RCDiscoveryError(3, @"Unable to open asset catalog");
        }
        dlclose(handle);
        return nil;
    }

    NSMutableSet<NSString *> *candidates = [NSMutableSet set];
    @try {
        [catalog enumerateNamedLookupsUsingBlock:^(id lookup, BOOL *stop) {
            (void)stop;
            NSString *className = NSStringFromClass([lookup class]);
            BOOL isCandidate = [className containsString:@"Multisize"] ||
                               [className containsString:@"IconLayerStack"];
            if (!isCandidate) {
                return;
            }

            RCDiscoveryLookup *typedLookup = lookup;
            if ([lookup respondsToSelector:@selector(name)]) {
                RCAddCandidate(candidates, [typedLookup name]);
            }
            if ([lookup respondsToSelector:@selector(renditionName)]) {
                RCAddCandidate(candidates, [typedLookup renditionName]);
            }
        }];
    } @catch (NSException *exception) {
        if (error) {
            *error = RCDiscoveryError(
                4,
                [NSString stringWithFormat:@"CoreUI lookup enumeration failed: %@", exception.reason ?: exception.name]
            );
        }
        dlclose(handle);
        return nil;
    }

    NSArray<NSArray<NSString *> *> *normalizedAppearances = @[
        @[ @"UIAppearanceLight", @"NSAppearanceNameAqua" ],
        @[ @"UIAppearanceDark", @"NSAppearanceNameDarkAqua" ],
        @[ @"ISAppearanceTintable" ]
    ];
    NSMutableArray<NSDictionary *> *iconRecords = [NSMutableArray array];
    for (NSString *candidate in candidates) {
        BOOL resolved = NO;
        RCIconGeneration generation = RCIconGeneration26;
        @try {
            for (NSArray<NSString *> *aliases in normalizedAppearances) {
                RCDiscoveryIconLayerStack *stack = nil;
                for (NSString *appearance in aliases) {
                    stack = [catalog iconLayerStackWithName:candidate
                                               scaleFactor:1.0
                                               deviceIdiom:0
                                             deviceSubtype:0
                                              displayGamut:0
                                            appearanceName:appearance
                                                    locale:nil];
                    if (stack != nil) {
                        break;
                    }
                }
                if (stack == nil) {
                    continue;
                }
                resolved = YES;
                for (id layer in [stack layers]) {
                    if (![layer isKindOfClass:NSClassFromString(@"CUINamedIconLayerGroup")]) {
                        continue;
                    }
                    RCDiscoveryIconLayerGroup *group = layer;
                    RCIconGeneration groupGeneration = RCMinimumIconGenerationForGroupRecord(@{
                        @"hasSpecular": @([group hasSpecular]),
                        @"specularPlacement": @([group specularPlacement]),
                        @"refractionHeight": @([group refractionHeight]),
                        @"refractionStrength": @([group refractionStrength])
                    });
                    generation = MAX(generation, groupGeneration);
                }
            }
        } @catch (NSException *exception) {
            if (error) {
                *error = RCDiscoveryError(
                    5,
                    [NSString stringWithFormat:@"Unable to classify %@: %@",
                     candidate, exception.reason ?: exception.name]
                );
            }
            dlclose(handle);
            return nil;
        }
        if (resolved) {
            [iconRecords addObject:@{
                @"name": candidate,
                @"minimumGeneration": @(generation)
            }];
        }
    }

    [iconRecords sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSString *leftName = left[@"name"];
        NSString *rightName = right[@"name"];
        NSComparisonResult insensitive = [leftName caseInsensitiveCompare:rightName];
        return insensitive == NSOrderedSame ? [leftName compare:rightName] : insensitive;
    }];
    dlclose(handle);
    return iconRecords;
}

NSArray<NSString *> *RCDiscoverIconStackNames(NSString *catalogPath, NSError **error) {
    NSArray<NSDictionary *> *records = RCDiscoverIconStackRecords(catalogPath, error);
    if (records == nil) {
        return nil;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:records.count];
    for (NSDictionary *record in records) {
        [names addObject:record[@"name"]];
    }
    return names;
}
