# Commercetools Sunrise iOS watchOS :sunrise:

[![][travis img]][travis]
[![][license img]][license]
[![][demo img]][demo]

The mobile shop template using the latest version of [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk), and providing you with the best and quickest way to get up and running with the commercetools platform.

## Getting started

### Demo

If you want to try out Sunrise without building the project, you can use the following link to get the latest TestFlight build on your iPhone / Apple Watch: https://testflight.apple.com/join/pzpGWTe2

### Requirements

- iOS 11.0+ / watchOS 4.0+
- Xcode 11+
- Swift 5.0

### Installing CocoaPods Dependencies

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.8.4+ is required to build the latest Sunrise project.

Then, run the following command:

```bash
$ pod install
```

### Commercetools Project Configuration

Sunrise is a mobile shop template that relies on the commercetools platform, and the first step after successfully installing and being able to build the project is to configure [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk) with your project key and credentials, as well as other SDK specific settings (e.g `anonymousSession`, `keychainAccessGroupName`, `shareWatchSession`, desired logging level, etc).

You can optionally decide to have multiple environments (staging, qa, production), and this project provides a good example on how to make this work.

## Mobile Shop Template Features

The main goal of this project is to provide you with the best practices on how to utilize the [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk) along with current iOS trends, and quickly start with your own mobile shop. We are constantly working on adding new features, and you can always check the status by looking at the project's [Waffle board](https://waffle.io/commercetools/commercetools-sunrise-ios).

This is the list of features you can find in the current version of the Sunrise app:
- Category / Products overview: a customer can browse for categories and products on the overview screen, and navigate to product details.
- Product details: all product related details.
- Click 'n' collect / reserve in store: from the product details, a customer can reserve an item to be picked up from one of the stores selected on the score selection screen.
- Carts: products can be added to the cart from the details page, and managed on the cart tab (delete items, change quantity, etc).
- Wishlist: products can be saved from overview and details pages, and managed from the wishlist tab (remove items, get details, etc).
- Search: textual search, voice search, with results presented on the product overview screen.
- My account:
  - Login and registration screen in case the customer has not previously logged in.
  - Orders and reservations overview, when the customer is logged in.
  - My style can be defined for authenticated customer, and it is automatically applied while browsing products.
  - Address book is used to store customer's shipping and billing addresses, which can be used during checkout.
  - Map view with stores and associated information, search, and option to choose a default store.
  - Change password, notification and location permissions settings.

## Siri Shortcuts

Sunrise has Siri Shortcuts integration for reordering items. In order to create your shortcut, navigate to _My Account_ tab, and select a specific order from _My Orders_ screen. Order details contains _Add to Siri_ button you can use to create a shortcut.

![siri-shortcuts](https://user-images.githubusercontent.com/14024032/54280662-45ce3c00-4598-11e9-9ae6-4825829a2785.png)

## Apple Pay

One of the checkout options Sunrise app offers is Apple Pay. The project provides an example on how to implement it, and how models from [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk) map to `PassKit` objects.

![apple-pay](https://user-images.githubusercontent.com/14024032/54283647-bd9f6500-459e-11e9-8013-7738e7e85216.png)

## Push Notifications

Another important aspect of a mobile shop template is the ability to receive notifications important to the customer. Sunrise iOS project provides an example on how to implement a notification that is triggered when a customer reserves an item to be picked up in a store.

### Storing Customer Tokens

In order to be able to deliver a notification to the customer's device, you first need to save the push token somewhere. There are many possible scenarios, and the approach used in Sunrise project is simply storing it in a [Customer](http://dev.commercetools.com/http-api-projects-customers.html#customer)'s [custom field](http://dev.commercetools.com/http-api-projects-custom-fields.html#customfields).

### Triggers

Depending on the business case, you might want to trigger customer notifications based on a certain event or change that occurred on the e-commerce platform. The best way to accomplish that is to [subscribe](http://dev.commercetools.com/http-api-projects-subscriptions.html) to one or more [messages](http://dev.commercetools.com/http-api-projects-messages.html) provided by the Commercetools platform.

### Delivering Notifications

Sunrise uses serverless push notification solution. We have prepared both [IronWorker](https://www.iron.io/platform/ironworker/) and [AWS Lambda](https://aws.amazon.com/lambda/) functions, which work when triggered from [IronMQ](https://www.iron.io/platform/ironmq/) or [AWS SNS](https://aws.amazon.com/sns/) respectively, for messages delivered using the commercetools platform subscription.
- [IronWorker example](https://github.com/nikola-mladenovic/notification-service-iron-worker)
- [AWS Lambda function example](https://github.com/nikola-mladenovic/notification-service-aws-lambda)

### Rich Content Notifications (Notification Content Extension)

Sunrise provides an example on how to use keychain access group to share the same customer access tokens between the main iOS app, and a notification content extension (although, the same goes for any kind of iOS extension).
Notification delivery methods from the examples above prepare the payload with the proper `category` value, and includes additional information needed to load the rich content.

#### Reservation Confirmation Notification

Triggered on `OrderCreated` message. Function for delivering the notification retrieves the `apnsToken` from the customer's custom field, for the `customerId` specified in the `OrderCreated` message payload.

![phone notification](https://cloud.githubusercontent.com/assets/14024032/22203139/dbb949c8-e16b-11e6-8088-09258ace2fbe.png)

![watch notification](https://cloud.githubusercontent.com/assets/14024032/22203151/f321d4ea-e16b-11e6-8454-29189681ea94.png)

[travis]:https://travis-ci.org/commercetools/commercetools-ios-sdk
[travis img]:https://travis-ci.org/commercetools/commercetools-ios-sdk.svg?branch=master

[license]:LICENSE
[license img]:https://img.shields.io/badge/License-Apache%202-blue.svg

[demo]:https://testflight.apple.com/join/pzpGWTe2
[demo img]:https://img.shields.io/badge/Demo-TestFlight-blue.svg