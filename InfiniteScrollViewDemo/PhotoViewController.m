//
//  PhotoViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 4/4/15.
//  Copyright (c) 2015 codeispoetry.ru. All rights reserved.
//

#import "PhotoViewController.h"

@implementation PhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageView.image = self.photo;
}

- (IBAction)dismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
