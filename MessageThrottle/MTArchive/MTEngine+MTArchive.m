//
//  MTEngine+MTArchive.m
//  MTDemo
//
//  Created by renektonli on 2025/7/14.
//  Copyright © 2025 杨萧玉. All rights reserved.
//

#import "MTEngine+MTArchive.h"
#import "MessageThrottle.h"

NSString * const kMTPersistentRulesKey = @"kMTPersistentRulesKey";

@implementation MTEngine (MTArchive)

+ (void)load {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSArray<NSData *> *array = [NSUserDefaults.standardUserDefaults objectForKey:kMTPersistentRulesKey];
        for (NSData *data in array) {
            NSError *error = nil;
            MTRule *rule = [NSKeyedUnarchiver unarchivedObjectOfClass:MTRule.class fromData:data error:&error];
            if (error) {
                NSLog(@"%@", error.localizedDescription);
            } else {
                [rule apply];
            }
        }
    });
}

- (void)savePersistentRules {
    NSMutableArray<NSData *> *array = [NSMutableArray array];
    for (MTRule *rule in self.allRules) {
        if (rule.isPersistent) {
            NSError *error = nil;
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rule requiringSecureCoding:YES error:&error];
            if (error) {
                NSLog(@"%@", error.localizedDescription);
            }
            if (data) {
                [array addObject:data];
            }
        }
    }
    [NSUserDefaults.standardUserDefaults setObject:array forKey:kMTPersistentRulesKey];
}

@end
