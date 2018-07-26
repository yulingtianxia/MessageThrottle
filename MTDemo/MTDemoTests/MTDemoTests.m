//
//  MTDemoTests.m
//  MTDemoTests
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
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
    MTRule *rule = [self.stub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01];
    rule.alwaysInvokeBlock =  ^(MTRule *rule, NSDate *date) {
        return YES;
    };
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
//    [MTEngine.defaultEngine savePersistentRules];
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
}

- (void)testDiscardRule {
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
    }
    for (MTRule *rule in self.sstub.mt_allRules) {
        [rule discard];
    }
    [self.stub foo:[NSDate date]];
    [self.sstub foo:[NSDate date]];
}

- (void)testDiscardRuleThenApply {
    for (MTRule *rule in self.stub.mt_allRules) {
        [rule discard];
        [rule apply];
    }
    [self.stub foo:[NSDate date]];
}

- (void)testDealloc {
    self.stub = nil;
    self.sstub = nil;
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
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
