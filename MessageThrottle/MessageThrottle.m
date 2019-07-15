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

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#if !__has_feature(objc_arc)
#error
#endif

static inline BOOL mt_object_isClass(id _Nullable obj)
{
    if (!obj) return NO;
    if (@available(iOS 8.0, macOS 10.10, tvOS 9.0, watchOS 2.0, *)) {
        return object_isClass(obj);
    }
    else {
        return obj == [obj class];
    }
}

Class mt_metaClass(Class cls)
{
    if (class_isMetaClass(cls)) {
        return cls;
    }
    return object_getClass(cls);
}

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

struct _MTBlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct _MTBlock
{
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct _MTBlockDescriptor *descriptor;
};

static const char * mt_blockMethodSignature(id blockObj)
{
    struct _MTBlock *block = (__bridge void *)blockObj;
    struct _MTBlockDescriptor *descriptor = block->descriptor;
    
    assert(block->flags & BLOCK_HAS_SIGNATURE);
    
    int index = 0;
    if(block->flags & BLOCK_HAS_COPY_DISPOSE)
        index += 2;
    
    return descriptor->rest[index];
}

@interface MTDealloc : NSObject

@property (nonatomic) MTRule *rule;
@property (nonatomic) Class cls;
@property (nonatomic) pthread_mutex_t invokeLock;

- (void)lock;
- (void)unlock;

@end

@implementation MTDealloc

- (instancetype)init
{
    self = [super init];
    if (self) {
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_invokeLock, &attr);
    }
    return self;
}

- (void)dealloc
{
    SEL selector = NSSelectorFromString(@"discardRule:whenTargetDealloc:");
    ((void (*)(id, SEL, MTRule *, MTDealloc *))[MTEngine.defaultEngine methodForSelector:selector])(MTEngine.defaultEngine, selector, self.rule, self);
}

- (void)lock
{
    pthread_mutex_lock(&_invokeLock);
}

- (void)unlock
{
    pthread_mutex_unlock(&_invokeLock);
}

@end

@interface MTRule () <NSSecureCoding>

@property (nonatomic) NSTimeInterval lastTimeRequest;
@property (nonatomic) NSInvocation *lastInvocation;
@property (nonatomic) SEL aliasSelector;
@property (nonatomic, readwrite, getter=isActive) BOOL active;
@property (nonatomic, readwrite) id alwaysInvokeBlock;
@property (nonatomic, readwrite) dispatch_queue_t messageQueue;

@end

@implementation MTRule

- (instancetype)initWithTarget:(id)target selector:(SEL)selector durationThreshold:(NSTimeInterval)durationThreshold
{
    self = [super init];
    if (self) {
        _target = target;
        _selector = selector;
        _durationThreshold = durationThreshold;
        _mode = MTPerformModeDebounce;
        _lastTimeRequest = 0;
        _messageQueue = dispatch_get_main_queue();
    }
    return self;
}

#pragma mark Getter & Setter

- (SEL)aliasSelector
{
    if (!_aliasSelector) {
        NSString *selectorName = NSStringFromSelector(self.selector);
        _aliasSelector = NSSelectorFromString([NSString stringWithFormat:@"__mt_%@", selectorName]);
    }
    return _aliasSelector;
}

- (BOOL)isPersistent
{
    if (!mt_object_isClass(self.target)) {
        _persistent = NO;
    }
    return _persistent;
}

#pragma mark Public Method

- (BOOL)apply
{
    return [MTEngine.defaultEngine applyRule:self];
}

- (BOOL)discard
{
    return [MTEngine.defaultEngine discardRule:self];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"target:%@, selector:%@, durationThreshold:%f, mode:%lu", [self.target description], NSStringFromSelector(self.selector), self.durationThreshold, (unsigned long)self.mode];
}

#pragma mark Private Method

