#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSArray<NSDictionary *> *MethodsForClass(Class cls) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        const char *types = method_getTypeEncoding(methods[index]);
        [result addObject:@{
            @"name": NSStringFromSelector(method_getName(methods[index])),
            @"types": types ? [NSString stringWithUTF8String:types] : @""
        }];
    }
    free(methods);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] compare:right[@"name"]];
    }];
    return result;
}

int main(void) {
    @autoreleasepool {
        NSString *frameworkPath = @"/Applications/Icon Composer.app/Contents/Frameworks/IconComposerFoundation.framework/Versions/A/IconComposerFoundation";
        void *handle = dlopen(frameworkPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            fprintf(stderr, "Unable to load IconComposerFoundation: %s\n", dlerror());
            return 1;
        }

        int classCount = objc_getClassList(NULL, 0);
        Class *classes = (Class *)calloc((size_t)classCount, sizeof(Class));
        classCount = objc_getClassList(classes, classCount);
        NSMutableArray *records = [NSMutableArray array];
        for (int index = 0; index < classCount; index++) {
            Class cls = classes[index];
            const char *imageName = class_getImageName(cls);
            if (imageName == NULL || strstr(imageName, "IconComposerFoundation.framework") == NULL) {
                continue;
            }
            [records addObject:@{
                @"name": NSStringFromClass(cls),
                @"superclass": class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : [NSNull null],
                @"classMethods": MethodsForClass(object_getClass(cls)),
                @"instanceMethods": MethodsForClass(cls)
            }];
        }
        free(classes);
        [records sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
            return [left[@"name"] compare:right[@"name"]];
        }];

        NSError *error = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
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
