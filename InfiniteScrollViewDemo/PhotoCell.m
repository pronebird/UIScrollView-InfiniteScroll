//
//  PhotoCell.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 24/01/15.
//  Copyright (c) 2015 codeispoetry.ru. All rights reserved.
//

#import "PhotoCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation PhotoCell

#if TARGET_OS_TV

- (instancetype)initWithCoder:(NSCoder *)coder {
    if(self = [super initWithCoder:coder]) {
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;
    }
    return self;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    if(context.nextFocusedView == self) {
        [coordinator addCoordinatedAnimations:^{
            self.layer.transform = CATransform3DMakeScale(1.2, 1.2, 1);
            self.layer.shadowOpacity = 0.5;
            self.layer.shadowOffset = CGSizeMake(0, 5);
            self.layer.shadowColor = [UIColor blackColor].CGColor;
            self.layer.shadowRadius = 10;
        } completion:^{
            
        }];
    }
    else if(context.previouslyFocusedView == self) {
        [coordinator addCoordinatedAnimations:^{
            self.layer.transform = CATransform3DMakeScale(1, 1, 1);
            self.layer.shadowOpacity = 0;
        } completion:^{
            
        }];
    }
}

#endif

@end
