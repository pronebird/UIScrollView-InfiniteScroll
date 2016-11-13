//
//  StoryModel.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import Foundation

private struct StoryModelAttributes {
    static let url = "url"
    static let title = "title"
    static let author = "author"
}

class StoryModel: NSObject {
    var title: String?
    var author: String?
    var url: URL
    
    init?(_ dictionary: [String: AnyObject]) {
        // sometimes HN returns some trash
        guard let urlString = dictionary[StoryModelAttributes.url] as? String,
              let urlObject = URL(string: urlString)
        else {
            return nil
        }
    
        title = dictionary[StoryModelAttributes.title] as? String
        author = dictionary[StoryModelAttributes.author] as? String
        url = urlObject
        
        super.init()
    }

}
