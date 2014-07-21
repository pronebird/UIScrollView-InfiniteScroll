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
#import "ItemModel.h"

#import "UIScrollView+InfiniteScroll.h"

static NSString* const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story";
static NSString* const kShowBrowserSegueIdentifier = @"ShowBrowser";
static NSString* const kCellIdentifier = @"Cell";

@interface TableViewController()

@property (strong) NSMutableArray* items;
@property (assign) NSInteger currentPage;
@property (assign) NSInteger numPages;

@end

@implementation TableViewController

#pragma mark - Private methods

- (void)handleAPIResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
	// Check for network errors
	if(error)
	{
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error loading data", @"")
															message:[error localizedDescription]
														   delegate:self
												  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
												  otherButtonTitles:NSLocalizedString(@"Retry", @""), nil];
		[alertView show];
		
		if(completion) {
			completion();
		}
		
		return;
	}
	
	// Unserialize JSON
	NSError* JSONError;
	NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
	
	if(JSONError)
	{
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error parsing data", @"")
															message:[JSONError localizedDescription]
														   delegate:self
												  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
												  otherButtonTitles:NSLocalizedString(@"Retry", @""), nil];
		
		[alertView show];
		
		if(completion) {
			completion();
		}
		
		return;
	}
	
	// Create new items on background queue
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		__block NSMutableArray* newItems = [NSMutableArray new];
		
		for(NSDictionary* item in responseDict[@"hits"]) {
			@autoreleasepool {
				[newItems addObject:[ItemModel itemWithDictionary:item]];
			}
		}
		
		// Append new data on main thread and reload table
		dispatch_async(dispatch_get_main_queue(), ^{
			self.numPages = [responseDict[@"nbPages"] integerValue];
			self.currentPage++;
			
			[self.items addObjectsFromArray:newItems];
			
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
	
	// Load twice more results on iPad to fill table with data.
	// Because infinite scroll will not show up if there are less items in table view then it can accomodate.
	NSInteger hitsPerPage = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? 12 : 24;
	
	// Craft API URL
	NSString* requestURL = [NSString stringWithFormat:@"%@&hitsPerPage=%ld&page=%ld", kAPIEndpointURL, (long)hitsPerPage, (long)self.currentPage];
	
	// Create request
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:requestURL]];
	
	// Create NSDataTask
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self handleAPIResponse:response data:data error:error completion:completion];
			
			// Hide network activity indicator
			[[UIApplication sharedApplication] stopNetworkActivity];
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
	
	self.currentPage = 0;
	self.numPages = 0;
	self.items = [NSMutableArray new];
	
	__weak typeof(self) weakSelf = self;
	
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
		browserController.itemModel = self.items[selectedRow.row];
	}
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
	ItemModel* itemModel = self.items[indexPath.row];
	
	cell.textLabel.text = itemModel.title;
	cell.detailTextLabel.text = itemModel.author;

	return cell;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == alertView.firstOtherButtonIndex) {
		[self loadRemoteDataWithDelay:NO completion:nil];
	}
}

@end
