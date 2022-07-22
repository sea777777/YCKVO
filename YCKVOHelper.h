//
//  YCKVOHelper.h
//
//  Created by LYC on 2022/7/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 辅助类：是能够帮助自动移除监听类的。
 */
@interface YCKVOHelper : NSObject

- (instancetype)initWithTarget:(NSString *)target;

@end

NS_ASSUME_NONNULL_END
