//
//  StoryModel.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "StoryModel.h"

@implementation StoryModel

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(self = [super init]) {
        self.title = dictionary[@"title"];
        self.author = dictionary[@"author"];
        
        // sometimes HN returns some trash
        NSString *url = dictionary[@"url"];
        
        if(!url || [[NSNull null] isEqual:url]) {
            return nil;
        }
        
        self.url = [NSURL URLWithString:url];
    }
    return self;
}

@end
