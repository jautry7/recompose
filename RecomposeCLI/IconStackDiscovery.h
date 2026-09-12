#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSArray<NSString *> * _Nullable RCDiscoverIconStackNames(NSString *catalogPath, NSError **error);
NSArray<NSDictionary *> * _Nullable RCDiscoverIconStackRecords(NSString *catalogPath, NSError **error);
NSDictionary * _Nullable RCDiscoverCatalogIconRecords(NSString *catalogPath, NSError **error);
NSString * _Nullable RCDiscoverCatalogCompilerVersion(NSString *catalogPath);

typedef NS_ENUM(NSInteger, RCIconPreviewAppearance) {
    RCIconPreviewAppearanceDefault,
    RCIconPreviewAppearanceDark,
    RCIconPreviewAppearanceTinted,
};

BOOL RCWriteIconPreview(NSString *catalogPath,
                        NSString *assetName,
                        NSString *outputPath,
                        RCIconPreviewAppearance previewAppearance,
                        NSError **error);

NS_ASSUME_NONNULL_END
