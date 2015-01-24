//
//  UIApplication+NetworkIndicator.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 21/07/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "UIApplication+NetworkIndicator.h"

static NSInteger networkActivityCount = 0;

@implementation UIApplication (NetworkIndicator)

- (void)startNetworkActivity {
    networkActivityCount++;
    
    [self setNetworkActivityIndicatorVisible:YES];
}

- (void)stopNetworkActivity {
    if(networkActivityCount > 0) {
        networkActivityCount--;
        
        [self setNetworkActivityIndicatorVisible:NO];
    }
}

@end
