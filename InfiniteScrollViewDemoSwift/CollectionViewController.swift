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

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    private let cellIdentifier = "PhotoCell"
    private let showPhotoSegueIdentifier = "ShowPhoto"
    private let apiURL = "https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json"
    
    private var photos = [NSURL]()
    private var modifiedAt = NSDate.distantPast() 
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
            self?.fetchData() {
                scrollView.finishInfiniteScroll()
            }
        }
        
        fetchData(nil)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == showPhotoSegueIdentifier {
            if let indexPath = collectionView?.indexPathForCell(sender as! UICollectionViewCell) {
                let url = photos[indexPath.item]
                if let _ = cache.objectForKey(url) {
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
                let controller = segue.destinationViewController as! PhotoViewController
                let url = photos[indexPath.item]
                
                controller.photo = cache.objectForKey(url) as? UIImage
            }
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        collectionViewLayout.invalidateLayout()
    }
    
    // MARK: - UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! PhotoCell
        let url = photos[indexPath.item]
        let image = cache.objectForKey(url) as? UIImage
        
        cell.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cell.imageView.image = image
        
        if image == nil {
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
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.handleResponse(data, response: response, error: error, completion: handler)
                
                UIApplication.sharedApplication().stopNetworkActivity()
            });
        })
        
        UIApplication.sharedApplication().startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (photos.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            task.resume()
        })
    }
    
    private func handleResponse(data: NSData!, response: NSURLResponse!, error: NSError!, completion: (Void -> Void)?) {
        if let _ = error {
            showAlertWithError(error)
            completion?()
            return;
        }
        
        var jsonError: NSError?
        var jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
        var responseDict: [String: AnyObject]?
        
        // Fix broken Flickr JSON
        jsonString = jsonString?.stringByReplacingOccurrencesOfString("\\'", withString: "'")
        let fixedData = jsonString?.dataUsingEncoding(NSUTF8StringEncoding)
        
        do {
            responseDict = try NSJSONSerialization.JSONObjectWithData(fixedData!, options: NSJSONReadingOptions()) as? [String: AnyObject]
        }
        catch {
            jsonError = NSError(domain: "JSONError", code: 1, userInfo: [ NSLocalizedDescriptionKey: "Failed to parse JSON." ])
        }
        
        if let jsonError = jsonError {
            showAlertWithError(jsonError)
            completion?()
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
        let firstIndex = photos.count
        
        if let items = responseDict?["items"] as? NSArray {
            if let urls = items.valueForKeyPath("media.m") as? [String] {
                for (i, url) in urls.enumerate() {
                    let indexPath = NSIndexPath(forItem: firstIndex + i, inSection: 0)
                    
                    photos.append(NSURL(string: url)!)
                    indexPaths.append(indexPath)
                }
            }
        }
        
        modifiedAt = modifiedAt_!
        
        collectionView?.performBatchUpdates({ () -> Void in
            self.collectionView?.insertItemsAtIndexPaths(indexPaths)
        }, completion: { (finished) -> Void in
            completion?()
        });
    }
    
    private func showAlertWithError(error: NSError) {
        let alert = UIAlertController(title: NSLocalizedString("Error fetching data", comment: ""), message: error.localizedDescription, preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: .Cancel, handler: { (action) -> Void in
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .Default, handler: { (action) -> Void in
            self.fetchData(nil)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }

}
