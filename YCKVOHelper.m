//
//  YCKVOHelper.m
//
//  Created by LYC on 2022/7/20.
//

#import "YCKVOHelper.h"
#import "YCKVOReferenceManager.h"


@interface YCKVOHelper()
@property (nonatomic, strong) NSString *target;
@end


@implementation YCKVOHelper

- (instancetype)initWithTarget:(NSString *)target {
    self = [super init];
    if (self) {
        self.target = target;
        [[YCKVOReferenceManager sharedInstance] addObserverObject:target];
    }
    return self;
}

-(void)dealloc {
    [[YCKVOReferenceManager sharedInstance] removeObserverObject:self.target];
}


@end
