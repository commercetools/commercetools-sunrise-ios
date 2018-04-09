//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import CoreLocation
import DateToolsSwift

class ReservationDetailsViewModel: BaseViewModel {
    
    // Outputs
    let productName: MutableProperty<String?>
    let productImageUrl: MutableProperty<String>
    let created: MutableProperty<String?>
    let total: MutableProperty<String?>
    let storeName: MutableProperty<String?>
    let storeAddress: MutableProperty<String?>
    let storeOpeningHours: MutableProperty<String?>
    let storeLocation: MutableProperty<CLLocation?>

    // MARK: - Lifecycle
    
    init(reservation: Order) {
        let reservedProduct = reservation.lineItems.first
        productName = MutableProperty(reservedProduct?.name.localizedString)
        productImageUrl = MutableProperty(reservedProduct?.variant.images?.first?.url ?? "")
        created = MutableProperty(reservation.createdAt.timeAgoSinceNow)
        total = MutableProperty(String(format: NSLocalizedString("Total %@", comment: "Order Total"), reservation.taxedPrice?.totalGross.description ?? reservation.totalPrice.description))
        storeName = MutableProperty(reservedProduct?.distributionChannel?.obj?.name?.localizedString)
        storeAddress = MutableProperty("\(reservedProduct?.distributionChannel?.obj?.streetAndNumberInfo ?? "")\n\(reservedProduct?.distributionChannel?.obj?.zipAndCityInfo ?? "")")
        storeOpeningHours = MutableProperty(reservedProduct?.distributionChannel?.obj?.openingTimes)
        storeLocation = MutableProperty(reservedProduct?.distributionChannel?.obj?.location)

        super.init()
    }
}