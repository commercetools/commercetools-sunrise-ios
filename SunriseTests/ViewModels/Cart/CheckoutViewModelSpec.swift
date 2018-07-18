//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class CheckoutViewModelSpec: QuickSpec {

    override func spec() {
        describe("CheckoutViewModel") {
            var checkoutViewModel: CheckoutViewModel!

            beforeEach {
                var path = Bundle.currentTestBundle!.path(forResource: "cart", ofType: "json")!
                let cartJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let cart = try! jsonDecoder.decode(Cart.self, from: cartJSON.data(using: .utf8)!)

                path = Bundle.currentTestBundle!.path(forResource: "shipping-methods", ofType: "json")!
                let methodsJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let methods = try! jsonDecoder.decode([ShippingMethod].self, from: methodsJSON.data(using: .utf8)!)

                checkoutViewModel = CheckoutViewModel()
                checkoutViewModel.cart.value = cart
                checkoutViewModel.methods.value = methods
            }

            it("has the correct number of unique items") {
                expect(checkoutViewModel.numberOfLineItems.value).to(equal(3))
            }

            it("has the correct subtotal amount") {
                expect(checkoutViewModel.subtotal.value).to(equal("1.569,80 €"))
            }

            it("has the correct shipping price amount") {
                expect(checkoutViewModel.shippingPrice.value).to(equal("10,00 €"))
            }

            it("has the correct order discount amount") {
                expect(checkoutViewModel.orderDiscount.value).to(equal("313,96 €"))
            }

            it("has the correct tax amount") {
                expect(checkoutViewModel.tax.value).to(equal("202,12 €"))
            }

            it("has the correct order total") {
                expect(checkoutViewModel.orderTotal.value).to(equal("1.265,84 €"))
            }

            context("retrieving data for the first line item") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("has the correct name") {
                    expect(checkoutViewModel.lineItemName(at: indexPath)).to(equal("Jacke Michael Kors dunkelblau"))
                }

                it("has the correct quantity") {
                    expect(checkoutViewModel.lineItemQuantity(at: indexPath)).to(equal("x1"))
                }

                it("has the correct price") {
                    expect(checkoutViewModel.lineItemPrice(at: indexPath)).to(equal("156,00 €"))
                }

            }

            context("retrieving data for the last shipping method") {
                let indexPath = IndexPath(row: 2, section: 0)

                it("has the correct name") {
                    expect(checkoutViewModel.shippingMethodName(at: indexPath)).to(equal("Express"))
                }

                it("has the correct description") {
                    expect(checkoutViewModel.shippingMethodDescription(at: indexPath)).to(equal("Delivery the same day"))
                }

                it("has the correct price") {
                    expect(checkoutViewModel.shippingMethodPrice(at: indexPath)).to(equal("10,00 €"))
                }

            }
        }
    }
}