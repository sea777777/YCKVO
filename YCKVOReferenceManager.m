//
//  YCKVOReferenceManager.m
//
//  Created by LYC on 2022/7/7.
//

#import "YCKVOReferenceManager.h"
#import <objc/runtime.h>

typedef void (^doBlock)(void);

static void cleanupBlock (__strong doBlock *block) {
    (*block)();
}

#define finalExe(finalBlock) \
__strong void(^placeHolderBlock)(void) __attribute__((cleanup(cleanupBlock),unused)) = finalBlock;


@interface YCKVOReferenceManager()
@property (nonatomic, strong) NSMutableDictionary* referenceCache;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation YCKVOReferenceManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YCKVOReferenceManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [YCKVOReferenceManager new];
    });
    return manager;
}

- (void)addObserverObject:(NSString *)obj {
    if (obj == nil || obj.length == 0) return;
    
    [self.lock lock];
    finalExe(^{
        [self.lock unlock];
    });
    
    NSNumber *count = [self.referenceCache objectForKey:obj];
    [self.referenceCache setObject:@((count ? [count integerValue] : 0) + 1) forKey:obj];
    
}

- (void)removeObserverObject:(NSString *)obj {
    if (obj == nil) return;
    
    [self.lock lock];
    finalExe(^{
        [self.lock unlock];
    });
    NSNumber *countNum = [self.referenceCache objectForKey:obj];
    NSInteger count = [countNum integerValue];
    if (count > 1) {
        [self.referenceCache setObject:@(count - 1) forKey:obj];
    } else if (count == 1) {
        [self.referenceCache removeObjectForKey:obj];
        [self destroy:obj];
    }
}

- (void)destroy:(NSString *)obj {
    if (NSClassFromString(obj)) {
        objc_disposeClassPair(NSClassFromString(obj));
    }
}

- (NSMutableDictionary *)referenceCache {
    if (!_referenceCache) {
        _referenceCache = [NSMutableDictionary new];
    }
    return _referenceCache;
}

- (NSLock *)lock {
    if (!_lock) {
        _lock = [NSLock new];
    }
    return _lock;
}

@end
