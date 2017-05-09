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

// Animation duration used for setContentOffset:
static const NSTimeInterval kPBInfiniteScrollAnimationDuration = 0.35;

// Keys for values in associated dictionary
static const void *kPBInfiniteScrollStateKey = &kPBInfiniteScrollStateKey;
static const void *kPBInfiniteScrollDirectionKey = &kPBInfiniteScrollDirectionKey;

/**
 *  Infinite scroll state class.
 *  @private
 */
@interface _PBInfiniteScrollState : NSObject

/**
 *  A flag that indicates whether scroll is initialized
 */
@property BOOL initialized;

/**
 *  A flag that indicates whether loading is in progress.
 */
@property BOOL loading;

/**
 *  Indicator view.
 */
@property UIView *indicatorView;

/**
 *  Indicator style when UIActivityIndicatorView used.
 */
@property UIActivityIndicatorViewStyle indicatorStyle;

/**
 *  Extra padding to push indicator view below view bounds.
 *  Used in case when content size is smaller than view bounds
 */
@property CGFloat extraBottomInset;

/**
 *  Extra padding to push indicator view below view bounds.
 *  Used in case when content size is smaller than view bounds
 */
@property CGFloat extraTopInset;

/**
 *  Indicator view inset.
 *  Essentially is equal to indicator view height.
 */
@property CGFloat indicatorInset;

/**
 *  Indicator view margin (top and bottom)
 */
@property CGFloat indicatorMargin;

/**
 *  A flag that indicates whether validate if content is higher that view height. Default NO.
 */
@property (nonatomic) BOOL allowTriggerOnUnfilledContent;

/**
 *  Infinite scroll handler block
 */
@property (copy) void(^infiniteScrollHandler)(id scrollView);

@end

@implementation _PBInfiniteScrollState

