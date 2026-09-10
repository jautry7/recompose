#import "IconStackDiscovery.h"
#import "IconAssembler.h"

#import <dlfcn.h>

static NSString *const RCDiscoveryErrorDomain = @"RecomposeDiscovery";

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
@end

@interface RCDiscoveryIconLayerGroup : NSObject
- (BOOL)hasSpecular;
- (double)refractionHeight;
- (double)refractionStrength;
- (NSInteger)specularPlacement;
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
