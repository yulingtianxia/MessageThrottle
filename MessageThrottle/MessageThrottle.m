//
//  MessageThrottle.m
//  MessageThrottle
//
//  Created by 杨萧玉 on 2017/11/04.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

#import "MessageThrottle.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>

Class mt_metaClass(Class cls)
{
    if (class_isMetaClass(cls)) {
        return cls;
    }
    return object_getClass(cls);
}

@interface MTRule ()

@property (nonatomic) NSTimeInterval lastTimeRequest;
@property (nonatomic) NSInvocation *lastInvocation;

@end

@implementation MTRule

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mode = MTPerformModeDebounce;
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

static pthread_mutex_t mutex;

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
        pthread_mutex_init(&mutex, NULL);
    }
    return self;
}

- (NSArray<MTRule *> *)allRules
{
    return [self.rules allValues];
}

- (BOOL)applyRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    __block BOOL shouldApply = YES;
    if (mt_checkRuleValid(rule)) {
        [self.rules enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MTRule * _Nonnull obj, BOOL * _Nonnull stop) {
            if (rule.selector == obj.selector
                && object_isClass(rule.target)
                && object_isClass(obj.target)) {
                Class clsA = rule.target;
                Class clsB = obj.target;
                shouldApply = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
                *stop = shouldApply;
                NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already apply rule in %@. A message can only have one throttle per class hierarchy.", NSStringFromSelector(obj.selector), NSStringFromClass(clsB)];
                NSLog(@"%@", errorDescription);
            }
        }];
        
        if (shouldApply) {
            self.rules[mt_methodDescription(rule.target, rule.selector)] = rule;
            mt_overrideMethod(rule.target, rule.selector);
        }
    }
    pthread_mutex_unlock(&mutex);
    return shouldApply;
}

- (BOOL)discardRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    BOOL shouldDiscard = NO;
    if (mt_checkRuleValid(rule)) {
        NSString *description = mt_methodDescription(rule.target, rule.selector);
        shouldDiscard = self.rules[description] != nil;
        if (shouldDiscard) {
            self.rules[description] = nil;
            mt_recoverMethod(rule.target, rule.selector);
        }
    }
    pthread_mutex_unlock(&mutex);
    return shouldDiscard;
}

#pragma mark - Private Helper

static BOOL mt_checkRuleValid(MTRule *rule)
{
    if (rule.target && rule.selector && rule.durationThreshold > 0) {
        NSString *selectorName = NSStringFromSelector(rule.selector);
        if ([selectorName isEqualToString:@"forwardInvocation:"]) {
            return NO;
        }
        Class cls;
        if (object_isClass(rule.target)) {
            cls = rule.target;
        }
        else {
            cls = object_getClass(rule.target);
        }
        NSString *className = NSStringFromClass(cls);
        if ([className isEqualToString:@"MTRule"] || [className isEqualToString:@"MTEngine"]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

static NSString * mt_methodDescription(id target, SEL selector)
{
    NSString *selectorName = NSStringFromSelector(selector);
    if (object_isClass(target)) {
        NSString *className = NSStringFromClass(target);
        return [NSString stringWithFormat:@"%@ [%@ %@]", class_isMetaClass(target) ? @"+" : @"-", className, selectorName];
    }
    else {
        return [NSString stringWithFormat:@"[%p %@]", target, selectorName];
    }
}

static SEL mt_aliasForSelector(Class cls, SEL selector)
{
    NSString *fixedOriginalSelectorName = [NSString stringWithFormat:@"__mt_%@", NSStringFromSelector(selector)];
    SEL fixedOriginalSelector = NSSelectorFromString(fixedOriginalSelectorName);
    return fixedOriginalSelector;
}

/**
 处理执行 NSInvocation

 @param invocation NSInvocation 对象
 @param fixedSelector 修正后的 SEL
 */
static void mt_handleInvocation(NSInvocation *invocation, SEL fixedSelector)
{
    NSString *methodDescriptionForInstance = mt_methodDescription(invocation.target, invocation.selector);
    NSString *methodDescriptionForClass = mt_methodDescription(object_getClass(invocation.target), invocation.selector);
    
    MTRule *rule = MTEngine.defaultEngine.rules[methodDescriptionForInstance];
    if (!rule) {
        rule = MTEngine.defaultEngine.rules[methodDescriptionForClass];
    }
    
    if (rule.durationThreshold <= 0) {
        [invocation setSelector:fixedSelector];
        [invocation invoke];
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    switch (rule.mode) {
        case MTPerformModeFirstly:
            if (now - rule.lastTimeRequest > rule.durationThreshold) {
                rule.lastTimeRequest = now;
                invocation.selector = fixedSelector;
                [invocation invoke];
            }
            break;
        case MTPerformModeLast:
            if (now - rule.lastTimeRequest > rule.durationThreshold) {
                rule.lastTimeRequest = now;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
                    [rule.lastInvocation invoke];
                });
            }
            else {
                invocation.selector = fixedSelector;
                rule.lastInvocation = invocation;
                [rule.lastInvocation retainArguments];
            }
            break;
        case MTPerformModeDebounce:
            invocation.selector = fixedSelector;
            rule.lastInvocation = invocation;
            [rule.lastInvocation retainArguments];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
                if (rule.lastInvocation == invocation) {
                    [rule.lastInvocation invoke];
                }
            });
            break;
    }
}