- (MTDealloc *)mt_deallocObject
{
    MTDealloc *mtDealloc = objc_getAssociatedObject(self.target, self.selector);
    if (!mtDealloc) {
        mtDealloc = [MTDealloc new];
        mtDealloc.rule = self;
        mtDealloc.cls = object_getClass(self.target);
        objc_setAssociatedObject(self.target, self.selector, mtDealloc, OBJC_ASSOCIATION_RETAIN);
    }
    return mtDealloc;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (mt_object_isClass(self.target)) {
        Class cls = self.target;
        NSString *classKey = @"target";
        if (class_isMetaClass(cls)) {
            classKey = @"meta_target";
        }
        [aCoder encodeObject:NSStringFromClass(cls) forKey:classKey];
        [aCoder encodeObject:NSStringFromSelector(self.selector) forKey:@"selector"];
        [aCoder encodeDouble:self.durationThreshold forKey:@"durationThreshold"];
        [aCoder encodeObject:@(self.mode) forKey:@"mode"];
        [aCoder encodeDouble:self.lastTimeRequest forKey:@"lastTimeRequest"];
        [aCoder encodeBool:self.isPersistent forKey:@"persistent"];
        [aCoder encodeObject:NSStringFromSelector(self.aliasSelector) forKey:@"aliasSelector"];
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    id target = NSClassFromString([aDecoder decodeObjectOfClass:NSString.class forKey:@"target"]);
    if (!target) {
        target = NSClassFromString([aDecoder decodeObjectOfClass:NSString.class forKey:@"meta_target"]);
        target = mt_metaClass(target);
    }
    if (target) {
        SEL selector = NSSelectorFromString([aDecoder decodeObjectOfClass:NSString.class forKey:@"selector"]);
        NSTimeInterval durationThreshold = [aDecoder decodeDoubleForKey:@"durationThreshold"];
        MTPerformMode mode = [[aDecoder decodeObjectForKey:@"mode"] unsignedIntegerValue];
        NSTimeInterval lastTimeRequest = [aDecoder decodeDoubleForKey:@"lastTimeRequest"];
        BOOL persistent = [aDecoder decodeBoolForKey:@"persistent"];
        NSString *aliasSelector = [aDecoder decodeObjectOfClass:NSString.class forKey:@"aliasSelector"];
        
        self = [self initWithTarget:target selector:selector durationThreshold:durationThreshold];
        self.mode = mode;
        self.lastTimeRequest = lastTimeRequest;
        self.persistent = persistent;
        self.aliasSelector = NSSelectorFromString(aliasSelector);
        return self;
    }
    return nil;
}

@end

@interface MTInvocation ()

@property (nonatomic, weak, readwrite) NSInvocation *invocation;
@property (nonatomic, weak, readwrite) MTRule *rule;

@end

@implementation MTInvocation

@end

@interface MTEngine ()

@property (nonatomic) NSMapTable<id, NSMutableSet<NSString *> *> *targetSELs;
@property (nonatomic) NSMutableSet<Class> *classHooked;

- (void)discardRule:(MTRule *)rule whenTargetDealloc:(MTDealloc *)mtDealloc;

@end

@implementation MTEngine

static pthread_mutex_t mutex;
NSString * const kMTPersistentRulesKey = @"kMTPersistentRulesKey";

+ (instancetype)defaultEngine
{
    static dispatch_once_t onceToken;
    static MTEngine *instance;
    dispatch_once(&onceToken, ^{
        instance = [MTEngine new];
    });
    return instance;
}

+ (void)load
{
    NSArray<NSData *> *array = [NSUserDefaults.standardUserDefaults objectForKey:kMTPersistentRulesKey];
    for (NSData *data in array) {
        if (@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *)) {
            NSError *error = nil;
            MTRule *rule = [NSKeyedUnarchiver unarchivedObjectOfClass:MTRule.class fromData:data error:&error];
            if (error) {
                NSLog(@"%@", error.localizedDescription);
            }
            else {
                [rule apply];
            }
        } else {
            @try {
                MTRule *rule = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                [rule apply];
            } @catch (NSException *exception) {
                NSLog(@"%@", exception.description);
            }
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _targetSELs = [NSMapTable weakToStrongObjectsMapTable];
        _classHooked = [NSMutableSet set];
        pthread_mutex_init(&mutex, NULL);
        NSNotificationName name = nil;
#if TARGET_OS_IOS || TARGET_OS_TV
        name = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX
        name = NSApplicationWillTerminateNotification;
#endif
        if (name.length > 0) {
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleAppWillTerminateNotification:) name:name object:nil];
        }
    }
    return self;
}

