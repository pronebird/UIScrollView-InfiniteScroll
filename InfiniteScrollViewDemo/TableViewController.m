//
//  TableViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 09/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "TableViewController.h"
#import "BrowserViewController.h"
#import "ItemModel.h"

#import "UIScrollView+InfiniteScroll.h"

static NSString* const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=12";

@interface TableViewController()

@property (strong) NSMutableArray* items;
@property (assign) NSInteger currentPage;
@property (assign) NSInteger numPages;

@end

@implementation TableViewController

- (void)loadRemoteDataWithCompletionHandler:(void(^)(void))completionHandler
{
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@&page=%ld", kAPIEndpointURL, (long)self.currentPage]];
	NSURLRequest* request = [NSURLRequest requestWithURL:url];
	
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if(error)
		{
			[[[UIAlertView alloc] initWithTitle:@"Error loading data"
										message:[NSString stringWithFormat:@"%@", error]
									   delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
		}
		else
		{
			NSError* jsonError;
			NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

			if(jsonError)
			{
				[[[UIAlertView alloc] initWithTitle:@"Error parsing data"
											message:[NSString stringWithFormat:@"%@", error]
										   delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					self.numPages = [responseDict[@"nbPages"] integerValue];
					self.currentPage++;
					
					for(NSDictionary* item in responseDict[@"hits"]) {
						[self.items addObject:[ItemModel itemWithDictionary:item]];
					}
					
					[self.tableView reloadData];
				});
			}
			
			if(completionHandler) {
				dispatch_async(dispatch_get_main_queue(), ^{
					completionHandler();
				});
			}
		}
	}];

	[task resume];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.currentPage = 0;
	self.numPages = 0;
	self.items = [NSMutableArray new];
	
	__weak typeof(self) weakSelf = self;
	[self.tableView addInfiniteScrollWithHandler:^(UIScrollView* scrollView) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		
		if(strongSelf) {
			// My network is too fast
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[strongSelf loadRemoteDataWithCompletionHandler:^{
					[scrollView finishInfiniteScroll];
				}];
			});
		}
	}];
	
	[self loadRemoteDataWithCompletionHandler:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
	ItemModel* itemModel = self.items[indexPath.row];
	
	cell.textLabel.text = itemModel.title;
	cell.detailTextLabel.text = itemModel.author;

	return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if([segue.identifier isEqualToString:@"ShowBrowser"]) {
		NSIndexPath* selectedRow = [self.tableView indexPathForSelectedRow];
		BrowserViewController* browserController = (BrowserViewController*)segue.destinationViewController;
		browserController.itemModel = self.items[selectedRow.row];
	}
}

@end
