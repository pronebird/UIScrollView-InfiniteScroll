//
//  TableViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 09/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "TableViewController.h"
#import "UIApplication+NetworkIndicator.h"
#import "BrowserViewController.h"
#import "StoryModel.h"

#import "CustomInfiniteIndicator.h"
#import "UIScrollView+InfiniteScroll.h"

static NSString* const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=%ld&page=%ld";
static NSString* const kShowBrowserSegueIdentifier = @"ShowBrowser";
static NSString* const kCellIdentifier = @"Cell";

static NSString* const kJSONResultsKey = @"hits";
static NSString* const kJSONNumPagesKey = @"nbPages";

@interface TableViewController()

@property (strong) NSMutableArray* stories;
@property (assign) NSInteger currentPage;
@property (assign) NSInteger numPages;

@end

@implementation TableViewController

#pragma mark - Private methods

- (void)showRetryAlertWithError:(NSError*)error {
	UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error fetching data", @"")
														message:[error localizedDescription]
													   delegate:self
											  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
											  otherButtonTitles:NSLocalizedString(@"Retry", @""), nil];
	[alertView show];
}

- (void)handleAPIResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
	// Hide network activity indicator
	[[UIApplication sharedApplication] stopNetworkActivity];

	// Check for network errors
	if(error) {
		[self showRetryAlertWithError:error];
		if(completion) {
			completion();
		}
		return;
	}
	
	// Unserialize JSON
	NSError* JSONError;
	NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
	
	if(JSONError) {
		[self showRetryAlertWithError:JSONError];
		if(completion) {
			completion();
		}
		return;
	}
	
	// Decode models on background queue
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		__block NSMutableArray* newStories = [NSMutableArray new];
		
		for(NSDictionary* item in responseDict[kJSONResultsKey]) {
			@autoreleasepool {
				[newStories addObject:[StoryModel modelWithDictionary:item]];
			}
		}
		
		// Append new data on main thread and reload table
		dispatch_async(dispatch_get_main_queue(), ^{
			self.numPages = [responseDict[kJSONNumPagesKey] integerValue];
			self.currentPage++;
			
			[self.stories addObjectsFromArray:newStories];
			[self.tableView reloadData];
			
			if(completion) {
				completion();
			}
		});
	});
}

- (void)loadRemoteDataWithDelay:(BOOL)withDelay completion:(void(^)(void))completion
{
	// Show network activity indicator
	[[UIApplication sharedApplication] startNetworkActivity];
	
	// Calculate optimal number of results to load
	NSInteger hitsPerPage = CGRectGetHeight(self.tableView.bounds) / 44.0;
	
	// Craft API URL
	NSString* requestURL = [NSString stringWithFormat:kAPIEndpointURL, (long)hitsPerPage, (long)self.currentPage];
	
	// Create request
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:requestURL]];
	
	// Create NSDataTask
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self handleAPIResponse:response data:data error:error completion:completion];
		});
	}];
	
	// Start network task
	
	// I run -[task resume] with delay because my network is too fast
	NSTimeInterval delay = (withDelay ? 2.0 : 0.0);
	
	[task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];

	// enable auto-sizing cells on iOS 8
	if([self.tableView respondsToSelector:@selector(layoutMargins)]) {
		self.tableView.estimatedRowHeight = 88.0;
		self.tableView.rowHeight = UITableViewAutomaticDimension;
	}
	
	self.currentPage = 0;
	self.numPages = 0;
	self.stories = [NSMutableArray new];
	
	__weak typeof(self) weakSelf = self;
	
	// Create custom indicator
	CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];

	// Set custom indicator
	[self.tableView setInfiniteIndicatorView:indicator];
	
	// Add infinite scroll handler
	[self.tableView addInfiniteScrollWithHandler:^(UIScrollView* scrollView) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		
		[strongSelf loadRemoteDataWithDelay:YES completion:^{
			// Finish infinite scroll animations
			[scrollView finishInfiniteScroll];
		}];
	}];
	
	// Load initial data
	[self loadRemoteDataWithDelay:NO completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if([segue.identifier isEqualToString:kShowBrowserSegueIdentifier]) {
		NSIndexPath* selectedRow = [self.tableView indexPathForSelectedRow];
		BrowserViewController* browserController = (BrowserViewController*)segue.destinationViewController;
		browserController.story = self.stories[selectedRow.row];
	}
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.stories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
	StoryModel* itemModel = self.stories[indexPath.row];
	
	cell.textLabel.text = itemModel.title;
	cell.detailTextLabel.text = itemModel.author;

	// enable auto-sizing cells on iOS 8
	if([tableView respondsToSelector:@selector(layoutMargins)]) {
		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
	}

	return cell;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == alertView.firstOtherButtonIndex) {
		[self loadRemoteDataWithDelay:NO completion:nil];
	}
}

@end
