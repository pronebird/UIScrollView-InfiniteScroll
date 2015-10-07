//
//  UIApplication+NetworkIndicator.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 21/07/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "UIApplication+NetworkIndicator.h"

@implementation UIApplication (NetworkIndicator)

#if TARGET_OS_TV

- (void)startNetworkActivity {}
- (void)stopNetworkActivity {}

#else

static NSInteger networkActivityCount = 0;

- (void)startNetworkActivity {
    networkActivityCount++;
    
    [self setNetworkActivityIndicatorVisible:YES];
}

- (void)stopNetworkActivity {
    if(networkActivityCount < 1) {
        return;
    }
    
    if(--networkActivityCount == 0) {
        [self setNetworkActivityIndicatorVisible:NO];
    }
}

#endif

@end
