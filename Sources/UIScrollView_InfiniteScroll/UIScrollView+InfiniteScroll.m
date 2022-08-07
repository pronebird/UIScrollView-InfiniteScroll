//
//  UIScrollView+InfiniteScroll.m
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-2022 Andrej Mihajlov. All rights reserved.
//

#import "UIScrollView+InfiniteScroll.h"
#import <objc/runtime.h>

#define TRACE_ENABLED 0

#if TRACE_ENABLED
#   define TRACE(_format, ...) NSLog(_format, ##__VA_ARGS__)
#else
#   define TRACE(_format, ...)
#endif

static void PBSwizzleMethod(Class c, SEL original, SEL alternate) {
    Method origMethod = class_getInstanceMethod(c, original);
    Method newMethod = class_getInstanceMethod(c, alternate);

    if(class_addMethod(c, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, alternate, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

/**
 *  A helper function to force table view to update its content size
 *
 *  See https://github.com/pronebird/UIScrollView-InfiniteScroll/issues/31
 *
 *  @param tableView table view
 */
static void PBForceUpdateTableViewContentSize(UITableView *tableView) {
    tableView.contentSize = [tableView sizeThatFits:CGSizeMake(CGRectGetWidth(tableView.frame), CGFLOAT_MAX)];
}

// Animation duration used for setContentOffset:
static const NSTimeInterval kPBInfiniteScrollAnimationDuration = 0.35;

// Keys for values in associated dictionary
static const void *kPBInfiniteScrollStateKey = &kPBInfiniteScrollStateKey;

#pragma mark - Infinite scroll state
#pragma mark -

/**
 *  Infinite scroll state class.
 *  @private
 */
@interface _PBInfiniteScrollState : NSObject

/**
 *  A flag that indicates whether scroll is initialized
 */
@property (nonatomic) BOOL initialized;

/**
 *  A flag that indicates whether loading is in progress.
 */
@property (nonatomic) BOOL loading;

/**
 * The direction that the infinite scroll is working in.
 */
@property (nonatomic) InfiniteScrollDirection direction;

/**
 *  Indicator view.
 */
@property (nonatomic) UIView *indicatorView;

/**
 *  Indicator style when UIActivityIndicatorView used.
 */
@property (nonatomic) UIActivityIndicatorViewStyle indicatorStyle;

/**
 *  Flag used to return user back to start of scroll view
 *  when loading initial content.
 */
@property (nonatomic) BOOL scrollToStartWhenFinished;

/**
 *  Extra padding to push indicator view outside view bounds.
 *  Used in case when content size is smaller than view bounds
 */
@property (nonatomic) CGFloat extraEndInset;

/**
 *  Indicator view inset.
 *  Essentially is equal to indicator view height.
 */
@property (nonatomic) CGFloat indicatorInset;

/**
 *  Indicator view margin (top and bottom for vertical direction
 *  or left and right for horizontal direction)
 */
@property (nonatomic) CGFloat indicatorMargin;

/**
 *  Trigger offset.
 */
@property (nonatomic) CGFloat triggerOffset;

/**
 *  Infinite scroll handler block
 */
@property (nonatomic, copy) void(^infiniteScrollHandler)(id scrollView);

/**
 *  Infinite scroll allowed block
 *  Return NO to block the infinite scroll. Useful to stop requests when you have shown all results, etc.
 */
@property (nonatomic, copy) BOOL(^shouldShowInfiniteScrollHandler)(id scrollView);

@end

@implementation _PBInfiniteScrollState

- (instancetype)init {
    self = [super init];
    if(!self) {
        return nil;
    }

#if TARGET_OS_TV
    if (@available(tvOS 13, *)) {
        _indicatorStyle = UIActivityIndicatorViewStyleLarge;
    } else {
        _indicatorStyle = UIActivityIndicatorViewStyleWhite;
    }
#else
    if (@available(iOS 13, *)) {
        _indicatorStyle = UIActivityIndicatorViewStyleMedium;
    } else {
        _indicatorStyle = UIActivityIndicatorViewStyleGray;
    }
#endif

    // Default row height (44) minus activity indicator height (22) / 2
    _indicatorMargin = 11;

    _direction = InfiniteScrollDirectionVertical;

    return self;
}

@end


/**
 *  Private category on UIScrollView to define dynamic properties.
 */
@interface UIScrollView ()

/**
 *  Infinite scroll state.
 */
@property (nonatomic, readonly, getter=pb_infiniteScrollState) _PBInfiniteScrollState *pb_infiniteScrollState;

@end

@implementation UIScrollView (InfiniteScroll)

#pragma mark - Public methods
#pragma mark -

- (void)addInfiniteScrollWithHandler:(void(^)(UIScrollView *scrollView))handler {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // Save handler block
    state.infiniteScrollHandler = handler;

    // Double initialization only replaces handler block
    // Do not continue if already initialized
    if(state.initialized) {
        return;
    }

    // Add pan guesture handler
    [self.panGestureRecognizer addTarget:self action:@selector(pb_handlePanGesture:)];

    // Mark infiniteScroll initialized
    state.initialized = YES;
}

- (void)removeInfiniteScroll {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // Ignore multiple calls to remove infinite scroll
    if(!state.initialized) {
        return;
    }

    // Remove pan gesture handler
    [self.panGestureRecognizer removeTarget:self action:@selector(pb_handlePanGesture:)];

    // Destroy infinite scroll indicator
    [state.indicatorView removeFromSuperview];
    state.indicatorView = nil;

    // Release handler block
    state.infiniteScrollHandler = nil;

    // Mark infinite scroll as uninitialized
    state.initialized = NO;
}

- (void)beginInfiniteScroll:(BOOL)forceScroll {
    [self pb_beginInfinitScrollIfNeeded:forceScroll];
}

- (void)finishInfiniteScroll {
    [self finishInfiniteScrollWithCompletion:nil];
}

- (void)finishInfiniteScrollWithCompletion:(nullable void(^)(UIScrollView *scrollView))handler {
    if(self.pb_infiniteScrollState.loading) {
        [self pb_stopAnimatingInfiniteScrollWithCompletion:handler];
    }
}

#pragma mark - Accessors
#pragma mark -

- (InfiniteScrollDirection)infiniteScrollDirection {
    return self.pb_infiniteScrollState.direction;
}

- (void)setInfiniteScrollDirection:(InfiniteScrollDirection)infiniteScrollDirection {
    self.pb_infiniteScrollState.direction = infiniteScrollDirection;
}

- (BOOL)isAnimatingInfiniteScroll {
    return self.pb_infiniteScrollState.loading;
}

- (void)setInfiniteScrollIndicatorStyle:(UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    state.indicatorStyle = infiniteScrollIndicatorStyle;

    id activityIndicatorView = state.indicatorView;
    if([activityIndicatorView isKindOfClass:[UIActivityIndicatorView class]]) {
        [activityIndicatorView setActivityIndicatorViewStyle:infiniteScrollIndicatorStyle];
    }
}

- (UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
    return self.pb_infiniteScrollState.indicatorStyle;
}

- (void)setInfiniteScrollIndicatorView:(UIView *)indicatorView {
    // make sure indicator is initially hidden
    indicatorView.hidden = YES;

    self.pb_infiniteScrollState.indicatorView = indicatorView;
}

- (UIView *)infiniteScrollIndicatorView {
    return self.pb_infiniteScrollState.indicatorView;
}

- (void)setInfiniteScrollIndicatorMargin:(CGFloat)infiniteScrollIndicatorMargin {
    self.pb_infiniteScrollState.indicatorMargin = infiniteScrollIndicatorMargin;
}

- (CGFloat)infiniteScrollIndicatorMargin {
    return self.pb_infiniteScrollState.indicatorMargin;
}

- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UIScrollView *scrollView))handler{
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // Save handler block
    state.shouldShowInfiniteScrollHandler = handler;
}

- (CGFloat)infiniteScrollTriggerOffset {
    return self.pb_infiniteScrollState.triggerOffset;
}

- (void)setInfiniteScrollTriggerOffset:(CGFloat)infiniteScrollTriggerOffset {
    self.pb_infiniteScrollState.triggerOffset = fabs(infiniteScrollTriggerOffset);
}

#pragma mark - Private dynamic properties
#pragma mark -

- (_PBInfiniteScrollState *)pb_infiniteScrollState {
    _PBInfiniteScrollState *state = objc_getAssociatedObject(self, kPBInfiniteScrollStateKey);

    if(!state) {
        state = [[_PBInfiniteScrollState alloc] init];

        objc_setAssociatedObject(self, kPBInfiniteScrollStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return state;
}

#pragma mark - Category
#pragma mark -

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PBSwizzleMethod(self, @selector(setContentOffset:), @selector(pb_setContentOffset:));
        PBSwizzleMethod(self, @selector(setContentSize:), @selector(pb_setContentSize:));
    });
}

