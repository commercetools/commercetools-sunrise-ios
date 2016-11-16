//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class ProductOverviewViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let nextPageObserver: Observer<Void, NoError>
    let searchText = MutableProperty("")

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>

    let pageSize: UInt = 16
    var products: [ProductOverviewQuery.Data.Product.Result]

    // MARK: - Lifecycle

    override init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")

        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        super.init()

        refreshSignal
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        nextPageSignal
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount), text: self?.searchText.value ?? "")
            }
        }

        searchText.signal
        .observeValues({ [weak self] searchText in
            self?.queryForProductProjections(offset: 0, text: searchText)
        })
    }

    func productDetailsViewModelForProductAtIndexPath(_ indexPath: IndexPath) -> ProductViewModel {
//        let product = products[indexPath.row]
//        return ProductViewModel(product: product)
        return ProductViewModel()
    }

    // MARK: - Data Source

    func numberOfProductsInSection(_ section: Int) -> Int {
        return products.count
    }

    func productNameAtIndexPath(_ indexPath: IndexPath) -> String {
        return products[indexPath.row].masterData.current.name ?? ""
    }

    func productImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        let product = products[indexPath.row]
        if product.masterData.current.masterVariant.fragments.variantDetails.independentPrice != nil {
            return product.masterData.current.masterVariant.fragments.variantDetails.images.first?.url ?? ""
        } else {
            return product.masterData.current.variants.filter({ $0.fragments.variantDetails.independentPrice != nil }).first?.fragments.variantDetails.images.first?.url ?? ""
        }
    }

    func productPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let price = independentPrice(at: indexPath) else { return "" }
        let value = price.fragments.priceDetails.value.fragments.moneyDetails

        if let discounted = price.fragments.priceDetails.discounted?.value.fragments.moneyDetails {
            return discounted.description
        } else {
            return value.description
        }
    }

    func productOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let price = independentPrice(at: indexPath),
              let discounted = price.fragments.priceDetails.discounted?.value.fragments.moneyDetails else { return "" }

        return discounted.description
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset: UInt, text: String = "") {
        if let apolloClient = AppDelegate.shared.apolloClient {
            isLoading.value = true
            
            apolloClient.fetch(query: ProductOverviewQuery(pageSize: Int(pageSize), offset: Int(offset))) { result, error in
                if let error = error {
                    NSLog("Error while fetching query: \(error.localizedDescription)")
                    return
                } else if let results = result?.data?.products.results {
                    self.products = offset == 0 ? results : self.products + results
                }
                self.isLoading.value = false
            }
        }
    }
    
    func independentPrice(at indexPath: IndexPath) -> VariantDetails.Price? {
        let product = products[indexPath.row]
        if let independentPrice = product.masterData.current.masterVariant.fragments.variantDetails.independentPrice {
            return independentPrice
        } else {
            return product.masterData.current.variants.filter({ $0.fragments.variantDetails.independentPrice != nil }).first?.fragments.variantDetails.independentPrice
        }
    }
}

extension VariantDetails {
    
    /// The price without channel, customerGroup, country and validUntil/validFrom
    var independentPrice: VariantDetails.Price? {
        return prices?.filter({ price in
            let priceDetails = price.fragments.priceDetails
            if priceDetails.channel == nil && priceDetails.customerGroup == nil && priceDetails.country == nil
                && priceDetails.validFrom == nil && priceDetails.validUntil == nil {
                return true
            }
            return false
        }).first
    }
}

extension MoneyDetails: CustomStringConvertible {

    /// The textual representation used when written to an output stream, with locale based format
    public var description: String {
        if let currencySymbol = (Locale(identifier: currencyCode) as NSLocale).displayName(forKey: NSLocale.Key.currencySymbol, value: currencyCode) {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencySymbol = currencySymbol
            currencyFormatter.locale = Locale.current
            return currencyFormatter.string(from: NSNumber(value: Double(centAmount) / 100)) ?? ""
        }
        return ""
    }
}