static void mt_forwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    SEL originalSelector = invocation.selector;
    SEL fixedOriginalSelector = mt_aliasForSelector(object_getClass(assignSlf), originalSelector);
    if (![assignSlf respondsToSelector:fixedOriginalSelector]) {
        mt_executeOrigForwardInvocation(assignSlf, selector, invocation);
        return;
    }
    mt_handleInvocation(invocation, fixedOriginalSelector);
}

static NSString *const MTForwardInvocationSelectorName = @"__mt_forwardInvocation:";

static void mt_overrideMethod(id target, SEL selector)
{
    Class cls;
    if (object_isClass(target)) {
        cls = target;
    }
    else {
        cls = object_getClass(target);
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
    if (originType[0] == _C_STRUCT_B) {
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
        // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
        // https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
        // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originType];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    
    if (originalImp == msgForwardIMP) {
        return;
    }
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)mt_forwardInvocation) {
        IMP originalForwardImp = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)mt_forwardInvocation, "v@:@");
        if (originalForwardImp) {
            class_addMethod(cls, NSSelectorFromString(MTForwardInvocationSelectorName), originalForwardImp, "v@:@");
        }
    }
    
    if (class_respondsToSelector(cls, selector)) {
        SEL fixedOriginalSelector = mt_aliasForSelector(cls, selector);
        if(!class_respondsToSelector(cls, fixedOriginalSelector)) {
            class_addMethod(cls, fixedOriginalSelector, originalImp, originType);
        }
    }
    
    // Replace the original selector at last, preventing threading issus when
    // the selector get called during the execution of `overrideMethod`
    class_replaceMethod(cls, selector, msgForwardIMP, originType);
}

static void mt_recoverMethod(id target, SEL selector)
{
    Class cls;
    if (object_isClass(target)) {
        cls = target;
    }
    else {
        cls = object_getClass(target);
        if (MTEngine.defaultEngine.rules[mt_methodDescription(cls, selector)]) {
            return;
        }
    }
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) == (IMP)mt_forwardInvocation) {
        IMP originalForwardImp = class_getMethodImplementation(cls, NSSelectorFromString(MTForwardInvocationSelectorName));
        if (originalForwardImp) {
            class_replaceMethod(cls, @selector(forwardInvocation:), originalForwardImp, "v@:@");
        }
    }
    else {
        return;
    }
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        NSCAssert(NO, @"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
        return;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
 
    SEL fixedOriginalSelector = mt_aliasForSelector(cls, selector);
    if (class_respondsToSelector(cls, fixedOriginalSelector)) {
        IMP originalImp = class_getMethodImplementation(cls, fixedOriginalSelector);
        class_replaceMethod(cls, selector, originalImp, originType);
    }
}

static void mt_executeOrigForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    SEL origForwardSelector = NSSelectorFromString(MTForwardInvocationSelectorName);
    
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

