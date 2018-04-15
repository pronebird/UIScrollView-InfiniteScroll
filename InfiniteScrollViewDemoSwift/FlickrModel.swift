//
//  FlickrModel.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 12/20/16.
//  Copyright © 2016 pronebird. All rights reserved.
//

import Foundation

struct FlickrMedia {
    let medium: URL?
}

struct FlickrResponse: Decodable {
    let link: URL?
    private let rawMedia: [String: URL]
    
    var media: FlickrMedia {
        return FlickrMedia(medium: rawMedia["m"])
    }
    
    private enum CodingKeys: String, CodingKey {
        case link, rawMedia = "media"
    }
}

private struct FlickModelAttributes {
    struct mediaAttributes {
        static let medium = "m"
    }
    
    static let media = "media"
    static let link = "link"
}

class FlickrModel {
    struct Media {
        let medium: URL
    }
    
    let link: URL
    let media: Media
    
    init?(_ dictionary: [String: Any]) {
        guard let linkUrlString = dictionary[FlickModelAttributes.link] as? String,
              let linkUrl = URL(string: linkUrlString) else { return nil }
        
        guard let mediaDictionary = dictionary[FlickModelAttributes.media] as? [String: String],
              let mediumPhotoUrlString = mediaDictionary[FlickModelAttributes.mediaAttributes.medium],
              let mediumPhotoUrl = URL(string: mediumPhotoUrlString) else { return nil }
        
        link = linkUrl
        media = Media(medium: mediumPhotoUrl)
    }
    
}
