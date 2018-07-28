//
//  MTDemoTests.m
//  MTDemoTests
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SuperStub.h"
#import "Stub.h"
#import "MessageThrottle.h"

@interface MTDemoTests : XCTestCase

@property (nonatomic) Stub *stub;
@property (nonatomic) SuperStub *sstub;

@end

@implementation MTDemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.stub = [Stub new];
    self.sstub = [SuperStub new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
//    [MTEngine.defaultEngine savePersistentRules];
    [super tearDown];
}

- (void)testInstancesOfSuperAndSub {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
}

- (void)testTwoSameClassInstances {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    Stub *stub1 = [Stub new];
    [stub1 mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    [stub1 foo:[NSDate date]];
}

- (void)testSubInstanceAndSuperClass {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [SuperStub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in SuperStub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
}

- (void)testSubInstanceAndSuperMetaClass {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [mt_metaClass(SuperStub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    for (MTRule *rule in self.sstub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in SuperStub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in mt_metaClass(SuperStub.class).mt_allRules) {
        NSLog(@"%@", rule.description);
    }
}

- (void)testInstanceAndMetaClass {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [mt_metaClass(Stub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    
    for (MTRule *rule in self.stub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in SuperStub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in mt_metaClass(Stub.class).mt_allRules) {
        NSLog(@"%@", rule.description);
    }
}

- (void)testClassAndMetaClass {
    [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [mt_metaClass(Stub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    
    for (MTRule *rule in self.stub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in Stub.mt_allRules) {
        NSLog(@"%@", rule.description);
    }
    for (MTRule *rule in mt_metaClass(Stub.class).mt_allRules) {
        NSLog(@"%@", rule.description);
    }
}

- (void)testDiscardRule {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
    for (MTRule *rule in self.sstub.mt_allRules) {
        [rule discard];
    }
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    for (MTRule *rule in MTEngine.defaultEngine.allRules) {
        NSLog(@"%@", rule.description);
    }
}

- (void)testDiscardRuleThenApply {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];

    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
        [rule apply];
    }
    for (MTRule *rule in self.sstub.mt_allRules) {
        [rule discard];
        [rule apply];
    }
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
}

- (void)testDealloc {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    self.stub = nil;
    self.sstub = nil;
}

- (void)testApplyRuleTwice {
    MTRule *rule = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    rule = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.02 usingMode:MTPerformModeFirstly];
    NSCAssert((rule.durationThreshold == 0.02 && rule.mode == MTPerformModeFirstly), @"rule content not updated!");
    NSCAssert(![rule apply], @"rule already applied!");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    rule.alwaysInvokeBlock =  ^(MTRule *rule, NSDate *date) {
        return YES;
    };
    NSDate *date = [NSDate date];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 1000; i ++) {
            @autoreleasepool {
                [self.stub foo:date];
            }
        }
    }];
}

- (void)testThreadSafety
{
    MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    rule.alwaysInvokeBlock =  ^(MTRule *rule, NSDate *date) {
        return YES;
    };
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 1000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.stub foo:[NSDate date]];
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 1000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.sstub foo:[NSDate date]];
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 1000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.stub foo:[NSDate date]];
            });
        }
    });
}

@end
