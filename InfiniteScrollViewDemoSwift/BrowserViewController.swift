//
//  BrowserViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit

class BrowserViewController: UIViewController, UIWebViewDelegate, UIAlertViewDelegate {
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
            webView.loadRequest(NSURLRequest(URL: story_.url!))
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
            let alert = UIAlertView(
                title: NSLocalizedString("Failed to load URL", comment: ""),
                message: error!.localizedDescription,
                delegate: self,
                cancelButtonTitle: NSLocalizedString("Cancel", comment: ""),
                otherButtonTitles: NSLocalizedString("Retry", comment: "")
            )
            alert.show()
        }
        
        UIApplication.sharedApplication().stopNetworkActivity()
    }
    
    // MARL: - UIAlertViewDelegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        // Swift bug: firstOtherButtonIndex is not being set, use cancelButtonIndex then
        if buttonIndex != alertView.cancelButtonIndex {
            startLoading()
            return
        }
        
        navigationController?.popViewControllerAnimated(true)
    }
    
}