- (instancetype)init {
    if(self = [super init]) {
#if TARGET_OS_TV
        _indicatorStyle = UIActivityIndicatorViewStyleWhite;
#else
        _indicatorStyle = UIActivityIndicatorViewStyleGray;
#endif
        
        // Default row height (44) minus activity indicator height (22) / 2
        _indicatorMargin = 11;
    }
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

- (void)setInfiniteScrollDirection:(UIScrollViewInfiniteScrollDirection)infiniteScrollDirection {
    objc_setAssociatedObject(self, kPBInfiniteScrollDirectionKey, @(infiniteScrollDirection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIScrollViewInfiniteScrollDirection)infiniteScrollDirection {
    NSNumber *direction = objc_getAssociatedObject(self, kPBInfiniteScrollDirectionKey);
    return direction.integerValue;
}

- (BOOL)isAnimatingInfiniteScroll {
    return self.pb_infiniteScrollState.loading;
}

- (void)addInfiniteScrollWithHandler:(void(^)(__pb_kindof(UIScrollView *) scrollView))handler {
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

- (void)removeInfiniteScroll_ {
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
    
    // Mark infinite scroll as uninitialized
    self.pb_infiniteScrollState.initialized = NO;
}

- (void)finishInfiniteScroll:(BOOL)animated {
    [self finishInfiniteScroll:animated completion:nil];
}

- (void)finishInfiniteScroll:(BOOL)animated completion:(nullable void(^)(__pb_kindof(UIScrollView *) scrollView))handler {
    if(self.pb_infiniteScrollState.loading) {
        [self pb_stopAnimatingInfiniteScroll:animated completion:handler];
    }
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

- (void)setAllowTriggerOnUnfilledContent:(BOOL)allowTriggerOnUnfilledContent {
    self.pb_infiniteScrollState.allowTriggerOnUnfilledContent = allowTriggerOnUnfilledContent;
}

- (BOOL)allowTriggerOnUnfilledContent {
    return self.pb_infiniteScrollState.allowTriggerOnUnfilledContent;
}

#pragma mark - Private dynamic properties

- (_PBInfiniteScrollState *)pb_infiniteScrollState {
    _PBInfiniteScrollState *state = objc_getAssociatedObject(self, kPBInfiniteScrollStateKey);
    
    if(!state) {
        state = [[_PBInfiniteScrollState alloc] init];
        
        objc_setAssociatedObject(self, kPBInfiniteScrollStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return state;
}

#pragma mark - Private methods

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PBSwizzleMethod(self, @selector(setContentOffset:), @selector(pb_setContentOffset:));
        PBSwizzleMethod(self, @selector(setContentSize:), @selector(pb_setContentSize:));
    });
}

/**
 *  Additional pan gesture handler used to adjust content offset to reveal or hide indicator view.
 *
 *  @param gestureRecognizer
 */
- (void)pb_handlePanGesture:(UITapGestureRecognizer *)gestureRecognizer {
    if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self pb_scrollToInfiniteIndicatorIfNeeded];
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
    
    CGFloat inset = self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop ? [self pb_originalTopInset] + self.contentInset.bottom : [self pb_originalBottomInset] + self.contentInset.top;
    
    
    // Find minimum content height. Only original insets are used in calculation.
    CGFloat minHeight = self.bounds.size.height - inset;
    
    return MAX(contentSize.height, minHeight);
}

/**
 *  Returns top inset without extra padding and indicator padding.
 *
 *  @return CGFloat
 */
- (CGFloat)pb_originalTopInset {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    
    return self.contentInset.top - state.extraTopInset - state.indicatorInset;
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
    CGFloat contentHeight = self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop ? 0.0f : [self pb_clampContentSizeToFitVisibleBounds:contentSize];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    CGFloat sign = self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop ? -1 : 1;
    
    CGPoint center = CGPointMake(contentSize.width * 0.5, sign * (contentHeight + indicatorRowHeight * 0.5));
    
    if(!CGPointEqualToPoint(activityIndicator.center, center)) {
        activityIndicator.center = center;
    }
}

/**
 *  Start animating infinite indicator
 */
- (void)pb_startAnimatingInfiniteScroll {
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
    
    
    // We have to pad scroll view when content height is smaller than view bounds.
    // This will guarantee that indicator view appears at the very bottom of scroll view.
    CGFloat adjustedContentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    CGFloat extraInset = adjustedContentHeight - self.contentSize.height;
    
    // Make a room to accommodate indicator view
    if (self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop) {
        
        //
        contentInset.top += indicatorInset;
        
        // Add empty space padding
        contentInset.top += 0.0f;
        
        //
        state.extraTopInset = 0.0f;
    }
    
    // bottom
    else {
        
        //
        contentInset.bottom += indicatorInset;
        
        // Add empty space padding
        contentInset.bottom += extraInset;
        
        //
        state.extraBottomInset = extraInset;
    }
    
    // Save indicator view inset
    state.indicatorInset = indicatorInset;
    
    // Update infinite scroll state
    state.loading = YES;
    
    // Animate content insets
    [self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
        if(finished) {
            [self pb_scrollToInfiniteIndicatorIfNeeded];
        }
    }];
    
    TRACE(@"Start animating.");
}

/**
 *  Stop animating infinite scroll indicator
 *
 *  @param handler a completion handler
 */
- (void)pb_stopAnimatingInfiniteScroll:(BOOL)animated completion:(nullable void(^)(id scrollView))handler {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    UIView *activityIndicator = self.infiniteScrollIndicatorView;
    UIEdgeInsets contentInset = self.contentInset;
    
    // top
    if (self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop) {
        
        contentInset.top -= state.indicatorInset;
        
        // Remove extra inset added to pad infinite scroll
        contentInset.top -= state.extraTopInset;
    }
    
    // bottom
    else {
        // Remove row height inset
        contentInset.bottom -= state.indicatorInset;
        
        // Remove extra inset added to pad infinite scroll
        contentInset.bottom -= state.extraBottomInset;
    }
    
    // Reset indicator view inset
    state.indicatorInset = 0;
    
    // Reset extra bottom inset
    state.extraBottomInset = 0;
    state.extraTopInset = 0;
    
    // Animate content insets
    [self pb_setScrollViewContentInset:contentInset animated:animated completion:^(BOOL finished) {
        // Curtain is closing they're throwing roses at my feet
        if([activityIndicator respondsToSelector:@selector(stopAnimating)]) {
            [activityIndicator performSelector:@selector(stopAnimating)];
        }
        activityIndicator.hidden = YES;
        
        // Reset scroll state
        state.loading = NO;
        
        // Initiate scroll to the bottom if due to user interaction contentOffset.y
        // stuck somewhere between last cell and activity indicator
        if(finished) {
            CGFloat newY = self.contentSize.height - self.bounds.size.height + self.contentInset.bottom;
            
            if(self.contentOffset.y > newY && newY > 0) {
                [self setContentOffset:CGPointMake(0, newY) animated:YES];
                TRACE(@"Stop animating and scroll to bottom.");
            }
        }
        
        // Call completion handler
        if(handler) {
            handler(self);
        }
    }];
    
    TRACE(@"Stop animating.");
}

- (void)pb_scrollViewDidScroll:(CGPoint)contentOffset {
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    
    CGFloat actionOffset = 0;
    
    if (self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionBottom) {
        CGFloat contentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
        
        // The lower bound when infinite scroll should kick in
        actionOffset = contentHeight - self.bounds.size.height + [self pb_originalBottomInset];
        
        // Disable infinite scroll when scroll view is empty
        // Default UITableView reports height = 1 on empty tables
        BOOL hasActualContent = (self.contentSize.height > 1);
        
        // is there any content?
        if(!hasActualContent) {
            return;
        }
    }
    
    // is user initiated?
    if(![self isDragging]) {
        return;
    }
    
    // did it kick in already?
    if(state.loading) {
        return;
    }
    
    BOOL validContentHeight = !self.allowTriggerOnUnfilledContent ? self.contentSize.height > CGRectGetHeight(self.frame) : YES;
    BOOL animate = self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionBottom ? contentOffset.y > actionOffset : contentOffset.y < 0 && validContentHeight;
    
    if(animate) {
        TRACE(@"Action.");
        
        [self pb_startAnimatingInfiniteScroll];
        
        // This will delay handler execution until scroll deceleration
        [self performSelector:@selector(pb_callInfiniteScrollHandler) withObject:self afterDelay:0.1 inModes:@[ NSDefaultRunLoopMode ]];
    }
}

/**
 *  Scrolls down to activity indicator position if activity indicator is partially visible
 */
- (void)pb_scrollToInfiniteIndicatorIfNeeded {
    
    // top
    if (self.infiniteScrollDirection == UIScrollViewInfiniteScrollDirectionTop) return;
    
    // do not interfere with user
    if([self isDragging]) {
        return;
    }
    
    _PBInfiniteScrollState *state = self.pb_infiniteScrollState;
    
    // filter out calls from pan gesture
    if(!state.loading) {
        return;
    }
    
    CGFloat contentHeight = [self pb_clampContentSizeToFitVisibleBounds:self.contentSize];
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    
    CGFloat minY = contentHeight - self.bounds.size.height + [self pb_originalBottomInset];
    CGFloat maxY = minY + indicatorRowHeight;
    
    TRACE(@"minY = %.2f; maxY = %.2f; offsetY = %.2f", minY, maxY, self.contentOffset.y);
    
    if(self.contentOffset.y > minY && self.contentOffset.y < maxY) {
        TRACE(@"Scroll to infinite indicator.");
        [self setContentOffset:CGPointMake(0, maxY) animated:YES];
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
