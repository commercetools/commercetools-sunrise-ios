//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import MapKit
import CoreLocation
import ReactiveSwift
import Result
import Commercetools

class ProductDetailsInterfaceModel {

    // Inputs
    var moveToCartAction: Action<Void, Void, NoError>!
    var addToWishListAction: Action<Void, Void, NoError>!

    // Outputs
    var productName: String {
        return product.name.localizedString ?? ""
    }
    var productImageUrl: String {
        return product.displayVariant()?.images?.first?.url ?? ""
    }
    var productPrice: String? {
        guard let variant = product.displayVariant(),
              let price = variant.price() else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }

    private let product: ProductProjection

    // MARK: - Lifecycle

    init(product: ProductProjection) {
        self.product = product

        moveToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return SignalProducer { [unowned self] observer, disposable in
                
                observer.send(value: ())
                observer.sendCompleted()
            }
        }
        
        addToWishListAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return SignalProducer { [unowned self] observer, disposable in
                
                observer.send(value: ())
                observer.sendCompleted()
            }
        }
    }
}
