//
//  Created by LYC on 2022/7/7.
//

#import "NSObject+yc_kvo.h"
#import <objc/runtime.h>
#import "YCKVOHelper.h"

#define kSetterPrefix @"set"
#define kGetterPrefix @"get"
#define kObserverClsPrefix @"YCObserver"
#define kGenObserverClsName(clsName) [NSString stringWithFormat:@"%@_%@",kObserverClsPrefix,clsName]

static NSString *const kYCMethodStorageKey = @"kMethodStorageKey";
static NSString *const kYCCallbackStorageKey = @"kCallbackStorageKey";
static NSString *const kYCHelperKey = @"kYCHelperKey";

@implementation NSObject (yc_kvo)


-(void)safeAddObserver:(NSObject *)target forKeyPath:(NSString *)keyPath callBack:(YCCallback)callback{
    NSAssert(target != nil, @"target 不允许为空！");
    NSAssert(keyPath != nil && keyPath.length > 0, @"keyPath 不允许为空！");

    Class subClass = nil;
    // 注册新的子类 （注意：这里需要判断，如果第一次kvo修改了isa，那么第二次kvo时当前self是子类，只需要添加一个子类即可）
    if (![self alreadyRegister]) {
        subClass = [self registerNewClass:self.class className:[self getSubClassName]];
    } else {
        // 找到真实子类
        Class curSubCls = NSClassFromString([self getSubClassName]);
        subClass = (curSubCls == nil ? [self class] : curSubCls);
    }
    
    // 修改 self 的 isa ，让他指向新的子类
    object_setClass(self, subClass);
    initMethodStorage(self);
    initCallBackStorage(self);
    initHelper(self);

    SEL origionSetter = [self generateSetter:keyPath];
    SEL origionGetter = generateGetter(keyPath);

    // 当前 self 为 sub class
    Method origionSetterMethod = class_getInstanceMethod(self.superclass, origionSetter);
    Method origionGetterMethod = class_getInstanceMethod(self.superclass, origionGetter);
    if (origionSetterMethod == nil) return;
    
    // 存储父类 setter getter 以及 callback
    storeSuperMethod(self, NSStringFromSelector(origionSetter),origionSetterMethod);
    storeSuperMethod(self, NSStringFromSelector(origionGetter),origionGetterMethod);
    storeCallBack(self, NSStringFromSelector(origionSetter), callback);
    
    //给子类新增setter方法，覆盖父类的setter，子类方法名不变
    Method subSetterMethod = class_getInstanceMethod(self.class, origionSetter);
    if (subSetterMethod == origionSetterMethod) { // 子类取到 method 和父类一样，说明子类没添加过
        class_addMethod(subClass, origionSetter, (IMP)yc_setIMP, method_getTypeEncoding(origionSetterMethod));
    }
}

#pragma mark 是否已经注册过监听类
- (BOOL)alreadyRegister {
    // 如果当前子类已经注册过，或当前 self 就是已经注册过的子类
    BOOL isSubCls = [NSStringFromClass(self.class) hasPrefix:kObserverClsPrefix];
    Class subCls = NSClassFromString([self getSubClassName]);
    return isSubCls || subCls != nil;
}

- (NSString *)getSubClassName {
    NSString *origionClsName = NSStringFromClass(self.class);
    return kGenObserverClsName(origionClsName);
}

#pragma mark 注册监听类
- (Class)registerNewClass:(Class)superClass className:(NSString *)className{
    // 向runtime注册新的class
    Class allocatedNewClass = objc_allocateClassPair(superClass, [className UTF8String], 0);
    if (allocatedNewClass == nil) return nil;
    
    objc_registerClassPair(allocatedNewClass);
    return allocatedNewClass;
}

#pragma mark 生成setter方法：如：what -> setWhat:
- (SEL)generateSetter:(NSString *)keyPath {
    if (keyPath.length == 0) return nil;
    
    NSString *firstKeyPathChar = [keyPath substringToIndex:1];
    NSString *otherKeyPathChar = [keyPath substringFromIndex:1];

    NSMutableString *setterSELName = [[NSMutableString alloc] initWithString:kSetterPrefix];
    [setterSELName appendString:[firstKeyPathChar uppercaseString]];
    [setterSELName appendString:otherKeyPathChar];
    [setterSELName appendString:@":"];

    return NSSelectorFromString(setterSELName);
}

SEL generateGetter(NSString *keyPath) {
    return keyPath.length == 0 ? nil : NSSelectorFromString(keyPath);
}

