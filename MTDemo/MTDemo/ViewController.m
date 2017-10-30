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
    rule.selector = @selector(test:);
    rule.classMethod = YES;
    rule.durationThreshold = 0;
    rule.mode = MTModePerformFirstly;
    rule.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    [MTEngine.defaultEngine updateRule:rule];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            SEL selector = NSSelectorFromString(@"sel1");
            @autoreleasepool {
                [ViewController test:selector];
            }
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            SEL selector = NSSelectorFromString(@"sel2");
            @autoreleasepool {
                [ViewController test:selector];
            }
        }
    });
}

+ (void)test:(SEL)arg {
    NSLog(@"%@", NSStringFromSelector(arg));
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
