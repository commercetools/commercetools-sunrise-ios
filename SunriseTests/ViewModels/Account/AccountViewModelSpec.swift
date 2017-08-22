//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import ReactiveCocoa
import Result
@testable import Sunrise

class AccountViewModelSpec: QuickSpec {

    override func spec() {
        describe("AccountViewModelSpec") {
            var accountViewModel: AccountViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "cartAndOrder", ofType: "json")!
                let orderJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let order = try! jsonDecoder.decode(Order.self, from: orderJSON.data(using: .utf8)!)

                accountViewModel = AccountViewModel()
                accountViewModel.orders = [order]
                accountViewModel.reservations = [order]
            }

            it("both orders and reservations are collapsed initially") {
                expect(accountViewModel.numberOfRowsInSection(1)).to(equal(0))
                expect(accountViewModel.numberOfRowsInSection(2)).to(equal(0))
            }

            it("has the proper title for section headers") {
                expect(accountViewModel.headerTitleForSection(1)).to(equal("MY ORDERS"))
                expect(accountViewModel.headerTitleForSection(2)).to(equal("MY RESERVATIONS"))
            }

            context("expanding orders works") {
                beforeEach {
                    accountViewModel.ordersExpanded.value = true
                }

                it("orders are expanded") {
                    expect(accountViewModel.numberOfRowsInSection(1)).to(equal(1))
                }
            }

            context("expanding reservations works") {
                beforeEach {
                    accountViewModel.reservationsExpanded.value = true
                }

                it("reservations are expanded") {
                    expect(accountViewModel.numberOfRowsInSection(2)).to(equal(1))
                }
            }

            context("retrieving data for the first order") {
                let indexPath = IndexPath(row: 0, section: 1)

                it("order number is properly extracted") {
                    expect(accountViewModel.orderNumberAtIndexPath(indexPath)).to(equal("ORD123"))
                }

                it("total price is properly extracted") {
                    expect(accountViewModel.totalPriceAtIndexPath(indexPath)).to(equal("€625.00"))
                }
            }
        }
    }
}
