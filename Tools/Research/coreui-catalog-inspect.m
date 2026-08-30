#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

@interface CoreUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)appearanceNames;
- (NSArray<NSString *> *)allImageNames;
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
- (id)_rendition;
@end

@interface CoreUIThemeRendition : NSObject
- (NSData *)data;
- (NSData *)srcData;
- (NSString *)utiType;
- (NSDictionary *)properties;
@end

static NSDictionary *DescribeLookup(id lookup) {
    if (lookup == nil) {
        return @{};
    }
    NSMutableDictionary *record = [@{
        @"class": NSStringFromClass([lookup class]),
        @"name": [lookup respondsToSelector:@selector(name)] ? ([lookup name] ?: @"") : @"",
        @"renditionName": [lookup respondsToSelector:@selector(renditionName)] ? ([lookup renditionName] ?: @"") : @"",
        @"appearance": [lookup respondsToSelector:@selector(appearance)] ? ([lookup appearance] ?: @"") : @""
    } mutableCopy];

    if ([lookup respondsToSelector:@selector(_rendition)]) {
        id rendition = [lookup _rendition];
        if (rendition != nil) {
            NSData *data = [rendition respondsToSelector:@selector(data)] ? [rendition data] : nil;
            NSData *sourceData = [rendition respondsToSelector:@selector(srcData)] ? [rendition srcData] : nil;
            record[@"renditionClass"] = NSStringFromClass([rendition class]);
            record[@"dataLength"] = @(data.length);
            record[@"sourceDataLength"] = @(sourceData.length);
            if ([rendition respondsToSelector:@selector(utiType)]) {
                record[@"utiType"] = [rendition utiType] ?: @"";
            }
            if ([rendition respondsToSelector:@selector(properties)]) {
                id properties = [rendition properties];
                record[@"propertyKeys"] = [properties isKindOfClass:[NSDictionary class]] ? [[properties allKeys] sortedArrayUsingSelector:@selector(compare:)] : @[];
            }
        }
    }

    if ([lookup respondsToSelector:@selector(layers)]) {
        NSArray *layers = [lookup valueForKey:@"layers"];
        NSMutableArray *children = [NSMutableArray arrayWithCapacity:layers.count];
        for (id layer in layers) {
            [children addObject:DescribeLookup(layer)];
        }
        record[@"layers"] = children;
    }
    return record;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "usage: coreui-catalog-inspect Assets.car asset-name\n");
            return 64;
        }

        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            fprintf(stderr, "Unable to load CoreUI: %s\n", dlerror());
            return 1;
        }

        NSString *catalogPath = [NSString stringWithUTF8String:argv[1]];
        NSString *assetName = [NSString stringWithUTF8String:argv[2]];
        NSError *error = nil;
        Class catalogClass = NSClassFromString(@"CUICatalog");
        CoreUICatalog *catalog = [[catalogClass alloc] initWithURL:[NSURL fileURLWithPath:catalogPath] error:&error];
        if (catalog == nil) {
            fprintf(stderr, "Unable to open catalog: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }

        NSArray<NSString *> *appearances = [catalog appearanceNames] ?: @[];
        NSMutableDictionary *stacks = [NSMutableDictionary dictionary];
        for (NSString *appearance in appearances) {
            id stack = [catalog iconLayerStackWithName:assetName
                                           scaleFactor:1.0
                                           deviceIdiom:0
                                         deviceSubtype:0
                                          displayGamut:0
                                        appearanceName:appearance
                                                locale:nil];
            stacks[appearance] = stack ? DescribeLookup(stack) : [NSNull null];
        }

        NSDictionary *output = @{
            @"appearances": appearances,
            @"imageNameCount": @([catalog allImageNames].count),
            @"stacks": stacks
        };
        NSData *json = [NSJSONSerialization dataWithJSONObject:output options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (json == nil) {
            fprintf(stderr, "Unable to encode output: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }
        fwrite(json.bytes, 1, json.length, stdout);
        fputc('\n', stdout);
        dlclose(handle);
    }
    return 0;
}
