//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Quick
import Nimble
import ObjectMapper
import ReactiveCocoa
import Result
@testable import Sunrise

class ProductViewModelSpec: QuickSpec {

    override func spec() {
        describe("ProductViewModel") {
            var productViewModel: ProductViewModel!

            beforeEach {
                let path = NSBundle.currentTestBundle!.pathForResource("product-projection", ofType: "json")!
                let productProjectionJSON = try! NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
                let product = Mapper<ProductProjection>().map(productProjectionJSON)!

                productViewModel = ProductViewModel(product: product)
            }

            it("has the correct upper case name") {
                expect(productViewModel.name).to(equal("SNEAKERS ”TOKYO” LOTTO GREY"))
            }

            it("has proper sizes extracted") {
                expect(productViewModel.sizes).to(equal(["34", "34.5", "35", "35.5", "36", "36.5", "37", "37.5", "38", "38.5", "39", "39.5", "40", "40.5", "41", "41.5", "42", "42.5", "43", "43.5", "44", "44.5", "45", "45.5", "46"]))
            }

            it("initially has size selected from master variant") {
                expect(productViewModel.size.value).to(equal("34"))
            }

            it("initially has sku selected from master variant") {
                expect(productViewModel.sku.value).to(equal("M0E20000000E7W1"))
            }

            it("initially has imageUrl selected from master variant") {
                expect(productViewModel.imageUrl.value).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/080534_1_medium.jpg"))
            }

            it("initially has properly formatted price from master variant") {
                expect(productViewModel.price.value).to(equal("€96.25"))
            }

            it("initially has properly formatted price before discount from master variant") {
                expect(productViewModel.oldPrice.value).to(equal("€137.50"))
            }

            context("after changing selected size") {
                beforeEach {
                    productViewModel.size.value = "38"
                }

                it("sku is updated") {
                    expect(productViewModel.sku.value).to(equal("M0E20000000E7W9"))
                }
            }
        }
    }
}