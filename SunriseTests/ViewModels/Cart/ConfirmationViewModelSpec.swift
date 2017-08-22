//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class ConfirmationViewModelSpec: QuickSpec {

    override func spec() {
        describe("ConfirmationViewModel") {
            var confirmationViewModel: ConfirmationViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "cartConfirmation", ofType: "json")!
                let cartJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let cart = try! jsonDecoder.decode(Cart.self, from: cartJSON.data(using: .utf8)!)

                confirmationViewModel = ConfirmationViewModel(cart: cart)
            }

            it("has the correct shipping address") {
                expect(confirmationViewModel.shippingFirstName.value).to(equal("Mr. John"))
                expect(confirmationViewModel.shippingLastName.value).to(equal("Smith"))
                expect(confirmationViewModel.shippingStreetName.value).to(equal("Sonnenallee 223 "))
                expect(confirmationViewModel.shippingCity.value).to(equal("Berlin"))
                expect(confirmationViewModel.shippingPostalCode.value).to(equal("12059"))
                expect(confirmationViewModel.shippingRegion.value).to(equal(""))
                expect(confirmationViewModel.shippingCountry.value).to(equal("Germany"))
            }

            it("has the correct billing address") {
                expect(confirmationViewModel.billingFirstName.value).to(equal("Mr. JohnB"))
                expect(confirmationViewModel.billingLastName.value).to(equal("SmithB"))
                expect(confirmationViewModel.billingStreetName.value).to(equal("Sonnenallee 223B "))
                expect(confirmationViewModel.billingCity.value).to(equal("BerlinB"))
                expect(confirmationViewModel.billingPostalCode.value).to(equal("12059B"))
                expect(confirmationViewModel.billingRegion.value).to(equal("B"))
                expect(confirmationViewModel.billingCountry.value).to(equal("United States"))
            }

            it("has the correct shipping method") {
                expect(confirmationViewModel.shippingMethodName.value).to(equal("DHL"))
                expect(confirmationViewModel.shippingMethodDescription.value).to(equal("Standard shipping"))
            }
        }
    }
}