- (void)handleAppWillTerminateNotification:(NSNotification *)notification
{
    if (@available(macOS 10.11, *)) {
        [self savePersistentRules];
    }
}

- (void)savePersistentRules
{
    NSMutableArray<NSData *> *array = [NSMutableArray array];
    for (MTRule *rule in self.allRules) {
        if (rule.isPersistent) {
            NSData *data;
            if (@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *)) {
                NSError *error = nil;
                data = [NSKeyedArchiver archivedDataWithRootObject:rule requiringSecureCoding:YES error:&error];
                if (error) {
                    NSLog(@"%@", error.localizedDescription);
                }
            } else {
                data = [NSKeyedArchiver archivedDataWithRootObject:rule];
            }
            if (data) {
                [array addObject:data];
            }
        }
    }
    [NSUserDefaults.standardUserDefaults setObject:array forKey:kMTPersistentRulesKey];
}

- (NSArray<MTRule *> *)allRules
{
    pthread_mutex_lock(&mutex);
    NSMutableArray *rules = [NSMutableArray array];
    for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
        NSMutableSet *selectors = [self.targetSELs objectForKey:target];
        for (NSString *selectorName in selectors) {
            MTDealloc *mtDealloc = objc_getAssociatedObject(target, NSSelectorFromString(selectorName));
            if (mtDealloc.rule) {
                [rules addObject:mtDealloc.rule];
            }
        }
    }
    pthread_mutex_unlock(&mutex);
    return [rules copy];
}

/**
 添加 target-selector 记录

 @param selector 方法名
 @param target 对象，类，元类
 */
- (void)addSelector:(SEL)selector onTarget:(id)target
{
    if (!target) {
        return;
    }
    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
    }
    [selectors addObject:NSStringFromSelector(selector)];
    [self.targetSELs setObject:selectors forKey:target];
}

/**
 移除 target-selector 记录
 
 @param selector 方法名
 @param target 对象，类，元类
 */
- (void)removeSelector:(SEL)selector onTarget:(id)target
{
    if (!target) {
        return;
    }
    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
    }
    [selectors removeObject:NSStringFromSelector(selector)];
    [self.targetSELs setObject:selectors forKey:target];
}

/**
 是否存在 target-selector 记录

 @param selector 方法名
 @param target 对象，类，元类
 @return 是否存在记录
 */
- (BOOL)containsSelector:(SEL)selector onTarget:(id)target
{
    return [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)];
}

/**
 是否存在 target-selector 记录，未指定具体 target，但 target 的类型为 cls 即可

 @param selector 方法名
 @param cls 类
 @return 是否存在记录
 */
