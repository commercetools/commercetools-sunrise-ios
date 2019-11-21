//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class ProductOverviewInterfaceModel {

    // Inputs
    let retrieveProductsObserver: Signal<Void, NoError>.Observer

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let presentProductSignal: Signal<ReducedProductDetailsInterfaceModel, NoError>

    let type: MainMenuInterfaceModel.ProductOverviewType
    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let presentProductObserver: Signal<ReducedProductDetailsInterfaceModel, NoError>.Observer
    private var products = [ReducedProduct]()
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(type: MainMenuInterfaceModel.ProductOverviewType, mainMenuInterfaceModel: MainMenuInterfaceModel?) {
        self.type = type
        self.mainMenuInterfaceModel = mainMenuInterfaceModel

        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)
        
        let (retrieveProductsSignal, retrieveProductsObserver) = Signal<Void, NoError>.pipe()
        self.retrieveProductsObserver = retrieveProductsObserver

        (presentProductSignal, presentProductObserver) = Signal<ReducedProductDetailsInterfaceModel, NoError>.pipe()
        
        disposables += retrieveProductsSignal.observeValues { [unowned self] in
            self.retrieveProducts()
        }
    }
    
    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func productDetailsInterfaceModel(for row: Int) -> ReducedProductDetailsInterfaceModel {
        return ReducedProductDetailsInterfaceModel(product: products[row], mainMenuInterfaceModel: (WKExtension.shared().rootInterfaceController as? MainMenuInterfaceController)?.interfaceModel)
    }

    // MARK: - Products retrieval

    private func retrieveProducts() {
        isLoading.value = true
        var text: String? = nil
        var sort: String? = nil
        var whereClause: String? = nil
        
        switch type {
            case .newProducts:
                sort = "createdAt desc"
            case .onSale:
                whereClause = "masterData(current(variants(prices(discounted is defined))))"
            case .search(let term):
                text = term
            default:
                break
        }
        
        let activity = ProcessInfo.processInfo.beginActivity(options: [.background, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve products")
        mainMenuInterfaceModel?.activeWishList { _ in
            if let text = text {
                ProductProjection.search(limit: 5, text: text) { result in
                    if let products = result.model?.results, result.isSuccess {
                        DispatchQueue.main.async {
                            self.products = products.map { ReducedProduct(productProjection: $0) }
                            self.numberOfRows.value = self.products.count
                        }

                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        debugPrint(errors)

                    }
                    self.isLoading.value = false
                    ProcessInfo.processInfo.endActivity(activity)
                }

            } else {
                var params = ""
                if let whereClause = whereClause {
                    params.append("where: \"\(whereClause)\" ")
                }
                if let sort = sort {
                    params.append("sort: \"\(sort)\" ")
                }
                let query = """
                            {
                              products(\(params) limit: 5) {
                                total
                                count
                                offset
                                results {
                                  \(ReducedProduct.reducedProductQuery)
                                }
                              }
                            }
                            \(ReducedProduct.moneyFragment)
                            \(ReducedProduct.variantFragment)
                            """
                GraphQL.query(query) { (result: Commercetools.Result<GraphQLResponse<ProductsResponse>>) in
                    if let products = result.model?.data.products.results, result.isSuccess {
                        DispatchQueue.main.async {
                            self.products = products.filter { $0.masterData.published }
                            self.numberOfRows.value = self.products.count
                        }

                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        debugPrint(errors)

                    }
                    self.isLoading.value = false
                    ProcessInfo.processInfo.endActivity(activity)

                }
            }
        }
    }
}
