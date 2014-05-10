//
//  ItemModel.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "ItemModel.h"

@implementation ItemModel

+ (instancetype)itemWithDictionary:(NSDictionary*)dictionary {
	return [[self alloc] initWithDictionary:dictionary];
}

- (id)initWithDictionary:(NSDictionary*)dictionary {
	if(self = [super init]) {
		self.title = dictionary[@"title"];
		self.author = dictionary[@"author"];
		self.url = [NSURL URLWithString:dictionary[@"url"]];
	}
	return self;
}

@end
