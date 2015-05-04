//
//  CollectionViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
import Foundation

private let downloadQueue = dispatch_queue_create("ru.codeispoetry.downloadQueue", nil)

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UIAlertViewDelegate {
    
    private let cellIdentifier = "PhotoCell"
    private let showPhotoSegueIdentifier = "ShowPhoto"
    private let apiURL = "https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json"
    
    private var photos = [NSURL]()
    private var modifiedAt = NSDate.distantPast() as! NSDate
    private var cache = NSCache()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set custom indicator
        collectionView?.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRectMake(0, 0, 24, 24))
        
        // Set custom indicator margin
        collectionView?.infiniteScrollIndicatorMargin = 40
        
        // Add infinite scroll handler
        collectionView?.addInfiniteScrollWithHandler { [weak self] (scrollView) -> Void in
            let collectionView = scrollView as! UICollectionView
            
            self?.fetchData() {
                collectionView.finishInfiniteScroll()
            }
        }
        
        fetchData(nil)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == showPhotoSegueIdentifier {
            if let indexPath = collectionView?.indexPathForCell(sender as! UICollectionViewCell) {
                let url = photos[indexPath.item]
                if let image = cache.objectForKey(url) as? UIImage {
                    return true
                }
            }
            return false
        }
        return true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == showPhotoSegueIdentifier {
            if let indexPath = collectionView?.indexPathForCell(sender as! UICollectionViewCell) {
                var controller: PhotoViewController
                let url = photos[indexPath.item]
                
                if segue.destinationViewController.isKindOfClass(UINavigationController) {
                    controller = (segue.destinationViewController as! UINavigationController).topViewController as! PhotoViewController
                }
                else {
                    controller = segue.destinationViewController as! PhotoViewController
                }
                
                controller.photo = cache.objectForKey(url) as? UIImage
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! PhotoCell
        let url = photos[indexPath.item]
        
        if let image = cache.objectForKey(url) as? UIImage {
            cell.imageView.image = image
            cell.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        }
        else {
            cell.imageView.image = nil
            
            downloadPhoto(url, completion: { (url, image) -> Void in
                let indexPath_ = collectionView.indexPathForCell(cell)
                if indexPath.isEqual(indexPath_) {
                    cell.imageView.image = image
                }
            })
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let collectionWidth = CGRectGetWidth(collectionView.bounds);
        var itemWidth = collectionWidth / 3 - 1;
        
        if(UI_USER_INTERFACE_IDIOM() == .Pad) {
            itemWidth = collectionWidth / 4 - 1;
        }
        
        return CGSizeMake(itemWidth, itemWidth);
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - UIAlertViewDelegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex != alertView.cancelButtonIndex {
            fetchData(nil)
        }
    }
    
    // MARK: - Private
    
    private func downloadPhoto(url: NSURL, completion: (url: NSURL, image: UIImage) -> Void) {
        dispatch_async(downloadQueue, { () -> Void in
            if let data = NSData(contentsOfURL: url) {
                if let image = UIImage(data: data) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.cache.setObject(image, forKey: url)
                        completion(url: url, image: image)
                    })
                }
            }
        })
    }
    
    private func fetchData(handler: (Void -> Void)?) {
        let requestURL = NSURL(string: apiURL)!
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(requestURL, completionHandler: {
            (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.handleResponse(data, response: response, error: error, completion: handler)
                
                UIApplication.sharedApplication().stopNetworkActivity()
            });
        })
        
        UIApplication.sharedApplication().startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (photos.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
        var time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            task.resume()
        })
    }
    
    private func handleResponse(data: NSData!, response: NSURLResponse!, error: NSError!, completion: (Void -> Void)?) {
        if error != nil {
            showAlertWithError(error)
            return;
        }
        
        var jsonError: NSError?
        var jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
        
        // Fix broken Flickr JSON
        jsonString = jsonString?.stringByReplacingOccurrencesOfString("\\'", withString: "'")
        let fixedData = jsonString?.dataUsingEncoding(NSUTF8StringEncoding)
        
        let responseDict = NSJSONSerialization.JSONObjectWithData(fixedData!, options: NSJSONReadingOptions.allZeros, error: &jsonError) as? Dictionary<String, AnyObject>
        
        if jsonError != nil {
            showAlertWithError(jsonError)
            return
        }
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        let modifiedAt_ = dateFormatter.dateFromString(responseDict?["modified"] as! String)
        
        if modifiedAt_?.compare(modifiedAt) != NSComparisonResult.OrderedDescending {
            completion?()
            return
        }
        
        var indexPaths = [NSIndexPath]()
        let firstIndex = self.photos.count
        
        if let items = responseDict?["items"] as? NSArray {
            if let urls = items.valueForKeyPath("media.m") as? [String] {
                for (i, url) in enumerate(urls) {
                    let indexPath = NSIndexPath(forItem: firstIndex + i, inSection: 0)
                    
                    self.photos.append(NSURL(string: url)!)
                    indexPaths.append(indexPath)
                }
            }
        }
        
        self.modifiedAt = modifiedAt_!
        
        collectionView?.performBatchUpdates({ () -> Void in
            self.collectionView?.insertItemsAtIndexPaths(indexPaths)
        }, completion: { (finished) -> Void in
            completion?()
        });
    }
    
    private func showAlertWithError(error: NSError!) {
        let alert = UIAlertView(
            title: NSLocalizedString("Error fetching data", comment: ""),
            message: error.localizedDescription,
            delegate: self,
            cancelButtonTitle: NSLocalizedString("Dismiss", comment: ""),
            otherButtonTitles: NSLocalizedString("Retry", comment: "")
        )
        alert.show()
    }

}
