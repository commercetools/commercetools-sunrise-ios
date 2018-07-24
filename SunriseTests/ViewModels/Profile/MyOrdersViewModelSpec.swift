//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class MyOrdersViewModelSpec: QuickSpec {

    override func spec() {
        describe("MyOrdersViewModel") {
            var ordersViewModel: MyOrdersViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "order", ofType: "json")!
                let orderJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let order = try! jsonDecoder.decode(Order.self, from: orderJSON.data(using: .utf8)!)

                ordersViewModel = MyOrdersViewModel(orders: [order])
            }

            it("has the correct number of orders") {
                expect(ordersViewModel.numberOfOrders).to(equal(1))
            }

            context("retrieving data for the first order") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("has the correct order number") {
                    expect(ordersViewModel.orderNumber(at: indexPath)).to(equal("Order # 342890"))
                }

                it("has the correct total price") {
                    expect(ordersViewModel.totalPrice(at: indexPath)).to(equal("Total € 1265.84"))
                }
            }
        }
    }
}