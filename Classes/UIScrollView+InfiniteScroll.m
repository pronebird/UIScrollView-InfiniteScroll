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
#	define TRACE(_format, ...) NSLog(_format, ##__VA_ARGS__)
#else
#	define TRACE(_format, ...)
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
static const void* kPBInfiniteScrollHandlerKey = &kPBInfiniteScrollHandlerKey;
static const void* kPBInfiniteScrollIndicatorViewKey = &kPBInfiniteScrollIndicatorViewKey;
static const void* kPBInfiniteScrollIndicatorStyleKey = &kPBInfiniteScrollIndicatorStyleKey;
static const void* kPBInfiniteScrollStateKey = &kPBInfiniteScrollStateKey;
static const void* kPBInfiniteScrollInitKey = &kPBInfiniteScrollInitKey;
static const void* kPBInfiniteScrollOriginalInsetsKey = &kPBInfiniteScrollOriginalInsetsKey;
static const void* kPBInfiniteScrollExtraBottomInsetKey = &kPBInfiniteScrollExtraBottomInsetKey;
static const void* kPBInfiniteScrollIndicatorMarginKey = &kPBInfiniteScrollIndicatorMarginKey;

// Infinite scroll states
typedef NS_ENUM(NSInteger, PBInfiniteScrollState) {
	PBInfiniteScrollStateNone,
	PBInfiniteScrollStateLoading
};

// Private category on UIScrollView to define dynamic properties
@interface UIScrollView ()

// Infinite scroll handler block
@property (copy, nonatomic, setter=pb_setInfiniteScrollHandler:, getter=pb_infiniteScrollHandler)
    void(^pb_infiniteScrollHandler)(UIScrollView* scrollView);

// Infinite scroll state
@property (nonatomic, setter=pb_setInfiniteScrollState:, getter=pb_infiniteScrollState)
    PBInfiniteScrollState pb_infiniteScrollState;

// A flag that indicates whether scroll is initialized
@property (nonatomic, setter=pb_setInfiniteScrollInitialized:, getter=pb_infiniteScrollInitialized)
    BOOL pb_infiniteScrollInitialized;

// Original scroll insets
@property (nonatomic, setter=pb_setInfiniteScrollOriginalInsets:, getter=pb_infiniteScrollOriginalInsets)
    UIEdgeInsets pb_infiniteScrollOriginalInsets;

// Extra padding to push indicator view below view bounds.
// Used in case when content size is smaller than view bounds
@property (nonatomic, setter=pb_setInfiniteScrollExtraBottomInset:, getter=pb_infiniteScrollExtraBottomInset)
    CGFloat pb_infiniteScrollExtraBottomInset;

@end

@implementation UIScrollView (InfiniteScroll)

#pragma mark - Public methods

- (void)addInfiniteScrollWithHandler:(void(^)(UIScrollView* scrollView))handler {
	// Save handler block
    self.pb_infiniteScrollHandler = handler;
	
	// Double initialization only replaces handler block
	// Do not continue if already initialized
	if(self.pb_infiniteScrollInitialized) {
		return;
	}
	
	// Save original scrollView insets
	self.pb_infiniteScrollOriginalInsets = self.contentInset;
	
	// Add pan guesture handler
	[self.panGestureRecognizer addTarget:self action:@selector(pb_handlePanGesture:)];
	
	// Mark infiniteScroll initialized
    self.pb_infiniteScrollInitialized = YES;
}

- (void)removeInfiniteScroll {
	// Ignore multiple calls to remove infinite scroll
	if(!self.pb_infiniteScrollInitialized) {
		return;
	}
	
    // Remove pan gesture handler
	[self.panGestureRecognizer removeTarget:self action:@selector(pb_handlePanGesture:)];
    
    // Destroy infinite scroll indicator
    [self.infiniteScrollIndicatorView removeFromSuperview];
    self.infiniteScrollIndicatorView = nil;
    
    // Mark infinite scroll as uninitialized
	self.pb_infiniteScrollInitialized = NO;
}

- (void)finishInfiniteScroll {
	[self finishInfiniteScrollWithCompletion:nil];
}