- (BOOL)containsSelector:(SEL)selector onTargetsOfClass:(Class)cls
{
    for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
        if (!mt_object_isClass(target) &&
            object_getClass(target) == cls &&
            [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)applyRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    MTDealloc *mtDealloc = [rule mt_deallocObject];
    [mtDealloc lock];
    BOOL shouldApply = YES;
    if (mt_checkRuleValid(rule)) {
        for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
            NSMutableSet *selectors = [self.targetSELs objectForKey:target];
            NSString *selectorName = NSStringFromSelector(rule.selector);
            if ([selectors containsObject:selectorName]) {
                if (target == rule.target) {
                    shouldApply = NO;
                    continue;
                }
                if (mt_object_isClass(rule.target) && mt_object_isClass(target)) {
                    Class clsA = rule.target;
                    Class clsB = target;
                    shouldApply = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
                    // inheritance relationship
                    if (!shouldApply) {
                        NSLog(@"Sorry: %@ already apply rule in %@. A message can only have one rule per class hierarchy.", selectorName, NSStringFromClass(clsB));
                        break;
                    }
                }
                else if (mt_object_isClass(target) && target == object_getClass(rule.target)) {
                    shouldApply = NO;
                    NSLog(@"Sorry: %@ already apply rule in target's Class(%@).", selectorName, target);
                    break;
                }
            }
        }
        shouldApply = shouldApply && mt_overrideMethod(rule);
        if (shouldApply) {
            [self addSelector:rule.selector onTarget:rule.target];
            rule.active = YES;
        }
    }
    else {
        shouldApply = NO;
        NSLog(@"Sorry: invalid rule.");
    }
    [mtDealloc unlock];
    if (!shouldApply) {
        objc_setAssociatedObject(rule.target, rule.selector, nil, OBJC_ASSOCIATION_RETAIN);
    }
    pthread_mutex_unlock(&mutex);
    return shouldApply;
}

- (BOOL)discardRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    MTDealloc *mtDealloc = [rule mt_deallocObject];
    [mtDealloc lock];
    BOOL shouldDiscard = NO;
    if (mt_checkRuleValid(rule)) {
        [self removeSelector:rule.selector onTarget:rule.target];
        shouldDiscard = mt_recoverMethod(rule.target, rule.selector, rule.aliasSelector);
        rule.active = NO;
    }
    [mtDealloc unlock];
    pthread_mutex_unlock(&mutex);
    return shouldDiscard;
}

- (void)discardRule:(MTRule *)rule whenTargetDealloc:(MTDealloc *)mtDealloc
{
    if (mt_object_isClass(rule.target)) {
        return;
    }
    pthread_mutex_lock(&mutex);
    [mtDealloc lock];
    if (![self containsSelector:rule.selector onTarget:mtDealloc.cls] &&
        ![self containsSelector:rule.selector onTargetsOfClass:mtDealloc.cls]) {
        mt_revertHook(mtDealloc.cls, rule.selector, rule.aliasSelector);
    }
    rule.active = NO;
    [mtDealloc unlock];
    pthread_mutex_unlock(&mutex);
}

#pragma mark - Private Helper Function

