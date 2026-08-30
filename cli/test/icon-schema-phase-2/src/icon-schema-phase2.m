#import <Foundation/Foundation.h>

static NSDictionary *ReadJSON(NSString *path) {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!data) [NSException raise:@"ReadFailed" format:@"Could not read %@: %@", path, error];
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!object) [NSException raise:@"ParseFailed" format:@"Could not parse %@: %@", path, error];
    return object;
}

static NSMutableDictionary *MutableCopyJSON(NSDictionary *object) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    id copy = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (!copy) [NSException raise:@"CopyFailed" format:@"Could not copy JSON: %@", error];
    return copy;
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

static NSArray<NSString *> *AssetNames(NSDictionary *icon) {
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *group in icon[@"groups"]) {
        for (NSDictionary *layer in group[@"layers"]) [names addObject:layer[@"image-name"]];
    }
    return names.array;
}

static void CreatePackage(NSString *root,
                          NSString *name,
                          NSDictionary *icon,
                          NSString *sourceAssets) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *package = [root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"icon"]];
    NSString *assets = [package stringByAppendingPathComponent:@"Assets"];
    NSError *error = nil;
    if ([files fileExistsAtPath:package]) {
        [NSException raise:@"RefuseOverwrite" format:@"Candidate already exists: %@", package];
    }
    if (![files createDirectoryAtPath:assets withIntermediateDirectories:YES attributes:nil error:&error]) {
        [NSException raise:@"CreateFailed" format:@"Could not create %@: %@", assets, error];
    }
    for (NSString *asset in AssetNames(icon)) {
        NSString *source = [sourceAssets stringByAppendingPathComponent:asset];
        NSString *destination = [assets stringByAppendingPathComponent:asset];
        if (![files copyItemAtPath:source toPath:destination error:&error]) {
            [NSException raise:@"AssetCopyFailed" format:@"Could not copy %@: %@", asset, error];
        }
    }
    WriteJSON(icon, [package stringByAppendingPathComponent:@"icon.json"]);
}

static NSDictionary *AddingGroupKey(NSDictionary *baseline,
                                    NSDictionary *source,
                                    NSString *key) {
    NSMutableDictionary *candidate = MutableCopyJSON(baseline);
    NSMutableArray *candidateGroups = candidate[@"groups"];
    NSArray *sourceGroups = source[@"groups"];
    for (NSUInteger index = 0; index < candidateGroups.count; index++) {
        id value = sourceGroups[index][key];
        if (value) candidateGroups[index][key] = value;
    }
    return candidate;
}

static NSDictionary *AddingLayerKey(NSDictionary *baseline,
                                    NSDictionary *source,
                                    NSString *key) {
    NSMutableDictionary *candidate = MutableCopyJSON(baseline);
    NSMutableArray *candidateGroups = candidate[@"groups"];
    NSArray *sourceGroups = source[@"groups"];
    for (NSUInteger groupIndex = 0; groupIndex < candidateGroups.count; groupIndex++) {
        NSMutableArray *candidateLayers = candidateGroups[groupIndex][@"layers"];
        NSArray *sourceLayers = sourceGroups[groupIndex][@"layers"];
        for (NSUInteger layerIndex = 0; layerIndex < candidateLayers.count; layerIndex++) {
            id value = sourceLayers[layerIndex][key];
            if (value) candidateLayers[layerIndex][key] = value;
        }
    }
    return candidate;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 5) {
            fprintf(stderr, "usage: %s BASELINE_JSON FULL_BASE_JSON ASSETS OUTPUT_ROOT\n", argv[0]);
            return 64;
        }
        NSDictionary *baseline = ReadJSON(@(argv[1]));
        NSDictionary *fullBase = ReadJSON(@(argv[2]));
        NSString *assets = @(argv[3]);
        NSString *root = @(argv[4]);
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:root
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error]) {
            [NSException raise:@"CreateFailed" format:@"Could not create %@: %@", root, error];
        }

        NSArray<NSArray<NSString *> *> *groupTests = @[
            @[ @"01-group-name", @"name" ],
            @[ @"02-group-opacity", @"opacity" ],
            @[ @"03-group-specular-placement", @"specular-highlight-placement" ],
            @[ @"04-group-lighting", @"lighting" ]
        ];
        for (NSArray<NSString *> *test in groupTests) {
            CreatePackage(root, test[0], AddingGroupKey(baseline, fullBase, test[1]), assets);
        }

        NSArray<NSArray<NSString *> *> *layerTests = @[
            @[ @"05-layer-blend-mode", @"blend-mode" ],
            @[ @"06-layer-glass", @"glass" ],
            @[ @"07-layer-fill", @"fill" ],
            @[ @"08-layer-position", @"position" ]
        ];
        for (NSArray<NSString *> *test in layerTests) {
            CreatePackage(root, test[0], AddingLayerKey(baseline, fullBase, test[1]), assets);
        }
        printf("created eight phase-two candidates in %s\n", root.UTF8String);
    }
    return 0;
}
