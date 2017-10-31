# MessageThrottle

MessageThrottle is a tool helps you control Objective-C message's forwarding frequency.

## Usage

The following example shows how to restrict the frequency of forwarding `- [ViewController foo:]` message to 10 times per second.

```
MTRule *rule = [MTRule new];
rule.cls = ViewController.class;
rule.selector = @selector(foo:);
rule.durationThreshold = 0.1;
[MTEngine.defaultEngine updateRule:rule];
```

`MTRule` represents the rule of a message throttle, which contains message's infomation and frequency. If you want to restrict a class method, just set value of `classMethod` property to `YES`. `MTRule` also define the mode of performing selector. There are three modes in `MTMode`: `MTModePerformFirstly`, `MTModePerformLast` and `MTModePerformDebounce`. 

The default mode is `MTModePerformFirstly`. `MTModePerformFirstly` will performs the first message and ignore all following messages during `durationThreshold`.

```
MTModePerformFirstly:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
perform immediately       ignore     ignore          ignore     
```

`MTModePerformLastly` performs the last message at end time. Please note that does not perform message immediately, the delay time could be `durationThreshold` at most. 

```
MTModePerformLast:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
ignore                    ignore     ignore          perform at end
```

`MTModePerformDebounce` restart timer when another message arrives during `durationThreshold`. So there must be a delay of `durationThreshold` before performing message. 

```
MTModePerformDebounce:
start                                  end
|           durationThreshold(old)       |
@-------------------@------------------->>
|                   |                 
ignore              perform at end of new duration
                    |--------------------------------------->>
                    |           durationThreshold(new)       |
                    start                                  end
```

When using `MTModePerformLastly` or `MTModePerformDebounce`, you can designate a dispatch queue which messages perform on. The `messageQueue` is main queue by default.

`MTEngine` is a singleton class. It manages all rules of message throttles. `updateRule:` method will cover the old rule of the same message.

## Installation

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

## Contributing

- If you **need help** or you'd like to **ask a general question**, open an issue.
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Author

yulingtianxia, yulingtianxia@gmail.com

## License

MessageThrottle is available under the MIT license. See the LICENSE file for more info.

