//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

class CreditCardStore: NSObject {

    /// A shared instance of `CreditCardStore`, which should be used by view models.
    static let sharedInstance = CreditCardStore()

    // MARK: - Properties

    private let secMatchLimit: String! = kSecMatchLimit as String
    private let secReturnData: String! = kSecReturnData as String
    private let secValueData: String! = kSecValueData as String
    private let secAttrAccessible: String! = kSecAttrAccessible as String
    private let secClass: String! = kSecClass as String
    private let secAttrService: String! = kSecAttrService as String
    private let secAttrGeneric: String! = kSecAttrGeneric as String
    private let secAttrAccount: String! = kSecAttrAccount as String

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    /// The key used for storing credit cards.
    private let creditCardsKey = "com.commercetools.Sunrise.creditCardsKey"

    /// The value for kSecAttrService property which uniquely identifies keychain accessor.
    private let kKeychainServiceName = "com.commercetools.Sunrise"

    /// The serial queue used for credit cards to keychain.
    private let serialQueue = DispatchQueue(label: "com.commercetools.Sunrise.creditCardsQueue", attributes: [])

    /// The auth token which should be included in all requests against Commercetools service.
    var creditCards: [CreditCard]! {
        didSet {
            // Keychain write operation can be expensive, and we can do it asynchronously.
            serialQueue.async(execute: {
                do {
                    try self.setObject(self.jsonEncoder.encode(self.creditCards) as NSCoding?, forKey: self.creditCardsKey)
                } catch {
                    debugPrint("Error while encoding credit cards array.")
                }
            })
        }
    }

    // MARK: - Lifecycle

    /**
     Initializes the `CreditCardStore` by loading previously stored credit cards in keychain.
     */
    override private init() {
        super.init()

        guard let creditCardsData = objectForKey(creditCardsKey) as? Data else {
            creditCards = []
            return
        }
        do {
            creditCards = try jsonDecoder.decode([CreditCard].self, from: creditCardsData)
        } catch {
            creditCards = []
            debugPrint("Error while decoding credit cards array.")
        }
    }


    // MARK: - Keychain access

    private func objectForKey(_ keyName: String) -> NSCoding? {
        guard let keychainData = dataForKey(keyName) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(with: keychainData) as? NSCoding
    }

    private func dataForKey(_ keyName: String) -> Data? {
        var keychainQuery = keychainQueryForKey(keyName)

        // Limit search results to one
        keychainQuery[secMatchLimit] = kSecMatchLimitOne

        // Specify we want NSData/CFData returned
        keychainQuery[secReturnData] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(keychainQuery as CFDictionary, UnsafeMutablePointer($0))
        }

        return status == noErr ? result as? Data : nil
    }

    private func setObject(_ value: NSCoding?, forKey keyName: String) {
        if let value = value {
            let data = NSKeyedArchiver.archivedData(withRootObject: value)
            setData(data, forKey: keyName)

        } else if let _ = objectForKey(keyName) {
            removeObjectForKey(keyName)
        }
    }

    private func removeObjectForKey(_ keyName: String) {
        let keychainQuery = keychainQueryForKey(keyName)

        let status: OSStatus =  SecItemDelete(keychainQuery as CFDictionary);
        if status != errSecSuccess {
            debugPrint("Error while deleting '\(keyName)' keychain entry.")
        }
    }

    private func setData(_ value: Data, forKey keyName: String) {
        var keychainQuery = keychainQueryForKey(keyName)

        keychainQuery[secValueData] = value as AnyObject?

        // Protect the keychain entry so it's only available after first device unlocked
        keychainQuery[secAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status: OSStatus = SecItemAdd(keychainQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            updateData(value, forKey: keyName)
        } else if status != errSecSuccess {
            debugPrint("Error while creating '\(keyName)' keychain entry.")
        }
    }

    private func updateData(_ value: Data, forKey keyName: String) {
        let keychainQuery = keychainQueryForKey(keyName)

        let status: OSStatus = SecItemUpdate(keychainQuery as CFDictionary, [secValueData: value] as CFDictionary)

        if status != errSecSuccess {
            debugPrint("Error while updating '\(keyName)' keychain entry.")
        }
    }

    private func keychainQueryForKey(_ key: String) -> [String: Any] {
        // Setup dictionary to access keychain and specify we are using a generic password (rather than a certificate, internet password, etc)
        var keychainQueryDictionary: [String: Any] = [secClass: kSecClassGenericPassword]

        // Uniquely identify this keychain accessor
        keychainQueryDictionary[secAttrService] = kKeychainServiceName

        // Uniquely identify the account who will be accessing the keychain
        let encodedIdentifier: Data? = key.data(using: String.Encoding.utf8)

        keychainQueryDictionary[secAttrGeneric] = encodedIdentifier
        keychainQueryDictionary[secAttrAccount] = encodedIdentifier

        return keychainQueryDictionary
    }
}