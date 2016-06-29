//
//  BrowserViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "BrowserViewController.h"
#import "UIApplication+NetworkIndicator.h"
#import "StoryModel.h"

@implementation BrowserViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = self.story.title;
    
    [self startLoading];
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

- (void)startLoading {
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.story.url]];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(__unused UIWebView *)webView {
    [[UIApplication sharedApplication] startNetworkActivity];
}

- (void)webViewDidFinishLoad:(__unused UIWebView *)webView {
    [[UIApplication sharedApplication] stopNetworkActivity];
}

- (void)webView:(__unused UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if(error.code != NSURLErrorCancelled) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Failed to load URL", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            [self.navigationController popViewControllerAnimated:YES];
        }]];
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self startLoading];
        }]];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    [[UIApplication sharedApplication] stopNetworkActivity];
}

@end
