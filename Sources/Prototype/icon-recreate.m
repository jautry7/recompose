#import <Foundation/Foundation.h>

static id NullToNil(id value) {
    return value == [NSNull null] ? nil : value;
}

static NSString *ShortName(NSString *name) {
    NSRange slash = [name rangeOfString:@"/" options:NSBackwardsSearch];
    return slash.location == NSNotFound ? name : [name substringFromIndex:slash.location + 1];
}

static NSString *ColorSpaceToken(NSString *space) {
    NSDictionary *tokens = @{
        @"kCGColorSpaceDisplayP3": @"display-p3",
        @"kCGColorSpaceExtendedSRGB": @"extended-srgb",
        @"kCGColorSpaceSRGB": @"srgb",
        @"kCGColorSpaceExtendedGray": @"extended-gray",
        @"kCGColorSpaceGenericGrayGamma2_2": @"gray"
    };
    NSString *token = tokens[space];
    if (!token) {
        [NSException raise:@"UnsupportedColorSpace" format:@"Unsupported Core Graphics color space: %@", space];
    }
    return token;
}

static NSString *ColorString(NSDictionary *color) {
    if (!color) return nil;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSNumber *component in color[@"components"]) {
        [parts addObject:[NSString stringWithFormat:@"%.9g", component.doubleValue]];
    }
    return [NSString stringWithFormat:@"%@:%@", ColorSpaceToken(color[@"colorSpace"]),
            [parts componentsJoinedByString:@","]];
}

static id FillValue(NSDictionary *record) {
    NSDictionary *color = NullToNil(record[@"color"]);
    if (color) return @{ @"solid": ColorString(color) };

    NSDictionary *gradient = NullToNil(record[@"gradient"]);
    if (!gradient) return nil;
    NSArray *colors = gradient[@"colors"];
    if (colors.count != 2) {
        [NSException raise:@"UnsupportedGradient" format:@"Expected two gradient colors, found %lu",
         (unsigned long)colors.count];
    }
    return @{
        @"linear-gradient": @[ ColorString(colors[0]), ColorString(colors[1]) ],
        @"orientation": @{
            @"start": gradient[@"start"],
            @"stop": gradient[@"end"]
        }
    };
}

static NSDictionary *Specialization(NSString *appearance, id value) {
    return @{
        @"slot": @{ @"appearance": appearance },
        @"value": value ?: [NSNull null]
    };
}

static BOOL Same(id a, id b) {
    if (!a && !b) return YES;
    return a && b && [a isEqual:b];
}

static void AddSpecializable(NSMutableDictionary *destination,
                             NSString *key,
                             id base,
                             id dark,
                             id tinted) {
    base = NullToNil(base);
    dark = NullToNil(dark);
    tinted = NullToNil(tinted);
    if (base) destination[key] = base;
    BOOL darkDiffers = !Same(base, dark);
    BOOL tintedDiffers = !Same(base, tinted);
    NSMutableArray *variants = [NSMutableArray array];
    if (darkDiffers) [variants addObject:Specialization(@"dark", dark)];
    if (tintedDiffers) [variants addObject:Specialization(@"tinted", tinted)];
    if (variants.count > 0) {
        destination[[key stringByAppendingString:@"-specializations"]] = variants;
    }
}

static NSString *ShadowKind(NSNumber *raw) {
    switch (raw.integerValue) {
        case 2: return @"layer-color";
        case 3: return @"neutral";
        default:
            [NSException raise:@"UnsupportedShadowStyle" format:@"Unsupported CoreUI shadow style: %@", raw];
            return nil;
    }
}

static NSDictionary *ShadowValue(NSDictionary *group) {
    return @{
        @"kind": ShadowKind(group[@"shadowStyle"]),
        @"opacity": group[@"shadowOpacity"]
    };
}

static NSDictionary *RefractivityValue(NSDictionary *group) {
    double depth = [group[@"refractionHeight"] doubleValue];
    double strength = [group[@"refractionStrength"] doubleValue];
    return @{
        @"enabled": (depth != 0.0 || strength != 0.0) ? @YES : @NO,
        @"depth": group[@"refractionHeight"],
        @"strength": group[@"refractionStrength"]
    };
}

static NSDictionary *TranslucencyValue(NSDictionary *group) {
    double value = [group[@"translucency"] doubleValue];
    return @{ @"enabled": (value != 0.0) ? @YES : @NO, @"value": group[@"translucency"] };
}

static NSString *SpecularPlacement(NSNumber *raw) {
    switch (raw.integerValue) {
        case 0: return @"automatic";
        case 1: return @"inside";
        case 2: return @"outside";
        default:
            [NSException raise:@"UnsupportedSpecularPlacement" format:@"Unsupported placement: %@", raw];
            return nil;
    }
}

static NSString *BlendMode(NSNumber *raw) {
    switch (raw.integerValue) {
        case 0: return @"normal";
        case 1: return @"multiply";
        default:
            [NSException raise:@"UnsupportedBlendMode" format:@"Unsupported Core Graphics blend mode: %@", raw];
            return nil;
    }
}

