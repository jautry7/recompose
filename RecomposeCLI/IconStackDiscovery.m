#import "IconStackDiscovery.h"

#import <dlfcn.h>

static NSString *const RCDiscoveryErrorDomain = @"RecomposeDiscovery";

@interface RCDiscoveryCatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)appearanceNames;
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

static NSError *RCDiscoveryError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:RCDiscoveryErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
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

NSArray<NSString *> *RCDiscoverIconStackNames(NSString *catalogPath, NSError **error) {
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

    NSMutableOrderedSet<NSString *> *appearanceNames = [NSMutableOrderedSet orderedSetWithArray:@[
        @"UIAppearanceLight",
        @"NSAppearanceNameAqua",
        @"UIAppearanceDark",
        @"NSAppearanceNameDarkAqua",
        @"ISAppearanceTintable"
    ]];
    for (NSString *appearance in [catalog appearanceNames] ?: @[]) {
        if (appearance.length > 0) {
            [appearanceNames addObject:appearance];
        }
    }

    NSMutableArray<NSString *> *iconNames = [NSMutableArray array];
    for (NSString *candidate in candidates) {
        BOOL resolved = NO;
        for (NSString *appearance in appearanceNames) {
            id stack = [catalog iconLayerStackWithName:candidate
                                           scaleFactor:1.0
                                           deviceIdiom:0
                                         deviceSubtype:0
                                          displayGamut:0
                                        appearanceName:appearance
                                                locale:nil];
            if (stack != nil) {
                resolved = YES;
                break;
            }
        }
        if (resolved) {
            [iconNames addObject:candidate];
        }
    }

    [iconNames sortUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        NSComparisonResult insensitive = [left caseInsensitiveCompare:right];
        return insensitive == NSOrderedSame ? [left compare:right] : insensitive;
    }];
    dlclose(handle);
    return iconNames;
}
