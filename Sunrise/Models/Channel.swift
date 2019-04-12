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

    private var fields: [String: JsonValue]? {
        return custom?.dictionary?["fields"]?.dictionary
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
        if let openingTimes = fields?["openingTimes"]?.dictionary {
            return localizedString(from: openingTimes) ?? "-"
        }
        return "-"
    }
    var imageUrl: String? {
        return fields?["imageUrl"]?.string
    }
    var latitude: String? {
        return fields?["latitude"]?.string
    }
    var longitude: String? {
        return fields?["longitude"]?.string
    }
}

extension Channel: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}

extension Channel: Equatable {}

public func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

public func localizedString(from jsonDictionary: [String: JsonValue]) -> String? {
    return jsonDictionary.reduce([String: String]()) { dict, item in
        var openingTimes = dict
        if let stringValue = item.1.string {
            openingTimes[item.key] = stringValue
        }
        return openingTimes
    }.localizedString
}
