//
//  StoryModel.h
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StoryModel : NSObject

@property NSString *title;
@property NSString *author;
@property NSURL *url;

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;
- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
