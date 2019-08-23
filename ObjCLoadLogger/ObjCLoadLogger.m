//
//  ObjCLoadLogger.m
//  ObjCLoadLogger
//
//  Created by Darcy Liu on 2019/8/23.
//  Copyright © 2019 Darcy Liu. All rights reserved.
//

#import "ObjCLoadLogger.h"

#import <mach/mach_time.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <os/signpost.h>

static NSMutableArray *_loadInfo;

static os_log_t _log;
static os_signpost_id_t _spid;

void _setupSignpost() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(iOS 12.0, *)) {
            _log = os_log_create("com.example.signpost", "objcload");
            _spid = os_signpost_id_generate(_log);
        }
    });
}

double _machTimeToSeconds(uint64_t time)
{
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    return (double)time * (double)timebase.numer / (double)timebase.denom / NSEC_PER_SEC;
}

@implementation ObjCLoadLogger
+ (void)_swappedLoad {
    uint64_t start = mach_absolute_time();
    
    [self _swappedLoad];
    
    uint64_t end = mach_absolute_time();
    
    NSDictionary *info = @{@"duration": @(_machTimeToSeconds(end - start)),
                           @"name": NSStringFromClass([self class])
                           };
    [_loadInfo addObject:info];
}

+ (void)load
{
    _setupSignpost();
    _loadInfo = [[NSMutableArray alloc] init];
    
    // hook begin
    if (@available(iOS 12.0, *)) {
        os_signpost_interval_begin(_log, _spid, "hook_load");
    }
    uint64_t start = mach_absolute_time();
    
    uint32_t imageCount = _dyld_image_count();
    
    NSString *mainBundlePath = [NSBundle mainBundle].bundlePath;

    for(uint32_t i = 0; i < imageCount; i++) {
        const char* path = _dyld_get_image_name(i);
        NSString *imagePath = [NSString stringWithUTF8String:path];
        
        if ([imagePath containsString:mainBundlePath]) {
            unsigned int classCount = 0;
            const char ** classNames = objc_copyClassNamesForImage(path,&classCount);
            for(unsigned int classIndex = 0; classIndex < classCount; ++classIndex){
                NSString *className = [NSString stringWithUTF8String:classNames[classIndex]];
                Class cls = object_getClass(NSClassFromString(className));
                if([self class] == cls){
                    continue;
                }
                
                SEL originalSelector = @selector(load);
                SEL swizzledSelector = @selector(_swappedLoad);
                
                Method originalMethod = class_getClassMethod(cls, originalSelector);
                Method swizzledMethod = class_getClassMethod([ObjCLoadLogger class], swizzledSelector);
                
                BOOL hasMethod = class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
                if (!hasMethod) {
                    BOOL didAddMethod = class_addMethod(cls, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
                    
                    if (didAddMethod) {
                        swizzledMethod = class_getClassMethod(cls, swizzledSelector);
                        method_exchangeImplementations(originalMethod, swizzledMethod);
                    }
                }
            }
        }
    }
    
    // hook end
    uint64_t end = mach_absolute_time();
    if (@available(iOS 12.0, *)) {
        os_signpost_interval_end(_log, _spid, "hook_load");
    }
    
    NSDictionary *info = @{@"duration": @(_machTimeToSeconds(end - start)),
                           @"name": @"Hook"
                           };
    [_loadInfo addObject:info];
}

+ (NSArray *)allObjCLoadInfo
{
    return [_loadInfo copy];
}
@end
