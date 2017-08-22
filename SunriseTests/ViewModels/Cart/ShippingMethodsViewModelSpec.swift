//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class ShippingMethodsViewModelSpec: QuickSpec {

    override func spec() {
        describe("ShippingMethodsViewModel") {
            var shippingMethodsViewModel: ShippingMethodsViewModel!

            beforeEach {
                let shippingMethodsPath = Bundle.currentTestBundle!.path(forResource: "shipping-methods", ofType: "json")!
                let shippingMethodsJSON = try! String(contentsOfFile: shippingMethodsPath, encoding: .utf8)
                let shippingMethods = try! jsonDecoder.decode([ShippingMethod].self, from: shippingMethodsJSON.data(using: .utf8)!)
                
                let cartPath = Bundle.currentTestBundle!.path(forResource: "cartAndOrder", ofType: "json")!
                let cartJSON = try! String(contentsOfFile: cartPath, encoding: .utf8)
                let cart = try! jsonDecoder.decode(Cart.self, from: cartJSON.data(using: .utf8)!)

                shippingMethodsViewModel = ShippingMethodsViewModel(shippingMethods: shippingMethods, cart: cart)
            }

            it("has the correct number of cells (i.e shipping methods)") {
                expect(shippingMethodsViewModel.numberOfRows(in: 0)).to(equal(2))
            }

            context("retrieving data for the first shipping method") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("name and description is properly extracted") {
                    expect(shippingMethodsViewModel.nameAndDescription(at: indexPath)).to(equal("DHL Standard shipping"))
                }

                it("price is properly calculated") {
                    expect(shippingMethodsViewModel.price(at: indexPath)).to(equal("Free"))
                }
            }

            context("retrieving data for the second shipping method") {
                let indexPath = IndexPath(row: 1, section: 0)

                it("name and description is properly extracted") {
                    expect(shippingMethodsViewModel.nameAndDescription(at: indexPath)).to(equal("Expensive Option "))
                }

                it("price is properly calculated") {
                    expect(shippingMethodsViewModel.price(at: indexPath)).to(equal("€3,333.00"))
                }
            }
        }
    }
}
