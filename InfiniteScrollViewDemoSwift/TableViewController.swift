//
//  TableViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit

private let useAutosizingCells = true

class TableViewController: UITableViewController {
    
    private let cellIdentifier = "Cell"
    private let showBrowserSegueIdentifier = "ShowBrowser"
    private let JSONResultsKey = "hits"
    private let JSONNumPagesKey = "nbPages"
    
    private var currentPage = 0
    private var numPages = 0
    private var stories = [StoryModel]()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if useAutosizingCells && tableView.respondsToSelector(Selector("layoutMargins")) {
            tableView.estimatedRowHeight = 88
            tableView.rowHeight = UITableViewAutomaticDimension
        }
        
        // Set custom indicator
        tableView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRectMake(0, 0, 24, 24))
        
        // Set custom indicator margin
        tableView.infiniteScrollIndicatorMargin = 40
        
        // Set custom trigger offset
        tableView.infiniteScrollTriggerOffset = 500
        
        // Add infinite scroll handler
        tableView.addInfiniteScrollWithHandler { [weak self] (tableView) -> Void in
            self?.fetchData() {
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
        
        fetchData(nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == showBrowserSegueIdentifier {
            if let selectedRow = tableView.indexPathForSelectedRow {
                let browser = segue.destinationViewController as! BrowserViewController
                browser.story = stories[selectedRow.row]
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) 
        let story = stories[indexPath.row]
        
        cell.textLabel?.text = story.title
        cell.detailTextLabel?.text = story.author
        
        if useAutosizingCells && tableView.respondsToSelector(Selector("layoutMargins")) {
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
        }
        
        return cell
    }

    // MARK: - Private
    
    private func apiURL(numHits: Int, page: Int) -> NSURL {
        let string = "https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=\(numHits)&page=\(page)"
        let url = NSURL(string: string)
        
        return url!
    }
    
    private func fetchData(handler: ((Void) -> Void)?) {
        let hits: Int = Int(CGRectGetHeight(tableView.bounds)) / 44
        let requestURL = apiURL(hits, page: currentPage)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(requestURL, completionHandler: {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.handleResponse(data, response: response, error: error)
                
                UIApplication.sharedApplication().stopNetworkActivity()
                
                handler?()
            });
        })
        
        UIApplication.sharedApplication().startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (stories.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            task.resume()
        })
    }
    
    private func handleResponse(data: NSData!, response: NSURLResponse!, error: NSError!) {
        if let _ = error {
            showAlertWithError(error)
            return;
        }
        
        var jsonError: NSError?
        var responseDict: [String: AnyObject]?
        
        do {
            responseDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String: AnyObject]
        } catch {
            jsonError = NSError(domain: "JSONError", code: 1, userInfo: [ NSLocalizedDescriptionKey: "Failed to parse JSON." ])
        }
        
        if let jsonError = jsonError {
            showAlertWithError(jsonError)
            return
        }
        
        if let pages = responseDict?[JSONNumPagesKey] as? NSNumber {
            numPages = pages as Int
        }
        
        var indexPaths = [NSIndexPath]()
        var indexPathRow = stories.count
        
        if let results = responseDict?[JSONResultsKey] as? [[String: AnyObject]] {
            currentPage += 1

            for i in results {
                guard let model = StoryModel(i) else {
                    continue
                }
                
                stories.append(model)
                
                indexPaths.append(NSIndexPath(forRow: indexPathRow, inSection: 0))
                
                indexPathRow += 1
            }
            
            tableView.beginUpdates()
            tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
            tableView.endUpdates()
        }
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
