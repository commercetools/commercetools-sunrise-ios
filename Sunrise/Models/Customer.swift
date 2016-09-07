//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Customer: Mappable {

    // MARK: - Properties

    var id: String?
    var version: UInt?
    var customerNumber: String?
    var createdAt: NSDate?
    var lastModifiedAt: NSDate?
    var email: String?
    var firstName: String?
    var lastName: String?
    var middleName: String?
    var title: String?
    var dateOfBirth: NSDate?
    var companyName: String?
    var vatId: String?
    var addresses: [Address]?
    var defaultShippingAddressId: String?
    var defaultBillingAddressId: String?
    var isEmailVerified: Bool?
    var externalId: String?
    var locale: String?

    // Customer address used when making a reservation
    var reservationAddress: Address {
        var address = addresses?.filter({ $0.id ==  defaultBillingAddressId }).first ?? Address()
        address.firstName = firstName
        address.lastName = lastName
        return address
    }

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id                         <- map["id"]
        version                    <- map["version"]
        customerNumber             <- map["customerNumber"]
        createdAt                  <- (map["createdAt"], ISO8601DateTransform())
        lastModifiedAt             <- (map["lastModifiedAt"], ISO8601DateTransform())
        email                      <- map["email"]
        firstName                  <- map["firstName"]
        lastName                   <- map["lastName"]
        middleName                 <- map["middleName"]
        title                      <- map["title"]
        dateOfBirth                <- (map["dateOfBirth"], ISO8601DateTransform())
        companyName                <- map["companyName"]
        vatId                      <- map["vatId"]
        addresses                  <- map["addresses"]
        defaultShippingAddressId   <- map["defaultShippingAddressId"]
        defaultBillingAddressId    <- map["defaultBillingAddressId"]
        isEmailVerified            <- map["isEmailVerified"]
        externalId                 <- map["externalId"]
        locale                     <- map["locale"]
    }

}