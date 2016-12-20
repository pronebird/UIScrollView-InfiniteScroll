//
//  UIScrollView+InfiniteScroll.m
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-2015 Andrej Mihajlov. All rights reserved.
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
 *  @param tableView
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
 *  Indicator view.
 */
@property (nonatomic) UIView *indicatorView;

/**
 *  Indicator style when UIActivityIndicatorView used.
 */
@property (nonatomic) UIActivityIndicatorViewStyle indicatorStyle;

/**
 *  Flag used to return user back to top of scroll view 
 *  when loading initial content
 */
@property (nonatomic) BOOL scrollToTopWhenFinished;

/**
 *  Extra padding to push indicator view below view bounds.
 *  Used in case when content size is smaller than view bounds
 */
@property (nonatomic) CGFloat extraBottomInset;

/**
 *  Indicator view inset.
 *  Essentially is equal to indicator view height.
 */
@property (nonatomic) CGFloat indicatorInset;

/**
 *  Indicator view margin (top and bottom)
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
    _indicatorStyle = UIActivityIndicatorViewStyleWhite;
#else
    _indicatorStyle = UIActivityIndicatorViewStyleGray;
#endif
    
    // Default row height (44) minus activity indicator height (22) / 2
    _indicatorMargin = 11;
    
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
 *  @param gestureRecognizer
 */
- (void)pb_handlePanGesture:(UITapGestureRecognizer *)gestureRecognizer {
    if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:NO];
    }
}

/**
 *  This is a swizzled proxy method for setContentOffset of UIScrollView.
 *
 *  @param contentOffset
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
 *  @param contentSize
 */
- (void)pb_setContentSize:(CGSize)contentSize {
    [self pb_setContentSize:contentSize];
    
    if(self.pb_infiniteScrollState.initialized) {
        [self pb_positionInfiniteScrollIndicatorWithContentSize:contentSize];
    }
}

/**
 *  Clamp content size to fit visible bounds of scroll view.
 *  Visible area is a scroll view size minus original top and bottom insets.
 *
 *  @param contentSize content size
 *
 *  @return CGFloat
 */
- (CGFloat)pb_clampContentSizeToFitVisibleBounds:(CGSize)contentSize {
    // Find minimum content height. Only original insets are used in calculation.
    CGFloat minHeight = self.bounds.size.height - self.contentInset.top - [self pb_originalBottomInset];

    return MAX(contentSize.height, minHeight);
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
    
    return self.contentSize.height > constant;
}

/**
 *  Returns bottom inset without extra padding and indicator padding.
 *
 *  @return CGFloat
 */
- (CGFloat)pb_originalBottomInset {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    
    return self.contentInset.bottom - state.extraBottomInset - state.indicatorInset;
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
- (CGFloat)pb_infiniteIndicatorRowHeight {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat indicatorHeight = CGRectGetHeight(activityIndicator.bounds);
    
    return indicatorHeight + self.infiniteScrollIndicatorMargin * 2;
}

/**
 *  Update infinite scroll indicator's position in view.
 *
 *  @param contentSize content size.
 */
- (void)pb_positionInfiniteScrollIndicatorWithContentSize:(CGSize)contentSize {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat contentHeight = [self pb_clampContentSizeToFitVisibleBounds:contentSize];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    CGPoint center = CGPointMake(contentSize.width * 0.5, contentHeight + indicatorRowHeight * 0.5);
    
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
    CGFloat indicatorInset = [self pb_infiniteIndicatorRowHeight];
    
    UIEdgeInsets contentInset = self.contentInset;
    
    // Make a room to accommodate indicator view
    contentInset.bottom += indicatorInset;
    
    // We have to pad scroll view when content height is smaller than view bounds.
    // This will guarantee that indicator view appears at the very bottom of scroll view.
    CGFloat adjustedContentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    CGFloat extraBottomInset = adjustedContentHeight - self.contentSize.height;
    
    // Add empty space padding
    contentInset.bottom += extraBottomInset;
    
    // Save indicator view inset
    state.indicatorInset = indicatorInset;
    
    // Save extra inset
    state.extraBottomInset = extraBottomInset;
    
    // Update infinite scroll state
    state.loading = YES;
    
    // Scroll to top if scroll view had no content before update
    state.scrollToTopWhenFinished = ![self pb_hasContent];
    
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
    
    // Remove row height inset
    contentInset.bottom -= state.indicatorInset;
    
    // Remove extra inset added to pad infinite scroll
    contentInset.bottom -= state.extraBottomInset;
    
    // Reset indicator view inset
    state.indicatorInset = 0;
    
    // Reset extra bottom inset
    state.extraBottomInset = 0;
    
    // Animate content insets
    [self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
        // Initiate scroll to the bottom if due to user interaction contentOffset.y
        // stuck somewhere between last cell and activity indicator
        if(finished) {
            if(state.scrollToTopWhenFinished) {
                [self pb_scrollToTop];
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
 *  @param contentOffset
 */
- (void)pb_scrollViewDidScroll:(CGPoint)contentOffset {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    
    CGFloat contentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    
    // The lower bound when infinite scroll should kick in
    CGPoint actionOffset;
    actionOffset.x = 0;
    actionOffset.y = contentHeight - self.bounds.size.height + [self pb_originalBottomInset];
    
    // apply trigger offset adjustment
    actionOffset.y -= state.triggerOffset;
    
    // is user initiated?
    if(![self isDragging]) {
        return;
    }
    
    if(contentOffset.y > actionOffset.y) {
        [self pb_beginInfinitScrollIfNeeded:NO];
    }
}

/**
 *  Scrolls view to top
 */
- (void)pb_scrollToTop {
    CGPoint pt = CGPointZero;
    pt.y = self.contentInset.top * -1;
    
    [self setContentOffset:pt animated:YES];
}

/**
 *  Scrolls down to activity indicator if it is partially visible
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
    
    CGFloat contentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    
    CGFloat minY = contentHeight - self.bounds.size.height + [self pb_originalBottomInset];
    CGFloat maxY = minY + indicatorRowHeight;
    
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
        
        [self setContentOffset:CGPointMake(0, reveal ? maxY : minY) animated:YES];
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
