//
//  CustomInfiniteIndicator.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 27/11/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "CustomInfiniteIndicator.h"

static NSString *const kRotationAnimationKey = @"rotation";

@interface CustomInfiniteIndicator()

@property CAShapeLayer *outerCircle;
@property CAShapeLayer *innerCircle;
@property (readwrite) BOOL animating;

@end

@implementation CustomInfiniteIndicator

- (instancetype)initWithCoder:(NSCoder *)coder {
    if(self = [super initWithCoder:coder]) {
        [self _commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        [self _commonInit];
    }
    return self;
}

- (void)dealloc {
    [self _unregisterFromAppStateNotifications];
}

- (void)setThickness:(CGFloat)thickness {
    if(_thickness != thickness) {
        _thickness = thickness;
        
        self.innerCircle.lineWidth = thickness;
        self.outerCircle.lineWidth = thickness;
    }
}
- (void)setInnerColor:(UIColor *)innerColor {
    if(![_innerColor isEqual:innerColor]) {
        _innerColor = innerColor;
        
        self.innerCircle.strokeColor = innerColor.CGColor;
    }
}

- (void)setOuterColor:(UIColor *)outerColor {
    if(![_outerColor isEqual:outerColor]) {
        _outerColor = outerColor;
        
        self.outerCircle.strokeColor = outerColor.CGColor;
    }
}

- (void)startAnimating {
    if(self.animating) {
        return;
    }
    
    self.animating = YES;
    self.hidden = NO;
    [self _addAnimation];
}

- (void)stopAnimating {
    if(!self.animating) {
        return;
    }
    
    [self.layer removeAnimationForKey:kRotationAnimationKey];
    self.hidden = YES;
    self.animating = NO;
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    [self _setupBezierPaths];
}

- (void)prepareForInterfaceBuilder {
    self.hidden = NO;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    
    // CoreAnimation animations are removed when view goes offscreen.
    // So we have to restart them when view reappears.
    if(self.window) {
        [self _restartAnimationIfNeeded];
    }
}

#pragma mark - Private

- (void)_addAnimation {
    [self.layer addAnimation:[self _animation] forKey:kRotationAnimationKey];
}

- (void)_setupBezierPaths {
    CGPoint center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    CGFloat radius = self.bounds.size.width * 0.5 - self.thickness;
    UIBezierPath *ringPath = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    UIBezierPath *quarterRingPath = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:-M_PI_4 endAngle:M_PI_2 - M_PI_4 clockwise:YES];
    
    self.outerCircle.path = ringPath.CGPath;
    self.innerCircle.path = quarterRingPath.CGPath;
}

- (void)_commonInit {
    [self _registerForAppStateNotifications];
    
    self.hidden = YES;
    self.backgroundColor = [UIColor clearColor];
    
    if(self.thickness < 1) {
#if TARGET_OS_TV
        self.thickness = 6;
#else
        self.thickness = 2;
#endif
    }
    
    if(!self.innerColor) {
        self.innerColor = self.tintColor;
    }
    
    if(!self.outerColor) {
        self.outerColor = [[UIColor grayColor] colorWithAlphaComponent:0.2];
    }
    
    CAShapeLayer *outerCircle = [CAShapeLayer layer];
    CAShapeLayer *innerCircle = [CAShapeLayer layer];
    
    outerCircle.strokeColor = self.outerColor.CGColor;
    outerCircle.fillColor = [UIColor clearColor].CGColor;
    outerCircle.lineWidth = self.thickness;
    
    innerCircle.strokeColor = self.innerColor.CGColor;
    innerCircle.fillColor = [UIColor clearColor].CGColor;
    innerCircle.lineWidth = self.thickness;
    
    self.innerCircle = innerCircle;
    self.outerCircle = outerCircle;
    
    [self _setupBezierPaths];
    
    [self.layer addSublayer:outerCircle];
    [self.layer addSublayer:innerCircle];
}

- (CABasicAnimation *)_animation {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    animation.toValue = @(M_PI * 2);
    animation.duration = 1;
    animation.repeatCount = INFINITY;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    
    return animation;
}

- (void)_restartAnimationIfNeeded {
    if(self.animating && ![[self.layer animationKeys] containsObject:kRotationAnimationKey]) {
        [self _addAnimation];
    }
}

#pragma mark - Notifications

- (void)_registerForAppStateNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_restartAnimationIfNeeded) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)_unregisterFromAppStateNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
