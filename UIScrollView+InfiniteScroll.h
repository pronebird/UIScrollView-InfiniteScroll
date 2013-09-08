//
//  UIScrollView+InfiniteScroll.h
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013 Andrej Mihajlov. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^pb_infinite_scroll_handler_t)(void);
typedef void(^pb_infinite_scroll_completion_t)(void);

@interface UIScrollView (PBInfiniteScroll)

// Setup infinite scroll handler
- (void)addInfiniteScrollWithHandler:(pb_infinite_scroll_handler_t)handler;

// Unregister infinite scroll
- (void)removeInfiniteScroll;

// You must call this method from your handler to finish
// all animations properly and reset infinite scroll state
- (void)finishInfiniteScrollWithCompletion:(pb_infinite_scroll_completion_t)handler;
- (void)finishInfiniteScroll;

@end
