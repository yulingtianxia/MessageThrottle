//
//  MTEngine.m
//  MessageThrottle
//
//  Created by 杨萧玉 on 2017/10/19.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "MTEngine.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface MTRule ()

@property (nonatomic) NSTimeInterval lastTimeRequest;
@property (nonatomic) NSInvocation *lastInvocation;

@end

@implementation MTRule

- (instancetype)init
{
    self = [super init];
    if (self) {
        _classMethod = NO;
        _mode = MTModePerformFirstly;
        _lastTimeRequest = 0;
        _messageQueue = dispatch_get_main_queue();
    }
    return self;
}

@end

@interface MTEngine ()

@property (nonatomic) NSMutableDictionary<NSString *, MTRule *> *rules;

@end

@implementation MTEngine

static NSObject *_nilObj;

+ (instancetype)defaultEngine
{
    static dispatch_once_t onceToken;
    static MTEngine *instance;
    dispatch_once(&onceToken, ^{
        instance = [MTEngine new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rules = [NSMutableDictionary dictionary];
        _nilObj = [NSObject new];
    }
    return self;
}

- (void)updateRule:(MTRule *)rule
{
    self.rules[MTMethodDescription(rule.cls, rule.selector)] = rule;
    MTOverrideMethod(rule.cls, rule.selector, rule.isClassMethod);
}

#pragma mark - Private Func

NSString * MTMethodDescription(Class cls, SEL selector)
{
    return [NSString stringWithFormat:@"[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(selector)];
}

SEL MTFixSelector(Class cls, SEL selector)
{
    NSString *fixedOriginalSelectorName = [NSString stringWithFormat:@"ORIG_%@_%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
    SEL fixedOriginalSelector = NSSelectorFromString(fixedOriginalSelectorName);
    return fixedOriginalSelector;
}

/**
 处理执行 NSInvocation

 @param invocation NSInvocation 对象
 @param fixedSelector 修正后的 SEL
 */
void MTHandleInvocation(NSInvocation *invocation, SEL fixedSelector)
{
    NSString *methodDescription = MTMethodDescription(object_getClass(invocation.target), invocation.selector);
    MTRule *rule = MTEngine.defaultEngine.rules[methodDescription];
    
    if (rule.durationThreshold <= 0) {
        [invocation setSelector:fixedSelector];
        [invocation invoke];
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    switch (rule.mode) {
        case MTModePerformFirstly:
            if (now - rule.lastTimeRequest > rule.durationThreshold) {
                rule.lastTimeRequest = now;
                [invocation setSelector:fixedSelector];
                [invocation invoke];
            }
            break;
        case MTModePerformLastly:
            if (now - rule.lastTimeRequest > rule.durationThreshold) {
                rule.lastTimeRequest = now;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
                    [rule.lastInvocation invoke];
                });
            }
            else {
                [invocation setSelector:fixedSelector];
                rule.lastInvocation = invocation;
                [rule.lastInvocation retainArguments];
            }
            break;
        default:
            break;
    }
    
}

void MTForwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    SEL originalSelector = invocation.selector;
    SEL fixedOriginalSelector = MTFixSelector(object_getClass(assignSlf), originalSelector);
    if (![assignSlf respondsToSelector:fixedOriginalSelector]) {
        MTExecuteORIGForwardInvocation(assignSlf, selector, invocation);
        return;
    }
    MTHandleInvocation(invocation, fixedOriginalSelector);
}

void MTOverrideMethod(Class cls, SEL selector, BOOL isClassMethod)
{
    if (isClassMethod) {
        cls = object_getClass(cls);
    }
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        NSCAssert(NO, @"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
        return;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    
    IMP originalImp = class_respondsToSelector(cls, selector) ? class_getMethodImplementation(cls, selector) : NULL;
    
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (originType[0] == '{') {
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originType];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)MTForwardInvocation) {
        IMP originalForwardImp = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)MTForwardInvocation, "v@:@");
        if (originalForwardImp) {
            class_addMethod(cls, NSSelectorFromString(@"originalForwardInvocation:"), originalForwardImp, "v@:@");
        }
    }
    
    if (class_respondsToSelector(cls, selector)) {
        SEL fixedOriginalSelector = MTFixSelector(cls, selector);
        if(!class_respondsToSelector(cls, fixedOriginalSelector)) {
            class_addMethod(cls, fixedOriginalSelector, originalImp, originType);
        }
    }
    
    // Replace the original selector at last, preventing threading issus when
    // the selector get called during the execution of `overrideMethod`
    class_replaceMethod(cls, selector, msgForwardIMP, originType);
}

void MTExecuteORIGForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    SEL origForwardSelector = NSSelectorFromString(@"originalForwardInvocation:");
    
    if ([slf respondsToSelector:origForwardSelector]) {
        NSMethodSignature *methodSignature = [slf methodSignatureForSelector:origForwardSelector];
        if (!methodSignature) {
            NSString *assertLog = [NSString stringWithFormat:@"unrecognized selector -%@ for instance %@", NSStringFromSelector(origForwardSelector), slf];
            NSCAssert(NO, assertLog);
            return;
        }
        NSInvocation *forwardInv= [NSInvocation invocationWithMethodSignature:methodSignature];
        [forwardInv setTarget:slf];
        [forwardInv setSelector:origForwardSelector];
        [forwardInv setArgument:&invocation atIndex:2];
        [forwardInv invoke];
    } else {
        Class superCls = [[slf class] superclass];
        Method superForwardMethod = class_getInstanceMethod(superCls, @selector(forwardInvocation:));
        void (*superForwardIMP)(id, SEL, NSInvocation *);
        superForwardIMP = (void (*)(id, SEL, NSInvocation *))method_getImplementation(superForwardMethod);
        superForwardIMP(slf, @selector(forwardInvocation:), invocation);
    }
}

@end
