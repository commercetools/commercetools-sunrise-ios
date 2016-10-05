//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Quick
import Nimble
import ObjectMapper
import ReactiveCocoa
import Result
@testable import Sunrise

class OrdersViewModelSpec: QuickSpec {

    override func spec() {
        describe("OrdersViewModel") {
            var ordersViewModel: OrdersViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "cart", ofType: "json")!
                let orderJSON = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
                let order = Mapper<Order>().map(JSONString: orderJSON as String)!

                ordersViewModel = OrdersViewModel()
                ordersViewModel.orders = [order]
                ordersViewModel.reservations = [order]
            }

            it("both orders and reservations are collapsed initially") {
                expect(ordersViewModel.numberOfRowsInSection(0)).to(equal(0))
                expect(ordersViewModel.numberOfRowsInSection(1)).to(equal(0))
            }

            it("has the proper title for section headers") {
                expect(ordersViewModel.headerTitleForSection(0)).to(equal("MY ORDERS"))
                expect(ordersViewModel.headerTitleForSection(1)).to(equal("MY RESERVATIONS"))
            }

            context("expanding orders works") {
                beforeEach {
                    ordersViewModel.ordersExpanded.value = true
                }

                it("orders are expanded") {
                    expect(ordersViewModel.numberOfRowsInSection(0)).to(equal(1))
                }
            }

            context("expanding reservations works") {
                beforeEach {
                    ordersViewModel.reservationsExpanded.value = true
                }

                it("reservations are expanded") {
                    expect(ordersViewModel.numberOfRowsInSection(1)).to(equal(1))
                }
            }

            context("retrieving data for the first order") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("order number is properly extracted") {
                    expect(ordersViewModel.orderNumberAtIndexPath(indexPath)).to(equal("ORD123"))
                }

                it("total price is properly extracted") {
                    expect(ordersViewModel.totalPriceAtIndexPath(indexPath)).to(equal("€625.00"))
                }
            }
        }
    }
}
