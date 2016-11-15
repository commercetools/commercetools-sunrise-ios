//  This file was automatically generated and should not be edited.

import Apollo

public final class ProductOverviewQuery: GraphQLQuery {
  public static let operationDefinition =
    "query ProductOverview($pageSize: Int, $offset: Int) {" +
    "  products(sort: \"createdAt desc\", limit: $pageSize, offset: $offset) {" +
    "    results {" +
    "      masterData {" +
    "        current {" +
    "          masterVariant {" +
    "            ...VariantDetails" +
    "          }" +
    "          variants {" +
    "            ...VariantDetails" +
    "          }" +
    "          name(locale: \"en\")" +
    "        }" +
    "      }" +
    "    }" +
    "  }" +
    "}"
  public static let queryDocument = operationDefinition.appending(VariantDetails.fragmentDefinition).appending(PriceDetails.fragmentDefinition).appending(MoneyDetails.fragmentDefinition)

  public let pageSize: Int?
  public let offset: Int?

  public init(pageSize: Int? = nil, offset: Int? = nil) {
    self.pageSize = pageSize
    self.offset = offset
  }

  public var variables: GraphQLMap? {
    return ["pageSize": pageSize, "offset": offset]
  }

  public struct Data: GraphQLMapDecodable {
    public let products: Product

    public init(map: GraphQLMap) throws {
      products = try map.value(forKey: "products")
    }

    public struct Product: GraphQLMapDecodable {
      public let __typename = "ProductQueryResult"
      public let results: [Result]

      public init(map: GraphQLMap) throws {
        results = try map.list(forKey: "results")
      }

      public struct Result: GraphQLMapDecodable {
        public let __typename = "Product"
        public let masterData: MasterDatum

        public init(map: GraphQLMap) throws {
          masterData = try map.value(forKey: "masterData")
        }

        public struct MasterDatum: GraphQLMapDecodable {
          public let __typename = "ProductCatalogData"
          public let current: Current

          public init(map: GraphQLMap) throws {
            current = try map.value(forKey: "current")
          }

          public struct Current: GraphQLMapDecodable {
            public let __typename = "ProductData"
            public let masterVariant: MasterVariant
            public let variants: [Variant]
            public let name: String?

            public init(map: GraphQLMap) throws {
              masterVariant = try map.value(forKey: "masterVariant")
              variants = try map.list(forKey: "variants")
              name = try map.optionalValue(forKey: "name")
            }

            public struct MasterVariant: GraphQLMapDecodable {
              public let __typename = "ProductVariant"

              public let fragments: Fragments

              public init(map: GraphQLMap) throws {
                let variantDetails = try VariantDetails(map: map)
                fragments = Fragments(variantDetails: variantDetails)
              }

              public struct Fragments {
                public let variantDetails: VariantDetails
              }
            }

            public struct Variant: GraphQLMapDecodable {
              public let __typename = "ProductVariant"

              public let fragments: Fragments

              public init(map: GraphQLMap) throws {
                let variantDetails = try VariantDetails(map: map)
                fragments = Fragments(variantDetails: variantDetails)
              }

              public struct Fragments {
                public let variantDetails: VariantDetails
              }
            }
          }
        }
      }
    }
  }
}

public struct VariantDetails: GraphQLNamedFragment {
  public static let fragmentDefinition =
    "fragment VariantDetails on ProductVariant {" +
    "  prices {" +
    "    ...PriceDetails" +
    "  }" +
    "}"

  public static let possibleTypes = ["ProductVariant"]

  public let __typename = "ProductVariant"
  public let prices: [Price]?

  public init(map: GraphQLMap) throws {
    prices = try map.list(forKey: "prices")
  }

  public struct Price: GraphQLMapDecodable {
    public let __typename = "ProductPrice"

    public let fragments: Fragments

    public init(map: GraphQLMap) throws {
      let priceDetails = try PriceDetails(map: map)
      fragments = Fragments(priceDetails: priceDetails)
    }

    public struct Fragments {
      public let priceDetails: PriceDetails
    }
  }
}

public struct MoneyDetails: GraphQLNamedFragment {
  public static let fragmentDefinition =
    "fragment MoneyDetails on Money {" +
    "  currencyCode" +
    "  centAmount" +
    "}"

  public static let possibleTypes = ["Money"]

  public let __typename = "Money"
  public let currencyCode: String
  public let centAmount: Int

  public init(map: GraphQLMap) throws {
    currencyCode = try map.value(forKey: "currencyCode")
    centAmount = try map.value(forKey: "centAmount")
  }
}

public struct PriceDetails: GraphQLNamedFragment {
  public static let fragmentDefinition =
    "fragment PriceDetails on ProductPrice {" +
    "  value {" +
    "    ...MoneyDetails" +
    "  }" +
    "  country" +
    "  customerGroup {" +
    "    typeId" +
    "  }" +
    "  channel {" +
    "    typeId" +
    "  }" +
    "  discounted {" +
    "    value {" +
    "      ...MoneyDetails" +
    "    }" +
    "  }" +
    "}"

  public static let possibleTypes = ["ProductPrice"]

  public let __typename = "ProductPrice"
  public let value: Value
  public let country: String?
  public let customerGroup: CustomerGroup?
  public let channel: Channel?
  public let discounted: Discounted?

  public init(map: GraphQLMap) throws {
    value = try map.value(forKey: "value")
    country = try map.optionalValue(forKey: "country")
    customerGroup = try map.optionalValue(forKey: "customerGroup")
    channel = try map.optionalValue(forKey: "channel")
    discounted = try map.optionalValue(forKey: "discounted")
  }

  public struct Value: GraphQLMapDecodable {
    public let __typename = "Money"

    public let fragments: Fragments

    public init(map: GraphQLMap) throws {
      let moneyDetails = try MoneyDetails(map: map)
      fragments = Fragments(moneyDetails: moneyDetails)
    }

    public struct Fragments {
      public let moneyDetails: MoneyDetails
    }
  }

  public struct CustomerGroup: GraphQLMapDecodable {
    public let __typename = "Reference"
    public let typeId: String

    public init(map: GraphQLMap) throws {
      typeId = try map.value(forKey: "typeId")
    }
  }

  public struct Channel: GraphQLMapDecodable {
    public let __typename = "Reference"
    public let typeId: String

    public init(map: GraphQLMap) throws {
      typeId = try map.value(forKey: "typeId")
    }
  }

  public struct Discounted: GraphQLMapDecodable {
    public let __typename = "DiscountedProductPriceValue"
    public let value: Value

    public init(map: GraphQLMap) throws {
      value = try map.value(forKey: "value")
    }

    public struct Value: GraphQLMapDecodable {
      public let __typename = "Money"

      public let fragments: Fragments

      public init(map: GraphQLMap) throws {
        let moneyDetails = try MoneyDetails(map: map)
        fragments = Fragments(moneyDetails: moneyDetails)
      }

      public struct Fragments {
        public let moneyDetails: MoneyDetails
      }
    }
  }
}