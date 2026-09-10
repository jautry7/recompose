#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RCIconGeneration) {
    RCIconGeneration26 = 26,
    RCIconGeneration27 = 27
};

int RCAssembleIcon(NSString *manifestPath,
                   NSString *sourceAssets,
                   NSString *outputIcon,
                   RCIconGeneration generation);

NS_ASSUME_NONNULL_END
