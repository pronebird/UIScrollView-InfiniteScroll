//
//  ItemModel.h
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ItemModel : NSObject

@property (strong) NSString* title;
@property (strong) NSString* author;
@property (strong) NSURL* url;

+ (instancetype)itemWithDictionary:(NSDictionary*)dictionary;

- (id)initWithDictionary:(NSDictionary*)dictionary;

@end
