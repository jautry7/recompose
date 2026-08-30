#import <Foundation/Foundation.h>

static NSDictionary *ReadJSON(NSString *path) {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!data) [NSException raise:@"ReadFailed" format:@"Could not read %@: %@", path, error];
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!object) [NSException raise:@"ParseFailed" format:@"Could not parse %@: %@", path, error];
    return object;
}

static void WriteJSON(NSDictionary *object, NSString *path) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (!data) [NSException raise:@"EncodeFailed" format:@"Could not encode %@: %@", path, error];
    NSMutableData *terminated = [data mutableCopy];
    [terminated appendBytes:"\n" length:1];
    if (![terminated writeToFile:path options:NSDataWritingAtomic error:&error]) {
        [NSException raise:@"WriteFailed" format:@"Could not write %@: %@", path, error];
    }
}

static id RemovingSpecializations(id object) {
    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            (void)stop;
            if (![key hasSuffix:@"-specializations"]) result[key] = RemovingSpecializations(value);
        }];
        return result;
    }
    if ([object isKindOfClass:NSArray.class]) {
        NSMutableArray *result = [NSMutableArray array];
        for (id value in (NSArray *)object) [result addObject:RemovingSpecializations(value)];
        return result;
    }
    return object;
}

static NSArray<NSString *> *AssetNames(NSDictionary *icon) {
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *group in icon[@"groups"]) {
        for (NSDictionary *layer in group[@"layers"]) {
            NSString *name = layer[@"image-name"];
            if (name) [names addObject:name];
        }
    }
    return names.array;
}

static void CreatePackage(NSString *root,
                          NSString *name,
                          NSDictionary *icon,
                          NSString *sourceAssets,
                          NSArray<NSString *> *assets) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *package = [root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"icon"]];
    NSString *assetDirectory = [package stringByAppendingPathComponent:@"Assets"];
    NSError *error = nil;
    if ([files fileExistsAtPath:package]) {
        [NSException raise:@"RefuseOverwrite" format:@"Candidate already exists: %@", package];
    }
    if (![files createDirectoryAtPath:assetDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
        [NSException raise:@"CreateFailed" format:@"Could not create %@: %@", assetDirectory, error];
    }
    for (NSString *asset in assets) {
        NSString *source = [sourceAssets stringByAppendingPathComponent:asset];
        NSString *destination = [assetDirectory stringByAppendingPathComponent:asset];
        if (![files copyItemAtPath:source toPath:destination error:&error]) {
            [NSException raise:@"CopyFailed" format:@"Could not copy %@: %@", asset, error];
        }
    }
    WriteJSON(icon, [package stringByAppendingPathComponent:@"icon.json"]);
}

static NSDictionary *RootWithGroups(NSDictionary *templateIcon, NSArray *groups, NSDictionary *fill) {
    return @{
        @"features": templateIcon[@"features"],
        @"fill": fill,
        @"groups": groups,
        @"supported-platforms": templateIcon[@"supported-platforms"]
    };
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 6) {
            fprintf(stderr, "usage: %s KNOWN_GOOD_JSON RECREATED_JSON RECREATED_ASSETS OUTPUT_ROOT FIRST_ASSET\n", argv[0]);
            return 64;
        }
        NSString *knownPath = @(argv[1]);
        NSString *recreatedPath = @(argv[2]);
        NSString *assetRoot = @(argv[3]);
        NSString *outputRoot = @(argv[4]);
        NSString *firstAsset = @(argv[5]);
        NSDictionary *known = ReadJSON(knownPath);
        NSDictionary *recreated = ReadJSON(recreatedPath);

        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:outputRoot
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error]) {
            [NSException raise:@"CreateFailed" format:@"Could not create %@: %@", outputRoot, error];
        }

        NSDictionary *knownGroup = [known[@"groups"] firstObject];
        NSDictionary *singleLayer = @{ @"image-name": firstAsset, @"name": @"maps-extracted-control" };
        NSMutableDictionary *singleGroup = [NSMutableDictionary dictionary];
        singleGroup[@"layers"] = @[ singleLayer ];
        for (NSString *key in @[ @"blur-material", @"refractivity", @"shadow", @"translucency" ]) {
            id value = knownGroup[key];
            if (value) singleGroup[key] = value;
            else if ([knownGroup.allKeys containsObject:key]) singleGroup[key] = [NSNull null];
        }
        NSDictionary *single = RootWithGroups(known, @[ singleGroup ], known[@"fill"]);
        CreatePackage(outputRoot, @"01-single-extracted-safe-schema", single, assetRoot, @[ firstAsset ]);

        NSMutableArray *safeGroups = [NSMutableArray array];
        for (NSDictionary *sourceGroup in recreated[@"groups"]) {
            NSMutableArray *layers = [NSMutableArray array];
            for (NSDictionary *sourceLayer in sourceGroup[@"layers"]) {
                [layers addObject:@{
                    @"image-name": sourceLayer[@"image-name"],
                    @"name": sourceLayer[@"name"]
                }];
            }
            NSMutableDictionary *group = [NSMutableDictionary dictionary];
            group[@"layers"] = layers;
            for (NSString *key in @[ @"refractivity", @"shadow", @"translucency" ]) group[key] = knownGroup[key];
            [safeGroups addObject:group];
        }
        NSDictionary *allSafe = RootWithGroups(known, safeGroups, known[@"fill"]);
        CreatePackage(outputRoot, @"02-all-extracted-safe-schema", allSafe, assetRoot, AssetNames(recreated));

        NSMutableArray *baseKnownKeyGroups = [NSMutableArray array];
        for (NSDictionary *sourceGroup in recreated[@"groups"]) {
            NSMutableArray *layers = [NSMutableArray array];
            for (NSDictionary *sourceLayer in sourceGroup[@"layers"]) {
                [layers addObject:@{
                    @"image-name": sourceLayer[@"image-name"],
                    @"name": sourceLayer[@"name"],
                    @"opacity": sourceLayer[@"opacity"]
                }];
            }
            [baseKnownKeyGroups addObject:@{
                @"layers": layers,
                @"refractivity": sourceGroup[@"refractivity"],
                @"shadow": sourceGroup[@"shadow"],
                @"translucency": sourceGroup[@"translucency"]
            }];
        }
        NSDictionary *baseKnownKeys = RootWithGroups(known, baseKnownKeyGroups, recreated[@"fill"]);
        CreatePackage(outputRoot, @"03-maps-base-known-keys", baseKnownKeys, assetRoot, AssetNames(recreated));

        NSDictionary *baseAllKeys = RemovingSpecializations(recreated);
        CreatePackage(outputRoot, @"04-maps-base-all-keys", baseAllKeys, assetRoot, AssetNames(recreated));
        CreatePackage(outputRoot, @"05-maps-full-specializations", recreated, assetRoot, AssetNames(recreated));

        printf("created five diagnostic candidates in %s\n", outputRoot.UTF8String);
    }
    return 0;
}