static NSDictionary *PositionValue(NSDictionary *layer) {
    NSDictionary *frame = layer[@"frame"];
    NSDictionary *origin = frame[@"origin"];
    NSDictionary *size = frame[@"size"];
    double x = [origin[@"x"] doubleValue];
    double y = [origin[@"y"] doubleValue];
    double width = [size[@"width"] doubleValue];
    double height = [size[@"height"] doubleValue];
    if (x == 0.0 && y == 0.0 && width == 1024.0 && height == 1024.0) return nil;

    if (width != height) {
        [NSException raise:@"UnsupportedFrame" format:@"Expected a square layer frame: %@", frame];
    }
    double scale = width / 1024.0;

    double centerX = x + width / 2.0 - 512.0;
    double centerY = y + height / 2.0 - 512.0;
    return @{
        @"scale": @(scale),
        @"translation-in-points": @[ @(centerX), @(centerY) ]
    };
}

static NSDictionary *LayerValue(NSDictionary *base,
                                NSDictionary *dark,
                                NSDictionary *tinted) {
    NSMutableDictionary *layer = [NSMutableDictionary dictionary];
    layer[@"name"] = ShortName(base[@"name"]);
    layer[@"image-name"] = base[@"assetFile"];

    AddSpecializable(layer, @"opacity", base[@"opacity"], dark[@"opacity"], tinted[@"opacity"]);
    AddSpecializable(layer, @"blend-mode", BlendMode(base[@"blendMode"]),
                     BlendMode(dark[@"blendMode"]), BlendMode(tinted[@"blendMode"]));
    AddSpecializable(layer, @"glass", base[@"hasLightingEffects"],
                     dark[@"hasLightingEffects"], tinted[@"hasLightingEffects"]);
    AddSpecializable(layer, @"fill", FillValue(base), FillValue(dark), FillValue(tinted));
    AddSpecializable(layer, @"position", PositionValue(base), PositionValue(dark), PositionValue(tinted));
    return layer;
}

static NSDictionary *GroupValue(NSDictionary *base,
                                NSDictionary *dark,
                                NSDictionary *tinted) {
    NSArray *baseLayers = base[@"layers"];
    NSArray *darkLayers = dark[@"layers"];
    NSArray *tintedLayers = tinted[@"layers"];
    if (baseLayers.count != darkLayers.count || baseLayers.count != tintedLayers.count) {
        [NSException raise:@"LayerCountMismatch" format:@"Appearance layer counts differ in %@", base[@"name"]];
    }

    NSMutableArray *layers = [NSMutableArray arrayWithCapacity:baseLayers.count];
    // CoreUI's compiled stacks are back-to-front; Icon Composer documents list
    // members front-to-back.
    for (NSInteger index = (NSInteger)baseLayers.count - 1; index >= 0; index--) {
        NSDictionary *baseLayer = baseLayers[index];
        NSDictionary *darkLayer = darkLayers[index];
        NSDictionary *tintedLayer = tintedLayers[index];
        if (![baseLayer[@"name"] isEqual:darkLayer[@"name"]] ||
            ![baseLayer[@"name"] isEqual:tintedLayer[@"name"]]) {
            [NSException raise:@"LayerOrderMismatch" format:@"Layer order differs at index %lu",
             (unsigned long)index];
        }
        [layers addObject:LayerValue(baseLayer, darkLayer, tintedLayer)];
    }

    NSMutableDictionary *group = [NSMutableDictionary dictionary];
    group[@"name"] = ShortName(base[@"name"]);
    group[@"layers"] = layers;
    AddSpecializable(group, @"opacity", base[@"opacity"], dark[@"opacity"], tinted[@"opacity"]);
    AddSpecializable(group, @"refractivity", RefractivityValue(base),
                     RefractivityValue(dark), RefractivityValue(tinted));
    AddSpecializable(group, @"shadow", ShadowValue(base), ShadowValue(dark), ShadowValue(tinted));
    AddSpecializable(group, @"translucency", TranslucencyValue(base),
                     TranslucencyValue(dark), TranslucencyValue(tinted));
    AddSpecializable(group, @"specular-highlight-placement", SpecularPlacement(base[@"specularPlacement"]),
                     SpecularPlacement(dark[@"specularPlacement"]), SpecularPlacement(tinted[@"specularPlacement"]));
    AddSpecializable(group, @"lighting",
                     [base[@"gathersSpecularByElement"] boolValue] ? @"individual" : @"combined",
                     [dark[@"gathersSpecularByElement"] boolValue] ? @"individual" : @"combined",
                     [tinted[@"gathersSpecularByElement"] boolValue] ? @"individual" : @"combined");
    return group;
}

static NSData *ReadData(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) [NSException raise:@"ReadFailed" format:@"Could not read %@", path];
    return data;
}

static NSDictionary *ReadJSON(NSString *path) {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:ReadData(path) options:0 error:&error];
    if (!object || error) [NSException raise:@"JSONReadFailed" format:@"Could not parse %@: %@", path, error];
    return object;
}

