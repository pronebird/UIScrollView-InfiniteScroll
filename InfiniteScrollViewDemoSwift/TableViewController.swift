//
//  TableViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
import SafariServices

private let useAutosizingCells = true

class TableViewController: UITableViewController {
    
    fileprivate let cellIdentifier = "Cell"
    fileprivate var currentPage = 0
    fileprivate var numPages = 0
    fileprivate var stories = [StoryModel]()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if useAutosizingCells && tableView.responds(to: #selector(getter: UIView.layoutMargins)) {
            tableView.estimatedRowHeight = 88
            tableView.rowHeight = UITableViewAutomaticDimension
        }
        
        // Set custom indicator
        tableView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        
        // Set custom indicator margin
        tableView.infiniteScrollIndicatorMargin = 40
        
        // Set custom trigger offset
        tableView.infiniteScrollTriggerOffset = 500
        
        // Add infinite scroll handler
        tableView.addInfiniteScroll { [weak self] (tableView) -> Void in
            self?.performFetch {
                tableView.finishInfiniteScroll()
            }
        }
        
        // Uncomment this to provide conditionally prevent the infinite scroll from triggering
        /*
        tableView.setShouldShowInfiniteScrollHandler { [weak self] (tableView) -> Bool in
            // Only show up to 5 pages then prevent the infinite scroll
            return (self?.currentPage < 5);
        }
        */
        
        // load initial data
        tableView.beginInfiniteScroll(true)
    }
    
    fileprivate func performFetch(_ completionHandler: ((Void) -> Void)?) {
        fetchData { (fetchResult) in
            do {
                let (newStories, pageCount, nextPage) = try fetchResult()
                
                let storyCount = self.stories.count
                let (start, end) = (storyCount, newStories.count + storyCount)
                let indexPaths = (start..<end).map { return IndexPath(row: $0, section: 0) }
                
                self.stories.append(contentsOf: newStories)
                self.numPages = pageCount
                self.currentPage = nextPage
                
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: indexPaths, with: .automatic)
                self.tableView.endUpdates()
            } catch {
                self.showAlertWithError(error)
            }
            
            completionHandler?()
        }
    }
    
    fileprivate func showAlertWithError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("tableView.errorAlert.title", comment: ""),
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("tableView.errorAlert.dismiss", comment: ""),
                                      style: .cancel,
                                      handler: nil))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("tableView.errorAlert.retry", comment: ""),
                                      style: .default,
                                      handler: { _ in self.performFetch(nil) }))
        
        self.present(alert, animated: true, completion: nil)
    }

}

// MARK: - Actions

extension TableViewController {
    
    @IBAction func handleRefresh() {
        tableView.beginInfiniteScroll(true)
    }
    
}

// MARK: - UITableViewDelegate

extension TableViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let story = stories[indexPath.row]
        let safariController = SFSafariViewController(url: story.url)
        safariController.delegate = self
        safariController.hidesBottomBarWhenPushed = true
        
        navigationController?.pushViewController(safariController, animated: true)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
}

// MARK: - SFSafariViewControllerDelegate

extension TableViewController: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        _ = navigationController?.popViewController(animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
}

// MARK: - UITableViewDataSource

extension TableViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let story = stories[indexPath.row]
        
        cell.textLabel?.text = story.title
        cell.detailTextLabel?.text = story.author
        
        if useAutosizingCells && tableView.responds(to: #selector(getter: UIView.layoutMargins)) {
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
        }
        
        return cell
    }
    
}

// MARK: - API

fileprivate enum ResponseError: Error {
    case load
    case noData
    case deserialization
}

extension ResponseError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .load:
            return NSLocalizedString("responseError.load", comment: "")
        case .deserialization:
            return NSLocalizedString("responseError.deserialization", comment: "")
        case .noData:
            return NSLocalizedString("responseError.noData", comment: "")
        }
    }
    
}

typealias FetchResult = (Void) throws -> ([StoryModel], Int, Int)

extension TableViewController {
    
    fileprivate func apiURL(_ numHits: Int, page: Int) -> URL {
        let string = "https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=\(numHits)&page=\(page)"
        let url = URL(string: string)
        
        return url!
    }
    
    fileprivate func fetchData(_ handler: @escaping ((FetchResult) -> Void)) {
        let hits = Int(tableView.bounds.height) / 44
        let requestURL = apiURL(hits, page: currentPage)
        
        let task = URLSession.shared.dataTask(with: requestURL, completionHandler: {
            (data, _, error) -> Void in
            DispatchQueue.main.async {
                handler({ (Void) -> ([StoryModel], Int, Int) in
                    return try self.handleResponse(data, error: error)
                })
                
                UIApplication.shared.stopNetworkActivity()
            }
        })
        
        UIApplication.shared.startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (stories.count == 0 ? 0 : 5)

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: {
            task.resume()
        })
    }
    
    fileprivate func handleResponse(_ data: Data?, error: Error?) throws -> ([StoryModel], Int, Int) {
        let resultsKey = "hits"
        let numPagesKey = "nbPages"
        
        if error != nil { throw ResponseError.load }
        
        guard let data = data else { throw ResponseError.noData }
        let raw = try? JSONSerialization.jsonObject(with: data, options: [])
        
        guard let response = raw as? [String: AnyObject],
              let pageCount = response[numPagesKey] as? Int,
              let entries = response[resultsKey] as? [[String: AnyObject]] else { throw ResponseError.deserialization }
        
        let newStories = entries.flatMap { return StoryModel($0) }
        
        return (newStories, pageCount, currentPage + 1)
    }
    
}
