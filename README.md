UIScrollView+InfiniteScroll
===========================

UIScrollView infinite scroll category, that shows a nice spinner when user reaches the bottom of scroll view. It can be useful to organize a message stream loaded in chunks from server like for instance in twitter app.

# Usage

So usually because scroll view or table view can be destroyed in modern storyboard flow when user navigates to another controller, I suggest to use `viewDidAppear` and `viewDidDisappear` to setup and remove infinite scroll. Here below the example for table view:

```objc
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // setup infinite scroll
    // keep a weak reference to table view
    __weak UITableView* weakTableView = self.tableView;
    
    [self.tableView addInfiniteScrollWithHandler:^{
        // keep a strong reference to table view
        __strong UITableView* strongTableView = weakTableView;
        
        // seems like our table view didn't make it
        if(strongTableView == nil) return;
        
        //
        // fetch your data here, can be async operation, 
        // just make sure to call finishInfiniteScroll in the end
        //
        
        // finish infinite scroll animation
        [strongTableView finishInfiniteScroll];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // remove infinite scroll
    [self.tableView removeInfiniteScroll];
}
```
