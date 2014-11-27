//
//  CustomInfiniteIndicator.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 27/11/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "CustomInfiniteIndicator.h"

static NSString* const kSpinAnimationKey = @"SpinAnimation";

@implementation CustomInfiniteIndicator

- (void)startAnimating {
	[super startAnimating];

	CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];

	animation.fromValue = @(0.0);
	animation.toValue = @(2 * M_PI);
	animation.duration = 1.0f;
	animation.repeatCount = INFINITY;

	[self.layer addAnimation:animation forKey:kSpinAnimationKey];
}

- (void)stopAnimating {
	[super stopAnimating];

	[self.layer removeAnimationForKey:kSpinAnimationKey];
}

@end
