//
//  YCKVOReferenceManager.h
//
//  Created by LYC on 2022/7/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YCKVOReferenceManager : NSObject

+ (instancetype)sharedInstance;

- (void)addObserverObject:(NSString *)obj;

- (void)removeObserverObject:(NSString *)obj;

@end

NS_ASSUME_NONNULL_END
