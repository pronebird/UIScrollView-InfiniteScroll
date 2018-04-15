//
//  FlickrModel.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 12/20/16.
//  Copyright © 2016 pronebird. All rights reserved.
//

import Foundation

struct FlickrItem: Decodable {
    let link: URL
    let media: [String: URL]
    var mediumMediaUrl: URL? {
        return media["m"]
    }
}

struct FlickrResponse: Decodable {
    let items: [FlickrItem]
}
