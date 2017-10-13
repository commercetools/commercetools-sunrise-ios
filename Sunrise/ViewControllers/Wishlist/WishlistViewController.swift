//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class WishlistViewController: UIViewController {

    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    private let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        gradientLayer.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
//        tableView.contentInset = UIEdgeInsetsMake(10, 0, 0, 0)
    }
}

extension WishlistViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "WishlistCell")!
    }
}

