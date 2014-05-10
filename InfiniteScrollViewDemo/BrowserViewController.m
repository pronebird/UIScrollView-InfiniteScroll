//
//  BrowserViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "BrowserViewController.h"
#import "ItemModel.h"

@implementation BrowserViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.title = self.itemModel.title;
	
	[self.webView loadRequest:[NSURLRequest requestWithURL:self.itemModel.url]];
}

@end
