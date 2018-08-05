//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import Result
@testable import Sunrise

class MainViewModelSpec: QuickSpec {

    override func spec() {
        describe("MainViewModel") {
            var mainViewModel: MainViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "categories", ofType: "json")!
                let categoriesJSON = try! String(contentsOfFile: path, encoding: .utf8)
                let categories = try! jsonDecoder.decode(QueryResponse<Commercetools.Category>.self, from: categoriesJSON.data(using: .utf8)!)

                mainViewModel = MainViewModel(allCategories: categories.results)
            }

            it("has the correct active category name") {
                expect(mainViewModel.activeCategoryName.value).to(equal("New"))
            }

            it("has the correct number of root category rows") {
                expect(mainViewModel.numberOfCategoryRows).to(equal(6))
            }

            it("has the correct number of child category items") {
                expect(mainViewModel.numberOfCategoryItems).to(equal(3))
            }

            it("popup category selection updates active category name correctly") {
                mainViewModel.selectedCategoryTableRowObserver.send(value: IndexPath(row: 1, section: 0))
                expect(mainViewModel.activeCategoryName.value).to(equal("Women"))
            }

            it("child category selection updates active category name correctly") {
                mainViewModel.selectedCategoryCollectionItemObserver.send(value: IndexPath(item: 2, section: 0))
                expect(mainViewModel.activeCategoryName.value).to(equal("Special"))
            }

            context("retrieving data for the first child category") {
                let indexPath = IndexPath(item: 0, section: 0)

                it("has the correct image url") {
                    expect(mainViewModel.categoryImageUrl(at: indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/categories/new-women%403x.png"))
                }
            }
        }
    }
}