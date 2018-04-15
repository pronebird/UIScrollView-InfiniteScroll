//
//  Support.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 4/15/18.
//  Copyright © 2018 pronebird. All rights reserved.
//

import Foundation

enum Result<T, E: Error> {
    case ok(T)
    case error(E)
}
