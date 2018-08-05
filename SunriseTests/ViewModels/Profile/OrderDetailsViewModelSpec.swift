//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class OrderDetailsViewModelSpec: QuickSpec {

    override func spec() {
        describe("OrderDetailsViewModel") {
            var orderDetailsViewModel: OrderDetailsViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "order", ofType: "json")!
                let orderJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let order = try! jsonDecoder.decode(Order.self, from: orderJSON.data(using: .utf8)!)

                orderDetailsViewModel = OrderDetailsViewModel(order: order)
            }

            it("has the correct number of line items") {
                expect(orderDetailsViewModel.numberOfLineItems).to(equal(3))
            }

            it("has the correct order number") {
                expect(orderDetailsViewModel.orderNumber.value).to(equal("Order # 342890"))
            }

            it("has the correct order total") {
                expect(orderDetailsViewModel.orderTotal.value).to(equal("Total € 1265.84"))
            }

            it("has the correct delivery address") {
                expect(orderDetailsViewModel.deliveryAddress.value).to(contain("Germany"))
            }

            context("retrieving data for the first line item") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("has the correct name") {
                    expect(orderDetailsViewModel.lineItemName(at: indexPath)).to(equal("Jacket Michael Kors dark blue"))
                }

                it("has the correct quantity") {
                    expect(orderDetailsViewModel.lineItemQuantity(at: indexPath)).to(equal("x1"))
                }

                it("has the correct price") {
                    expect(orderDetailsViewModel.lineItemPrice(at: indexPath)).to(equal("€ 156.00"))
                }
            }
        }
    }
}