static BOOL mt_checkRuleValid(MTRule *rule)
{
    if (rule.target && rule.selector && rule.durationThreshold > 0) {
        NSString *selectorName = NSStringFromSelector(rule.selector);
        if ([selectorName isEqualToString:@"forwardInvocation:"]) {
            return NO;
        }
        Class cls = [rule.target class];
        NSString *className = NSStringFromClass(cls);
        if ([className isEqualToString:@"MTRule"] || [className isEqualToString:@"MTEngine"]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

static BOOL mt_invokeFilterBlock(MTRule *rule, NSInvocation *originalInvocation)
{
    if (!rule.alwaysInvokeBlock || ![rule.alwaysInvokeBlock isKindOfClass:NSClassFromString(@"NSBlock")]) {
        return NO;
    }
    NSMethodSignature *filterBlockSignature = [NSMethodSignature signatureWithObjCTypes:mt_blockMethodSignature(rule.alwaysInvokeBlock)];
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:filterBlockSignature];
    NSUInteger numberOfArguments = filterBlockSignature.numberOfArguments;
    
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        NSLog(@"Block has too many arguments. Not calling %@", rule);
        return NO;
    }
    
    MTInvocation *invocation = nil;
    
    if (numberOfArguments > 1) {
        invocation = [MTInvocation new];
        invocation.invocation = originalInvocation;
        invocation.rule = rule;
        [blockInvocation setArgument:&invocation atIndex:1];
    }
    
    void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
        NSUInteger argSize;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        
        if (!(argBuf = reallocf(argBuf, argSize))) {
            NSLog(@"Failed to allocate memory for block invocation.");
            return NO;
        }
        
        [originalInvocation getArgument:argBuf atIndex:idx];
        [blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:rule.alwaysInvokeBlock];
    BOOL returnedValue = NO;
    [blockInvocation getReturnValue:&returnedValue];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return returnedValue;
}

/**
 处理执行 NSInvocation

 @param invocation NSInvocation 对象
 @param rule MTRule 对象
 */
static void mt_handleInvocation(NSInvocation *invocation, MTRule *rule)
{
    NSCParameterAssert(invocation);
    NSCParameterAssert(rule);
    
    if (!rule.isActive) {
        [invocation invoke];
        return;
    }
    
    if (rule.durationThreshold <= 0 || mt_invokeFilterBlock(rule, invocation)) {
        invocation.selector = rule.aliasSelector;
        [invocation invoke];
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    now += MTEngine.defaultEngine.correctionForSystemTime;
    
    switch (rule.mode) {
        case MTPerformModeFirstly: {
            if (now - rule.lastTimeRequest > rule.durationThreshold) {
                invocation.selector = rule.aliasSelector;
                [invocation invoke];
                rule.lastTimeRequest = now;
                dispatch_async(rule.messageQueue, ^{
                    // May switch from other modes, set nil just in case.
                    rule.lastInvocation = nil;
                });
            }
            break;
        }
        case MTPerformModeLast: {
            invocation.selector = rule.aliasSelector;
            [invocation retainArguments];
            dispatch_async(rule.messageQueue, ^{
                rule.lastInvocation = invocation;
                if (now - rule.lastTimeRequest > rule.durationThreshold) {
                    rule.lastTimeRequest = now;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
                        if (!rule.isActive) {
                            rule.lastInvocation.selector = rule.selector;
                        }
                        [rule.lastInvocation invoke];
                        rule.lastInvocation = nil;
                    });
                }
            });
            break;
        }
        case MTPerformModeDebounce: {
            invocation.selector = rule.aliasSelector;
            [invocation retainArguments];
            dispatch_async(rule.messageQueue, ^{
                rule.lastInvocation = invocation;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
                    if (rule.lastInvocation == invocation) {
                        if (!rule.isActive) {
                            rule.lastInvocation.selector = rule.selector;
                        }
                        [rule.lastInvocation invoke];
                        rule.lastInvocation = nil;
                    }
                });
            });
            break;
        }
    }
}

static void mt_forwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    MTDealloc *mtDealloc = nil;
    if (!mt_object_isClass(invocation.target)) {
        mtDealloc = objc_getAssociatedObject(invocation.target, invocation.selector);
    }
    else {
        mtDealloc = objc_getAssociatedObject(object_getClass(invocation.target), invocation.selector);
    }
    
    BOOL respondsToAlias = YES;
    Class cls = object_getClass(invocation.target);
    
    do {
        if (!mtDealloc.rule) {
            mtDealloc = objc_getAssociatedObject(cls, invocation.selector);
        }
        if ((respondsToAlias = [cls instancesRespondToSelector:mtDealloc.rule.aliasSelector])) {
            break;
        }
        mtDealloc = nil;
    }
    while (!respondsToAlias && (cls = class_getSuperclass(cls)));
    
    [mtDealloc lock];
    
    if (!respondsToAlias) {
        mt_executeOrigForwardInvocation(assignSlf, selector, invocation);
    }
    else {
        mt_handleInvocation(invocation, mtDealloc.rule);
    }
    
    [mtDealloc unlock];
}

static NSString *const MTForwardInvocationSelectorName = @"__mt_forwardInvocation:";
static NSString *const MTSubclassPrefix = @"_MessageThrottle_";

/**
 获取实例对象的类。如果 instance 是类对象，则返回元类。
 兼容 KVO 用子类替换 isa 并覆写 class 方法的场景。
 */
static Class mt_classOfTarget(id target)
{
    Class cls;
    if (mt_object_isClass(target)) {
        cls = object_getClass(target);
    }
    else {
        cls = [target class];
    }
    return cls;
}

