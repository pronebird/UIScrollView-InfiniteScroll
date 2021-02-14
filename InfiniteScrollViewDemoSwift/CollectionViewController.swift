//
//  CollectionViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
#if !os(tvOS)
import SafariServices
#endif

class CollectionViewController: UICollectionViewController {
    
    fileprivate let downloadQueue = DispatchQueue(label: "Photo cache", qos: .background)
    
    fileprivate var items = [FlickrItem]()
    fileprivate var cache = NSCache<NSURL, UIImage>()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set custom indicator
        let indicatorRect: CGRect
        #if os(tvOS)
        indicatorRect = CGRect(x: 0, y: 0, width: 64, height: 64)
        #else
        indicatorRect = CGRect(x: 0, y: 0, width: 24, height: 24)
        #endif
        collectionView?.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: indicatorRect)
        
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
        let itemWidth: CGFloat

        switch self.traitCollection.userInterfaceIdiom  {
        case .pad:
            itemWidth = collectionWidth / 4 - 1
        case .tv:
            let spacing = self.collectionView(collectionView, layout: collectionViewLayout, minimumInteritemSpacingForSectionAt: indexPath.section)

            itemWidth = collectionWidth / 8 - spacing
        default:
            itemWidth = collectionWidth / 3 - 1

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

        #if !os(tvOS)
        let safariController = SFSafariViewController(url: model.link)
        safariController.delegate = self
        
        let safariNavigationController = UINavigationController(rootViewController: safariController)
        safariNavigationController.setNavigationBarHidden(true, animated: false)
        
        present(safariNavigationController, animated: true)
        #endif
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
}

// MARK: - SFSafariViewControllerDelegate

#if !os(tvOS)
extension CollectionViewController: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
}
#endif

// MARK: - Cells

class PhotoCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!

    override func awakeFromNib() {
        if #available(iOS 13.0, *) {
            #if os(tvOS)
            imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
            #else
            imageView.backgroundColor = .tertiarySystemFill
            #endif
        } else {
            imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        }
    }
    
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
