//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class ProductOverviewInterfaceModel {

    // Inputs

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let presentProductSignal: Signal<ProductDetailsInterfaceModel, NoError>

    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let presentProductObserver: Signal<ProductDetailsInterfaceModel, NoError>.Observer
    private var products = [ProductProjection]()
    private let text: String?
    private let filterQuery: [String]?
    private let sort: [String]?
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(mainMenuInterfaceModel: MainMenuInterfaceModel?, text: String? = nil, filterQuery: [String]? = nil, sort: [String]? = nil) {
        self.mainMenuInterfaceModel = mainMenuInterfaceModel
        self.text = text
        self.filterQuery = filterQuery
        self.sort = sort

        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)

        (presentProductSignal, presentProductObserver) = Signal<ProductDetailsInterfaceModel, NoError>.pipe()

        if let mainMenuInterfaceModel = mainMenuInterfaceModel {
            disposables += mainMenuInterfaceModel.activeWishList.signal
            .observeValues { [weak self] _  in
                self?.numberOfRows.value = self?.numberOfRows.value ?? 0
            }
        }

        retrieveProducts()
    }
    
    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func productImageUrl(at row: Int) -> String {
        return products[row].displayVariant()?.images?.first?.url ?? ""
    }

    func productName(at row: Int) -> String {
        return products[row].name.localizedString ?? ""
    }
    
    func isInWishList(at row: Int) -> Bool {
        let product = products[row]
        return mainMenuInterfaceModel?.activeWishList.value?.lineItems.contains(where: { $0.productId == product.id && $0.variantId == product.displayVariant()?.id ?? product.masterVariant.id }) == true
    }

    func productPrice(at row: Int) -> String {
        guard let variant = products[row].displayVariant(),
              let price = variant.price() else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }
    
    func productOldPrice(at row: Int) -> String {
        guard let variant = products[row].displayVariant(),
              let price = variant.price(), price.discounted?.value != nil else { return "" }
        
        return price.value.description
    }

    func productDetailsInterfaceModel(for row: Int) -> ProductDetailsInterfaceModel {
        return ProductDetailsInterfaceModel(product: products[row], mainMenuInterfaceModel: (WKExtension.shared().rootInterfaceController as? MainMenuInterfaceController)?.interfaceModel)
    }

    // MARK: - Reservations retrieval

    private func retrieveProducts() {
        isLoading.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.background, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve products")
        mainMenuInterfaceModel?.wishListShoppingList(observer: nil, activity: activity) { _ in
            ProductProjection.search(sort: self.sort, limit: 4, text: self.text, filterQuery: self.filterQuery) { result in
                if let products = result.model?.results, result.isSuccess {
                    DispatchQueue.main.async {
                        self.products = products
                        self.numberOfRows.value = products.count
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
