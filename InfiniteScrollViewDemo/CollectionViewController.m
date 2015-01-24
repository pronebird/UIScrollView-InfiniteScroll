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

@end

@implementation CollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;
    
    self.flickrPhotos = [NSMutableArray new];
    self.flickrFeedModifiedAt = [NSDate distantPast];
    
    // Create custom indicator
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    
    // Set custom indicator
    self.collectionView.infiniteScrollIndicatorView = indicator;
    
    // Add infinite scroll handler
    [self.collectionView addInfiniteScrollWithHandler:^(UIScrollView *scrollView) {
        [weakSelf loadFlickrFeedWithCompletion:^{
            // Finish infinite scroll animations
            [scrollView finishInfiniteScroll];
        }];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(!self.flickrPhotos.count) {
        [self loadFlickrFeedWithCompletion:nil];
    }
}

- (void)loadFlickrFeedWithCompletion:(void(^)(void))completion {
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
            NSInteger firstIndex = self.flickrPhotos.count;
            
            for(NSInteger i = 0; i < photos.count; i++) {
                [self.collectionView insertItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:firstIndex + i inSection:0] ]];
            }
            
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

- (NSString*)diskPathForPhotoURL:(NSURL*)URL {
    NSString* filename = [URL lastPathComponent];
    NSString* cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString* photoCacheDir = [cacheDir stringByAppendingPathComponent:@"FlickrPhotoCache"];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSFileManager defaultManager] createDirectoryAtPath:photoCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    
    return [photoCacheDir stringByAppendingPathComponent:filename];
}

- (void)photoForURL:(NSURL*)URL completion:(void(^)(NSURL* URL, UIImage* image))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block UIImage* image = [UIImage imageWithContentsOfFile:[self diskPathForPhotoURL:URL]];
        
        if(!image) {
            [self downloadPhotoFromURL:URL completion:completion];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(URL, image);
        });
    });
}

- (void)downloadPhotoFromURL:(NSURL*)URL completion:(void(^)(NSURL* URL, UIImage* image))completion {
    static dispatch_queue_t downloadQueue;
    
    if(!downloadQueue) {
        downloadQueue = dispatch_queue_create("ru.codeispoetry.downloadQueue", 0);
    }
    
    dispatch_async(downloadQueue, ^{
        NSData *data = [NSData dataWithContentsOfURL:URL];
        [data writeToFile:[self diskPathForPhotoURL:URL] atomically:YES];
        
        __block UIImage* image = [UIImage imageWithData:data];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(completion) {
                completion(URL, image);
            }
        });
    });
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.flickrPhotos.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PhotoCell* cell = (PhotoCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    NSURL* photoURL = [NSURL URLWithString:self.flickrPhotos[indexPath.item]];
    cell.imageView.image = nil;
    cell.imageView.backgroundColor = [UIColor lightGrayColor];
    [self photoForURL:photoURL completion:^(NSURL *URL, UIImage *image) {
        cell.imageView.image = image;
    }];
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat collectionWidth = CGRectGetWidth(collectionView.bounds);
    CGFloat itemWidth = collectionWidth * 0.5;
    
    return CGSizeMake(itemWidth, itemWidth);
}

@end
