//
//  UIScrollView+InfiniteScroll.h
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-2015 Andrej Mihajlov. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef __pb_kindof
#   undef __pb_kindof
#endif

#if __has_feature(objc_kindof)
#   define __pb_kindof(__typename) __kindof __typename
#else
#   define __pb_kindof(__typename) id
#endif

NS_ASSUME_NONNULL_BEGIN

@interface UIScrollView (InfiniteScroll)

/**
 *  Flag that indicates whether infinite scroll is animating
 */
@property (nonatomic, readonly, getter=isAnimatingInfiniteScroll) BOOL animatingInfiniteScroll;

/**
 *  Infinite scroll activity indicator style (default: UIActivityIndicatorViewStyleGray on iOS, UIActivityIndicatorViewStyleWhite on tvOS)
 */
@property (nonatomic) UIActivityIndicatorViewStyle infiniteScrollIndicatorStyle;

/**
 *  Infinite indicator view
 *
 *  You can set your own custom view instead of default activity indicator, 
 *  make sure it implements methods below:
 *
 *  * `- (void)startAnimating`
 *  * `- (void)stopAnimating`
 *
 *  Infinite scroll will call implemented methods during user interaction.
 */
@property (nonatomic, nullable) UIView *infiniteScrollIndicatorView;

/**
 *  Vertical margin around indicator view (Default: 11)
 */
@property (nonatomic) CGFloat infiniteScrollIndicatorMargin;

/**
 *  Setup infinite scroll handler
 *
 *  @param handler a handler block
 */
- (void)addInfiniteScrollWithHandler:(void(^)(__pb_kindof(UIScrollView *) scrollView))handler;

/**
 *  Unregister infinite scroll
 */
- (void)removeInfiniteScroll;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 *
 *  @param handler a completion block handler called when animation finished
 */
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(__pb_kindof(UIScrollView *) scrollView))handler;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 */
- (void)finishInfiniteScroll;

@end

NS_ASSUME_NONNULL_END
