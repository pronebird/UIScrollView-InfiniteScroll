//
//  PhotoViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit

class PhotoViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView?
    var photo: UIImage? {
        didSet {
            imageView?.image = photo
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        imageView?.image = photo
    }
    
    @IBAction func dismiss(_ sender: AnyObject!) {
        self.dismiss(animated: true, completion: nil)
    }
}
