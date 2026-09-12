#import <Foundation/Foundation.h>

#import <unistd.h>

#import "IconExtractor.h"
#import "IconAssembler.h"
#import "IconStackDiscovery.h"

static const int RCUsageExit = 64;
static const int RCSelectionExit = 65;
static const int RCNoIconExit = 66;
static const int RCOutputExit = 73;

static void PrintUsage(void) {
    fprintf(stderr,
            "usage:\n"
            "  recompose Assets.car [--asset NAME] [--output OUTPUT.icon] [--generation 26|27]\n"
            "  recompose reconstruct Assets.car [--asset NAME] [--output OUTPUT.icon] [--generation 26|27]\n"
            "  recompose extract Assets.car [--asset NAME] [--output DIRECTORY]\n"
            "  recompose assemble DIRECTORY [--output OUTPUT.icon] [--generation 26|27]\n"
            "  recompose list Assets.car [--json]\n");
}

static NSString *SanitizeOutputName(NSString *name) {
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString:@"._-"];
    NSMutableString *result = [NSMutableString stringWithCapacity:name.length];
    for (NSUInteger index = 0; index < name.length; index++) {
        unichar character = [name characterAtIndex:index];
        [result appendString:[allowed characterIsMember:character]
            ? [NSString stringWithCharacters:&character length:1]
            : @"_"];
    }
    return result.length > 0 ? result : @"icon";
}

static BOOL WriteJSON(id object) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (data == nil) {
        fprintf(stderr, "Unable to encode JSON: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    return YES;
}

static NSArray<NSString *> *Discover(NSString *catalogPath) {
    NSError *error = nil;
    NSArray<NSString *> *names = RCDiscoverIconStackNames(catalogPath, &error);
    if (names == nil) {
        fprintf(stderr, "Unable to inspect catalog: %s\n", error.localizedDescription.UTF8String);
    }
    return names;
}

static NSDictionary *DiscoverCatalogRecords(NSString *catalogPath) {
    NSError *error = nil;
    NSDictionary *records = RCDiscoverCatalogIconRecords(catalogPath, &error);
    if (records == nil) {
        fprintf(stderr, "Unable to inspect catalog: %s\n", error.localizedDescription.UTF8String);
    }
    return records;
}

static NSString *SelectAsset(NSArray<NSString *> *names, NSString *requestedName) {
    if (requestedName.length > 0) {
        if ([names containsObject:requestedName]) {
            return requestedName;
        }
        fprintf(stderr, "No icon stack named %s was found.\n", requestedName.UTF8String);
        if (names.count > 0) {
            fprintf(stderr, "Available icon stacks:\n");
            for (NSString *name in names) {
                fprintf(stderr, "  %s\n", name.UTF8String);
            }
        }
        return nil;
    }

    if (names.count == 0) {
        fprintf(stderr, "No icon stacks were found.\n");
        return nil;
    }
    if (names.count == 1) {
        return names.firstObject;
    }
    if (!isatty(STDIN_FILENO)) {
        fprintf(stderr, "Multiple icon stacks were found; specify one with --asset NAME:\n");
        for (NSString *name in names) {
            fprintf(stderr, "  %s\n", name.UTF8String);
        }
        return nil;
    }

    fprintf(stderr, "Multiple icon stacks were found:\n");
    for (NSUInteger index = 0; index < names.count; index++) {
        fprintf(stderr, "  %lu. %s\n", (unsigned long)index + 1, names[index].UTF8String);
    }
    fprintf(stderr, "Choose an icon [1-%lu]: ", (unsigned long)names.count);
    fflush(stderr);

    char buffer[64] = {0};
    if (fgets(buffer, sizeof(buffer), stdin) == NULL) {
        fprintf(stderr, "No selection received.\n");
        return nil;
    }
    char *end = NULL;
    long selection = strtol(buffer, &end, 10);
    if (selection < 1 || selection > (long)names.count) {
        fprintf(stderr, "Invalid selection.\n");
        return nil;
    }
    return names[(NSUInteger)selection - 1];
}

static NSString *ManifestAssetName(NSString *extractionDirectory) {
    NSString *manifestPath = [extractionDirectory stringByAppendingPathComponent:@"manifest.json"];
    NSData *data = [NSData dataWithContentsOfFile:manifestPath];
    if (data == nil) {
        return nil;
    }
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![manifest isKindOfClass:[NSDictionary class]] ||
        ![manifest[@"formatVersion"] isEqual:@1]) {
        return nil;
    }
    id assetName = manifest[@"source"][@"assetName"];
    return [assetName isKindOfClass:[NSString class]] && [assetName length] > 0 ? assetName : nil;
}

