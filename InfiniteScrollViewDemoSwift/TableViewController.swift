//
//  TableViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit

private let useAutosizingCells = true

class TableViewController: UITableViewController, UIAlertViewDelegate {
    
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
        
        if useAutosizingCells && tableView.respondsToSelector("layoutMargins") {
            tableView.estimatedRowHeight = 88
            tableView.rowHeight = UITableViewAutomaticDimension
        }
        
        // Set custom indicator
        tableView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRectMake(0, 0, 24, 24))
        
        // Set custom indicator margin
        tableView.infiniteScrollIndicatorMargin = 40
        
        // Add infinite scroll handler
        tableView.addInfiniteScrollWithHandler { [weak self] (scrollView) -> Void in
            let scrollView = scrollView as! UITableView
            
            self?.fetchData() {
                scrollView.finishInfiniteScroll()
            }
        }
        
        fetchData(nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == showBrowserSegueIdentifier {
            if let selectedRow = tableView.indexPathForSelectedRow() {
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
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        let story = stories[indexPath.row]
        
        cell.textLabel?.text = story.title
        cell.detailTextLabel?.text = story.author
        
        if useAutosizingCells && tableView.respondsToSelector("layoutMargins") {
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
        }
        
        return cell
    }
    
    // MARK: - UIAlertViewDelegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex != alertView.cancelButtonIndex {
            fetchData(nil)
        }
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
            (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.handleResponse(data, response: response, error: error)
                
                UIApplication.sharedApplication().stopNetworkActivity()
                
                handler?()
            });
        })
        
        UIApplication.sharedApplication().startNetworkActivity()
        
        // I run task.resume() with delay because my network is too fast
        let delay = (stories.count == 0 ? 0 : 5) * Double(NSEC_PER_SEC)
        var time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            task.resume()
        })
    }
    
    private func handleResponse(data: NSData!, response: NSURLResponse!, error: NSError!) {
        if error != nil {
            showAlertWithError(error)
            return;
        }
        
        var jsonError: NSError?
        let responseDict = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.allZeros, error: &jsonError) as? Dictionary<String, AnyObject>
        
        if jsonError != nil {
            showAlertWithError(jsonError)
            return
        }
        
        if let pages = responseDict?[JSONNumPagesKey] as? NSNumber {
            numPages = pages as! Int
        }
        
        if let results = responseDict?[JSONResultsKey] as? [Dictionary<String, AnyObject>] {
            currentPage++

            for i in results {
                stories.append(StoryModel(i))
            }
            
            tableView.reloadData()
        }
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
