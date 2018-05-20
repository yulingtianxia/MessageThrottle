//
//  MTDemoTests.m
//  MTDemoTests
//
//  Created by 杨萧玉 on 2017/10/30.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SuperStub.h"
#import "MessageThrottle.h"

@interface MTDemoTests : XCTestCase

@property (nonatomic) SuperStub *sstub;

@end

@implementation MTDemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.sstub = [SuperStub new];
    MTRule *rule = [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    rule.alwaysInvokeBlock =  ^(MTRule *rule, NSDate *date) {
        return YES;
    };
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    NSDate *date = [NSDate date];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 1000; i ++) {
            @autoreleasepool {
                [self.sstub foo:date];
            }
        }
    }];
}

@end