static int RunList(NSString *catalogPath, BOOL json) {
    NSDictionary *catalogRecords = DiscoverCatalogRecords(catalogPath);
    if (catalogRecords == nil) {
        return 1;
    }
    NSArray<NSDictionary *> *records = catalogRecords[@"iconStacks"];
    if (json) {
        NSMutableDictionary *response = [@{
            @"formatVersion": @1,
            @"iconStacks": records,
            @"traditionalBitmapIcons": catalogRecords[@"traditionalBitmapIcons"]
        } mutableCopy];
        NSString *compilerVersion = RCDiscoverCatalogCompilerVersion(catalogPath);
        if (compilerVersion.length > 0) {
            response[@"compilerVersion"] = compilerVersion;
        }
        return WriteJSON(response) ? 0 : 1;
    }
    if (records.count == 0) {
        printf("No icon stacks found.\n");
        return 0;
    }
    for (NSUInteger index = 0; index < records.count; index++) {
        NSDictionary *record = records[index];
        printf("%lu. %s (%ld)\n", (unsigned long)index + 1,
               [record[@"name"] UTF8String],
               (long)[record[@"minimumGeneration"] integerValue]);
    }
    return 0;
}

static int RunInternalPreview(NSString *catalogPath,
                              NSString *assetName,
                              NSString *outputPath,
                              NSString *appearanceName) {
    RCIconPreviewAppearance appearance = RCIconPreviewAppearanceDefault;
    if ([appearanceName isEqualToString:@"dark"]) {
        appearance = RCIconPreviewAppearanceDark;
    } else if ([appearanceName isEqualToString:@"tinted"]) {
        appearance = RCIconPreviewAppearanceTinted;
    } else if (appearanceName.length > 0 && ![appearanceName isEqualToString:@"default"]) {
        fprintf(stderr, "_preview appearance must be default, dark, or tinted.\n");
        return RCUsageExit;
    }

    NSError *error = nil;
    if (!RCWriteIconPreview(catalogPath, assetName, outputPath, appearance, &error)) {
        fprintf(stderr, "Unable to render icon preview: %s\n", error.localizedDescription.UTF8String);
        return 1;
    }
    return 0;
}