#pragma mark - Private methods
#pragma mark -

/**
 *  Additional pan gesture handler used to adjust content offset to reveal or hide indicator view.
 *
 *  @param gestureRecognizer gesture recognizer
 */
- (void)pb_handlePanGesture:(UITapGestureRecognizer *)gestureRecognizer {
    if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:NO];
    }
}

/**
 *  This is a swizzled proxy method for setContentOffset of UIScrollView.
 *
 *  @param contentOffset content offset
 */
- (void)pb_setContentOffset:(CGPoint)contentOffset {
    [self pb_setContentOffset:contentOffset];

    if(self.pb_infiniteScrollState.initialized) {
        [self pb_scrollViewDidScroll:contentOffset];
    }
}

/**
 *  This is a swizzled proxy method for setContentSize of UIScrollView
 *
 *  @param contentSize content size
 */
- (void)pb_setContentSize:(CGSize)contentSize {
    [self pb_setContentSize:contentSize];

    if(self.pb_infiniteScrollState.initialized) {
        [self pb_positionInfiniteScrollIndicatorWithContentSize:contentSize];
    }
}

/**
 *  Clamp content size to fit visible bounds of scroll view.
 *  Visible area is a scroll view size minus original top and bottom insets for vertical direction,
 *  or minus original left and right insets for horizontal direction.
 *
 *  @param contentSize content size
 *
 *  @return CGFloat
 */
