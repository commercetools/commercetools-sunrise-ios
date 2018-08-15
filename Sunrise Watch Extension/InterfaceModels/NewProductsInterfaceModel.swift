//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class NewProductsInterfaceModel {

    // Inputs

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let presentProductSignal: Signal<ProductDetailsInterfaceModel, NoError>

    private let presentProductObserver: Signal<ProductDetailsInterfaceModel, NoError>.Observer
    private var products = [ProductProjection]()

    // MARK: - Lifecycle

    init() {
        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)

        (presentProductSignal, presentProductObserver) = Signal<ProductDetailsInterfaceModel, NoError>.pipe()

        retrieveProducts()
    }

    // MARK: - Data Source

    func productImageUrl(at row: Int) -> String {
        return products[row].displayVariant()?.images?.first?.url ?? ""
    }

    func productName(at row: Int) -> String {
        return products[row].name.localizedString ?? ""
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

    func productDetailsInterfaceModel(for row: Int) -> ProductDetailsInterfaceModel {
        return ProductDetailsInterfaceModel(product: products[row])
    }

    // MARK: - Reservations retrieval

    private func retrieveProducts() {
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Retrieve new products") { [weak self] expired in
            if !expired {
                ProductProjection.search(sort: ["createdAt desc"], limit: 4) { result in
                    if let products = result.model?.results, result.isSuccess {
                        DispatchQueue.main.async {
                            self?.products = products
                            self?.numberOfRows.value = products.count
                        }

                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        debugPrint(errors)

                    }
                    self?.isLoading.value = false
                }
            }
        }
    }
}
