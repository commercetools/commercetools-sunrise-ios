//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import PassKit
import Commercetools

extension Dictionary where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
    var localizedString: Value? {
        let currentLocaleIdentifier = Locale.current.identifier

        if let key = currentLocaleIdentifier as? Key, let localizedString = self[key] {
            return localizedString

        } else if let key = Locale.components(fromIdentifier: currentLocaleIdentifier)[NSLocale.Key.languageCode.rawValue] as? Key, let localizedString = self[key] {
            return localizedString

        } else {
            return self.first?.1
        }
    }
}

extension Address: CustomStringConvertible {
    /// The textual representation used when written to an output stream, with locale based format
    public var description: String {
        var description = ""
        description += streetName != nil ? "\(streetName!) " : ""
        description += additionalStreetInfo ?? ""
        description += "\n"
        description += city != nil ? "\(city!)\n" : ""
        description += region ?? state ?? ""
        description += postalCode ?? ""
        description += "\n"
        description += (Locale.current as NSLocale).displayName(forKey: NSLocale.Key.countryCode, value: country) ?? country
        return description
    }
}

extension Address {
    var pkContact: PKContact {
        let contact = PKContact()
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = firstName
        nameComponents.familyName = lastName
        contact.name = nameComponents
        let postalAddress = CNMutablePostalAddress()
        postalAddress.isoCountryCode = country
        postalAddress.city = city ?? ""
        postalAddress.street = "\(streetName ?? "") \(streetNumber ?? "")"
        postalAddress.postalCode = postalCode ?? ""
        if let state = state {
            postalAddress.state = state
        }
        contact.postalAddress = postalAddress
        contact.emailAddress = email
        if let phone = phone {
            contact.phoneNumber = CNPhoneNumber(stringValue: phone)
        }
        return contact
    }
}

extension PKContact {
    var ctAddress: Address {
        return Address(firstName: name?.givenName, lastName: name?.familyName, streetName: postalAddress?.street, city: postalAddress?.city, postalCode: postalAddress?.postalCode, state: postalAddress?.state, country: postalAddress?.isoCountryCode ?? "", phone: phoneNumber?.stringValue, email: emailAddress)
    }
}

extension ShippingMethod {
    func matchingPrice(for totalCentAmount: Int) -> Money? {
        if let shippingRate = zoneRates.flatMap({ $0.shippingRates }).filter({ $0.isMatching == true }).first {
            let freeAbove = shippingRate.freeAbove?.centAmount ?? Int.max
            return totalCentAmount > freeAbove ? Money(currencyCode: shippingRate.price.currencyCode, centAmount: 0) : shippingRate.price
        }
        return nil
    }
}

struct Project {
    private static let kProjectConfig = "ProjectConfig"
    private static let kSuiteName = "group.com.commercetools.Sunrise"
    
    static var config: Config? {
        #if PROD
            let configPath = "CommercetoolsProdConfig"
        #else
            let configPath = "CommercetoolsStagingConfig"
        #endif
        
        if let storedConfig = UserDefaults(suiteName: kSuiteName)?.dictionary(forKey: kProjectConfig), let configuration = Config(config: storedConfig as NSDictionary) {
            return configuration
        } else if let configuration = Config(path: configPath) {
            return configuration
        }
        return nil
    }
    
    static func update(config: NSDictionary) {
        UserDefaults(suiteName: kSuiteName)?.set(config, forKey: kProjectConfig)
        UserDefaults(suiteName: kSuiteName)?.synchronize()
    }
}

extension Customer {
    static var currentCountry: String?
    static var currentCurrency: String?
    static var customerGroup: Reference<CustomerGroup>?
}

extension Collection where Iterator.Element == URLQueryItem {
    subscript(key: String) -> [String] {
        return self.filter({ $0.name == key }).compactMap { $0.value }
    }
}