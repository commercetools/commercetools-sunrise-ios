//
//  NotificationsViewController.swift
//  Sunrise
//
//  Created by Nikola Mladenovic on 8/25/16.
//  Copyright © 2016 Commercetools. All rights reserved.
//

import UIKit

class NotificationsViewController: UIViewController {

    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func dismissNotification(sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }

}
