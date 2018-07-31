<p align="center">
<a href="https://github.com/yulingtianxia/MessageThrottle">
<img src="Assets/logo.png" alt="MessageThrottle" />
</a>
</p>

[![CI Status](http://img.shields.io/travis/yulingtianxia/MessageThrottle.svg?style=flat)](https://travis-ci.org/yulingtianxia/MessageThrottle)
[![Version](https://img.shields.io/cocoapods/v/MessageThrottle.svg?style=flat)](http://cocoapods.org/pods/MessageThrottle)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/yulingtianxia/MessageThrottle/branch/master/graph/badge.svg)](https://codecov.io/gh/yulingtianxia/MessageThrottle)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/74890ac9cb4d4be6a8478009ac1c4e52)](https://www.codacy.com/project/yulingtianxia/MessageThrottle/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=yulingtianxia/MessageThrottle&amp;utm_campaign=Badge_Grade_Dashboard)
[![License](https://img.shields.io/cocoapods/l/MessageThrottle.svg?style=flat)](http://cocoapods.org/pods/MessageThrottle)
[![Platform](https://img.shields.io/cocoapods/p/MessageThrottle.svg?style=flat)](http://cocoapods.org/pods/MessageThrottle)
[![CocoaPods](https://img.shields.io/cocoapods/dt/MessageThrottle.svg)](http://cocoapods.org/pods/MessageThrottle)
[![CocoaPods](https://img.shields.io/cocoapods/at/MessageThrottle.svg)](http://cocoapods.org/pods/MessageThrottle)
[![Twitter Follow](https://img.shields.io/twitter/follow/yulingtianxia.svg?style=social&label=Follow)](https://twitter.com/yulingtianxia)

# MessageThrottle

MessageThrottle is a lightweight, simple library for controlling frequency of forwarding Objective-C messages. You can choose to control existing methods per instance or per class. It's an implementation of function throttle/debounce developed with Objective-C runtime. For a visual explaination of the differences between throttling and debouncing, [see this demo](http://demo.nimius.net/debounce_throttle/).

## 📚 Article

- [Objective-C Message Throttle and Debounce](http://yulingtianxia.com/blog/2017/11/05/Objective-C-Message-Throttle-and-Debounce/)
- [Associated Object and Dealloc](http://yulingtianxia.com/blog/2017/12/15/Associated-Object-and-Dealloc/)
- [MessageThrottle Performance Benchmark and Optimization](http://yulingtianxia.com/blog/2018/05/31/MessageThrottle-Performance-Benchmark-and-Optimization/)

## 🌟 Features

- [x] Easy to use.
- [x] Keep your code clear
- [x] Reserve the whole arguments.
- [x] Support instance, class and meta class.
- [x] Support 3 modes: Throttle(Firstly), Throttle(Last) and Debounce.
- [x] Centralized management of rules.
- [x] Self-managed rules.
- [x] Let method **MUST** invoke at the specified conditions.
- [x] Persistent rules. 

## 🔮 Example

To run the example project, clone the repo and run MTDemo target.

![](Assets/demo.gif)

## 🐒 How to use

The following example shows how to restrict the frequency of forwarding `- [ViewController foo:]` message to 100 times per second.

```
Stub *s = [Stub new];
MTRule *rule = [s limitSelector:@selector(foo:) oncePerDuration:0.01]; // returns MTRule instance
``` 

For more control of rule, you can use `mt_limitSelector:oncePerDuration:usingMode:onMessageQueue:alwaysInvokeBlock:`.

You can also start with a creation of `MTRule`:

```
Stub *s = [Stub new];
// You can also assign `Stub.class` or `mt_metaClass(Stub.class)` to `target` argument.
MTRule *rule = [[MTRule alloc] initWithTarget:s selector:@selector(foo:) durationThreshold:0.01];
rule.mode = MTModePerformLast; // Or `MTModePerformFirstly`, ect
rule.messageQueue = /** a dispatch queue you want, maybe `dispatch_get_main_queue()` whatever...*/
rule.alwaysInvokeBlock = ^(MTRule *rule, NSDate *date) {
   if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]]) {
       return YES;
   }
   return NO;
};
[rule apply];
```

You can let method **MUST** invoke at the specified conditions using `alwaysInvokeBlock`. The example code above will invoke message immediately if its 1st parameter equals "1970". BTW, `alwaysInvokeBlock` can has no parameter, or has one more `MTRule` before message's parameter list.

You should call `discard` method When you don't need limit `foo:` method.

```
[rule discard];
```

**NOTE: `MTRule` is self-managed. If the `target` of rule is a object instance, `MTRule` will discard itself automatically when the `target` is deallocated.**

`MTRule` represents the rule of a message throttle, which contains strategy and frequency of sending messages. 

You can assign an instance or (meta)class to `target` property. When you assign an instance to `target`, MessageThrottle will only restrict messages send to this instance. If you want to restrict a class method, just using `mt_metaClass()` to get it's meta class, and assign the meta class to `target`. Rules with instance `target` won't conflict with each other, and have a higher priority than rules with class `target`.

**NOTE: A message can only have one rule per class hierarchy. For example, If there is one rule of message `- [Stub foo:]`, you can't add another rule of message `- [SuperStub foo:]` anymore.** PS: Assume that `Stub` is a subclass of `SuperStub`.

`MTRule` also define the mode of performing selector. There are three modes defined in `MTMode`: `MTModePerformFirstly`, `MTModePerformLast` and `MTModePerformDebounce`. [This demo](http://demo.nimius.net/debounce_throttle/) shows the difference between throttle and debounce.

The default mode is `MTModePerformDebounce`. `MTModePerformDebounce` will restart timer when another message arrives during `durationThreshold`. So there must be a delay of `durationThreshold` at least. 

```
MTModePerformDebounce:
start                                        end
|           durationThreshold(old)             |
@----------------------@---------------------->>
|                      |                 
ignore                 will perform at end of new duration
                       |--------------------------------------------->>
                       |           durationThreshold(new)             |
                       start                                        end
```

`MTModePerformFirstly` will performs the first message and ignore all following messages during `durationThreshold`.

```
MTModePerformFirstly:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
perform immediately       ignore     ignore          ignore     
```

`MTModePerformLast` performs the last message at end time. Please note that does not perform message immediately, the delay could be `durationThreshold` at most. 

```
MTModePerformLast:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
ignore                    ignore     ignore          will perform at end
```

When using `MTModePerformLast` or `MTModePerformDebounce`, you can designate a dispatch queue which messages perform on. The `messageQueue` is main queue by default. `MTModePerformLast` and `MTModePerformDebounce` modes will also use the last arguments to perform messages.

`MTEngine` is a singleton class. It manages all rules of message throttles. You can use `applyRule:` method to apply a rule or update an old rule that already exists. Using it's `discardRule:` method to discardRule a rule. There is also a readonly property `allRules` for obtaining all rules in current application. 

## 📲 Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate MessageThrottle into your Xcode project using CocoaPods, specify it in your `Podfile`:


```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '11.0'
use_frameworks!
target 'MyApp' do
	pod 'MessageThrottle'
end
```

You need replace "MyApp" with your project's name.

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate MessageThrottle into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "yulingtianxia/MessageThrottle"
```

Run `carthage update` to build the framework and drag the built `MessageThrottleKit.framework` into your Xcode project.

### Manual

Just drag the "MessageThrottle" document folder into your project.

## ❤️ Contributed

- If you **need help** or you'd like to **ask a general question**, open an issue.
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## 👨🏻‍💻 Author

yulingtianxia, yulingtianxia@gmail.com

## 👮🏻 License

MessageThrottle is available under the MIT license. See the LICENSE file for more info.

