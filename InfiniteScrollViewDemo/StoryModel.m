//
//  StoryModel.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "StoryModel.h"

static NSString * const StoryModelAttributeTitle  = @"title";
static NSString * const StoryModelAttributeAuthor = @"author";
static NSString * const StoryModelAttributeURL    = @"url";

@implementation StoryModel

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

+ (NSArray<StoryModel *> *)modelsFromArray:(NSArray<NSDictionary *> *)array {
    NSMutableArray *models = [[NSMutableArray alloc] init];
    
    for(NSDictionary *dict in array) {
        StoryModel *model = [self modelWithDictionary:dict];
        if(model) {
            [models addObject:model];
        }
    }
    
    return [models copy];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if(!self) {
        return nil;
    }
    
    self.title = dictionary[StoryModelAttributeTitle];
    self.author = dictionary[StoryModelAttributeAuthor];
    
    // sometimes HN returns some trash
    NSString *url = dictionary[StoryModelAttributeURL];
    
    if(!url || [[NSNull null] isEqual:url]) {
        return nil;
    }
    
    self.url = [NSURL URLWithString:url];
    
    return self;
}

@end