- (void)finishInfiniteScrollWithCompletion:(void(^)(UIScrollView* scrollView))handler {
	if(self.pb_infiniteScrollState == PBInfiniteScrollStateLoading) {
		[self pb_stopAnimatingInfiniteScrollWithCompletion:handler];
	}
}

- (void)setInfiniteScrollIndicatorStyle:(UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
	objc_setAssociatedObject(self, kPBInfiniteScrollIndicatorStyleKey, @(infiniteScrollIndicatorStyle), OBJC_ASSOCIATION_ASSIGN);
	id activityIndicatorView = self.infiniteScrollIndicatorView;
	if([activityIndicatorView isKindOfClass:[UIActivityIndicatorView class]]) {
		[activityIndicatorView setActivityIndicatorViewStyle:infiniteScrollIndicatorStyle];
	}
}

- (UIActivityIndicatorViewStyle)infiniteScrollIndicatorStyle {
	NSNumber* indicatorStyle = objc_getAssociatedObject(self, kPBInfiniteScrollIndicatorStyleKey);
    if(indicatorStyle) {
        return indicatorStyle.integerValue;
    }
    return UIActivityIndicatorViewStyleGray;
}

- (void)setInfiniteScrollIndicatorView:(UIView*)indicatorView {
    // make sure indicator is initially hidden
    indicatorView.hidden = YES;
    
    objc_setAssociatedObject(self, kPBInfiniteScrollIndicatorViewKey, indicatorView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView*)infiniteScrollIndicatorView {
    return objc_getAssociatedObject(self, kPBInfiniteScrollIndicatorViewKey);
}

- (void)setInfiniteScrollIndicatorMargin:(CGFloat)infiniteScrollIndicatorMargin {
    objc_setAssociatedObject(self, kPBInfiniteScrollIndicatorMarginKey, @(infiniteScrollIndicatorMargin), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)infiniteScrollIndicatorMargin {
    NSNumber* margin = objc_getAssociatedObject(self, kPBInfiniteScrollIndicatorMarginKey);
    if(margin) {
        return margin.floatValue;
    }
    // Default row height minus activity indicator height
    return 11;
}

#pragma mark - Deprecated methods

- (void)setInfiniteIndicatorView:(UIView*)indicatorView {
    [self setInfiniteScrollIndicatorView:indicatorView];
}

- (UIView*)infiniteIndicatorView {
    return [self infiniteScrollIndicatorView];
}

#pragma mark - Private dynamic properties

- (PBInfiniteScrollState)pb_infiniteScrollState {
    NSNumber* state = objc_getAssociatedObject(self, kPBInfiniteScrollStateKey);
    return [state integerValue];
}

- (void)pb_setInfiniteScrollState:(PBInfiniteScrollState)state {
    objc_setAssociatedObject(self, kPBInfiniteScrollStateKey, @(state), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    TRACE(@"pb_setInfiniteScrollState = %ld", (long)state);
}

- (void)pb_setInfiniteScrollHandler:(void(^)(UIScrollView* scrollView))handler {
    objc_setAssociatedObject(self, kPBInfiniteScrollHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void(^)(UIScrollView* scrollView))pb_infiniteScrollHandler {
    return objc_getAssociatedObject(self, kPBInfiniteScrollHandlerKey);
}

- (void)pb_setInfiniteScrollOriginalInsets:(UIEdgeInsets)insets {
    objc_setAssociatedObject(self, kPBInfiniteScrollOriginalInsetsKey, [NSValue valueWithUIEdgeInsets:insets], OBJC_ASSOCIATION_RETAIN);
}

- (UIEdgeInsets)pb_infiniteScrollOriginalInsets {
    NSValue* insetsValue = objc_getAssociatedObject(self, kPBInfiniteScrollOriginalInsetsKey);
    if(insetsValue) {
        return [insetsValue UIEdgeInsetsValue];
    }
    return UIEdgeInsetsZero;
}

- (void)pb_setInfiniteScrollExtraBottomInset:(CGFloat)height {
    objc_setAssociatedObject(self, kPBInfiniteScrollExtraBottomInsetKey, @(height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)pb_infiniteScrollExtraBottomInset {
    return [objc_getAssociatedObject(self, kPBInfiniteScrollExtraBottomInsetKey) doubleValue];
}

- (BOOL)pb_infiniteScrollInitialized {
    NSNumber* flag = objc_getAssociatedObject(self, kPBInfiniteScrollInitKey);
    
    return [flag boolValue];
}

- (void)pb_setInfiniteScrollInitialized:(BOOL)flag {
    objc_setAssociatedObject(self, kPBInfiniteScrollInitKey, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Private methods

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		PBSwizzleMethod(self, @selector(setContentOffset:), @selector(pb_setContentOffset:));
		PBSwizzleMethod(self, @selector(setContentSize:), @selector(pb_setContentSize:));
	});
}

- (void)pb_handlePanGesture:(UITapGestureRecognizer*)gestureRecognizer {
	if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
		[self pb_scrollToInfiniteIndicatorIfNeeded];
	}
}

- (void)pb_setContentOffset:(CGPoint)contentOffset {
	[self pb_setContentOffset:contentOffset];
	
	if(self.pb_infiniteScrollInitialized) {
		[self pb_scrollViewDidScroll:contentOffset];
	}
}

- (void)pb_setContentSize:(CGSize)contentSize {
	[self pb_setContentSize:contentSize];
	
	if(self.pb_infiniteScrollInitialized) {
		[self pb_positionInfiniteScrollIndicatorWithContentSize:contentSize];
	}
}

- (CGFloat)pb_adjustedHeightFromContentSize:(CGSize)contentSize {
	CGFloat remainingHeight = self.bounds.size.height - self.contentInset.top;
	if(contentSize.height < remainingHeight) {
		return remainingHeight;
	}
	return contentSize.height;
}

- (void)pb_callInfiniteScrollHandler {
	if(self.pb_infiniteScrollHandler) {
		self.pb_infiniteScrollHandler(self);
	}
	TRACE(@"pb_callInfiniteScrollHandler");
}

- (UIView*)pb_getOrCreateActivityIndicatorView {
	UIView* activityIndicator = self.infiniteScrollIndicatorView;

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

- (CGFloat)pb_infiniteIndicatorRowHeight {
    UIView* activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat indicatorHeight = CGRectGetHeight(activityIndicator.bounds);

    return indicatorHeight + self.infiniteScrollIndicatorMargin * 2;
}

- (void)pb_positionInfiniteScrollIndicatorWithContentSize:(CGSize)size {
	// adjust content height for case when contentSize smaller than view bounds
	CGFloat contentHeight = [self pb_adjustedHeightFromContentSize:size];

	UIView* activityIndicator = [self pb_getOrCreateActivityIndicatorView];
    CGFloat indicatorViewHeight = CGRectGetHeight(activityIndicator.bounds);
    CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];
    
	CGRect rect = activityIndicator.frame;
	rect.origin.x = size.width * 0.5 - CGRectGetWidth(rect) * 0.5;
	rect.origin.y = contentHeight + indicatorRowHeight * 0.5 - indicatorViewHeight * 0.5;
	
	if(!CGRectEqualToRect(rect, activityIndicator.frame)) {
		activityIndicator.frame = rect;
		TRACE(@"pb_positionInfiniteScrollIndicatorWithContentSize::setFrame");
	} else {
		TRACE(@"pb_positionInfiniteScrollIndicatorWithContentSize");
	}
}

- (void)pb_startAnimatingInfiniteScroll {
	UIView* activityIndicator = [self pb_getOrCreateActivityIndicatorView];
	
	[self pb_positionInfiniteScrollIndicatorWithContentSize:self.contentSize];

	activityIndicator.hidden = NO;

	if([activityIndicator respondsToSelector:@selector(startAnimating)]) {
		[activityIndicator performSelector:@selector(startAnimating) withObject:nil];
	}

	UIEdgeInsets contentInset = self.contentInset;

	// Make a room to accommodate indicator view
	contentInset.bottom += [self pb_infiniteIndicatorRowHeight];

	// We have to pad scroll view when content height is smaller than view bounds.
	// This will guarantee that indicator view appears at the very bottom of scroll view.
	CGFloat adjustedContentHeight = [self pb_adjustedHeightFromContentSize:self.contentSize];
	CGFloat extraBottomInset = adjustedContentHeight - self.contentSize.height;

	// Add empty space padding
	contentInset.bottom += extraBottomInset;

	// Save extra inset
	self.pb_infiniteScrollExtraBottomInset = extraBottomInset;

	TRACE(@"extraBottomInset = %.2f", extraBottomInset);
	
    self.pb_infiniteScrollState = PBInfiniteScrollStateLoading;
	[self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
		if(finished) {
			[self pb_scrollToInfiniteIndicatorIfNeeded];
		}
	}];
	TRACE(@"pb_startAnimatingInfiniteScroll");
}

- (void)pb_stopAnimatingInfiniteScrollWithCompletion:(void(^)(UIScrollView* scrollView))handler {
	UIView* activityIndicator = self.infiniteScrollIndicatorView;
	UIEdgeInsets contentInset = self.contentInset;
	
	contentInset.bottom -= [self pb_infiniteIndicatorRowHeight];

	// remove extra inset added to pad infinite scroll
	contentInset.bottom -= self.pb_infiniteScrollExtraBottomInset;
	
	[self pb_setScrollViewContentInset:contentInset animated:YES completion:^(BOOL finished) {
		if([activityIndicator respondsToSelector:@selector(stopAnimating)]) {
			[activityIndicator performSelector:@selector(stopAnimating) withObject:nil];
		}

		activityIndicator.hidden = YES;
		
        self.pb_infiniteScrollState = PBInfiniteScrollStateNone;
		
		// Initiate scroll to the bottom if due to user interaction contentOffset.y
		// stuck somewhere between last cell and activity indicator
		if(finished) {
			CGFloat newY = self.contentSize.height - self.bounds.size.height + self.pb_infiniteScrollOriginalInsets.bottom;
			
			if(self.contentOffset.y > newY && newY > 0) {
				[self setContentOffset:CGPointMake(0, newY) animated:YES];
				TRACE(@"pb_stopAnimatingInfiniteScroll::scrollToBottom");
			}
		}
		
		// Call completion handler
		if(handler) {
			handler(self);
		}
	}];
	
	TRACE(@"pb_stopAnimatingInfiniteScroll");
}

- (void)pb_scrollViewDidScroll:(CGPoint)contentOffset {
	CGFloat contentHeight = [self pb_adjustedHeightFromContentSize:self.contentSize];
	CGFloat minY = contentHeight - self.bounds.size.height;

	// Disable infinite scroll when scroll view is empty
	// Default UITableView reports height = 1 on empty tables
	BOOL hasActualContent = (self.contentSize.height > 1);
	
	if([self isDragging] && hasActualContent && contentOffset.y > minY) {
		if(self.pb_infiniteScrollState == PBInfiniteScrollStateNone) {
			TRACE(@"pb_scrollViewDidScroll::initiateInfiniteScroll");
			
			[self pb_startAnimatingInfiniteScroll];
			
			// This will delay handler execution until scroll deceleration
			[self performSelector:@selector(pb_callInfiniteScrollHandler) withObject:self afterDelay:0.1 inModes:@[ NSDefaultRunLoopMode ]];
		}
	}
}

//
// Scrolls down to activity indicator position if activity indicator is partially visible
//
- (void)pb_scrollToInfiniteIndicatorIfNeeded {
	if(![self isDragging] && self.pb_infiniteScrollState == PBInfiniteScrollStateLoading) {
		// adjust content height for case when contentSize smaller than view bounds
		CGFloat contentHeight = [self pb_adjustedHeightFromContentSize:self.contentSize];
        CGFloat indicatorRowHeight = [self pb_infiniteIndicatorRowHeight];

		CGFloat minY = contentHeight - self.bounds.size.height;
		CGFloat maxY = minY + indicatorRowHeight;
		
		TRACE(@"minY = %.2f; maxY = %.2f; offsetY = %.2f", minY, maxY, self.contentOffset.y);
		
		if(self.contentOffset.y > minY && self.contentOffset.y < maxY) {
			TRACE(@"pb_scrollToInfiniteIndicatorIfNeeded");
			[self setContentOffset:CGPointMake(0, maxY) animated:YES];
		}
	}
}

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
