//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import ObjectMapper
import Result
@testable import Sunrise

class AddressSelectionViewModelSpec: QuickSpec {

    override func spec() {
        describe("AddressSelectionModel") {
            var addressSelectionViewModel: AddressSelectionViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "customer", ofType: "json")!
                let customerJSON = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
                let customer = Mapper<Customer>().map(JSONString: customerJSON as String)!

                addressSelectionViewModel = AddressSelectionViewModel(customer: customer)
            }

            it("has the correct number of sections - default address + list of addresses") {
                expect(addressSelectionViewModel.numberOfSections).to(equal(2))
            }

            it("has the correct number of items for the default address section") {
                expect(addressSelectionViewModel.numberOfRows(in: 0)).to(equal(1))
            }

            it("has the correct number of items for the list of addresses (w/o the default one plus the 'add new' row)") {
                expect(addressSelectionViewModel.numberOfRows(in: 1)).to(equal(4))
            }

            context("retrieving data for the default address") {
                let indexPath = IndexPath(row: 0, section: 0)

                it("firstName is properly extracted") {
                    expect(addressSelectionViewModel.firstName(at: indexPath)).to(equal("Mr. John"))
                }

                it("lastName is properly extracted") {
                    expect(addressSelectionViewModel.lastName(at: indexPath)).to(equal("Smith"))
                }

                it("street name is properly extracted") {
                    expect(addressSelectionViewModel.streetName(at: indexPath)).to(equal("Sonnenallee 223 "))
                }

                it("city is properly extracted") {
                    expect(addressSelectionViewModel.city(at: indexPath)).to(equal("Berlin"))
                }

                it("postal code is properly extracted") {
                    expect(addressSelectionViewModel.postalCode(at: indexPath)).to(equal("12059"))
                }

                it("region is properly extracted") {
                    expect(addressSelectionViewModel.region(at: indexPath)).to(equal(""))
                }

                it("country is properly extracted") {
                    expect(addressSelectionViewModel.country(at: indexPath)).to(equal("Germany"))
                }
            }
        }
    }
}