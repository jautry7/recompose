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
            "  recompose Assets.car [--asset NAME] [--output OUTPUT.icon]\n"
            "  recompose reconstruct Assets.car [--asset NAME] [--output OUTPUT.icon]\n"
            "  recompose extract Assets.car [--asset NAME] [--output DIRECTORY]\n"
            "  recompose assemble DIRECTORY [--output OUTPUT.icon]\n"
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
    NSArray<NSString *> *names = Discover(catalogPath);
    if (names == nil) {
        return 1;
    }
    if (json) {
        NSMutableArray *records = [NSMutableArray arrayWithCapacity:names.count];
        for (NSString *name in names) {
            [records addObject:@{@"name": name}];
        }
        return WriteJSON(@{@"formatVersion": @1, @"iconStacks": records}) ? 0 : 1;
    }
    if (names.count == 0) {
        printf("No icon stacks found.\n");
        return 0;
    }
    for (NSUInteger index = 0; index < names.count; index++) {
        printf("%lu. %s\n", (unsigned long)index + 1, names[index].UTF8String);
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

static int RunAssemble(NSString *extractionDirectory, NSString *outputPath) {
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
    return RCAssembleIcon(manifestPath, assetsPath, destination);
}

static int RunReconstruct(NSString *catalogPath, NSString *assetName, NSString *outputPath) {
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
                destination
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

            NSSet<NSString *> *commands = [NSSet setWithArray:@[@"list", @"extract", @"assemble", @"reconstruct"]];
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
            BOOL json = NO;
            for (NSInteger index = inputIndex + 1; index < argc; index++) {
                NSString *argument = @(argv[index]);
                if ([argument isEqualToString:@"--json"]) {
                    json = YES;
                } else if ([argument isEqualToString:@"--asset"] || [argument isEqualToString:@"--output"]) {
                    if (++index >= argc) {
                        fprintf(stderr, "%s requires a value.\n", argument.UTF8String);
                        return RCUsageExit;
                    }
                    if ([argument isEqualToString:@"--asset"]) {
                        assetName = @(argv[index]);
                    } else {
                        outputPath = @(argv[index]);
                    }
                } else {
                    fprintf(stderr, "Unknown option: %s\n", argument.UTF8String);
                    return RCUsageExit;
                }
            }

            if ([command isEqualToString:@"list"]) {
                if (assetName || outputPath) {
                    fprintf(stderr, "list accepts only the --json option.\n");
                    return RCUsageExit;
                }
                return RunList(inputPath, json);
            }
            if (json) {
                fprintf(stderr, "--json is available only with list.\n");
                return RCUsageExit;
            }
            if ([command isEqualToString:@"extract"]) {
                return RunExtract(inputPath, assetName, outputPath);
            }
            if ([command isEqualToString:@"assemble"]) {
                if (assetName) {
                    fprintf(stderr, "assemble does not accept --asset; the asset is recorded in manifest.json.\n");
                    return RCUsageExit;
                }
                return RunAssemble(inputPath, outputPath);
            }
            return RunReconstruct(inputPath, assetName, outputPath);
        } @catch (NSException *exception) {
            fprintf(stderr, "%s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
            return 1;
        }
    }
}
