//
//  MTEngine+MTArchive.h
//  MTDemo
//
//  Created by renektonli on 2025/7/14.
//  Copyright © 2025 杨萧玉. All rights reserved.
//

#import "MessageThrottle.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTEngine (MTArchive)

/**
 保存持久化规则
 iOS、macOS 和 tvOS 下杀掉 App 后会自动调用。
 请在需要保存持久化规则的时候手动调用此方法。
 */
- (void)savePersistentRules API_AVAILABLE(macosx(10.11));

@end

NS_ASSUME_NONNULL_END
