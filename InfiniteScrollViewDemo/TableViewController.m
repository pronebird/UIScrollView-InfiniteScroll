//
//  TableViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 09/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "TableViewController.h"

#import "UIScrollView+InfiniteScroll.h"
#import "UIApplication+NetworkIndicator.h"
#import "StoryModel.h"
#import "CustomInfiniteIndicator.h"

#define USE_AUTOSIZING_CELLS 1

static NSString *const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=%@&page=%@";

static NSString *const kCellIdentifier = @"Cell";

static NSString *const kJSONResultsKey = @"hits";
static NSString *const kJSONNumPagesKey = @"nbPages";

@interface TableViewController()

@property (nonatomic) NSArray *stories;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) NSInteger numPages;

@end

@implementation TableViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if USE_AUTOSIZING_CELLS
    // enable auto-sizing cells on iOS 8
    if([self.tableView respondsToSelector:@selector(layoutMargins)]) {
        self.tableView.estimatedRowHeight = 88.0;
        self.tableView.rowHeight = UITableViewAutomaticDimension;
    }
#endif
    
    self.stories = [NSArray array];
    self.currentPage = 0;
    self.numPages = 0;
    
    __weak typeof(self) weakSelf = self;
    
    // Create custom indicator
    CGRect indicatorRect;
    
#if TARGET_OS_TV
    indicatorRect = CGRectMake(0, 0, 64, 64);
#else
    indicatorRect = CGRectMake(0, 0, 24, 24);
#endif
    
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:indicatorRect];
    
    // Set custom indicator
    self.tableView.infiniteScrollIndicatorView = indicator;
    
    // Set custom indicator margin
    self.tableView.infiniteScrollIndicatorMargin = 40;

    // Set custom trigger offset
    self.tableView.infiniteScrollTriggerOffset = 500;
    
    // Add infinite scroll handler
    [self.tableView addInfiniteScrollWithHandler:^(UITableView *tableView) {
        [weakSelf fetchData:^{
            // Finish infinite scroll animations
            [tableView finishInfiniteScroll];
        }];
    }];
    
    // Uncomment this to provide conditionally prevent the infinite scroll from triggering
    /*
    [self.tableView setShouldShowInfiniteScrollHandler:^BOOL(UIScrollView * _Nonnull scrollView) {
        // Only show up to 5 pages then prevent the infinite scroll
        return (weakSelf.currentPage < 5);
    }];
     */
    
    // Load initial data
    [self.tableView beginInfiniteScroll:YES];
}

#pragma mark - Actions

- (IBAction)handleRefresh {
    [self.tableView beginInfiniteScroll:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return [self.stories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    StoryModel *story = self.stories[indexPath.row];
    
    cell.textLabel.text = story.title;
    cell.detailTextLabel.text = story.author;

#if USE_AUTOSIZING_CELLS
    // enable auto-sizing cells on iOS 8
    if([tableView respondsToSelector:@selector(layoutMargins)]) {
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
    }
#endif
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StoryModel *story = self.stories[indexPath.row];

    // iOS 9.0+
    if([SFSafariViewController class]) {
        SFSafariViewController *safariController = [[SFSafariViewController alloc] initWithURL:story.url];
        safariController.delegate = self;
        
        UINavigationController *safariNavigationController = [[UINavigationController alloc] initWithRootViewController:safariController];
        [safariNavigationController setNavigationBarHidden:YES animated:NO];
        
        [self presentViewController:safariNavigationController animated:YES completion:nil];
    } else {
        [[UIApplication sharedApplication] openURL:story.url];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Private methods

- (void)showRetryAlertWithError:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"tableView.errorAlert.title", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"tableView.errorAlert.dismiss", @"") style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"tableView.errorAlert.retry", @"") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self fetchData:nil];
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)handleResponse:(NSData *)data error:(NSError *)error {
    if(error) {
        [self showRetryAlertWithError:error];
        return;
    }
    
    NSError *JSONError;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
    
    if(JSONError) {
        [self showRetryAlertWithError:JSONError];
        return;
    }
    
    // parse data into models
    NSArray *results = responseDict[kJSONResultsKey];
    NSArray *newModels = [StoryModel modelsFromArray:results];
    
    // create new index paths
    NSIndexSet *newIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.stories.count, newModels.count)];
    NSMutableArray *newIndexPaths = [[NSMutableArray alloc] init];
    
    [newIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
        [newIndexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
    }];
    
    // update data source
    self.numPages = [responseDict[kJSONNumPagesKey] integerValue];
    self.currentPage += 1;
    self.stories = [self.stories arrayByAddingObjectsFromArray:newModels];
    
    // update table view
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
}

- (void)fetchData:(void(^)(void))completion {
    NSInteger hits = CGRectGetHeight(self.tableView.bounds) / 44.0;
    NSString *URLString = [NSString stringWithFormat:kAPIEndpointURL, @(hits), @(self.currentPage)];
    NSURL *requestURL = [NSURL URLWithString:URLString];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, __unused NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:data error:error];
            
            [[UIApplication sharedApplication] stopNetworkActivity];
            
            if(completion) {
                completion();
            }
        });
    }];

    [[UIApplication sharedApplication] startNetworkActivity];
    
    // I run -[task resume] with delay because my network is too fast
    NSTimeInterval delay = (self.stories.count == 0 ? 0 : 5);
    
    [task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

@end
