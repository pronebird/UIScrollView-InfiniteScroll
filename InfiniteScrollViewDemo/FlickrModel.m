//
//  FlickrModel.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 12/20/16.
//  Copyright © 2016 codeispoetry.ru. All rights reserved.
//

#import "FlickrModel.h"

static NSString * const FlickrModelAttributeLink        = @"link";
static NSString * const FlickrModelAttributeMedia       = @"media";

static NSString * const FlickrMediaModelAttributeMedium = @"m";

@implementation FlickrMediaModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if(!self) {
        return nil;
    }
    
    NSString *mediumURLString = dictionary[FlickrMediaModelAttributeMedium];
    if(!mediumURLString) {
        return nil;
    }
    
    NSURL *mediumURL = [NSURL URLWithString:mediumURLString];
    if(!mediumURL) {
        return nil;
    }
    
    self.medium = mediumURL;
    
    return self;
}

@end

@implementation FlickrModel

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

+ (NSArray<FlickrModel *> *)modelsFromArray:(NSArray<NSDictionary *> *)array {
    NSMutableArray *models = [[NSMutableArray alloc] init];
    
    for(NSDictionary *dict in array) {
        FlickrModel *model = [self modelWithDictionary:dict];
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
    
    NSString *linkString = dictionary[FlickrModelAttributeLink];
    NSDictionary *mediaDictionary = dictionary[FlickrModelAttributeMedia];
    if(!linkString || !mediaDictionary) {
        return nil;
    }
    
    FlickrMediaModel *media = [[FlickrMediaModel alloc] initWithDictionary:mediaDictionary];
    NSURL *linkURL = [NSURL URLWithString:linkString];
    if(!linkURL || !media) {
        return nil;
    }
    
    self.link = linkURL;
    self.media = media;
    
    return self;
}

@end
