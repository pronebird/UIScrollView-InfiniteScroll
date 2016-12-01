//
//  TableViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 09/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "TableViewController.h"

#import <SafariServices/SafariServices.h>

#import "UIApplication+NetworkIndicator.h"

#import "StoryModel.h"

#import "CustomInfiniteIndicator.h"
#import "UIScrollView+InfiniteScroll.h"

#define USE_AUTOSIZING_CELLS 1

static NSString *const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=%@&page=%@";

static NSString *const kCellIdentifier = @"Cell";

static NSString *const kJSONResultsKey = @"hits";
static NSString *const kJSONNumPagesKey = @"nbPages";

@interface TableViewController() <SFSafariViewControllerDelegate>

@property (nonatomic) NSMutableArray *stories;
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
    
    self.stories = [[NSMutableArray alloc] init];
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

- (void)tableView:(__unused UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StoryModel *story = self.stories[indexPath.row];
    SFSafariViewController *safariController = [[SFSafariViewController alloc] initWithURL:story.url];
    safariController.delegate = self;
    safariController.hidesBottomBarWhenPushed = YES;
    
    [self.navigationController pushViewController:safariController animated:YES];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(__unused SFSafariViewController *)controller {
    [self.navigationController popViewControllerAnimated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

#pragma mark - Private methods

- (void)showRetryAlertWithError:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error fetching data", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
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
    
    self.numPages = [responseDict[kJSONNumPagesKey] integerValue];
    self.currentPage++;
    
    NSArray *results = responseDict[kJSONResultsKey];
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    
    NSInteger indexPathRow = self.stories.count;
    
    for(NSDictionary *i in results)
    {
        StoryModel *model = [StoryModel modelWithDictionary:i];
        if(!model) {
            continue;
        }
        
        [self.stories addObject:model];
        
        [indexPaths addObject:[NSIndexPath indexPathForRow:indexPathRow inSection:0]];
        
        indexPathRow++;
    }
    
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
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
