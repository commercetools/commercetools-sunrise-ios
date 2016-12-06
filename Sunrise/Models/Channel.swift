//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import CoreLocation

extension Channel: QueryEndpoint {

    public static let path = "channels"

    public typealias ResponseType = Channel
}

extension Channel {

    // MARK: - Retrieving physical stores

    var location: CLLocation? {
        if let lon = self.latitude, let lat = self.longitude, let latitude = Double(lat), let longitude = Double(lon) {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    /**
        Queries for channels which represent physical stores.

        - parameter result:                   The code to be executed after processing the response, providing channels
                                              query response.
    */
    static func physicalStores(result: @escaping (Result<QueryResponse<ResponseType>>) -> Void) {
        Channel.query(predicates: ["roles contains all (\"InventorySupply\", \"ProductDistribution\") AND NOT(roles contains any (\"Primary\"))"],
                sort:  ["lastModifiedAt desc"], result: result)
    }

    static func sortStoresByDistance(stores: [Channel], userLocation: CLLocation) -> [Channel] {
        return stores.sorted(by: {
            guard let first = $0.distance(from: userLocation), let second = $1.distance(from: userLocation) else { return false }
            return first < second
        })
    }

    func distance(from userLocation: CLLocation) -> Double? {
        if let channelLocation = location {
            return userLocation.distance(from: channelLocation)
        }
        return nil
    }

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