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
    
    fileprivate let downloadQueue = DispatchQueue(label: "ru.codeispoetry.downloadQueue", qos: DispatchQoS.background)
    
    fileprivate let cellIdentifier = "PhotoCell"
    fileprivate let apiURL = "https://api.flickr.com/services/feeds/photos_public.gne?nojsoncallback=1&format=json"
    
    fileprivate var items = [FlickrModel]()
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        collectionViewLayout.invalidateLayout()
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
        let delay = (items.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
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
        
        var jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        
        // Fix broken Flickr JSON
        jsonString = jsonString?.replacingOccurrences(of: "\\'", with: "'") as NSString?
        let fixedData = jsonString?.data(using: String.Encoding.utf8.rawValue)
        
        let responseDict: Any
        do {
            responseDict = try JSONSerialization.jsonObject(with: fixedData!, options: JSONSerialization.ReadingOptions())
        } catch {
            showAlertWithError(error)
            completion?()
            return
        }
        
        // extract data
        guard let payload = responseDict as? [String: Any],
              let results = payload["items"] as? [[String: Any]] else {
            completion?()
            return
        }
        
        // create new models
        let newModels = results.flatMap { FlickrModel($0) }
        
        // create new index paths
        let photoCount = items.count
        let (start, end) = (photoCount, newModels.count + photoCount)
        let indexPaths = (start..<end).map { return IndexPath(row: $0, section: 0) }
        
        // update data source
        items.append(contentsOf: newModels)
        
        // update collection view
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCell
        let model = items[indexPath.item]
        let image = cache.object(forKey: model.media.medium as NSURL)
        
        cell.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cell.imageView.image = image
        
        if image == nil {
            downloadPhoto(model.media.medium, completion: { (url, image) -> Void in
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

// MARK: - Actions

extension CollectionViewController {
    
    @IBAction func handleRefresh() {
        collectionView?.beginInfiniteScroll(true)
    }
    
}
