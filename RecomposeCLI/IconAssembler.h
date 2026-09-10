#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RCIconGeneration) {
    RCIconGenerationAutomatic = 0,
    RCIconGeneration26 = 26,
    RCIconGeneration27 = 27
};

RCIconGeneration RCMinimumIconGenerationForGroupRecord(NSDictionary *group);
RCIconGeneration RCMinimumIconGenerationForManifest(NSDictionary *manifest);

int RCAssembleIcon(NSString *manifestPath,
                   NSString *sourceAssets,
                   NSString *outputIcon,
                   RCIconGeneration generation);

NS_ASSUME_NONNULL_END
