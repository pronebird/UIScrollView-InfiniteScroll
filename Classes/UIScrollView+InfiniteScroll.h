//
//  UIScrollView+InfiniteScroll.h
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-2015 Andrej Mihajlov. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 UIScrollView infinite scroll category
 */
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
 *  Set vertical adjustment for scroll coordinate used to determine when to call handler block.
 *  Non-zero value advances the point when handler block is being called 
 *  making it fire by N points earlier before scroll view reaches the bottom.
 *  This value is measured in points and must be positive number.
 *  Default: 0.0
 */
@property (nonatomic) CGFloat infiniteScrollTriggerOffset;

/**
 *  Setup infinite scroll handler
 *
 *  @param handler a handler block
 */
- (void)addInfiniteScrollWithHandler:(void(^)(UIScrollView *scrollView))handler;

/**
 *  Set a handler to be called to check if the infinite scroll should be shown
 *
 *  @param handler a handler block
 */
- (void)setShouldShowInfiniteScrollHandler:(nullable BOOL(^)(UIScrollView *scrollView))handler;

/**
 *  Unregister infinite scroll
 */
- (void)removeInfiniteScroll;

/**
 *  Manually begin infinite scroll animations
 *
 *  This method provides identical behavior to user initiated scrolling.
 *
 *  @param forceScroll pass YES to scroll to indicator view
 */
- (void)beginInfiniteScroll:(BOOL)forceScroll;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 *
 *  @param handler a completion block handler called when animation finished
 */
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UIScrollView *scrollView))handler;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 */
- (void)finishInfiniteScroll;

/**
 * Removes the extra bottom inset 
 * You must call this method when the scrollable content has been ended.
 */
- (void)scrollableContentDidEnd;
    
@end

/*
 Convenience interface to avoid cast from UIScrollView to common subclasses such as UITableView and UICollectionView.
 */

@interface UITableView (InfiniteScrollConvenienceInterface)

- (void)addInfiniteScrollWithHandler:(void(^)(UITableView *tableView))handler;
- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UITableView *tableView))handler;
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UITableView *tableView))handler;
    
@end

@interface UICollectionView (InfiniteScrollConvenienceInterface)

- (void)addInfiniteScrollWithHandler:(void(^)(UICollectionView *collectionView))handler;
- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UICollectionView *collectionView))handler;
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UICollectionView *collectionView))handler;

@end

NS_ASSUME_NONNULL_END
