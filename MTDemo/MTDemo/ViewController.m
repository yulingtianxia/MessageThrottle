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
    rule.durationThreshold = 0.1;
    rule.mode = MTModePerformLast;
    rule.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    [MTEngine.defaultEngine updateRule:rule];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            SEL selector = NSSelectorFromString(@"bar1");
            @autoreleasepool {
                [ViewController foo:selector];
            }
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            SEL selector = NSSelectorFromString(@"bar2");
            @autoreleasepool {
                [ViewController foo:selector];
            }
        }
    });
}

+ (void)foo:(SEL)arg {
    NSLog(@"%@", NSStringFromSelector(arg));
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