#pragma mark setWhat: -> what
NSString* getIvarName(SEL sel){
    NSString *selName = NSStringFromSelector(sel);
    if ([selName hasPrefix:kSetterPrefix]) {
        selName = [selName stringByReplacingOccurrencesOfString:kSetterPrefix withString:@""];
        NSString *firstChar = [selName substringToIndex:1];
        NSRange range = NSMakeRange(1, selName.length - 2);
        NSString *lastChars = [selName substringWithRange:range];
        selName = [[firstChar lowercaseString] stringByAppendingString:lastChars];
    }
    return selName;
}

#pragma mark 监听类的 IMP
void yc_setIMP(id target, SEL sel, id newValue){
    if (!target || !sel) return;
    
    id originValue = nil;
    NSString *ivarName = getIvarName(sel);
    SEL superGetterSEL = generateGetter(ivarName);
    Method superGetterMethod = loadSuperMethod(target, NSStringFromSelector(superGetterSEL));
    if (superGetterMethod) {
        IMP superGetterImp = method_getImplementation(superGetterMethod);
        originValue = ((id(*)(id, SEL))superGetterImp)(target, superGetterSEL);
    }
    
    NSString *setSELName = NSStringFromSelector(sel);
    Method superSetMethod = loadSuperMethod(target,setSELName);
    if (superSetMethod) {
        IMP superSetImp = method_getImplementation(superSetMethod);
        SEL superSetSEL = method_getName(superSetMethod);
        ((id(*)(id, SEL, id))superSetImp)(target, superSetSEL, newValue);
    }
    
    YCCallback callback = loadCallback(target, setSELName);
    if (callback) {
        callback(originValue,newValue);
    }
}

#pragma mark - 存储相关操作 -
void initMethodStorage(id target){
    if (!objc_getAssociatedObject(target, &kYCMethodStorageKey)) {
        objc_setAssociatedObject(target, &kYCMethodStorageKey, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void initCallBackStorage(id target){
    if (!objc_getAssociatedObject(target, &kYCCallbackStorageKey)) {
        objc_setAssociatedObject(target, &kYCCallbackStorageKey, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void initHelper(id target){
    if (!objc_getAssociatedObject(target, &kYCHelperKey)) {
        objc_setAssociatedObject(target, &kYCHelperKey, [[YCKVOHelper alloc] initWithTarget:NSStringFromClass([target class])], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void storeSuperMethod(id target,NSString *key,Method method){
    if (!target || !key || !method) return;
    NSMutableDictionary *storage = objc_getAssociatedObject(target, &kYCMethodStorageKey);
    [storage setObject:[NSValue valueWithPointer:method] forKey:key];
}


void storeCallBack(id target,NSString *key,YCCallback callback){
    if (!target || !key || !callback) return;
    NSMutableDictionary *storage = objc_getAssociatedObject(target, &kYCCallbackStorageKey);
    [storage setObject:callback forKey:key];
}

Method loadSuperMethod(id target,NSString *key){
    if (!target || !key) return nil;
    NSMutableDictionary *storage = objc_getAssociatedObject(target, &kYCMethodStorageKey);
    NSValue *method = [storage objectForKey:key];
    if (method && [method isKindOfClass:NSValue.class]) {
        return [method pointerValue];
    }
    return nil;
}


YCCallback loadCallback(id target,NSString *key){
    if (!target || !key) return nil;
    NSMutableDictionary *storage = objc_getAssociatedObject(target, &kYCCallbackStorageKey);
    return [storage objectForKey:key];
}

-(void)safeRemoveObserverForKeyPath:(NSString *)keyPath{
    if (keyPath == nil || keyPath.length == 0) {
        objc_removeAssociatedObjects(self);
        if ([NSStringFromClass(self.class) hasPrefix:kObserverClsPrefix]) {
            objc_disposeClassPair(self.class);
        } else {
            objc_disposeClassPair(NSClassFromString([self getSubClassName]));
        }
    } else {
        NSMutableDictionary *methodStorage = objc_getAssociatedObject(self, &kYCMethodStorageKey);
        NSMutableDictionary *callbackStorage = objc_getAssociatedObject(self, &kYCCallbackStorageKey);
        NSString *sel = NSStringFromSelector([self generateSetter:keyPath]) ;
        [methodStorage removeObjectForKey:sel];
        [callbackStorage removeObjectForKey:sel];
    }
}


@end
