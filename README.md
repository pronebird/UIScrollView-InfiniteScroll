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

Objective-C:

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

        NSArray<NSIndexPath *> * indexPaths; // index paths of updated rows
        
        // make sure to update tableView before calling -finishInfiniteScroll
        [tableView beginUpdates];
        [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView endUpdates];

        // finish infinite scroll animation
        [tableView finishInfiniteScroll];
    }];
}
```

Swift

Before using InfiniteScroll you have to add the following line in your bridging header file: 

```objc
#import <UIScrollView_InfiniteScroll/UIScrollView+InfiniteScroll.h>
```

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // change indicator view style to white
    tableView.infiniteScrollIndicatorStyle = .White
    
    // Add infinite scroll handler
    tableView.addInfiniteScrollWithHandler { (tableView) -> Void in
        //
        // fetch your data here, can be async operation,
        // just make sure to call finishInfiniteScroll in the end
        //

        let indexPaths = [NSIndexPath]() // index paths of updated rows
        
        // make sure you update tableView before calling -finishInfiniteScroll
        tableView.beginUpdates()
        tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        tableView.endUpdates()
        
        // finish infinite scroll animation
        tableView.finishInfiniteScroll()
    }
}
```

#### Collection view quirks

`UICollectionView#reloadData` causes contentOffset to reset. Please use `UICollectionView#performBatchUpdates` instead when possible.

Objective-C:

```objc
// Somewhere in your implementation file
#import <UIScrollView+InfiniteScroll.h>

// ...

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;

    [self.collectionView addInfiniteScrollWithHandler:^(UICollectionView* collectionView) {
        //
        // fetch your data here, can be async operation,
        // just make sure to call finishInfiniteScroll in the end
        //
        
        // suppose this is an array with new data
        NSArray *newStories;
        
        NSMutableArray *indexPaths = [NSMutableArray new];
        NSInteger index = weakSelf.allStories.count;
    
        // create index paths for affected items
        for(Story *story in newStories) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index++ inSection:0];

            [weakSelf.allStories addObject:story];
            [indexPaths addObject:indexPath];
        }
        
        // Update collection view
        [collectionView performBatchUpdates:^{
            // add new items into collection
            [collectionView insertItemsAtIndexPaths:indexPaths];
        } completion:^(BOOL finished) {
            // finish infinite scroll animations
            [collectionView finishInfiniteScroll];
        }];
    }];
}
```

Swift: 

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // Add infinite scroll handler
    collectionView?.addInfiniteScrollWithHandler { [weak self] (scrollView) -> Void in
        let collectionView = scrollView as! UICollectionView
        
        // suppose this is an array with new data
        let newStories = [Story]()
        
        var indexPaths = [NSIndexPath]()
        let index = self?.allStories.count
        
        // create index paths for affected items
        for story in newStories {
            let indexPath = NSIndexPath(forItem: index++, inSection: 0)
            
            indexPaths.append(indexPath)
            self?.allStories.append(story)
        }
        
        // Update collection view
        collectionView.performBatchUpdates({ () -> Void in
            // add new items into collection
            collectionView.insertItemsAtIndexPaths(indexPaths)
        }, completion: { (finished) -> Void in
            // finish infinite scroll animations
            collectionView.finishInfiniteScroll()
        });
        
    }
}
```

### Custom indicator

You can use custom indicator instead of default `UIActivityIndicatorView`.

Custom indicator must be a subclass of `UIView` and implement the following methods:

```objc
- (void)startAnimating;
- (void)stopAnimating;
```

Objective-C: 
```objc
// optionally you can use custom indicator view
CustomInfiniteIndicator *infiniteIndicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];

self.tableView.infiniteScrollIndicatorView = indicator;
```

Swift: 
```swift
// optionally you can use custom indicator view
tableView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
```

Please see example implementation of indicator view:

* Objective-C: [CustomInfiniteIndicator.m](https://github.com/pronebird/UIScrollView-InfiniteScroll/blob/master/InfiniteScrollViewDemo/CustomInfiniteIndicator.m)

* Swift: [CustomInfiniteIndicator.swift](https://github.com/pronebird/UIScrollView-InfiniteScroll/blob/master/InfiniteScrollViewDemoSwift/CustomInfiniteIndicator.swift)

At the moment InfiniteScroll uses indicator's frame directly so make sure you size custom indicator view beforehand. Such views as `UIImageView` or `UIActivityIndicatorView` will automatically resize themselves so no need to setup frame for them.

### Prevent infinite scroll

Sometimes you need to prevent the infinite scroll from continuing. For example, if your search API has no more results, it does not make sense to keep making the requests or to show the spinner.

Objective-C: 
```objc
// Provide a block to be called right before a infinite scroll event is triggered.  Return YES to allow or NO to prevent it from triggering.
[self.tableView setShouldShowInfiniteScrollHandler:^BOOL(UIScrollView *scrollView) {
    // Only show up to 5 pages then prevent the infinite scroll
    return (weakSelf.currentPage < 5);
}];
```

### Seamlessly preload content

Ideally you want your content to flow seamlessly without ever showing a spinner. Infinite scroll offers an option to specify offset in points that will be used to start preloader before user reaches the bottom of scroll view. 

The proper balance between the number of results you load each time and large enough offset should give your users a decent experience. Most likely you will have to come up with your own formula for the combination of those based on kind of content and device dimensions.

Objective-C:

```objc
// Preload more data 500pt before reaching the bottom of scroll view.
tableView.infiniteScrollTriggerOffset = 500;
```

### Contributors

* [@GorkaMM](https://github.com/GorkaMM)<br/>
  Added custom trigger offset
* [@intrepidmatt](https://github.com/intrepidmatt)<br/>
  Solved longstanding issue with dynamic updates in table views (see [#31](https://github.com/pronebird/UIScrollView-InfiniteScroll/issues/31))
* Ryan Bertrand [@RyanBertrand](https://github.com/RyanBertrand)<br/>
  Added a handler to conditionally prevent the infinite scroll from showing
* Maxim Veksler [@maximveksler](https://github.com/maximveksler)<br/>
  Swift 2.2 upgrade
* Shigeyuki Takeuchi [@takeshig](https://github.com/takeshig)<br/>
  Add Carthage support
* Ivan Chirkov [@nsleader](https://github.com/nsleader)<br/>
  Custom indicators support
* Alex Shevchenko [@skeeet](https://github.com/skeeet)<br/>
  Fix for bounce back glitch when content size is smaller than view bounds
* Vlad [brightsider](https://github.com/brightsider)<br/>
  Add access to check loading status

.. and many others who reported issues and participated in conversations

### Attributions

Demo app icon by [PixelResort](http://appicontemplate.com/ios8/).
