//
//  MessageThrottle.h
//  MessageThrottle
//
//  Created by 杨萧玉 on 2017/11/04.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 消息节流模式

 - MTPerformModeFirstly: 执行最靠前发送的消息，后面发送的消息会被忽略
 - MTPerformModeLast: 执行最靠后发送的消息，前面发送的消息会被忽略，执行时间会有延时
 - MTPerformModeDebounce: 消息发送后延迟一段时间执行，如果在这段时间内继续发送消息，则重新计时
 */
typedef NS_ENUM(NSUInteger, MTPerformMode) {
    MTPerformModeFirstly,
    MTPerformModeLast,
    MTPerformModeDebounce,
};

NS_ASSUME_NONNULL_BEGIN

/**
 获取元类

 @param cls 类对象
 @return 类对象的元类
 */
Class mt_metaClass(Class cls);

/**
 消息节流的规则。durationThreshold = 0.1，则代表 0.1 秒内最多发送一次消息，多余的消息会被忽略掉。
 */
@interface MTRule : NSObject

/**
 target, 可以为实例，类，元类
 */
@property (nonatomic, weak) id target;

/**
 节流消息的 SEL
 */
@property (nonatomic) SEL selector;

/**
 消息节流时间的阈值，单位：秒
 */
@property (nonatomic) NSTimeInterval durationThreshold;

/**
 消息节流模式
 */
@property (nonatomic) MTPerformMode mode;

/**
 MTModePerformLastly 和 MTModePerformDebounce 模式下消息发送的队列，默认在主队列
 */
@property (nonatomic) dispatch_queue_t messageQueue;

@end

@interface MTEngine : NSObject

@property (nonatomic, class, readonly) MTEngine *defaultEngine;
@property (nonatomic, readonly) NSArray<MTRule *> *allRules;

/**
 应用规则，会覆盖已有的规则

 @param rule MTRule 对象
 @return 更新成功返回 YES；如果规则不合法或继承链上已有相同 selector 的规则，则返回 NO
 */
- (BOOL)applyRule:(MTRule *)rule;

/**
 废除规则

 @param rule MTRule 对象
 @return 废除成功返回 YES；如果规则不存在或不合法，则返回 NO
 */
- (BOOL)discardRule:(MTRule *)rule;

@end

NS_ASSUME_NONNULL_END
