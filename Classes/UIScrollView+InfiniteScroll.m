//
//  UIScrollView+InfiniteScroll.m
//
//  UIScrollView infinite scroll category
//
//  Created by Andrej Mihajlov on 9/4/13.
//  Copyright (c) 2013-present Andrej Mihajlov. All rights reserved.
//

#import "UIScrollView+InfiniteScroll.h"
#import <objc/runtime.h>

#define TRACE_ENABLED 0

#if TRACE_ENABLED
#   define TRACE(_format, ...) NSLog(_format, ##__VA_ARGS__)
#else
#   define TRACE(_format, ...)
#endif

/// Animation duration used for setContentOffset:
static const NSTimeInterval kPBInfiniteScrollAnimationDuration = 0.35;

/// Keys for values in associated dictionary
static const void *kPBInfiniteScrollStateKey = &kPBInfiniteScrollStateKey;


#pragma mark - Infinite scroll state
#pragma mark -

/// Private infinite scroll state
@interface _PBInfiniteScrollState : NSObject

/// A flag that indicates whether infinite scroll is initialized
@property (nonatomic) BOOL initialized;

/// A flag that indicates whether loading is in progress.
@property (nonatomic) BOOL loading;

/// Indicator view.
@property (nonatomic) UIView *indicatorView;

/// Indicator style when UIActivityIndicatorView used.
@property (nonatomic) UIActivityIndicatorViewStyle indicatorStyle;

/// Flag used to return user back to top of scroll view
/// when loading initial content.
@property (nonatomic) BOOL scrollToTopWhenFinished;

/// A difference between content size and view bounds
/// Used as a spacer when there is not enough content
/// to fill up the scroll view
@property (nonatomic) CGFloat unoccupiedSpace;

/// Indicator view inset.
/// Essentially is equal to indicator view height.
@property (nonatomic) CGFloat indicatorInset;

/// Indicator view margin (top and bottom)
@property (nonatomic) CGFloat indicatorMargin;

/// Trigger offset.
@property (nonatomic) CGFloat triggerOffset;

/// Infinite scroll handler block
@property (nonatomic, copy) void(^infiniteScrollHandler)(id scrollView);

/// Infinite scroll allowed block
/// Return NO to block the infinite scroll. Useful to stop requests when you have shown all results, etc.
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


#pragma mark - Static helpers
#pragma mark -

