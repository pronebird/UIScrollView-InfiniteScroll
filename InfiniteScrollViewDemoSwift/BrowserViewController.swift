//
//  BrowserViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit

class BrowserViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webView: UIWebView!
    var story: StoryModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = story?.title
        
        startLoading()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if webView.loading {
            webView.delegate = nil
            webView.stopLoading()
            
            UIApplication.sharedApplication().stopNetworkActivity()
        }
    }
    
    func startLoading() {
        if let story_ = story {
            webView.loadRequest(NSURLRequest(URL: story_.url))
        }
    }
    
    // MARK: - UIWebViewDelegate
    
    func webViewDidStartLoad(webView: UIWebView) {
        UIApplication.sharedApplication().startNetworkActivity()
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().stopNetworkActivity()
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        if error?.code != NSURLErrorCancelled {
            let alert = UIAlertController(title: NSLocalizedString("Failed to load URL", comment: ""), message: error!.localizedDescription, preferredStyle: .Alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: { (action) -> Void in
                self.navigationController?.popViewControllerAnimated(true)
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .Default, handler: { (action) -> Void in
                self.startLoading()
            }))
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        UIApplication.sharedApplication().stopNetworkActivity()
    }
    
}
