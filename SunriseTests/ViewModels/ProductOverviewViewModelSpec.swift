//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
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
                Commercetools.config = nil
                let path = Bundle.currentTestBundle!.path(forResource: "product-projection", ofType: "json")!
                let productProjectionJSON = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
                let product = Mapper<ProductProjection>().map(JSONString: productProjectionJSON as String)!

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
                let indexPath = IndexPath(item: 0, section: 0)

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

            context("online store shopping") {
                beforeEach {
                    AppRouting.accountViewController?.viewModel?.currentStore.value = nil
                }

                it("header shows online store name") {
                    expect(overviewViewModel.browsingStoreName.value).toEventually(equal("Online Store"))
                }
            }

            context("my store selected") {
                let indexPath = IndexPath(item: 0, section: 0)

                beforeEach {
                    AppRouting.accountViewController?.viewModel?.currentStore.value = ReservationViewModelSpec.order.lineItems?.first?.distributionChannel?.obj
                }

                it("header shows my store name") {
                    expect(overviewViewModel.browsingStoreName.value).toEventually(equal("SUNRISE Store Berlin"))
                }

                it("has properly formatted price for the selected store") {
                    expect(overviewViewModel.productPriceAtIndexPath(indexPath)).to(equal("€146.25"))
                }

                it("has properly formatted price for the selected store") {
                    expect(overviewViewModel.productOldPriceAtIndexPath(indexPath)).to(equal("€187.50"))
                }
            }
        }
    }
}