static void PBSwizzleMethod(Class c, SEL original, SEL alternate) {
    Method origMethod = class_getInstanceMethod(c, original);
    Method newMethod = class_getInstanceMethod(c, alternate);
    
    if(class_addMethod(c, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, alternate, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

/// A helper function to force table view to do the layout pass
/// See https://github.com/pronebird/UIScrollView-InfiniteScroll/issues/31
static void PBForceUpdateTableViewContentSize(UITableView *tableView) {
    tableView.contentSize = [tableView sizeThatFits:CGSizeMake(CGRectGetWidth(tableView.frame), CGFLOAT_MAX)];
}

static _PBInfiniteScrollState *PBGetInfiniteScrollState(UIScrollView *scrollView) {
    _PBInfiniteScrollState *state = objc_getAssociatedObject(scrollView, kPBInfiniteScrollStateKey);
    
    if(!state) {
        state = [[_PBInfiniteScrollState alloc] init];
        
        objc_setAssociatedObject(scrollView, kPBInfiniteScrollStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return state;
}

UIEdgeInsets PBAdjustedContentInset(UIScrollView *scrollView) {
    if (@available(iOS 11, *)) {
        return scrollView.adjustedContentInset;
    } else {
        return scrollView.contentInset;
    }
}

static void PBScrollViewToTop(UIScrollView *scrollView) {
    CGPoint scrollOffset = scrollView.contentOffset;
    UIEdgeInsets adjustedContentInset = PBAdjustedContentInset(scrollView);
    
    scrollOffset.y = adjustedContentInset.top * -1;
    
    [scrollView setContentOffset:scrollOffset animated:YES];
}

static BOOL PBScrollViewSubclassHasContent(UIScrollView *scrollView) {
    // Default UITableView reports height = 1 on empty tables
    if([scrollView isKindOfClass:[UITableView class]]) {
        return scrollView.contentSize.height > 1;
    } else {
        return scrollView.contentSize.height > 0;
    }
}

static BOOL PBShouldShowInfiniteScroll(UIScrollView *scrollView) {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(scrollView);
    // Use custom handler to determine if infinite scroll should be displayed
    if(state.shouldShowInfiniteScrollHandler) {
        return state.shouldShowInfiniteScrollHandler(scrollView);
    } else {
        return YES;
    }
}

static void PBSetScrollViewContentInset(UIScrollView *scrollView, UIEdgeInsets contentInset, BOOL animated, void(^completion)(BOOL finished)) {
    void(^animations)(void) = ^{
        scrollView.contentInset = contentInset;
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

#pragma mark - Implementation
#pragma mark -

@implementation UIScrollView (InfiniteScroll)

#pragma mark - Public methods
#pragma mark -

- (void)addInfiniteScrollWithHandler:(void(^)(UIScrollView *scrollView))handler {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
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
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
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
    if(PBGetInfiniteScrollState(self).loading) {
        [self pb_stopAnimatingInfiniteScrollWithCompletion:handler];
    }
}

#pragma mark - Accessors
#pragma mark -

- (BOOL)isAnimatingInfiniteScroll {
    return PBGetInfiniteScrollState(self).loading;
}

- (void)setInfiniteScrollIndicatorStyle:(UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    state.indicatorStyle = infiniteScrollIndicatorStyle;
    
    id activityIndicatorView = state.indicatorView;
    if([activityIndicatorView isKindOfClass:[UIActivityIndicatorView class]]) {
        [activityIndicatorView setActivityIndicatorViewStyle:infiniteScrollIndicatorStyle];
    }
}

- (UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
    return PBGetInfiniteScrollState(self).indicatorStyle;
}

- (void)setInfiniteScrollIndicatorView:(UIView *)indicatorView {
    // make sure indicator is initially hidden
    indicatorView.hidden = YES;

    PBGetInfiniteScrollState(self).indicatorView = indicatorView;
}

- (UIView *)infiniteScrollIndicatorView {
    return PBGetInfiniteScrollState(self).indicatorView;
}

- (void)setInfiniteScrollIndicatorMargin:(CGFloat)infiniteScrollIndicatorMargin {
    PBGetInfiniteScrollState(self).indicatorMargin = infiniteScrollIndicatorMargin;
}

- (CGFloat)infiniteScrollIndicatorMargin {
    return PBGetInfiniteScrollState(self).indicatorMargin;
}

- (void)setShouldShowInfiniteScrollHandler:(BOOL(^)(UIScrollView *scrollView))handler{
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
    // Save handler block
    state.shouldShowInfiniteScrollHandler = handler;
}

- (CGFloat)infiniteScrollTriggerOffset {
    return PBGetInfiniteScrollState(self).triggerOffset;
}

- (void)setInfiniteScrollTriggerOffset:(CGFloat)infiniteScrollTriggerOffset {
    PBGetInfiniteScrollState(self).triggerOffset = fabs(infiniteScrollTriggerOffset);
}

#pragma mark - Category
#pragma mark -

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PBSwizzleMethod(self, @selector(setContentOffset:), @selector(pb_setContentOffset:));
        PBSwizzleMethod(self, @selector(setContentSize:), @selector(pb_setContentSize:));
        
        if (@available(iOS 11, *)) {
            PBSwizzleMethod(self, @selector(safeAreaInsetsDidChange), @selector(pb_safeAreaInsetsDidChange));
        }
    });
}

#pragma mark - Private methods
#pragma mark -

/// Additional pan gesture handler used to adjust content offset to reveal or hide indicator view.
- (void)pb_handlePanGesture:(UITapGestureRecognizer *)gestureRecognizer {
    if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:NO];
    }
}

/// Swizzled setContentOffset
- (void)pb_setContentOffset:(CGPoint)contentOffset {
    [self pb_setContentOffset:contentOffset];
    
    if(PBGetInfiniteScrollState(self).initialized) {
        [self pb_scrollViewDidScroll:contentOffset];
    }
}

/// Swizzled setContentSize
- (void)pb_setContentSize:(CGSize)contentSize {
    [self pb_setContentSize:contentSize];
    
    if(PBGetInfiniteScrollState(self).initialized) {
        [self pb_layoutInfiniteScrollIndicator];
    }
}

/// Swizzled safeAreaInsetsDidChange
- (void)pb_safeAreaInsetsDidChange {
    [self pb_safeAreaInsetsDidChange];
    
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    UIEdgeInsets contentInset = self.contentInset;
    
    // We have to pad scroll view when content height is smaller than view bounds.
    CGFloat fittingContentHeight = [self pb_contentHeightFittingVisibleBounds];
    CGFloat unoccupiedSpace = fittingContentHeight - self.contentSize.height;
    
    // Remove previous empty space padding
    contentInset.bottom -= state.unoccupiedSpace;
    
    // Add empty space padding
    contentInset.bottom += unoccupiedSpace;
    
    // Save new empty space inset
    state.unoccupiedSpace = unoccupiedSpace;
    
    // Animate content insets
    PBSetScrollViewContentInset(self, contentInset, YES, ^(BOOL finished) {
        if(finished) {
            [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:NO];
        }
    });
}

/// Returns the content height sufficient enough to fill up the scroll view bounds
- (CGFloat)pb_contentHeightFittingVisibleBounds {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    UIEdgeInsets adjustedContentInset = PBAdjustedContentInset(self);
    CGFloat contentHeight = self.bounds.size.height -
        adjustedContentInset.top -
        (adjustedContentInset.bottom -
         state.unoccupiedSpace -
         state.indicatorInset);
    
    return MAX(self.contentSize.height, contentHeight);

}

/// Calls infinite scroll handler block.
/// Used with performSelector
- (void)pb_callInfiniteScrollHandler {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
    if(state.infiniteScrollHandler) {
        state.infiniteScrollHandler(self);
    }
    
    TRACE(@"Call handler.");
}

/// Returns existing or new activity indicator view.
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


/// Returns a vertical space occuppied by indicator view including margins
- (CGFloat)pb_infiniteIndicatorRowHeight {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    
    return CGRectGetHeight(activityIndicator.bounds) +
        self.infiniteScrollIndicatorMargin * 2;
}

/// Layout indicator view
- (void)pb_layoutInfiniteScrollIndicator {
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat fittingContentHeight = [self pb_contentHeightFittingVisibleBounds];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    CGPoint center = CGPointMake(self.contentSize.width * 0.5, fittingContentHeight + indicatorRowHeight * 0.5);
    
    if(!CGPointEqualToPoint(activityIndicator.center, center)) {
        activityIndicator.center = center;
    }
}

/// Internal method used to start the infinite scroll cycle
- (void)pb_beginInfinitScrollIfNeeded:(BOOL)forceScroll {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
    // already loading?
    if(state.loading) {
        return;
    }
    
    TRACE(@"Action.");
    
    // Only show the infinite scroll if it is allowed
    if(PBShouldShowInfiniteScroll(self)) {
        [self pb_startAnimatingInfiniteScroll:forceScroll];
        
        // This will delay handler execution until scroll deceleration
        [self performSelector:@selector(pb_callInfiniteScrollHandler) withObject:self afterDelay:0.1 inModes:@[ NSDefaultRunLoopMode ]];
    }
}

/// Internal method that starts animations and updates content inset.
- (void)pb_startAnimatingInfiniteScroll:(BOOL)forceScroll {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    UIView *activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    
    // Layout indicator view
    [self pb_layoutInfiniteScrollIndicator];
    
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
    CGFloat fittingContentHeight = [self pb_contentHeightFittingVisibleBounds];
    CGFloat unoccupiedSpace = fittingContentHeight - self.contentSize.height;
    
    // Add empty space padding
    contentInset.bottom += unoccupiedSpace;
    
    // Snapshot the dimensions we used to calculate the content inset
    state.indicatorInset = indicatorInset;
    state.unoccupiedSpace = unoccupiedSpace;
    
    // Update infinite scroll state
    state.loading = YES;
    
    // Scroll to top if scroll view had no content before update
    state.scrollToTopWhenFinished = !PBScrollViewSubclassHasContent(self);
    
    // Animate content insets
    PBSetScrollViewContentInset(self, contentInset, YES, ^(BOOL finished) {
        if(finished) {
            [self pb_scrollToInfiniteIndicatorIfNeeded:YES force:forceScroll];
        }
    });

    TRACE(@"Start animating.");
}

/// Internal method used to stop animations and restore content inset.
- (void)pb_stopAnimatingInfiniteScrollWithCompletion:(nullable void(^)(id scrollView))handler {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    UIView *activityIndicator = self.infiniteScrollIndicatorView;
    UIEdgeInsets contentInset = self.contentInset;
    
    // Force the table view to update its contentSize; if we don't do this,
    // finishInfiniteScroll() will adjust contentInsets and cause contentOffset
    // to be off by an amount equal to the height of the activity indicator.
    // See https://github.com/pronebird/UIScrollView-InfiniteScroll/issues/31
    // Note: this call has to happen before we reset unoccupiedSpace or indicatorInset
    //       otherwise indicator may re-layout at the wrong position but we haven't set
    //       contentInset yet!
    if([self isKindOfClass:[UITableView class]]) {
        PBForceUpdateTableViewContentSize((UITableView *)self);
    }
    
    // Remove row height inset
    contentInset.bottom -= state.indicatorInset;
    
    // Remove extra inset added to pad infinite scroll
    contentInset.bottom -= state.unoccupiedSpace;

    // Reset the dimensions we previously used to produce content inset
    state.indicatorInset = 0;
    state.unoccupiedSpace = 0;
    
    // Animate content insets
    PBSetScrollViewContentInset(self, contentInset, YES, ^(BOOL finished) {
        // Initiate scroll to the bottom if due to user interaction contentOffset.y
        // stuck somewhere between last cell and activity indicator
        if(finished) {
            if(state.scrollToTopWhenFinished) {
                PBScrollViewToTop(self);
            } else {
                [self pb_scrollToInfiniteIndicatorIfNeeded:NO force:NO];
            }
        }
        
        // Stop animating the activity indicator
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
    });
    
    TRACE(@"Stop animating.");
}

/// Called in response to content offset changes
- (void)pb_scrollViewDidScroll:(CGPoint)contentOffset {
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
    CGFloat contentHeight = [self pb_contentHeightFittingVisibleBounds];
    UIEdgeInsets adjustedContentInset = PBAdjustedContentInset(self);
    
    // The lower bound when infinite scroll should kick in
    CGPoint actionOffset;
    actionOffset.x = 0;
    actionOffset.y = contentHeight -
        self.bounds.size.height +
        (adjustedContentInset.bottom -
         state.unoccupiedSpace -
         state.indicatorInset);
    
    // apply trigger offset adjustment
    actionOffset.y -= state.triggerOffset;
    
    // is user initiated?
    if(![self isDragging]) {
        return;
    }
    
    if(contentOffset.y > actionOffset.y && [[self panGestureRecognizer] velocityInView: self].y <= 0) {
        [self pb_beginInfinitScrollIfNeeded:NO];
    }
}

/// Scroll view to reveal or hide the activity indicator when it's partially visible
- (void)pb_scrollToInfiniteIndicatorIfNeeded:(BOOL)reveal force:(BOOL)force {
    // do not interfere with user
    if([self isDragging]) {
        return;
    }
    
    _PBInfiniteScrollState *state = PBGetInfiniteScrollState(self);
    
    // filter out calls from pan gesture
    if(!state.loading) {
        return;
    }
    
    // Force table view to update content size
    if([self isKindOfClass:[UITableView class]]) {
        PBForceUpdateTableViewContentSize((UITableView *)self);
    }
    
    UIEdgeInsets adjustedContentInset = PBAdjustedContentInset(self);
    CGFloat contentHeight = [self pb_contentHeightFittingVisibleBounds];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];

    CGFloat minY = contentHeight - self.bounds.size.height +
        (adjustedContentInset.bottom - state.unoccupiedSpace - state.indicatorInset);
    CGFloat maxY = minY + indicatorRowHeight;
    
    TRACE(@"minY = %.2f; maxY = %.2f; offsetY = %.2f", minY, maxY, self.contentOffset.y);
    
    if((self.contentOffset.y > minY && self.contentOffset.y < maxY) || force) {
        TRACE(@"Scroll to infinite indicator. Reveal: %@", reveal ? @"YES" : @"NO");
        
        // Use -scrollToRowAtIndexPath: in case of UITableView
        // Because -setContentOffset: may not work properly when using self-sizing cells
        if([self isKindOfClass:[UITableView class]]) {
            UITableView *tableView = (UITableView *)self;
            NSInteger lastSection = [tableView numberOfSections] - 1;
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
}

@end
