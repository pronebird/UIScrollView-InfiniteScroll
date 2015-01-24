## UIScrollView+InfiniteScroll

Infinite scroll implementation as a category for UIScrollView.

Be aware that this category swizzles `setContentOffset` and `setContentSize` on `UIScrollView`.

Default indicator view

![Standard indicator view](https://raw.githubusercontent.com/pronebird/UIScrollView-InfiniteScroll/master/README%20images/InfiniteScroll1.gif)

Custom indicator view

![Custom indicator view](https://raw.githubusercontent.com/pronebird/UIScrollView-InfiniteScroll/master/README%20images/InfiniteScroll2.gif)

### CocoaPods

Just add the following line in your Podfile:

```ruby
pod 'UIScrollView-InfiniteScroll'
```

### Basic usage

```objc
// Somewhere in your implementation file
#import <UIScrollView+InfiniteScroll.h>

// ...

- (void)viewDidLoad {
    [super viewDidLoad];

    // change indicator view style to white
    self.tableView.infiniteScrollIndicatorStyle = UIActivityIndicatorViewStyleWhite;

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
```

### Custom indicator

You can use custom indicator instead of default `UIActivityIndicatorView`.

Custom indicator must be a subclass of `UIView` and implement the following methods:

 * `- (void)startAnimating`
 * `- (void)stopAnimating`

```objc
// optionally you can use custom indicator view
CustomInfiniteIndicator *infiniteIndicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];

self.tableView.infiniteScrollIndicatorView = indicator;
```

Please see example implementation of indicator view based on `UIImageView`:

[InfiniteScrollViewDemo/CustomInfiniteIndicator.m](https://github.com/pronebird/UIScrollView-InfiniteScroll/blob/master/InfiniteScrollViewDemo/CustomInfiniteIndicator.m)

At the moment InfiniteScroll uses indicator's frame directly so make sure you size custom indicator view beforehand. Such views as `UIImageView` or `UIActivityIndicatorView` will automatically resize themselves so no need to setup frame for them.

### Contributors

* Ivan Chirkov [@nsleader](https://github.com/nsleader)<br/>
  Custom indicators support
* Alex Shevchenko [@skeeet](https://github.com/skeeet)<br/>
  Fix for bounce back glitch when content size is smaller than view bounds

### Known bugs

- Invalid content offset on bounce back when loading small number of items at a time (reproducible with 1 item per page on sample app).
