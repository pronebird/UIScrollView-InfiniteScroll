//
//  BrowserViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "BrowserViewController.h"
#import "UIApplication+NetworkIndicator.h"
#import "ItemModel.h"

@implementation BrowserViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.title = self.itemModel.title;
	
	[self.webView loadRequest:[NSURLRequest requestWithURL:self.itemModel.url]];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	
	// This controller is about to die but webview is still loading data
	// Reset delegate, stop webview manually and make hide network activity indicator
	if([self.webView isLoading]) {
		self.webView.delegate = nil;
		[self.webView stopLoading];
		
		[[UIApplication sharedApplication] stopNetworkActivity];
	}
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[[UIApplication sharedApplication] startNetworkActivity];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[[UIApplication sharedApplication] stopNetworkActivity];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	if(error.code != NSURLErrorCancelled) {
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed to load URL", @"")
															message:[error localizedDescription]
														   delegate:self
												  cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
												  otherButtonTitles:NSLocalizedString(@"Retry", @""), nil];
		[alertView show];
	}
	
	[[UIApplication sharedApplication] stopNetworkActivity];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == alertView.firstOtherButtonIndex) {
		[self.webView reload];
		return;
	}
	
	[self.navigationController popViewControllerAnimated:YES];
}

@end
