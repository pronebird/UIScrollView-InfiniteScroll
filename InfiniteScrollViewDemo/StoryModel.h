//
//  StoryModel.h
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StoryModel : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *author;
@property (nonatomic) NSURL *url;

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;
+ (NSArray<StoryModel *> *)modelsFromArray:(NSArray<NSDictionary *> *)array;

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
