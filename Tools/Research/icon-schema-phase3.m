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
        if (![files copyItemAtPath:[sourceAssets stringByAppendingPathComponent:asset]
                            toPath:[assets stringByAppendingPathComponent:asset]
                             error:&error]) {
            [NSException raise:@"AssetCopyFailed" format:@"Could not copy %@: %@", asset, error];
        }
    }
    WriteJSON(icon, [package stringByAppendingPathComponent:@"icon.json"]);
}

static void CorrectPositionObject(NSMutableDictionary *position) {
    NSDictionary *translation = position[@"translation-in-points"];
    if (![translation isKindOfClass:NSDictionary.class]) return;
    NSNumber *x = translation[@"x"];
    NSNumber *y = translation[@"y"];
    if (!x || !y) [NSException raise:@"UnexpectedPosition" format:@"Unexpected translation: %@", translation];
    position[@"translation-in-points"] = @[ x, y ];
}

static void CorrectPositionsRecursively(id object) {
    if ([object isKindOfClass:NSMutableDictionary.class]) {
        NSMutableDictionary *dictionary = object;
        id position = dictionary[@"position"];
        if ([position isKindOfClass:NSMutableDictionary.class]) CorrectPositionObject(position);
        for (id value in dictionary.allValues) CorrectPositionsRecursively(value);
    } else if ([object isKindOfClass:NSMutableArray.class]) {
        for (id value in (NSMutableArray *)object) CorrectPositionsRecursively(value);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 7) {
            fprintf(stderr, "usage: %s BASELINE_JSON POSITION_JSON FULL_BASE_JSON FULL_JSON ASSETS OUTPUT_ROOT\n", argv[0]);
            return 64;
        }
        NSDictionary *baseline = ReadJSON(@(argv[1]));
        NSDictionary *positionSource = ReadJSON(@(argv[2]));
        NSDictionary *fullBase = ReadJSON(@(argv[3]));
        NSDictionary *full = ReadJSON(@(argv[4]));
        NSString *assets = @(argv[5]);
        NSString *root = @(argv[6]);
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:root
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error]) {
            [NSException raise:@"CreateFailed" format:@"Could not create %@: %@", root, error];
        }

        NSMutableDictionary *singlePosition = MutableCopyJSON(baseline);
        NSArray *sourceGroups = positionSource[@"groups"];
        NSMutableArray *candidateGroups = singlePosition[@"groups"];
        for (NSUInteger groupIndex = 0; groupIndex < sourceGroups.count; groupIndex++) {
            NSArray *sourceLayers = sourceGroups[groupIndex][@"layers"];
            NSMutableArray *candidateLayers = candidateGroups[groupIndex][@"layers"];
            for (NSUInteger layerIndex = 0; layerIndex < sourceLayers.count; layerIndex++) {
                id position = sourceLayers[layerIndex][@"position"];
                if (position) candidateLayers[layerIndex][@"position"] = [position mutableCopy];
            }
        }
        CorrectPositionsRecursively(singlePosition);
        CreatePackage(root, @"01-position-cgvector-array", singlePosition, assets);

        NSMutableDictionary *correctedBase = MutableCopyJSON(fullBase);
        CorrectPositionsRecursively(correctedBase);
        CreatePackage(root, @"02-full-base-corrected-position", correctedBase, assets);

        NSMutableDictionary *correctedFull = MutableCopyJSON(full);
        CorrectPositionsRecursively(correctedFull);
        CreatePackage(root, @"03-full-specializations-corrected-position", correctedFull, assets);
        printf("created three phase-three candidates in %s\n", root.UTF8String);
    }
    return 0;
}
