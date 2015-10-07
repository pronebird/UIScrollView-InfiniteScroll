//
//  CollectionViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 24/01/15.
//  Copyright (c) 2015 codeispoetry.ru. All rights reserved.
//

#import "CollectionViewController.h"
#import "PhotoCell.h"
#import "PhotoViewController.h"
#import "UIApplication+NetworkIndicator.h"
#import "UIScrollView+InfiniteScroll.h"
#import "CustomInfiniteIndicator.h"

static NSString *const kAPIEndpointURL = @"https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json";
static NSString *const kShowPhotoSegueIdentifier = @"ShowPhoto";
static NSString *const kCellIdentifier = @"PhotoCell";

@interface CollectionViewController()

@property NSMutableArray *photos;
@property NSDate *modifiedAt;
@property NSCache *cache;

@end

@implementation CollectionViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;

    self.photos = [[NSMutableArray alloc] init];
    self.modifiedAt = [NSDate distantPast];
    self.cache = [[NSCache alloc] init];
    
    // Create custom indicator
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    
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
    [self fetchData:nil];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if([identifier isEqualToString:kShowPhotoSegueIdentifier]) {
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:sender];
        NSURL *photoURL = self.photos[indexPath.item];
        
        if(![self.cache objectForKey:photoURL]) {
            return NO;
        }
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:kShowPhotoSegueIdentifier]) {
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:sender];
        NSURL *photoURL = self.photos[indexPath.item];
        UIImage *image = [self.cache objectForKey:photoURL];
        
        PhotoViewController *controller = segue.destinationViewController;
        controller.photo = image;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // invalidate layout on rotation
    [self.collectionViewLayout invalidateLayout];
}

#pragma mark - Private

- (void)fetchData:(void(^)(void))completion {
    NSURL *requestURL = [NSURL URLWithString:kAPIEndpointURL];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
            
            [[UIApplication sharedApplication] stopNetworkActivity];
        });
    }];
    
    [[UIApplication sharedApplication] startNetworkActivity];
    
    // I run -[task resume] with delay because my network is too fast
    NSTimeInterval delay = (self.photos.count == 0 ? 0 : 5);
    
    [task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

- (void)handleResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
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
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    
    NSDate *modifiedAt = [dateFormatter dateFromString:responseDict[@"modified"]];
    
    if([modifiedAt compare:self.modifiedAt] != NSOrderedDescending) {
        finish();
        return;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    NSArray *photos = [responseDict valueForKeyPath:@"items.media.m"];
    NSInteger index = self.photos.count;
    
    for(NSString *url in photos) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index++ inSection:0];
        
        [self.photos addObject:[NSURL URLWithString:url]];
        [indexPaths addObject:indexPath];
    }
    
    self.modifiedAt = modifiedAt;
    
    [self.collectionView performBatchUpdates:^{
        [self.collectionView insertItemsAtIndexPaths:indexPaths];
    } completion:^(BOOL finished) {
        finish();
    }];
}

- (void)downloadPhotoFromURL:(NSURL*)URL completion:(void(^)(NSURL *URL, UIImage *image))completion {
    static dispatch_queue_t downloadQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadQueue = dispatch_queue_create("ru.codeispoetry.downloadQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    dispatch_async(downloadQueue, ^{
        NSData *data = [NSData dataWithContentsOfURL:URL];
        UIImage *image = [UIImage imageWithData:data];
        
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
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error fetching data", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self fetchData:nil];
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photos.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PhotoCell *cell = (PhotoCell*)[collectionView dequeueReusableCellWithReuseIdentifier:kCellIdentifier forIndexPath:indexPath];
    NSURL *photoURL = self.photos[indexPath.item];
    UIImage *image = [self.cache objectForKey:photoURL];
    
    cell.imageView.image = image;
    cell.imageView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    
    if(!image) {
        [self downloadPhotoFromURL:photoURL completion:^(NSURL *URL, UIImage *image) {
            NSIndexPath *indexPath_ = [collectionView indexPathForCell:cell];
            if([indexPath isEqual:indexPath_]) {
                cell.imageView.image = image;
            }
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
        
        itemWidth = collectionWidth / 12 - spacing;
    }
    
    return CGSizeMake(itemWidth, itemWidth);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV) {
        return 10;
    }
    return 1;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV) {
        return 10;
    }
    return 1;
}

@end