- (CGFloat)pb_clampContentSizeToFitVisibleBounds:(CGSize)contentSize {
    UIEdgeInsets adjustedContentInset = [self pb_adjustedContentInset];

    // Find minimum content height. Only original insets are used in calculation.
    if (self.pb_infiniteScrollState.direction == InfiniteScrollDirectionVertical) {
        CGFloat minHeight = self.bounds.size.height - adjustedContentInset.top - [self pb_originalEndInset];
        return MAX(contentSize.height, minHeight);
    } else {
        CGFloat minWidth = self.bounds.size.width - adjustedContentInset.left - [self pb_originalEndInset];
        return MAX(contentSize.width, minWidth);
    }
}

/**
 *  Checks if UIScrollView is empty.
 *
 *  @return BOOL
 */
- (BOOL)pb_hasContent {
    CGFloat constant = 0;

    // Default UITableView reports height = 1 on empty tables
    if([self isKindOfClass:[UITableView class]]) {
        constant = 1;
    }

    if (self.pb_infiniteScrollState.direction == InfiniteScrollDirectionVertical) {
        return self.contentSize.height > constant;
    } else {
        return self.contentSize.width > constant;
    }
}

/**
 *  Returns end (bottom or right) inset without extra padding and indicator padding.
 *
 *  @return CGFloat
 */
- (CGFloat)pb_originalEndInset {
    UIEdgeInsets adjustedContentInset = [self pb_adjustedContentInset];
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    if (state.direction == InfiniteScrollDirectionVertical) {
        return adjustedContentInset.bottom - state.extraEndInset - state.indicatorInset;
    } else {
        return adjustedContentInset.right - state.extraEndInset - state.indicatorInset;
    }
}

/**
 *  Returns `adjustedContentInset` on iOS 11+, or `contentInset` on earlier iOS
 */
- (UIEdgeInsets)pb_adjustedContentInset {
    if (@available(iOS 11, tvOS 11, *)) {
        return self.adjustedContentInset;
    } else {
        return self.contentInset;
    }
}

/**
 *  Call infinite scroll handler block, primarily here because we use performSelector to call this method.
 */
- (void)pb_callInfiniteScrollHandler {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    if(state.infiniteScrollHandler) {
        state.infiniteScrollHandler(self);
    }

    TRACE(@"Call handler.");
}

/**
 *  Guaranteed to return an indicator view.
 *
 *  @return indicator view.
 */