static void mt_hookedGetClass(Class class, Class statedClass)
{
    NSCParameterAssert(class);
    NSCParameterAssert(statedClass);
    Method method = class_getInstanceMethod(class, @selector(class));
    IMP newIMP = imp_implementationWithBlock(^(id self) {
        return statedClass;
    });
    class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

static BOOL mt_isMsgForwardIMP(IMP impl)
{
    return impl == _objc_msgForward
#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret
#endif
    ;
}

static IMP mt_getMsgForwardIMP(Class cls, SEL selector)
{
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    Method originMethod = class_getInstanceMethod(cls, selector);
    const char *originType = (char *)method_getTypeEncoding(originMethod);
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
    return msgForwardIMP;
}

static BOOL mt_overrideMethod(MTRule *rule)
{
    id target = rule.target;
    SEL selector = rule.selector;
    SEL aliasSelector = rule.aliasSelector;
    Class cls;
    Class statedClass = [target class];
    Class baseClass = object_getClass(target);
    NSString *className = NSStringFromClass(baseClass);
    
    if ([className hasPrefix:MTSubclassPrefix]) {
        cls = baseClass;
    }
    else if (mt_object_isClass(target)) {
        cls = target;
    }
    else if (statedClass != baseClass) {
        cls = baseClass;
    }
    else {
        const char *subclassName = [MTSubclassPrefix stringByAppendingString:className].UTF8String;
        Class subclass = objc_getClass(subclassName);
        
        if (subclass == nil) {
            subclass = objc_allocateClassPair(baseClass, subclassName, 0);
            if (subclass == nil) {
                NSLog(@"objc_allocateClassPair failed to allocate class %s.", subclassName);
                return NO;
            }
            mt_hookedGetClass(subclass, statedClass);
            mt_hookedGetClass(object_getClass(subclass), statedClass);
            objc_registerClassPair(subclass);
        }
        object_setClass(target, subclass);
        cls = subclass;
    }
    
    // check if subclass has hooked!
    for (Class clsHooked in MTEngine.defaultEngine.classHooked) {
        if (clsHooked != cls && [clsHooked isSubclassOfClass:cls]) {
            NSLog(@"Sorry: %@ used to be applied, can't apply it's super class %@!", NSStringFromClass(cls), NSStringFromClass(cls));
            return NO;
        }
    }
    
    [rule mt_deallocObject].cls = cls;
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)mt_forwardInvocation) {
        IMP originalImplementation = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)mt_forwardInvocation, "v@:@");
        if (originalImplementation) {
            class_addMethod(cls, NSSelectorFromString(MTForwardInvocationSelectorName), originalImplementation, "v@:@");
        }
    }
    
    Class superCls = class_getSuperclass(cls);
    Method targetMethod = class_getInstanceMethod(cls, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!mt_isMsgForwardIMP(targetMethodIMP)) {
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        Method targetAliasMethod = class_getInstanceMethod(cls, aliasSelector);
        Method targetAliasMethodSuper = class_getInstanceMethod(superCls, aliasSelector);
        if (![cls instancesRespondToSelector:aliasSelector] || targetAliasMethod == targetAliasMethodSuper) {
            __unused BOOL addedAlias = class_addMethod(cls, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), cls);
        }
        class_replaceMethod(cls, selector, mt_getMsgForwardIMP(statedClass, selector), typeEncoding);
        [MTEngine.defaultEngine.classHooked addObject:cls];
    }
    
    return YES;
}

static void mt_revertHook(Class cls, SEL selector, SEL aliasSelector)
{
    Method targetMethod = class_getInstanceMethod(cls, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (mt_isMsgForwardIMP(targetMethodIMP)) {
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        Method originalMethod = class_getInstanceMethod(cls, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), cls);
        class_replaceMethod(cls, selector, originalIMP, typeEncoding);
    }
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) == (IMP)mt_forwardInvocation) {
        Method originalMethod = class_getInstanceMethod(cls, NSSelectorFromString(MTForwardInvocationSelectorName));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        IMP originalImplementation = method_getImplementation(originalMethod ?: objectMethod);
        class_replaceMethod(cls, @selector(forwardInvocation:), originalImplementation, "v@:@");
    }
}

