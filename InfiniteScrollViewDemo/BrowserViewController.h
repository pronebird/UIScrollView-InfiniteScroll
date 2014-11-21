//
//  BrowserViewController.h
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 10/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StoryModel;

@interface BrowserViewController : UIViewController<UIWebViewDelegate, UIAlertViewDelegate>

@property (weak) IBOutlet UIWebView* webView;
@property (strong) StoryModel* story;

@end
