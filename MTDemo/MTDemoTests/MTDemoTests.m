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
#import "MTEngine+MTArchive.h"

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
    [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01].persistent = YES;
    [MTEngine.defaultEngine savePersistentRules];
    [super tearDown];
}

- (void)testSamplePerformModeFirstly {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeFirstly onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:nil];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
}

- (void)testSamplePerformModeLast {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeLast onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:nil];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
}

- (void)testSamplePerformModeDebounce {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:nil];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
}

- (void)testSampleDurationZero
{
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0 usingMode:MTPerformModeDebounce onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:nil];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
}

- (void)testSampleAlwaysInvoke
{
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeFirstly onMessageQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) alwaysInvokeBlock:^(MTInvocation *invocation, NSDate *date) {
        return YES;
    }];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
}

- (void)testInstancesOfSuperAndSub {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    [rule1 discard];
    [rule2 discard];
}

- (void)testTwoSameClassInstances {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    Stub *stub1 = [Stub new];
    MTRule *rule2 = [stub1 mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    [Stub foo:[NSDate date]];
    [SuperStub foo:[NSDate date]];
    [stub1 foo:[NSDate date]];
    [rule1 discard];
    [rule2 discard];
}

- (void)testSubInstanceAndSuperClass {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [SuperStub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
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
    [rule1 discard];
    [rule2 discard];
}

- (void)testSubInstanceAndSuperMetaClass {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [mt_metaClass(SuperStub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    for (MTRule *rule in MTEngine.defaultEngine.allRules) {
        NSLog(@"%@", rule.description);
    }
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
    [rule1 discard];
    [rule2 discard];
}

- (void)testInstanceAndMetaClass {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [mt_metaClass(Stub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
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
    [rule1 discard];
    [rule2 discard];
}

- (void)testClassThenInstance {
    MTRule *rule2 = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
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
    [rule1 discard];
    [rule2 discard];
}

- (void)testSubAndSuperClass {
    MTRule *rule1 = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    MTRule *rule2 = [SuperStub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [rule1 discard];
    [rule2 discard];
}

- (void)testApplyStubThenDiscardThenApplySuperStub {
    MTRule *rule1 = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [rule1 discard];
    MTRule *rule2 = [SuperStub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [rule2 discard];
}

- (void)testApplySuperStubThenDiscardThenApplyStub {
    MTRule *rule1 = [SuperStub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [rule1 discard];
    MTRule *rule2 = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    [rule2 discard];
}

- (void)testApplyMetaStubThenDiscardThenApplyMetaSuperStub {
    MTRule *rule1 = [mt_metaClass(Stub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [rule1 discard];
    MTRule *rule2 = [mt_metaClass(SuperStub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [Stub foo:[NSDate date]];
    [rule2 discard];
}

- (void)testClassAndMetaClass {
    MTRule *rule1 = [Stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [mt_metaClass(Stub.class) mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
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
    [rule1 discard];
    [rule2 discard];
}

- (void)testDiscardRule {
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    [self.stub foo:[NSDate date]];
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
    for (MTRule *rule in self.sstub.mt_allRules) {
        [rule discard];
    }
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
    for (MTRule *rule in MTEngine.defaultEngine.allRules) {
        NSCAssert(rule.target != self.stub && rule.target != self.sstub, @"This rule is not discard!");
    }
}

- (void)testDiscardRuleThenApply {
    MTRule *rule1 = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    MTRule *rule2 = [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];

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
    [rule1 discard];
    [rule2 discard];
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
    [rule discard];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce onMessageQueue:nil alwaysInvokeBlock:^(MTInvocation *invocation, NSDate *date) {
        return YES;
    }];
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

- (void)testThreadSafetyForApplyAndDiscard
{
    MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 10000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [rule apply];
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 10000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [rule discard];
            });
        }
    });
}

- (void)testThreadSafetyForPerform
{
    [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 10000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.stub foo:[NSDate date]];
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 10000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.stub foo:[NSDate date]];
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 10000; i ++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.sstub foo:[NSDate date]];
            });
        }
    });
}

- (void)testApplyRuleThenKVO
{
    MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.stub addObserver:self forKeyPath:@"bar" options:NSKeyValueObservingOptionNew context:nil];
    NSCAssert(!rule || (rule.durationThreshold == 0.01 && rule.mode == MTPerformModeDebounce), @"rule not correct!");
    [self.stub foo:[NSDate date]];
    [self.stub removeObserver:self forKeyPath:@"bar"];
    
    [rule discard];
    
//    [self.stub removeObserver:self forKeyPath:@"bar"];
    
    [self.stub foo:[NSDate date]];
}

- (void)testKVOThenApplyRule
{
    self.stub.bar = [NSObject new];
    [self.stub addObserver:self forKeyPath:@"bar" options:NSKeyValueObservingOptionNew context:nil];
    MTRule *rule = [self.stub mt_limitSelector:@selector(bar) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    NSCAssert((rule.durationThreshold == 0.01 && rule.mode == MTPerformModeDebounce), @"rule not correct!");
    NSObject *bar = self.stub.bar;
//    [self.stub removeObserver:self forKeyPath:@"bar"];
    [rule discard];
    [self.stub removeObserver:self forKeyPath:@"bar"];
    bar = self.stub.bar;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"bar"] && object == self.stub) {
        NSLog(@"do nothing...");
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
