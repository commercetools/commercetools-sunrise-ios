//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Quick
import Nimble
import ObjectMapper
import ReactiveCocoa
import Result
@testable import Sunrise

class ProductOverviewViewModelSpec: QuickSpec {

    override func spec() {
        describe("ProductOverviewViewModel") {
            var overviewViewModel: ProductOverviewViewModel!

            beforeEach {
                let path = NSBundle.currentTestBundle!.pathForResource("product-projection", ofType: "json")!
                let productProjectionJSON = try! NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
                let product = Mapper<ProductProjection>().map(productProjectionJSON)!

                overviewViewModel = ProductOverviewViewModel()
                overviewViewModel.products = [product]
            }

            it("has the correct navigation bar title") {
                expect(overviewViewModel.title).to(equal("Products"))
            }

            it("has correct number of products in section") {
                expect(overviewViewModel.numberOfProductsInSection(0)).to(equal(1))
            }

            context("retrieving data for the first cell") {
                let indexPath = NSIndexPath(forItem: 0, inSection: 0)

                it("product name is properly extracted") {
                    expect(overviewViewModel.productNameAtIndexPath(indexPath)).to(equal("Sneakers ”Tokyo” Lotto grey"))
                }

                it("imageUrl selected from master variant") {
                    expect(overviewViewModel.productImageUrlAtIndexPath(indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/080534_1_medium.jpg"))
                }

                it("has properly formatted price from master variant") {
                    expect(overviewViewModel.productPriceAtIndexPath(indexPath)).to(equal("€96.25"))
                }

                it("has properly formatted price before discount from master variant") {
                    expect(overviewViewModel.productOldPriceAtIndexPath(indexPath)).to(equal("€137.50"))
                }
            }
        }
    }
}