//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class CartViewModelSpec: QuickSpec {

    override func spec() {
        describe("CartViewModel") {
            var cartViewModel: CartViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "cartAndOrder", ofType: "json")!
                let cartJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let cart = try! jsonDecoder.decode(Cart.self, from: cartJSON.data(using: .utf8)!)

                cartViewModel = CartViewModel()
                cartViewModel.cart.value = cart
            }

            it("has the correct number of cells line items + summary") {
                expect(cartViewModel.numberOfRowsInSection(0)).to(equal(4))
            }

            it("has the correct number of items") {
                expect(cartViewModel.numberOfItems.value).to(equal("3"))
            }

            context("retrieving data for the first line item") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("product name is properly extracted") {
                    expect(cartViewModel.lineItemNameAtIndexPath(indexPath)).to(equal("Dress “Olivia“ Polo Ralph Lauren blue"))
                }

                it("imageUrl selected from variant") {
                    expect(cartViewModel.lineItemImageUrlAtIndexPath(indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/078990_1_medium.jpg"))
                }

                it("sku is properly extracted") {
                    expect(cartViewModel.lineItemSkuAtIndexPath(indexPath)).to(equal("M0E20000000DVL9"))
                }

                it("has correct price before discount") {
                    expect(cartViewModel.lineItemPriceAtIndexPath(indexPath)).to(equal("€87.50"))
                }

                it("has correct discounted price") {
                    expect(cartViewModel.lineItemOldPriceAtIndexPath(indexPath)).to(equal("€175.00"))
                }

                it("has correct quantity") {
                    expect(cartViewModel.lineItemQuantityAtIndexPath(indexPath)).to(equal("2"))
                }

                it("has correct total item price") {
                    expect(cartViewModel.lineItemTotalPriceAtIndexPath(indexPath)).to(equal("€175.00"))
                }
            }

            context("retrieving data for the second line item") {
                let indexPath = IndexPath(row: 1, section: 0)

                it("product name is properly extracted") {
                    expect(cartViewModel.lineItemNameAtIndexPath(indexPath)).to(equal("Pumps ”Flex” Michael Kors red"))
                }

                it("imageUrl selected from variant") {
                    expect(cartViewModel.lineItemImageUrlAtIndexPath(indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/073017_1_medium.jpg"))
                }

                it("sku is properly extracted") {
                    expect(cartViewModel.lineItemSkuAtIndexPath(indexPath)).to(equal("M0E20000000DMV1"))
                }

                it("has correct item price") {
                    expect(cartViewModel.lineItemPriceAtIndexPath(indexPath)).to(equal("€127.50"))
                }

                it("has correct quantity") {
                    expect(cartViewModel.lineItemQuantityAtIndexPath(indexPath)).to(equal("1"))
                }
                
                it("has correct discounted price extracted from first discountedPricePerQuantity element") {
                    expect(cartViewModel.lineItemOldPriceAtIndexPath(indexPath)).to(equal("€137.50"))
                }

                it("has correct total item price") {
                    expect(cartViewModel.lineItemTotalPriceAtIndexPath(indexPath)).to(equal("€127.50"))
                }
            }
        }
    }
}
