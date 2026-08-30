#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static BOOL IsRelevantClassName(NSString *name) {
    NSArray<NSString *> *needles = @[
        @"CUICatalog",
        @"CUIThemeRendition",
        @"CUINamedIcon",
        @"CUINamedLayer",
        @"CUINamedLookup",
        @"CUINamedImage",
        @"CUINamedVectorSVGImage",
        @"CUINamedColor",
        @"CUINamedGradient"
    ];
    for (NSString *needle in needles) {
        if ([name containsString:needle]) {
            return YES;
        }
    }
    return NO;
}

static NSArray<NSDictionary *> *MethodsForClass(Class cls) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray<NSDictionary *> *result = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        SEL selector = method_getName(methods[index]);
        const char *types = method_getTypeEncoding(methods[index]);
        [result addObject:@{
            @"name": NSStringFromSelector(selector),
            @"types": types ? [NSString stringWithUTF8String:types] : @""
        }];
    }
    free(methods);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] compare:right[@"name"]];
    }];
    return result;
}

static NSArray<NSDictionary *> *PropertiesForClass(Class cls) {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    NSMutableArray<NSDictionary *> *result = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        const char *name = property_getName(properties[index]);
        const char *attributes = property_getAttributes(properties[index]);
        [result addObject:@{
            @"name": name ? [NSString stringWithUTF8String:name] : @"",
            @"attributes": attributes ? [NSString stringWithUTF8String:attributes] : @""
        }];
    }
    free(properties);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] compare:right[@"name"]];
    }];
    return result;
}

static NSArray<NSDictionary *> *IvarsForClass(Class cls) {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    NSMutableArray<NSDictionary *> *result = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        const char *name = ivar_getName(ivars[index]);
        const char *type = ivar_getTypeEncoding(ivars[index]);
        [result addObject:@{
            @"name": name ? [NSString stringWithUTF8String:name] : @"",
            @"type": type ? [NSString stringWithUTF8String:type] : @""
        }];
    }
    free(ivars);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] compare:right[@"name"]];
    }];
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        const char *frameworkPath = "/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI";
        void *handle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            fprintf(stderr, "Unable to load CoreUI: %s\n", dlerror());
            return 1;
        }

        int classCount = objc_getClassList(NULL, 0);
        Class *classes = (Class *)calloc((size_t)classCount, sizeof(Class));
        classCount = objc_getClassList(classes, classCount);
        NSMutableArray<NSDictionary *> *records = [NSMutableArray array];

        for (int index = 0; index < classCount; index++) {
            Class cls = classes[index];
            NSString *name = NSStringFromClass(cls);
            if (!IsRelevantClassName(name)) {
                continue;
            }
            Class metaclass = object_getClass(cls);
            [records addObject:@{
                @"name": name,
                @"superclass": class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : [NSNull null],
                @"classMethods": MethodsForClass(metaclass),
                @"instanceMethods": MethodsForClass(cls),
                @"properties": PropertiesForClass(cls),
                @"ivars": IvarsForClass(cls)
            }];
        }
        free(classes);

        [records sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
            return [left[@"name"] compare:right[@"name"]];
        }];

        NSError *error = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (json == nil) {
            fprintf(stderr, "Unable to encode probe output: %s\n", error.localizedDescription.UTF8String);
            dlclose(handle);
            return 1;
        }
        fwrite(json.bytes, 1, json.length, stdout);
        fputc('\n', stdout);
        dlclose(handle);
    }
    return 0;
}