static BOOL mt_recoverMethod(id target, SEL selector, SEL aliasSelector)
{
    Class cls;
    if (mt_object_isClass(target)) {
        cls = target;
        if ([MTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    else {
        MTDealloc *mtDealloc = objc_getAssociatedObject(target, selector);
        // get class when apply rule on target.
        cls = mtDealloc.cls;
        // target current real class name
        NSString *className = NSStringFromClass(object_getClass(target));
        if ([className hasPrefix:MTSubclassPrefix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:MTSubclassPrefix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            if (originalClass) {
                object_setClass(target, originalClass);
            }
        }
        if ([MTEngine.defaultEngine containsSelector:selector onTarget:cls] ||
            [MTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    mt_revertHook(cls, selector, aliasSelector);
    return YES;
}

static void mt_executeOrigForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    SEL origForwardSelector = NSSelectorFromString(MTForwardInvocationSelectorName);
    if ([object_getClass(slf) instancesRespondToSelector:origForwardSelector]) {
        NSMethodSignature *methodSignature = [slf methodSignatureForSelector:origForwardSelector];
        if (!methodSignature) {
            NSCAssert(NO, @"unrecognized selector -%@ for instance %@", NSStringFromSelector(origForwardSelector), slf);
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

@implementation NSObject (MessageThrottle)

- (NSArray<MTRule *> *)mt_allRules
{
    NSMutableArray<MTRule *> *result = [NSMutableArray array];
    for (MTRule *rule in MTEngine.defaultEngine.allRules) {
        if (rule.target == self || rule.target == mt_classOfTarget(self)) {
            [result addObject:rule];
        }
    }
    return [result copy];
}

- (nullable MTRule *)mt_limitSelector:(SEL)selector oncePerDuration:(NSTimeInterval)durationThreshold
{
    return [self mt_limitSelector:selector oncePerDuration:durationThreshold usingMode:MTPerformModeDebounce];
}

- (nullable MTRule *)mt_limitSelector:(SEL)selector oncePerDuration:(NSTimeInterval)durationThreshold usingMode:(MTPerformMode)mode
{
    return [self mt_limitSelector:selector oncePerDuration:durationThreshold usingMode:mode onMessageQueue:dispatch_get_main_queue()];
}

- (nullable MTRule *)mt_limitSelector:(SEL)selector oncePerDuration:(NSTimeInterval)durationThreshold usingMode:(MTPerformMode)mode onMessageQueue:(dispatch_queue_t)messageQueue
{
    return [self mt_limitSelector:selector oncePerDuration:durationThreshold usingMode:mode onMessageQueue:messageQueue alwaysInvokeBlock:nil];
}

- (nullable MTRule *)mt_limitSelector:(SEL)selector oncePerDuration:(NSTimeInterval)durationThreshold usingMode:(MTPerformMode)mode onMessageQueue:(dispatch_queue_t)messageQueue alwaysInvokeBlock:(id)alwaysInvokeBlock
{
    MTDealloc *mtDealloc = objc_getAssociatedObject(self, selector);
    MTRule *rule = mtDealloc.rule;
    BOOL isNewRule = NO;
    if (!rule) {
        rule = [[MTRule alloc] initWithTarget:self selector:selector durationThreshold:durationThreshold];
        isNewRule = YES;
    }
    rule.durationThreshold = durationThreshold;
    rule.mode = mode;
    rule.messageQueue = messageQueue ?: dispatch_get_main_queue();
    rule.alwaysInvokeBlock = alwaysInvokeBlock;
    rule.persistent = (mode == MTPerformModeFirstly && durationThreshold > 5 && mt_object_isClass(self));
    if (isNewRule) {
        return [rule apply] ? rule : nil;
    }
    return rule;
}

@end
