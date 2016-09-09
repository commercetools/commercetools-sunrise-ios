//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Channel: QueryEndpoint {

    public static let path = "channels"

    public typealias ResponseType = Channel
}

extension Channel {

    // MARK: - Physical store properties

    private var fields: [String: Any]? {
        return custom?["fields"] as? [String: Any]
    }
    var streetAndNumberInfo: String {
        if let street = address?.streetName, let number = address?.streetNumber {
            return "\(street) \(number)"
        }
        return "-"
    }
    var zipAndCityInfo: String {
        if let zip = address?.postalCode, let city = address?.city {
            return "\(zip), \(city)"
        }
        return "-"
    }
    var openingTimes: String {
        if let openingTimes = fields?["openingTimes"] as? [String: String] {
            return openingTimes.localizedString ?? "-"
        }
        return "-"
    }
    var imageUrl: String? {
        return fields?["imageUrl"] as? String
    }
    var latitude: String? {
        return fields?["latitude"] as? String
    }
    var longitude: String? {
        return fields?["longitude"] as? String
    }
}

extension Channel: Hashable {

    public var hashValue: Int {
        return (id ?? "").hashValue
    }

}

extension Channel: Equatable {}

public func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.hashValue == rhs.hashValue
}