- (UIView *)pb_getOrCreateActivityIndicatorView {
    UIView *activityIndicator = self.infiniteScrollIndicatorView;

    if(!activityIndicator) {
        activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:self.infiniteScrollIndicatorStyle];
        self.infiniteScrollIndicatorView = activityIndicator;
    }

    // Add activity indicator into scroll view if needed
    if(activityIndicator.superview != self) {
        [self addSubview:activityIndicator];
    }

    return activityIndicator;
}

/**
 *  A row height for indicator view, in other words: indicator margin + indicator height.
 *
 *  @return CGFloat
 */
- (CGFloat)pb_infiniteIndicatorRowSize {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];

    if (self.pb_infiniteScrollState.direction == InfiniteScrollDirectionVertical) {
        CGFloat indicatorHeight = CGRectGetHeight(activityIndicator.bounds);
        return indicatorHeight + self.infiniteScrollIndicatorMargin * 2;
    } else {
        CGFloat indicatorWidth = CGRectGetWidth(activityIndicator.bounds);
        return indicatorWidth + self.infiniteScrollIndicatorMargin * 2;
    }
}

/**
 *  Update infinite scroll indicator's position in view.
 *
 *  @param contentSize content size.
 */
- (void)pb_positionInfiniteScrollIndicatorWithContentSize:(CGSize)contentSize {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat contentLength = [self pb_clampContentSizeToFitVisibleBounds:contentSize];
    CGFloat indicatorRowSize = [self pb_infiniteIndicatorRowSize];

    CGPoint center;
    if (self.pb_infiniteScrollState.direction == InfiniteScrollDirectionVertical) {
        center = CGPointMake(contentSize.width * 0.5, contentLength + indicatorRowSize * 0.5);
    } else {
        center = CGPointMake(contentLength + indicatorRowSize * 0.5, contentSize.height * 0.5);
    }

    if(!CGPointEqualToPoint(activityIndicator.center, center)) {
        activityIndicator.center = center;
    }
}

/**
 *  Update infinite scroll indicator's position in view.
 *
 *  @param forceScroll force scroll to indicator view
 */
- (void)pb_beginInfinitScrollIfNeeded:(BOOL)forceScroll {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // already loading?
    if(state.loading) {
        return;
    }

    TRACE(@"Action.");

    // Only show the infinite scroll if it is allowed
    if([self pb_shouldShowInfiniteScroll]) {
        [self pb_startAnimatingInfiniteScroll:forceScroll];

        // This will delay handler execution until scroll deceleration
        [self performSelector:@selector(pb_callInfiniteScrollHandler) withObject:self afterDelay:0.1 inModes:@[ NSDefaultRunLoopMode ]];
    }
}

/**
 *  Start animating infinite indicator
 */
- (void)pb_startAnimatingInfiniteScroll:(BOOL)forceScroll {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];

    // Layout indicator view
    [self pb_positionInfiniteScrollIndicatorWithContentSize:self.contentSize];

    // It's show time!
    activityIndicator.hidden = NO;
    if([activityIndicator respondsToSelector:@selector(startAnimating)]) {
        [activityIndicator performSelector:@selector(startAnimating)];
    }

    // Calculate indicator view inset
    CGFloat indicatorInset = [self pb_infiniteIndicatorRowSize];

    UIEdgeInsets contentInset = self.contentInset;

    // Make a room to accommodate indicator view
    if (state.direction == InfiniteScrollDirectionVertical) {
        contentInset.bottom += indicatorInset;
    } else {
        contentInset.right += indicatorInset;
    }

    // We have to pad scroll view when content size is smaller than view bounds.
    // This will guarantee that indicator view appears at the very end of scroll view.
    CGFloat adjustedContentSize = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    // Add empty space padding
    if (state.direction == InfiniteScrollDirectionVertical) {
        CGFloat extraBottomInset = adjustedContentSize - self.contentSize.height;
        contentInset.bottom += extraBottomInset;

        // Save extra inset
        state.extraEndInset = extraBottomInset;
    } else {
        CGFloat extraRightInset = adjustedContentSize - self.contentSize.width;
        contentInset.right += extraRightInset;

        // Save extra inset
        state.extraEndInset = extraRightInset;
    }

    // Save indicator view inset
    state.indicatorInset = indicatorInset;

    // Update infinite scroll state
    state.loading = YES;

    // Scroll to start if scroll view had no content before update
    state.scrollToStartWhenFinished = ![self pb_hasContent];

    // Animate content insets
    [self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
        if(finished) {
            [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:forceScroll];
        }
    }];

    TRACE(@"Start animating.");
}

