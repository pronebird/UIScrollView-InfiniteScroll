//
//  CollectionViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 24/01/15.
//  Copyright (c) 2015 codeispoetry.ru. All rights reserved.
//

#import "CollectionViewController.h"
#import "PhotoCell.h"

#import "UIApplication+NetworkIndicator.h"
#import "UIScrollView+InfiniteScroll.h"
#import "CustomInfiniteIndicator.h"

@interface CollectionViewController() <UICollectionViewDelegateFlowLayout>

@property NSMutableArray* flickrPhotos;
@property NSDate* flickrFeedModifiedAt;
@property NSCache* cache;

@end

@implementation CollectionViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;
    
    self.flickrPhotos = [NSMutableArray new];
    self.flickrFeedModifiedAt = [NSDate distantPast];
    self.cache = [NSCache new];
    
    // Create custom indicator
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    
    // Set custom indicator
    self.collectionView.infiniteScrollIndicatorView = indicator;
    
    self.collectionView.infiniteScrollIndicatorMargin = 20;
    
    // Add infinite scroll handler
    [self.collectionView addInfiniteScrollWithHandler:^(UIScrollView *scrollView) {
        [weakSelf loadFlickrFeed:^{
            // Finish infinite scroll animations
            [scrollView finishInfiniteScroll];
        }];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(!self.flickrPhotos.count) {
        [self loadFlickrFeed:nil];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // invalidate layout on rotation
    [self.collectionViewLayout invalidateLayout];
}

#pragma mark - Private

- (void)loadFlickrFeed:(void(^)(void))completion {
    NSURL* feedURL = [NSURL URLWithString:@"https://api.flickr.com/services/feeds/photos_public.gne?tags=nature&nojsoncallback=1&format=json"];
    
    // Show network activity indicator
    [[UIApplication sharedApplication] startNetworkActivity];
    
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithURL:feedURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleAPIResponse:response data:data error:error completion:completion];
            
            // Hide network activity indicator
            [[UIApplication sharedApplication] stopNetworkActivity];
        });
    }];
    
    [task resume];
}

- (void)handleAPIResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
    NSError* JSONError;
    NSString* JSONString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // Fix broken Flickr JSON
    JSONString = [JSONString stringByReplacingOccurrencesOfString: @"\\'" withString: @"'"];
    
    NSDictionary* JSONResponse = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&JSONError];
    
    if(JSONError) {
        NSLog(@"JSON Error = %@", JSONError);
        return;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    
    NSDate* modifiedAt = [dateFormatter dateFromString:JSONResponse[@"modified"]];
    NSArray* photos = [JSONResponse valueForKeyPath:@"items.media.m"];
    
    if([self.flickrFeedModifiedAt compare:modifiedAt] == NSOrderedAscending) {
        [self.collectionView performBatchUpdates:^{
            NSMutableArray* newIndexPaths = [NSMutableArray new];
            NSInteger firstIndex = self.flickrPhotos.count;
            
            for(NSInteger i = 0; i < photos.count; i++) {
                NSIndexPath* indexPath = [NSIndexPath indexPathForItem:firstIndex + i inSection:0];
                [newIndexPaths addObject:indexPath];
            }
            
            [self.collectionView insertItemsAtIndexPaths:newIndexPaths];
            
            self.flickrFeedModifiedAt = modifiedAt;
            [self.flickrPhotos addObjectsFromArray:photos];
        } completion:^(BOOL finished) {
            if(completion) {
                completion();
            }
        }];
    } else {
        if(completion) {
            completion();
        }
    }
}

- (void)downloadPhotoFromURL:(NSURL*)URL completion:(void(^)(NSURL* URL, UIImage* image))completion {
    static dispatch_queue_t downloadQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadQueue = dispatch_queue_create("ru.codeispoetry.downloadQueue", 0);
    });
    
    dispatch_async(downloadQueue, ^{
        NSData *data = [NSData dataWithContentsOfURL:URL];
        __block UIImage* image = [UIImage imageWithData:data];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(image) {
                [self.cache setObject:image forKey:URL];
            }
            
            if(completion) {
                completion(URL, image);
            }
        });
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.flickrPhotos.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PhotoCell* cell = (PhotoCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    NSURL* photoURL = [NSURL URLWithString:self.flickrPhotos[indexPath.item]];
    UIImage* image = [self.cache objectForKey:photoURL];
    
    cell.imageView.image = image;
    cell.imageView.backgroundColor = [UIColor lightGrayColor];
    
    if(!image) {
        [self downloadPhotoFromURL:photoURL completion:^(NSURL *URL, UIImage *image) {
            NSIndexPath* newIndexPath = [collectionView indexPathForCell:cell];
            if([newIndexPath isEqual:indexPath]) {
                cell.imageView.image = image;
            }
        }];
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat collectionWidth = CGRectGetWidth(collectionView.bounds);
    CGFloat itemWidth = collectionWidth * 0.5;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        itemWidth = collectionWidth * 0.25;
    }
    
    return CGSizeMake(itemWidth, itemWidth);
}

@end
