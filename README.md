## UIScrollView+InfiniteScroll

Infinite scroll category helps to organize an infinite stream of content. It tracks user's position in scroll view and when user gets to the bottom of it, it shows the activity indicator and triggers a handler block to load more content.

<p align="center"><img src="InfiniteScrollScreenshot.jpg" /></p>

### CocoaPods

This repo has podspec so you can use it in your Podfile. I'll take an effort to put it on CocoaPods some time later.

```
pod 'UIScrollView-InfiniteScroll', :git => 'https://github.com/pronebird/UIScrollView-InfiniteScroll.git'
```

or 

### Example

```objc
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // setup infinite scroll
    [self.tableView addInfiniteScrollWithHandler:^(UIScrollView* scrollView) {
        //
        // fetch your data here, can be async operation,
        // just make sure to call finishInfiniteScroll in the end
        //

        // finish infinite scroll animation
        [scrollView finishInfiniteScroll];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // remove infinite scroll
    [self.tableView removeInfiniteScroll];
}
```
