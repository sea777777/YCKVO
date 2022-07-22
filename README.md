# YCKVO

## 这是什么？ What is this ?
  类似系统的 KVO, 但是系统的 KVO 使用苛刻，不能多移除，不能不移除，不能多次添加，回调方式不好，等等。 而 YCKVO 不存在以上所有问题。

## 注意事项：Notice
  1、允许多次添加监听，大胆的添加就是了，但只有最后一次监听才生效。   不需要移除监听，不用费那个劲，底层都帮你处理好了，干就得了。 
  Allow add observer any times, don't need to remove observer.
 
  2、允许子线程添加监听。
  Allow add observer in sub thread.


## 怎么用 ？  How to use ?

```
    // 步骤1 ：
    self.test = [Test new];
    self.test.what = @"before value";
    
    [self.test safeAddObserver:self forKeyPath:@"what" callBack:^(id  _Nullable originValue, id  _Nullable newValue) {
            
        NSLog(@"before value : %@",originValue);
        NSLog(@"after value : %@",newValue);
        
    }];
```    

```
    //步骤2：
    self.test.what = @"after value";
    [self.test safeRemoveObserverForKeyPath:@"what"];
```
 
```
   //输出：
   2022-07-22 14:01:05.365061+0800 [50371:5357232] before value : before value
   2022-07-22 14:01:05.365312+0800 [50371:5357232] after value : after value
```
