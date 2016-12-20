//
//  CollectionViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 24/01/15.
//  Copyright (c) 2015 codeispoetry.ru. All rights reserved.
//

#import "CollectionViewController.h"
#import "UIScrollView+InfiniteScroll.h"
#import "UIApplication+NetworkIndicator.h"
#import "PhotoCell.h"
#import "FlickrModel.h"
#import "CustomInfiniteIndicator.h"

static NSString *const kAPIEndpointURL = @"https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json";
static NSString *const kCellIdentifier = @"PhotoCell";

@interface CollectionViewController()

@property (nonatomic) NSArray *items;
@property (nonatomic) NSCache *cache;

@end

@implementation CollectionViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;

    self.items = [NSArray array];
    self.cache = [[NSCache alloc] init];
    
    // Create custom indicator
    CGRect indicatorRect;
    
#if TARGET_OS_TV
    indicatorRect = CGRectMake(0, 0, 64, 64);
#else
    indicatorRect = CGRectMake(0, 0, 24, 24);
#endif
    
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:indicatorRect];
    
    // Set custom indicator
    self.collectionView.infiniteScrollIndicatorView = indicator;
    
    // Set custom indicator margin
    self.collectionView.infiniteScrollIndicatorMargin = 40;
    
    // Add infinite scroll handler
    [self.collectionView addInfiniteScrollWithHandler:^(UICollectionView *collectionView) {
        [weakSelf fetchData:^{
            // Finish infinite scroll animations
            [collectionView finishInfiniteScroll];
        }];
    }];
    
    // Load initial data
    [self.collectionView beginInfiniteScroll:YES];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    // invalidate layout on rotation
    [self.collectionViewLayout invalidateLayout];
}

#pragma mark - Actions

- (IBAction)handleRefresh {
    [self.collectionView beginInfiniteScroll:YES];
}

#pragma mark - Private

- (void)fetchData:(void(^)(void))completion {
    NSURL *requestURL = [NSURL URLWithString:kAPIEndpointURL];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, __unused NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:data error:error completion:completion];
            
            [[UIApplication sharedApplication] stopNetworkActivity];
        });
    }];
    
    [[UIApplication sharedApplication] startNetworkActivity];
    
    // I run -[task resume] with delay because my network is too fast
    NSTimeInterval delay = (self.items.count == 0 ? 0 : 5);
    
    [task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

- (void)handleResponse:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
    void(^finish)(void) = completion ?: ^{};
    
    if(error) {
        [self showRetryAlertWithError:error];
        finish();
        return;
    }
    
    NSError *jsonError;
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // Fix broken Flickr JSON
    jsonString = [jsonString stringByReplacingOccurrencesOfString: @"\\'" withString: @"'"];
    NSData *fixedData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *responseDict = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:fixedData options:0 error:&jsonError];
    
    if(jsonError) {
        [self showRetryAlertWithError:jsonError];
        finish();
        return;
    }
    
    // create models
    NSArray *results = [responseDict objectForKey:@"items"];
    NSArray *newModels = [FlickrModel modelsFromArray:results];
    
    // create new index paths
    NSIndexSet *newIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.items.count, newModels.count)];
    NSMutableArray *newIndexPaths = [[NSMutableArray alloc] init];
    
    [newIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
        [newIndexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
    }];
    
    // update data source
    self.items = [self.items arrayByAddingObjectsFromArray:newModels];
    
    // update collection view
    [self.collectionView performBatchUpdates:^{
        [self.collectionView insertItemsAtIndexPaths:newIndexPaths];
    } completion:^(__unused BOOL finished) {
        finish();
    }];
}

- (void)downloadPhotoFromURL:(NSURL *)URL completion:(void(^)(NSURL *URL, UIImage *image))completion {
    static dispatch_queue_t downloadQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadQueue = dispatch_queue_create("ru.codeispoetry.downloadQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    dispatch_async(downloadQueue, ^{
        // already loaded?
        UIImage *image = [self.cache objectForKey:URL];
        if(image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(completion) {
                    completion(URL, image);
                }
            });
            
            return;
        }
        
        NSData *data = [NSData dataWithContentsOfURL:URL];
        image = [UIImage imageWithData:data];
        
        if(image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.cache setObject:image forKey:URL];
                
                if(completion) {
                    completion(URL, image);
                }
            });
        }
    });
}

- (void)showRetryAlertWithError:(NSError*)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"collectionView.errorAlert.title", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"collectionView.errorAlert.dismiss", @"") style:UIAlertActionStyleCancel handler:nil]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"collectionView.errorAlert.retry", @"") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self fetchData:nil];
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    FlickrModel *model = self.items[indexPath.row];
    
    // iOS 9.0+
    if([SFSafariViewController class]) {
        SFSafariViewController *safariController = [[SFSafariViewController alloc] initWithURL:model.link];
        safariController.delegate = self;
        
        UINavigationController *safariNavigationController = [[UINavigationController alloc] initWithRootViewController:safariController];
        [safariNavigationController setNavigationBarHidden:YES animated:NO];
        
        [self presentViewController:safariNavigationController animated:YES completion:nil];
    } else {
        [[UIApplication sharedApplication] openURL:model.link];
    }
    
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(__unused UICollectionView *)collectionView numberOfItemsInSection:(__unused NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PhotoCell *cell = (PhotoCell *)[collectionView dequeueReusableCellWithReuseIdentifier:kCellIdentifier forIndexPath:indexPath];
    FlickrModel *model = self.items[indexPath.item];
    UIImage *image = [self.cache objectForKey:model.media.medium];
    
    cell.imageView.image = image;
    cell.imageView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    
    if(!image) {
        [self downloadPhotoFromURL:model.media.medium completion:^(__unused NSURL *URL, __unused UIImage *image) {
            [collectionView reloadItemsAtIndexPaths:@[ indexPath ]];
        }];
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat collectionWidth = CGRectGetWidth(collectionView.bounds);
    CGFloat spacing = [self collectionView:collectionView layout:collectionViewLayout minimumInteritemSpacingForSectionAtIndex:indexPath.section];
    CGFloat itemWidth = collectionWidth / 3 - spacing;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        itemWidth = collectionWidth / 4 - spacing;
    }
    else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV) {
        CGFloat spacing = [self collectionView:collectionView layout:collectionViewLayout minimumInteritemSpacingForSectionAtIndex:indexPath.section];
        
        itemWidth = collectionWidth / 8 - spacing;
    }
    
    return CGSizeMake(itemWidth, itemWidth);
}

- (CGFloat)collectionView:(__unused UICollectionView *)collectionView layout:(__unused UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(__unused NSInteger)section {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV) {
        return 40;
    }
    return 1;
}

- (CGFloat)collectionView:(__unused UICollectionView *)collectionView layout:(__unused UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(__unused NSInteger)section {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV) {
        return 40;
    }
    return 1;
}

@end
