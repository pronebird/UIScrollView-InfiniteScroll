//
//  HackerNewsStory.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 4/15/18.
//  Copyright © 2018 pronebird. All rights reserved.
//

import Foundation

struct HackerNewsStory: Decodable {
    let objectID: String
    let title: String
    let author: String
    let url: URL?
    var postUrl: URL {
        return URL(string: "https://news.ycombinator.com/item?id=\(self.objectID)")!
    }
}

struct HackerNewsResponse: Decodable {
    let hits: [HackerNewsStory]
    let nbPages: Int
}
