//
//  MTEngine.h
//  MessageThrottle
//
//  Created by 杨萧玉 on 2017/10/19.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 消息节流模式

 - MTModePerformFirstly: 执行最靠前发送的消息，后面发送的消息会被忽略
 - MTModePerformLastly: 执行最靠后发送的消息，前面发送的消息会被忽略，执行时间会有延时
 */
typedef NS_ENUM(NSUInteger, MTMode) {
    MTModePerformFirstly,
    MTModePerformLast,
};

NS_ASSUME_NONNULL_BEGIN

/**
 消息节流的规则。durationThreshold = 0.1，则代表 0.1 秒内最多发送一次消息，多余的消息会被忽略掉。
 */
@interface MTRule : NSObject

@property (nonatomic) Class cls;
@property (nonatomic) SEL selector;
/**
 是否是类方法
 */
@property (nonatomic, getter=isClassMethod) BOOL classMethod;
/**
 消息节流时间的阈值，单位：秒
 */
@property (nonatomic) NSTimeInterval durationThreshold;

/**
 消息节流模式
 */
@property (nonatomic) MTMode mode;

/**
 MTModePerformLastly 模式下消息发送的队列，默认在主队列
 */
@property (nonatomic) dispatch_queue_t messageQueue;

@end

@interface MTEngine : NSObject

@property (nonatomic, class, readonly) MTEngine *defaultEngine;
- (void)updateRule:(MTRule *)rule;

@end

NS_ASSUME_NONNULL_END
