//
//  UIApplication+NetworkIndicator.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import Foundation

private var networkActivityCount = 0

extension UIApplication {
    
    func startNetworkActivity() {
        networkActivityCount += 1
        isNetworkActivityIndicatorVisible = true
    }
    
    func stopNetworkActivity() {
        if networkActivityCount < 1 {
            return;
        }
        
        networkActivityCount -= 1
        if networkActivityCount == 0 {
            isNetworkActivityIndicatorVisible = false
        }
    }
    
}
