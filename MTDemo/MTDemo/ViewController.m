//
//  ViewController.m
//  MTDemo
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "MessageThrottle.h"
#import "Stub.h"
#import "SuperStub.h"
#import <objc/runtime.h>

@interface ViewController ()

@property (nonatomic) Stub *stub;

@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleFooNotification:) name:MTStubFooNotification object:nil];
    
    self.stub = [Stub new];
    
//    MTRule *rule = [[MTRule alloc] initWithTarget:self.stub selector:@selector(foo:) durationThreshold:1];
//    rule.messageQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    rule.alwaysInvokeBlock = ^(MTRule *rule, NSDate *date) {
//        if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]]) {
//            return YES;
//        }
//        return NO;
//    };
//    [MTEngine.defaultEngine applyRule:rule];
    
    // 跟上面的用法等价
    __unused MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.5 usingMode:MTPerformModeDebounce onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:^(MTInvocation *invocation, NSDate *date) {
        if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]]) {
            return YES;
        }
        return NO;
    }];

    NSArray<MTRule *> *rules = self.stub.mt_allRules;
//    self.stub = nil;
    
    for (MTRule *rule in rules) {
//        rule.persistent = YES;
        NSLog(@"%@", rule);
    }
    
//    [MTEngine.defaultEngine discardRule:rule];
}

- (IBAction)tapFoo:(UIButton *)sender {
    [self.stub foo:[NSDate date]];
}

- (IBAction)tapBar:(UIButton *)sender {
    [self.stub foo:[NSDate dateWithTimeIntervalSince1970:0]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)handleFooNotification:(NSNotification *)notification
{
    NSDate *date = notification.userInfo[@"arg"];
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"dd/MM/yyyy\nHH:mm:ss"];
    
    df.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[NSTimeZone localTimeZone].secondsFromGMT];
    NSString *localDateString = [df stringFromDate:date];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.label.text = [NSString stringWithFormat:@"Last Fire Date:\n%@", localDateString];
    });
}

@end