static void WriteJSON(id object, NSString *path) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (!data || error) [NSException raise:@"JSONWriteFailed" format:@"Could not encode %@: %@", path, error];
    NSMutableData *withNewline = [data mutableCopy];
    [withNewline appendBytes:"\n" length:1];
    if (![withNewline writeToFile:path options:NSDataWritingAtomic error:&error]) {
        [NSException raise:@"WriteFailed" format:@"Could not write %@: %@", path, error];
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 4) {
            fprintf(stderr, "usage: %s MANIFEST_JSON EXTRACTED_ASSETS_DIR OUTPUT_ICON\n", argv[0]);
            return 64;
        }
        NSString *manifestPath = @(argv[1]);
        NSString *sourceAssets = @(argv[2]);
        NSString *outputIcon = @(argv[3]);
        NSFileManager *files = NSFileManager.defaultManager;
        if ([files fileExistsAtPath:outputIcon]) {
            fprintf(stderr, "refusing to overwrite existing output: %s\n", outputIcon.UTF8String);
            return 73;
        }

        NSDictionary *manifest = ReadJSON(manifestPath);
        NSDictionary *appearances = manifest[@"appearances"];
        NSDictionary *light = appearances[@"UIAppearanceLight"];
        NSDictionary *dark = appearances[@"UIAppearanceDark"];
        NSDictionary *tinted = appearances[@"ISAppearanceTintable"];
        if (!light || !dark || !tinted) {
            [NSException raise:@"MissingAppearance" format:@"Expected Light, Dark, and Tintable appearances"];
        }

        NSArray *lightRecords = light[@"layers"];
        NSArray *darkRecords = dark[@"layers"];
        NSArray *tintedRecords = tinted[@"layers"];
        if (lightRecords.count != darkRecords.count || lightRecords.count != tintedRecords.count || lightRecords.count < 2) {
            [NSException raise:@"AppearanceMismatch" format:@"Appearance stack shapes do not match"];
        }

        NSMutableArray *groups = [NSMutableArray array];
        // CoreUI's compiled group order is the reverse of icon.json's authoring order.
        for (NSInteger index = (NSInteger)lightRecords.count - 1; index >= 1; index--) {
            NSDictionary *baseGroup = lightRecords[index];
            NSDictionary *darkGroup = darkRecords[index];
            NSDictionary *tintedGroup = tintedRecords[index];
            if (![baseGroup[@"name"] isEqual:darkGroup[@"name"]] ||
                ![baseGroup[@"name"] isEqual:tintedGroup[@"name"]]) {
                [NSException raise:@"GroupOrderMismatch" format:@"Group order differs at index %lu",
                 (unsigned long)index];
            }
            [groups addObject:GroupValue(baseGroup, darkGroup, tintedGroup)];
        }

        NSMutableDictionary *icon = [@{
            @"features": @[ @"refractivity" ],
            @"groups": groups,
            @"supported-platforms": @{ @"circles": @[ @"watchOS" ], @"squares": @"shared" }
        } mutableCopy];
        AddSpecializable(icon, @"fill", FillValue(lightRecords[0]),
                         FillValue(darkRecords[0]), FillValue(tintedRecords[0]));

        NSError *error = nil;
        NSString *outputAssets = [outputIcon stringByAppendingPathComponent:@"Assets"];
        if (![files createDirectoryAtPath:outputAssets withIntermediateDirectories:YES attributes:nil error:&error]) {
            [NSException raise:@"DirectoryCreateFailed" format:@"Could not create %@: %@", outputAssets, error];
        }

        NSMutableSet<NSString *> *assetNames = [NSMutableSet set];
        for (NSDictionary *group in [lightRecords subarrayWithRange:NSMakeRange(1, lightRecords.count - 1)]) {
            for (NSDictionary *layer in group[@"layers"]) [assetNames addObject:layer[@"assetFile"]];
        }
        for (NSString *name in assetNames) {
            NSString *source = [sourceAssets stringByAppendingPathComponent:name];
            NSString *destination = [outputAssets stringByAppendingPathComponent:name];
            if (![files copyItemAtPath:source toPath:destination error:&error]) {
                [NSException raise:@"AssetCopyFailed" format:@"Could not copy %@: %@", name, error];
            }
        }

        WriteJSON(icon, [outputIcon stringByAppendingPathComponent:@"icon.json"]);
        NSString *companion = [[outputIcon stringByDeletingPathExtension]
                               stringByAppendingString:@".source-manifest.json"];
        if (![files copyItemAtPath:manifestPath toPath:companion error:&error]) {
            [NSException raise:@"ManifestCopyFailed" format:@"Could not copy source manifest: %@", error];
        }

        printf("created %s with %lu groups and %lu assets\n", outputIcon.UTF8String,
               (unsigned long)groups.count, (unsigned long)assetNames.count);
        printf("source manifest: %s\n", companion.UTF8String);
    }
    return 0;
}
