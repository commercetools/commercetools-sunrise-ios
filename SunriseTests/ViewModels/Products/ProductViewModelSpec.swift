//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import ReactiveSwift
import Result
@testable import Sunrise

class ProductViewModelSpec: QuickSpec {

    lazy var product: ProductProjection = {
        let path = Bundle.currentTestBundle!.path(forResource: "product-projection", ofType: "json")!
        let productProjectionJSON = try! String(contentsOfFile: path, encoding: .utf8)
        return try! jsonDecoder.decode(ProductProjection.self, from: productProjectionJSON.data(using: .utf8)!)
    }()

    override func spec() {
        describe("ProductViewModel") {
            var productViewModel: ProductDetailsViewModel!

            beforeSuite {
                Commercetools.config = Config(path: "CommercetoolsStagingConfig")
                // For my store test context, we need to load product overview view controller.
                AppRouting.switchToHome()
                _ = AppRouting.productOverviewViewController?.view
                productViewModel = ProductDetailsViewModel(product: self.product)
                waitUntil { done in
                    productViewModel.isLoading.producer
                    .startWithValues({ isLoading in
                        if !isLoading {
                            done()
                        }
                    })
                }
            }

            beforeEach {
                AppRouting.productOverviewViewController?.viewModel?.browsingStore.value = nil
            }

            it("has the correct upper case name") {
                expect(productViewModel.name.value).toEventually(equal("SNEAKERS ”TOKYO” LOTTO GREY"))
            }

            it("has proper sizes extracted") {
                expect(productViewModel.attributes.value["size"]).toEventually(equal(["34", "34.5", "35", "35.5", "36", "36.5", "37", "37.5", "38", "38.5", "39", "39.5", "40", "40.5", "41", "41.5", "42", "42.5", "43", "43.5", "44", "44.5", "45", "45.5", "46"]))
            }

            it("initially has size selected from master variant") {
                expect(productViewModel.activeAttributes.value["size"]).toEventually(equal("34"))
            }

            it("initially has sku selected from master variant") {
                expect(productViewModel.sku.value).toEventually(equal("M0E20000000E7W1"))
            }

            it("initially has imageCount selected from master variant") {
                expect(productViewModel.imageCount.value).toEventually(equal(1))
            }

            it("initially has imageUrl selected from master variant") {
                expect(productViewModel.productImageUrl(at: IndexPath(row: 0, section: 0))).toEventually(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/080534_1_medium.jpg"))
            }

            it("initially has properly formatted price from master variant") {
                expect(productViewModel.price.value).toEventually(equal("€96.25"))
            }

            it("initially has properly formatted price before discount from master variant") {
                expect(productViewModel.oldPrice.value).toEventually(equal("€137.50"))
            }

            context("after changing selected size") {
                it("sku is updated") {
                    waitUntil { done in
                        productViewModel.isLoading.producer
                        .startWithValues({ isLoading in
                            if !isLoading {
                                productViewModel.activeAttributes.value["size"] = "38"
                                done()
                            }
                        })
                    }
                    waitUntil { done in
                        productViewModel.activeAttributes.producer
                        .startWithValues({ activeAttributes in
                            if activeAttributes["size"] == "38" {
                                expect(productViewModel.sku.value).to(equal("M0E20000000E7W9"))
                                done()
                            }
                        })
                    }
                }
            }

            context("when customer is shopping for selected store") {
                beforeEach {
                    AppRouting.productOverviewViewController?.viewModel?.browsingStore.value = ReservationViewModelSpec.order.lineItems.first?.distributionChannel?.obj
                    productViewModel = ProductDetailsViewModel(product: self.product)
                    waitUntil { done in
                        productViewModel.isLoading.producer
                        .startWithValues({ isLoading in
                            if !isLoading {
                                done()
                            }
                        })
                    }
                }

                it("has proper sizes extracted") {
                    expect(productViewModel.attributes.value["size"]).toEventually(equal(["35"]))
                }

                it("has properly formatted price from variant containing price for specified channel") {
                    expect(productViewModel.price.value).toEventually(equal("€146.25"))
                }

                it("has properly formatted price before discount from variant containing price for specified channel") {
                    expect(productViewModel.oldPrice.value).toEventually(equal("€187.50"))
                }
            }
        }
    }
}