//
//  Stub.m
//  MTDemo
//
//  Created by 杨萧玉 on 2017/11/2.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "Stub.h"

NSString * const MTStubFooNotification = @"MTStubFooNotification";

@implementation Stub

- (void)foo:(NSDate *)arg {
    [super foo:arg];
    NSLog(@"Stub foo: %@", arg);
    [NSNotificationCenter.defaultCenter postNotificationName:MTStubFooNotification object:nil userInfo:@{@"arg" : arg}];
}

+ (void)foo:(NSDate *)arg {
    [super foo:arg];
    NSLog(@"Stub foo: %@", arg);
    [NSNotificationCenter.defaultCenter postNotificationName:MTStubFooNotification object:nil userInfo:@{@"arg" : arg}];
}

@end
