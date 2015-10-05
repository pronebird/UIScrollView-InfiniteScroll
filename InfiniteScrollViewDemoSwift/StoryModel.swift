//
//  StoryModel.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import Foundation

class StoryModel: NSObject {
    
    var title: String?
    var author: String?
    var url: NSURL?
    
    init(_ dictionary: [String: AnyObject]) {
        super.init()
    
        title = dictionary["title"] as? String
        author = dictionary["author"] as? String
        
        if let urlString = dictionary["url"] as? String {
            url = NSURL(string: urlString)
        }
    }

}
