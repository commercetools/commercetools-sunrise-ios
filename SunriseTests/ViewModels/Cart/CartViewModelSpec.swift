//
// Copyright (c) 2018 Commercetools. All rights reserved.
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
                let path = Bundle.currentTestBundle!.path(forResource: "cart", ofType: "json")!
                let cartJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let cart = try! jsonDecoder.decode(Cart.self, from: cartJSON.data(using: .utf8)!)

                cartViewModel = CartViewModel()
                cartViewModel.cart.value = cart
            }

            it("has the correct number of unique items") {
                expect(cartViewModel.numberOfItems.value).to(equal("3"))
            }

            it("has the correct number of line item cells") {
                expect(cartViewModel.numberOfLineItems).to(equal(3))
            }

            it("has the correct total") {
                expect(cartViewModel.orderTotal.value).to(equal("€ 1265.84"))
            }

            context("retrieving data for the first line item") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("has the correct line item name") {
                    expect(cartViewModel.lineItemName(at: indexPath)).to(equal("Jacket Michael Kors dark blue"))
                }

                it("has the correct line item sku") {
                    expect(cartViewModel.lineItemSku(at: indexPath)).to(equal("M0E20000000DLUW"))
                }

                it("has the correct line item size") {
                    expect(cartViewModel.lineItemSize(at: indexPath)).to(equal("XXS"))
                }

                it("has the correct line item image url") {
                    expect(cartViewModel.lineItemImageUrl(at: indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/072769_1_large.jpg"))
                }

                it("has the correct old price for the line item") {
                    expect(cartViewModel.lineItemOldPrice(at: indexPath)).to(equal("€ 195.00"))
                }

                it("has the correct current price for the line item") {
                    expect(cartViewModel.lineItemPrice(at: indexPath)).to(equal("€ 156.00"))
                }

                it("has the correct quantity for the line item") {
                    expect(cartViewModel.lineItemQuantity(at: indexPath)).to(equal("x1"))
                }

                it("has the correct color for the line item") {
                    expect(cartViewModel.lineItemColor(at: indexPath)).to(equal(.blue))
                }
            }

            context("retrieving data for the third line item") {
                let indexPath = IndexPath(row: 2, section: 0)

                it("has the correct old price for the line item") {
                    expect(cartViewModel.lineItemOldPrice(at: indexPath)).to(equal("€ 910.00"))
                }

                it("has the correct current price for the line item") {
                    expect(cartViewModel.lineItemPrice(at: indexPath)).to(equal("€ 637.00"))
                }

                it("has the correct quantity for the line item") {
                    expect(cartViewModel.lineItemQuantity(at: indexPath)).to(equal("x2"))
                }
            }
        }
    }
}