/**
 *  Stop animating infinite scroll indicator
 *
 *  @param handler a completion handler
 */
- (void)pb_stopAnimatingInfiniteScrollWithCompletion:(nullable void(^)(id scrollView))handler {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    UIView *activityIndicator = self.infiniteScrollIndicatorView;
    UIEdgeInsets contentInset = self.contentInset;

    // Force the table view to update its contentSize; if we don't do this,
    // finishInfiniteScroll() will adjust contentInsets and cause contentOffset
    // to be off by an amount equal to the height of the activity indicator.
    // See https://github.com/pronebird/UIScrollView-InfiniteScroll/issues/31
    // Note: this call has to happen before we reset extraBottomInset or indicatorInset
    //       otherwise indicator may re-layout at the wrong position but we haven't set
    //       contentInset yet!
    if([self isKindOfClass:[UITableView class]]) {
        PBForceUpdateTableViewContentSize((UITableView *)self);
    }

    if (state.direction == InfiniteScrollDirectionVertical) {
        // Remove row height inset
        contentInset.bottom -= state.indicatorInset;
        // Remove extra inset added to pad infinite scroll
        contentInset.bottom -= state.extraEndInset;
    } else {
        // Remove row height inset
        contentInset.right -= state.indicatorInset;
        // Remove extra inset added to pad infinite scroll
        contentInset.right -= state.extraEndInset;
    }

    // Reset indicator view inset
    state.indicatorInset = 0;

    // Reset extra end inset
    state.extraEndInset = 0;

    // Animate content insets
    [self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
        // Initiate scroll to the end if due to user interaction contentOffset
        // stuck somewhere between last cell and activity indicator
        if(finished) {
            if(state.scrollToStartWhenFinished) {
                [self pb_scrollToStart];
            } else {
                [self pb_scrollToInfiniteIndicatorIfNeeded:NO force:NO];
            }
        }

        // Curtain is closing they're throwing roses at my feet
        if([activityIndicator respondsToSelector:@selector(stopAnimating)]) {
            [activityIndicator performSelector:@selector(stopAnimating)];
        }
        activityIndicator.hidden = YES;

        // Reset scroll state
        state.loading = NO;

        // Call completion handler
        if(handler) {
            handler(self);
        }
    }];

    TRACE(@"Stop animating.");
}

- (BOOL)pb_shouldShowInfiniteScroll {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // Ensure we should show the inifinite scroll
    if(state.shouldShowInfiniteScrollHandler) {
        return state.shouldShowInfiniteScrollHandler(self);
    }

    return YES;
}

/**
 *  Called whenever content offset changes.
 *
 *  @param contentOffset content offset
 */
- (void)pb_scrollViewDidScroll:(CGPoint)contentOffset {
    // is user initiated?
    if(![self isDragging] && !UIAccessibilityIsVoiceOverRunning()) {
        return;
    }

    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    CGFloat contentSize = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];

    if (state.direction == InfiniteScrollDirectionVertical) {
        // The lower bound when infinite scroll should kick in
        CGPoint actionOffset;
        actionOffset.x = 0;
        actionOffset.y = contentSize - self.bounds.size.height + [self pb_originalEndInset];

        // apply trigger offset adjustment
        actionOffset.y -= state.triggerOffset;

        if(contentOffset.y > actionOffset.y && [[self panGestureRecognizer] velocityInView: self].y <= 0) {
            [self pb_beginInfinitScrollIfNeeded:NO];
        }
    } else {
        // The lower bound when infinite scroll should kick in
        CGPoint actionOffset;
        actionOffset.x = contentSize - self.bounds.size.width + [self pb_originalEndInset];
        actionOffset.y = 0;

        // apply trigger offset adjustment
        actionOffset.x -= state.triggerOffset;

        if(contentOffset.x > actionOffset.x && [[self panGestureRecognizer] velocityInView: self].x <= 0) {
            [self pb_beginInfinitScrollIfNeeded:NO];
        }
    }
}

