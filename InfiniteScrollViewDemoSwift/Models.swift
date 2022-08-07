//
//  Models.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 7/8/22.
//  Copyright © 2022 pronebird. All rights reserved.
//

import Foundation

struct FlickrItem: Decodable {
    let link: URL
    let media: [String: URL]
    var mediumMediaUrl: URL? {
        media["m"]
    }
}

struct FlickrResponse: Decodable {
    let items: [FlickrItem]
}

struct HackerNewsStory: Decodable {
    let objectID: String
    let title: String
    let author: String
    let url: URL?
    var postUrl: URL {
        URL(string: "https://news.ycombinator.com/item?id=\(objectID)")!
    }
}

struct HackerNewsResponse: Decodable {
    let hits: [HackerNewsStory]
    let nbPages: Int
}
