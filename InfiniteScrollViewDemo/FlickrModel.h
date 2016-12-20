//
//  FlickrModel.h
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 12/20/16.
//  Copyright © 2016 codeispoetry.ru. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlickrMediaModel : NSObject

@property (nonatomic) NSURL *medium;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface FlickrModel : NSObject

@property (nonatomic) NSURL *link;
@property (nonatomic) FlickrMediaModel *media;

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;
+ (NSArray<FlickrModel *> *)modelsFromArray:(NSArray<NSDictionary *> *)array;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
