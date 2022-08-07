//
//  UIScrollView+InfiniteScroll.h
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-2022 Andrej Mihajlov. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Enum that describes the infinite scroll direction.
 */
typedef NS_ENUM(NSUInteger, InfiniteScrollDirection) {
	/**
	 *  Trigger infinite scroll when the scroll view reaches the bottom.
	 *  This is the default. It is also the only supported direction for
	 *  table views.
	 */
	InfiniteScrollDirectionVertical,

	/**
	 *  Trigger infinite scroll when the scroll view reaches the right edge.
	 *  This should be used for horizontally scrolling collection views.
	 */
	InfiniteScrollDirectionHorizontal,
};

/**
 UIScrollView infinite scroll category
 */
@interface UIScrollView (InfiniteScroll)

/**
 * The direction that the infinite scroll should work in (default: InfiniteScrollDirectionVertical).
 */
@property (nonatomic) InfiniteScrollDirection infiniteScrollDirection;

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
 *  The margin from the scroll view content to the indicator view (Default: 11)
 */
@property (nonatomic) CGFloat infiniteScrollIndicatorMargin;

/**
 *  Set adjustment for scroll coordinate used to determine when to call handler block.
 *  Non-zero value advances the point when handler block is being called 
 *  making it fire by N points earlier before scroll view reaches the bottom or right edge.
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

@end

/**
 Convenience interface for UIScrollView+InfiniteScroll category.
 */
@interface UITableView (InfiniteScrollConvenienceInterface)

/**
 *  Setup infinite scroll handler
 *
 *  @param handler a handler block
 */
- (void)addInfiniteScrollWithHandler:(void(^)(UITableView *tableView))handler;

/**
 *  Set a handler to be called to check if the infinite scroll should be shown
 *
 *  @param handler a handler block
 */
- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UITableView *tableView))handler;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 *
 *  @param handler a completion block handler called when animation finished
 */
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UITableView *tableView))handler;

@end


/**
 Convenience interface for UIScrollView+InfiniteScroll category.
 */
@interface UICollectionView (InfiniteScrollConvenienceInterface)

/**
 *  Setup infinite scroll handler
 *
 *  @param handler a handler block
 */
- (void)addInfiniteScrollWithHandler:(void(^)(UICollectionView *collectionView))handler;

/**
 *  Set a handler to be called to check if the infinite scroll should be shown
 *
 *  @param handler a handler block
 */
- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UICollectionView *collectionView))handler;

/**
 *  Finish infinite scroll animations
 *
 *  You must call this method from your infinite scroll handler to finish all
 *  animations properly and reset infinite scroll state
 *
 *  @param handler a completion block handler called when animation finished
 */
- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UICollectionView *collectionView))handler;

@end

NS_ASSUME_NONNULL_END
