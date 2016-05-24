//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ObjectMapper

class OverviewViewController: UITableViewController {
    
    private var productMock: ProductProjection?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Just a hard coded example for trying out PDP
        Commercetools.ProductProjection.byId("273bdb43-7475-4ee8-ab54-d0398d79327f", result: { result in
            if let response = result.response, product = Mapper<ProductProjection>().map(response) where result.isSuccess {
                self.productMock = product
            }
        })
        
    }

    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let productViewController = segue.destinationViewController as? ProductViewController {
            let productViewModel = ProductViewModel(product: productMock!)
            productViewController.viewModel = productViewModel
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        return productMock != nil
    }

}