/**
 *  Scrolls view to start
 */
- (void)pb_scrollToStart {
    UIEdgeInsets adjustedContentInset = [self pb_adjustedContentInset];
    CGPoint pt = CGPointZero;

    if (self.pb_infiniteScrollState.direction == InfiniteScrollDirectionVertical) {
        pt.x = self.contentOffset.x;
        pt.y = adjustedContentInset.top * -1;
    } else {
        pt.x = adjustedContentInset.left * -1;
        pt.y = self.contentOffset.y;
    }

    [self setContentOffset:pt animated:YES];
}

/**
 *  Scrolls to activity indicator if it is partially visible
 *
 *  @param reveal scroll to reveal or hide activity indicator
 *  @param force forces scroll to bottom
 */
- (void)pb_scrollToInfiniteIndicatorIfNeeded:(BOOL)reveal force:(BOOL)force {
    // do not interfere with user
    if([self isDragging]) {
        return;
    }

    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;

    // filter out calls from pan gesture
    if(!state.loading) {
        return;
    }

    // Force table view to update content size
    if([self isKindOfClass:[UITableView class]]) {
        PBForceUpdateTableViewContentSize((UITableView *)self);
    }

    CGFloat contentSize = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    CGFloat indicatorRowSize = [self pb_infiniteIndicatorRowSize];

    if (state.direction == InfiniteScrollDirectionVertical) {
        CGFloat minY = contentSize - self.bounds.size.height + [self pb_originalEndInset];
        CGFloat maxY = minY + indicatorRowSize;

        TRACE(@"minY = %.2f; maxY = %.2f; offsetY = %.2f", minY, maxY, self.contentOffset.y);

        if((self.contentOffset.y > minY && self.contentOffset.y < maxY) || force) {
            TRACE(@"Scroll to infinite indicator. Reveal: %@", reveal ? @"YES" : @"NO");

            // Use -scrollToRowAtIndexPath: in case of UITableView
            // Because -setContentOffset: may not work properly when using self-sizing cells
            if([self isKindOfClass:[UITableView class]]) {
                UITableView *tableView = (UITableView *)self;
                NSInteger numSections = [tableView numberOfSections];
                NSInteger lastSection = numSections - 1;
                NSInteger numRows = lastSection >= 0 ? [tableView numberOfRowsInSection:lastSection] : 0;
                NSInteger lastRow = numRows - 1;

                if(lastSection >= 0 && lastRow >= 0) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:lastRow inSection:lastSection];
                    UITableViewScrollPosition scrollPos = reveal ? UITableViewScrollPositionTop : UITableViewScrollPositionBottom;

                    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPos animated:YES];

                    // explicit return
                    return;
                }

                // setContentOffset: works fine for empty table view.
            }

            [self setContentOffset:CGPointMake(self.contentOffset.x, reveal ? maxY : minY) animated:YES];
        }
    } else {
        CGFloat minX = contentSize - self.bounds.size.width + [self pb_originalEndInset];
        CGFloat maxX = minX + indicatorRowSize;

        TRACE(@"minX = %.2f; maxX = %.2f; offsetX = %.2f", minX, maxX, self.contentOffset.x);

        if((self.contentOffset.x > minX && self.contentOffset.x < maxX) || force) {
            TRACE(@"Scroll to infinite indicator. Reveal: %@", reveal ? @"YES" : @"NO");
            [self setContentOffset:CGPointMake(reveal ? maxX : minX, self.contentOffset.y) animated:YES];
        }
    }
}

/**
 *  Set content inset with animation.
 *
 *  @param contentInset a new content inset
 *  @param animated     animate?
 *  @param completion   a completion block
 */
- (void)pb_setScrollViewContentInset:(UIEdgeInsets)contentInset animated:(BOOL)animated completion:(void(^)(BOOL finished))completion {
    void(^animations)(void) = ^{
        self.contentInset = contentInset;
    };

    if(animated)
    {
        [UIView animateWithDuration:kPBInfiniteScrollAnimationDuration
                              delay:0.0
                            options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState)
                         animations:animations
                         completion:completion];
    }
    else
    {
        [UIView performWithoutAnimation:animations];

        if(completion) {
            completion(YES);
        }
    }
}

@end
