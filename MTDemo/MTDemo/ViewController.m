//
//  ViewController.m
//  MTDemo
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "MTEngine.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    MTRule *rule = [MTRule new];
    rule.cls = self.class;
    rule.selector = @selector(foo:);
    rule.classMethod = YES;
    rule.durationThreshold = 2;
    rule.mode = MTModePerformDebounce;
    rule.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    [MTEngine.defaultEngine updateRule:rule];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            SEL selector = NSSelectorFromString(@"bar1");
            @autoreleasepool {
//                [ViewController foo:selector];
            }
        }
    });
    __block NSTimeInterval lastTime;
    __block NSTimeInterval value = 1;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
//            SEL selector = NSSelectorFromString(@"bar2");
            @autoreleasepool {
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                
                if (now - lastTime > value) {
                    lastTime = now;
                    value += 0.1;
                    NSLog(@"message send value:%f", value);
                    [ViewController foo:[NSDate date]];
                }
            }
        }
    });
}

+ (void)foo:(NSDate *)arg {
    NSLog(@"foo: %@", arg);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