static int RunExtract(NSString *catalogPath, NSString *assetName, NSString *outputPath) {
    NSArray<NSString *> *names = Discover(catalogPath);
    if (names == nil) {
        return 1;
    }
    NSString *selected = SelectAsset(names, assetName);
    if (selected == nil) {
        return names.count == 0 ? RCNoIconExit : RCSelectionExit;
    }

    NSString *destination = outputPath;
    if (destination.length == 0) {
        destination = [[[NSFileManager defaultManager] currentDirectoryPath]
            stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-extracted", SanitizeOutputName(selected)]];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
        fprintf(stderr, "Refusing to overwrite existing output: %s\n", destination.UTF8String);
        return RCOutputExit;
    }
    int status = RCExtractIcon(catalogPath, selected, destination);
    if (status == 0) {
        printf("extracted %s to %s\n", selected.UTF8String, destination.UTF8String);
    }
    return status;
}

static int RunAssemble(NSString *extractionDirectory,
                       NSString *outputPath,
                       RCIconGeneration generation) {
    NSString *assetName = ManifestAssetName(extractionDirectory);
    if (assetName.length == 0) {
        fprintf(stderr, "The extraction directory does not contain a supported manifest.json.\n");
        return 1;
    }
    NSString *destination = outputPath;
    if (destination.length == 0) {
        destination = [[[NSFileManager defaultManager] currentDirectoryPath]
            stringByAppendingPathComponent:[SanitizeOutputName(assetName) stringByAppendingPathExtension:@"icon"]];
    }
    NSString *manifestPath = [extractionDirectory stringByAppendingPathComponent:@"manifest.json"];
    NSString *assetsPath = [extractionDirectory stringByAppendingPathComponent:@"Assets"];
    return RCAssembleIcon(manifestPath, assetsPath, destination, generation);
}

static int RunReconstruct(NSString *catalogPath,
                          NSString *assetName,
                          NSString *outputPath,
                          RCIconGeneration generation) {
    NSArray<NSString *> *names = Discover(catalogPath);
    if (names == nil) {
        return 1;
    }
    NSString *selected = SelectAsset(names, assetName);
    if (selected == nil) {
        return names.count == 0 ? RCNoIconExit : RCSelectionExit;
    }

    NSString *destination = outputPath;
    if (destination.length == 0) {
        destination = [[[NSFileManager defaultManager] currentDirectoryPath]
            stringByAppendingPathComponent:[SanitizeOutputName(selected) stringByAppendingPathExtension:@"icon"]];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
        fprintf(stderr, "Refusing to overwrite existing output: %s\n", destination.UTF8String);
        return RCOutputExit;
    }

    NSFileManager *files = NSFileManager.defaultManager;
    NSString *workspace = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"recompose-cli-%@", NSUUID.UUID.UUIDString]];
    NSString *extraction = [workspace stringByAppendingPathComponent:@"extracted"];
    NSError *error = nil;
    if (![files createDirectoryAtPath:workspace withIntermediateDirectories:YES attributes:nil error:&error]) {
        fprintf(stderr, "Unable to create temporary workspace: %s\n", error.localizedDescription.UTF8String);
        return 1;
    }

    int status = 1;
    @try {
        status = RCExtractIcon(catalogPath, selected, extraction);
        if (status == 0) {
            status = RCAssembleIcon(
                [extraction stringByAppendingPathComponent:@"manifest.json"],
                [extraction stringByAppendingPathComponent:@"Assets"],
                destination,
                generation
            );
        }
    } @finally {
        if (![files removeItemAtPath:workspace error:&error]) {
            fprintf(stderr, "Warning: unable to remove temporary workspace: %s\n", error.localizedDescription.UTF8String);
        }
    }
    return status;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        @try {
            if (argc < 2) {
                PrintUsage();
                return RCUsageExit;
            }

            NSString *first = @(argv[1]);
            if ([first isEqualToString:@"--help"] || [first isEqualToString:@"-h"]) {
                PrintUsage();
                return 0;
            }

            NSSet<NSString *> *commands = [NSSet setWithArray:@[@"list", @"extract", @"assemble", @"reconstruct", @"_preview"]];
            BOOL explicitCommand = [commands containsObject:first];
            NSString *command = explicitCommand ? first : @"reconstruct";
            NSInteger inputIndex = explicitCommand ? 2 : 1;
            if (argc <= inputIndex) {
                PrintUsage();
                return RCUsageExit;
            }

            NSString *inputPath = @(argv[inputIndex]);
            NSString *assetName = nil;
            NSString *outputPath = nil;
            NSString *previewAppearanceName = nil;
            RCIconGeneration generation = RCIconGenerationAutomatic;
            BOOL generationSpecified = NO;
            BOOL json = NO;
            for (NSInteger index = inputIndex + 1; index < argc; index++) {
                NSString *argument = @(argv[index]);
                if ([argument isEqualToString:@"--json"]) {
                    json = YES;
                } else if ([argument isEqualToString:@"--asset"] ||
                           [argument isEqualToString:@"--output"] ||
                           [argument isEqualToString:@"--appearance"] ||
                           [argument isEqualToString:@"--generation"]) {
                    if (++index >= argc) {
                        fprintf(stderr, "%s requires a value.\n", argument.UTF8String);
                        return RCUsageExit;
                    }
                    if ([argument isEqualToString:@"--asset"]) {
                        assetName = @(argv[index]);
                    } else if ([argument isEqualToString:@"--appearance"]) {
                        previewAppearanceName = @(argv[index]);
                    } else if ([argument isEqualToString:@"--generation"]) {
                        generationSpecified = YES;
                        NSString *value = @(argv[index]);
                        if ([value isEqualToString:@"26"]) {
                            generation = RCIconGeneration26;
                        } else if ([value isEqualToString:@"27"]) {
                            generation = RCIconGeneration27;
                        } else {
                            fprintf(stderr, "--generation must be 26 or 27.\n");
                            return RCUsageExit;
                        }
                    } else {
                        outputPath = @(argv[index]);
                    }
                } else {
                    fprintf(stderr, "Unknown option: %s\n", argument.UTF8String);
                    return RCUsageExit;
                }
            }

            if ([command isEqualToString:@"list"]) {
                if (assetName || outputPath || previewAppearanceName || generationSpecified) {
                    fprintf(stderr, "list accepts only the --json option.\n");
                    return RCUsageExit;
                }
                return RunList(inputPath, json);
            }
            if (json) {
                fprintf(stderr, "--json is available only with list.\n");
                return RCUsageExit;
            }
            if ([command isEqualToString:@"_preview"]) {
                if (assetName.length == 0 || outputPath.length == 0 || generationSpecified) {
                    fprintf(stderr, "_preview requires --asset NAME and --output OUTPUT.png; --appearance is optional.\n");
                    return RCUsageExit;
                }
                return RunInternalPreview(inputPath, assetName, outputPath, previewAppearanceName);
            }
            if ([command isEqualToString:@"extract"]) {
                if (generationSpecified || previewAppearanceName) {
                    fprintf(stderr, "extract does not accept --generation.\n");
                    return RCUsageExit;
                }
                return RunExtract(inputPath, assetName, outputPath);
            }
            if ([command isEqualToString:@"assemble"]) {
                if (assetName || previewAppearanceName) {
                    fprintf(stderr, "assemble does not accept --asset; the asset is recorded in manifest.json.\n");
                    return RCUsageExit;
                }
                return RunAssemble(inputPath, outputPath, generation);
            }
            if (previewAppearanceName) {
                fprintf(stderr, "--appearance is available only with the internal preview command.\n");
                return RCUsageExit;
            }
            return RunReconstruct(inputPath, assetName, outputPath, generation);
        } @catch (NSException *exception) {
            fprintf(stderr, "%s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
            return 1;
        }
    }
}
