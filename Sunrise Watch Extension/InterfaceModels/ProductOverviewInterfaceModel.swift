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
    let presentProductSignal: Signal<ProductProjectionDetailsInterfaceModel, NoError>

    let type: MainMenuInterfaceModel.ProductOverviewType
    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let presentProductObserver: Signal<ProductProjectionDetailsInterfaceModel, NoError>.Observer
    private var products = [ProductProjection]()
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(type: MainMenuInterfaceModel.ProductOverviewType, mainMenuInterfaceModel: MainMenuInterfaceModel?) {
        self.type = type
        self.mainMenuInterfaceModel = mainMenuInterfaceModel

        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)
        
        let (retrieveProductsSignal, retrieveProductsObserver) = Signal<Void, NoError>.pipe()
        self.retrieveProductsObserver = retrieveProductsObserver

        (presentProductSignal, presentProductObserver) = Signal<ProductProjectionDetailsInterfaceModel, NoError>.pipe()
        
        disposables += retrieveProductsSignal.observeValues { [unowned self] in
            self.retrieveProducts()
        }
    }
    
    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func productDetailsInterfaceModel(for row: Int) -> ProductProjectionDetailsInterfaceModel {
        return ProductProjectionDetailsInterfaceModel(product: products[row], mainMenuInterfaceModel: (WKExtension.shared().rootInterfaceController as? MainMenuInterfaceController)?.interfaceModel)
    }

    // MARK: - Products retrieval

    private func retrieveProducts() {
        isLoading.value = true
        var text: String? = nil
        var sort: [String]? = nil
        var filterQuery: [String]? = nil
        
        switch type {
            case .newProducts:
                sort = ["createdAt desc"]
            case .onSale:
                filterQuery = ["variants.prices.discounted:exists"]
            case .search(let term):
                text = term
            default:
                break
        }
        
        let activity = ProcessInfo.processInfo.beginActivity(options: [.background, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve products")
        mainMenuInterfaceModel?.activeWishList { _ in
            ProductProjection.search(sort: sort, limit: 5, text: text, filterQuery: filterQuery) { result in
                if let products = result.model?.results, result.isSuccess {
                    DispatchQueue.main.async {
                        self.products = products
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
