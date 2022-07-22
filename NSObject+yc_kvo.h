//
//  Created by LYC on 2022/7/7.
//

#import <Foundation/Foundation.h>

typedef void (^YCCallback)(id _Nullable originValue, id _Nullable newValue);




@interface NSObject (yc_kvo)

/**
 只管添加监听，它会自己移除
 允许重复添加监听，但生效的只有最后那个
 */
-(void)safeAddObserver:(NSObject *_Nonnull)target forKeyPath:(NSString *_Nonnull)keyPath callBack:(YCCallback _Nullable )callback;

/**
 当你不需要监听这个属性，你就调一下，如果传nil，就移除这个对象所有的属性监听
 */
-(void)safeRemoveObserverForKeyPath:(NSString  *_Nullable)keyPath;

@end

