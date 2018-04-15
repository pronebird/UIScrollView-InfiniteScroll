//
//  CollectionViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
import SafariServices

class CollectionViewController: UICollectionViewController {
    
    fileprivate let downloadQueue = DispatchQueue(label: "Photo cache", qos: DispatchQoS.background)
    
    fileprivate var items = [FlickrItem]()
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
            self?.performFetch({
                scrollView.finishInfiniteScroll()
            })
        }
        
        // load initial data
        collectionView?.beginInfiniteScroll(true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        collectionViewLayout.invalidateLayout()
    }
    
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
    
    fileprivate func performFetch(_ completionHandler: (() -> Void)?) {
        fetchData { (result) in
            switch result {
            case .ok(let response):
                let newItems = response.items
                
                // create new index paths
                let photoCount = self.items.count
                let (start, end) = (photoCount, newItems.count + photoCount)
                let indexPaths = (start..<end).map { return IndexPath(row: $0, section: 0) }
                
                // update data source
                self.items.append(contentsOf: newItems)
                
                // update collection view
                self.collectionView?.performBatchUpdates({ () -> Void in
                    self.collectionView?.insertItems(at: indexPaths)
                }, completion: { (finished) -> Void in
                    completionHandler?()
                });
                
            case .error(let error):
                self.showAlertWithError(error)
            }
        }
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
                                      handler: { _ in self.performFetch(nil) }))
        
        self.present(alert, animated: true, completion: nil)
    }

}

// MARK: - Actions

extension CollectionViewController {
    
    @IBAction func handleRefresh() {
        collectionView?.beginInfiniteScroll(true)
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CollectionViewController: UICollectionViewDelegateFlowLayout {
    
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
}

// MARK: - UICollectionViewDataSource

extension CollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let mediaUrl = item.mediumMediaUrl!
        let image = cache.object(forKey: mediaUrl as NSURL)
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cell.imageView.image = image
        
        if image == nil {
            downloadPhoto(mediaUrl, completion: { (url, image) -> Void in
                collectionView.reloadItems(at: [indexPath])
            })
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = items[indexPath.row]
        
        if #available(iOS 9.0, *) {
            let safariController = SFSafariViewController(url: model.link)
            safariController.delegate = self
            
            let safariNavigationController = UINavigationController(rootViewController: safariController)
            safariNavigationController.setNavigationBarHidden(true, animated: false)
            
            present(safariNavigationController, animated: true)
        } else {
            UIApplication.shared.openURL(model.link)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
}

// MARK: - SFSafariViewControllerDelegate

@available(iOS 9.0, *)
extension CollectionViewController: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
}

// MARK: - Cells

class PhotoCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
}

// MARK: - API

extension CollectionViewController {
    typealias FetchResult = Result<FlickrResponse, FetchError>
    
    fileprivate func fetchData(handler: @escaping ((FetchResult) -> Void)) {
        let requestUrl = URL(string: "https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json")!
        
        let task = URLSession.shared.dataTask(with: requestUrl, completionHandler: { (data, _, networkError) in
            DispatchQueue.main.async {
                handler(handleFetchResponse(data: data, networkError: networkError))
            }
        })
        
        // I run task.resume() with delay because my network is too fast
        let delay = items.count == 0 ? 0 : 5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: {
            task.resume()
        })
    }
    
}
