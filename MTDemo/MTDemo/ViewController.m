//
//  ViewController.m
//  MTDemo
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "MTEngine.h"
#import "Stub.h"
#import "SuperStub.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    Stub *s = [Stub new];
    
    MTRule *rule = [MTRule new];
    rule.target = s;
    rule.selector = @selector(foo:);
    rule.durationThreshold = 2;
    rule.mode = MTPerformModeDebounce;
    rule.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    MTRule *rule1 = [MTRule new];
    rule1.target = Stub.class;
    rule1.selector = @selector(foo:);
    rule1.durationThreshold = 2;
    rule1.mode = MTPerformModeDebounce;
    rule1.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    [MTEngine.defaultEngine updateRule:rule];
//    [MTEngine.defaultEngine updateRule:rule1];
//
//    [MTEngine.defaultEngine deleteRule:rule];
//    [MTEngine.defaultEngine deleteRule:rule];
    
    
    Stub *ss = [Stub new];
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        while (YES) {
//            @autoreleasepool {
//                [ss foo:[NSDate date]];
//            }
//        }
//    });
    __block NSTimeInterval lastTime = 0;
    __block NSTimeInterval value = 1;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            @autoreleasepool {
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                
                if (now - lastTime > value && (now - lastTime <= 3 || lastTime == 0)) {
                    lastTime = now;
                    value += 0.1;
                    NSLog(@"message send value:%f", value);
                    [s foo:[NSDate date]];
                }
                if (lastTime > 0 && now - lastTime > 3) {
                    [s foo:[NSDate date]];
                    [MTEngine.defaultEngine deleteRule:rule];
                }
            }
        }
    });
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
