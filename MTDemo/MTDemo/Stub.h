//
//  Stub.h
//  MTDemo
//
//  Created by 杨萧玉 on 2017/11/2.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SuperStub.h"

extern NSString * const MTStubFooNotification;

@interface Stub : SuperStub

@property (nonatomic) NSObject *bar;

- (void)foo:(NSDate *)arg;
+ (void)foo:(NSDate *)arg;

@end
