## UIScrollView+InfiniteScroll

Infinite scroll implementation as a category for UIScrollView.

Be aware that this category swizzles `setContentOffset` and `setContentSize` on `UIScrollView`.

<img src="https://raw.githubusercontent.com/pronebird/UIScrollView-InfiniteScroll/master/README%20images/InfiniteScroll1.gif" width="25%" align="left" hspace="10" vspace="10">
<img src="https://raw.githubusercontent.com/pronebird/UIScrollView-InfiniteScroll/master/README%20images/InfiniteScroll2.gif" width="25%" hspace="10" vspace="10">
<img src="https://raw.githubusercontent.com/pronebird/UIScrollView-InfiniteScroll/master/README%20images/InfiniteScroll3.gif" width="25%" hspace="10" vspace="10">

\* The content used in demo app is publicly available and provided by hn.algolia.com and Flickr. Both can be inappropriate.

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
    [self.tableView addInfiniteScrollWithHandler:^(UITableView* tableView) {
        //
        // fetch your data here, can be async operation,
        // just make sure to call finishInfiniteScroll in the end
        //

        // finish infinite scroll animation
        [tableView finishInfiniteScroll];
    }];
}
```

#### Collection view quirks

`UICollectionView#reloadData` causes contentOffset to reset. Please use `UICollectionView#performBatchUpdates` instead when possible.

```objc
// Somewhere in your implementation file
#import <UIScrollView+InfiniteScroll.h>

// ...

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.collectionView addInfiniteScrollWithHandler:^(UICollectionView* collectionView) {
        //
        // fetch your data here, can be async operation,
        // just make sure to call finishInfiniteScroll in the end
        //
        
        NSArray* newData;
        
        // update collection view
        [collectionView performBatchUpdates:^{
            NSMutableArray* newIndexPaths = [NSMutableArray new];
            NSInteger firstIndex = [collectionView numberOfItemsInSection:0];
            
            // create index paths for new elements
            for(NSInteger i = 0; i < newData.count; i++) {
                NSInteger index = firstIndex + i;
                NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];
                
                [newIndexPaths addObject:indexPath];
            }
            
            // tell collection to append new elements
            [collectionView insertItemsAtIndexPaths:newIndexPaths];
            
            // update your data source with more data
            [collectionView.dataSource appendData:newData];
        } completion:^(BOOL finished) {
            // finish infinite scroll animation
            [collectionView finishInfiniteScroll];
        }];
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

Please see example implementation of indicator view:

[InfiniteScrollViewDemo/CustomInfiniteIndicator.m](https://github.com/pronebird/UIScrollView-InfiniteScroll/blob/master/InfiniteScrollViewDemo/CustomInfiniteIndicator.m)

At the moment InfiniteScroll uses indicator's frame directly so make sure you size custom indicator view beforehand. Such views as `UIImageView` or `UIActivityIndicatorView` will automatically resize themselves so no need to setup frame for them.

### Contributors

* Ivan Chirkov [@nsleader](https://github.com/nsleader)<br/>
  Custom indicators support
* Alex Shevchenko [@skeeet](https://github.com/skeeet)<br/>
  Fix for bounce back glitch when content size is smaller than view bounds

### Known bugs

- Invalid content offset on bounce back when loading small number of items at a time (reproducible with 1 item per page on sample app).
