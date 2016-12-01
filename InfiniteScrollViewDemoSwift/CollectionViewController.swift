//
//  CollectionViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
import Foundation

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    fileprivate let downloadQueue = DispatchQueue(label: "ru.codeispoetry.downloadQueue", qos: DispatchQoS.background)
    
    fileprivate let cellIdentifier = "PhotoCell"
    fileprivate let showPhotoSegueIdentifier = "ShowPhoto"
    fileprivate let apiURL = "https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json"
    
    fileprivate var photos = [URL]()
    fileprivate var modifiedAt = Date.distantPast 
    fileprivate var cache = NSCache<NSURL, UIImage>()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set custom indicator
        collectionView?.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        
        // Set custom indicator margin
        collectionView?.infiniteScrollIndicatorMargin = 40
        
        // Add infinite scroll handler
        collectionView?.addInfiniteScroll { [weak self] (scrollView) -> Void in
            self?.fetchData() {
                scrollView.finishInfiniteScroll()
            }
        }
        
        // load initial data
        collectionView?.beginInfiniteScroll(true)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == showPhotoSegueIdentifier {
            if let indexPath = collectionView?.indexPath(for: sender as! UICollectionViewCell) {
                let url = photos[indexPath.item]
                if let _ = cache.object(forKey: url as NSURL) {
                    return true
                }
            }
            return false
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == showPhotoSegueIdentifier {
            if let indexPath = collectionView?.indexPath(for: sender as! UICollectionViewCell) {
                let controller = segue.destination as! PhotoViewController
                let url = photos[indexPath.item]
                
                controller.photo = cache.object(forKey: url as NSURL)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        collectionViewLayout.invalidateLayout()
    }
    
    // MARK: - UICollectionViewDataSource
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCell
        let url = photos[indexPath.item]
        let image = cache.object(forKey: url as NSURL)
        
        cell.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cell.imageView.image = image
        
        if image == nil {
            downloadPhoto(url, completion: { (url, image) -> Void in
                collectionView.reloadItems(at: [indexPath])
            })
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let collectionWidth = collectionView.bounds.width;
        var itemWidth = collectionWidth / 3 - 1;
        
        if(UI_USER_INTERFACE_IDIOM() == .pad) {
            itemWidth = collectionWidth / 4 - 1;
        }
        
        return CGSize(width: itemWidth, height: itemWidth);
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - Private
    
    fileprivate func downloadPhoto(_ url: URL, completion: @escaping (_ url: URL, _ image: UIImage) -> Void) {
        downloadQueue.async(execute: { () -> Void in
            if let image = self.cache.object(forKey: url as NSURL) {
                DispatchQueue.main.async {
                    completion(url, image)
                }
                
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.cache.setObject(image, forKey: url as NSURL)
                        completion(url, image)
                    }
                } else {
                    print("Could not decode image")
                }
            } catch {
                print("Could not load URL: \(url): \(error)")
            }
        })
    }
    
    fileprivate func fetchData(_ handler: ((Void) -> Void)?) {
        let requestURL = URL(string: apiURL)!
        
        let task = URLSession.shared.dataTask(with: requestURL, completionHandler: { (data, response, error) in
            DispatchQueue.main.async {
                self.handleResponse(data, response: response, error: error, completion: handler)
                
                UIApplication.shared.stopNetworkActivity()
            }
        })
        
        UIApplication.shared.startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (photos.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: {
            task.resume()
        })
    }
    
    fileprivate func handleResponse(_ data: Data!, response: URLResponse!, error: Error!, completion: ((Void) -> Void)?) {
        if let error = error {
            showAlertWithError(error)
            completion?()
            return;
        }
        
        var jsonError: NSError?
        var jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        var responseDict: [String: AnyObject]?
        
        // Fix broken Flickr JSON
        jsonString = jsonString?.replacingOccurrences(of: "\\'", with: "'") as NSString?
        let fixedData = jsonString?.data(using: String.Encoding.utf8.rawValue)
        
        do {
            responseDict = try JSONSerialization.jsonObject(with: fixedData!, options: JSONSerialization.ReadingOptions()) as? [String: AnyObject]
        }
        catch {
            jsonError = NSError(domain: "JSONError", code: 1, userInfo: [ NSLocalizedDescriptionKey: "Failed to parse JSON." ])
        }
        
        if let jsonError = jsonError {
            showAlertWithError(jsonError)
            completion?()
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        let modifiedAt_ = dateFormatter.date(from: responseDict?["modified"] as! String)
        
        if modifiedAt_?.compare(modifiedAt) != ComparisonResult.orderedDescending {
            completion?()
            return
        }
        
        var indexPaths = [IndexPath]()
        let firstIndex = photos.count
        
        if let items = responseDict?["items"] as? NSArray {
            if let urls = items.value(forKeyPath: "media.m") as? [String] {
                for (i, url) in urls.enumerated() {
                    let indexPath = IndexPath(item: firstIndex + i, section: 0)
                    
                    photos.append(URL(string: url)!)
                    indexPaths.append(indexPath)
                }
            }
        }
        
        modifiedAt = modifiedAt_!
        
        collectionView?.performBatchUpdates({ () -> Void in
            self.collectionView?.insertItems(at: indexPaths)
        }, completion: { (finished) -> Void in
            completion?()
        });
    }
    
    fileprivate func showAlertWithError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("collectionView.errorAlert.title", comment: ""),
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("collectionView.errorAlert.dismiss", comment: ""),
                                      style: .cancel,
                                      handler: nil))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("collectionView.errorAlert.retry", comment: ""),
                                      style: .default,
                                      handler: { _ in self.fetchData(nil) }))
        
        self.present(alert, animated: true, completion: nil)
    }

}

// MARK: - Actions

extension CollectionViewController {
    
    @IBAction func handleRefresh() {
        collectionView?.beginInfiniteScroll(true)
    }
    
}
