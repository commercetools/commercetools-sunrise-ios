# Commercetools Sunrise iOS :sunrise:

[![][travis img]][travis]
[![][license img]][license]
[![Stories in Ready](https://badge.waffle.io/commercetools/commercetools-sunrise-ios.svg?label=ready&title=Ready)](http://waffle.io/commercetools/commercetools-sunrise-ios)

The mobile shop template using the latest version of [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk), and providing you with the best and quickest way to get up and running with the Commercetools platform.

## Getting started

### Requirements

- iOS 10.0+ / watchOS 3.0+
- Xcode 8.1+
- Swift 3.0+

### Installing CocoaPods Dependencies

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1.0+ is required to build the latest Sunrise project.

Then, run the following command:

```bash
$ pod install
```

### Commercetools Project Configuration

Sunrise is a mobile shop template that relies on the Commercetools platform, and the first step after successfully installing and being able to build the project is to configure [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk) with your project key and credentials, as well as other SDK specific settings (e.g `anonymousSession`, `keychainAccessGroupName`, `shareWatchSession`, desired logging level, etc).

You can optionally decide to have multiple environments (staging, qa, production), and this project provides a good example on how to make this work.

## Mobile Shop Template Features

The main goal of this project is to provide you with the best practices on how to utilize [Commercetools SDK](https://github.com/commercetools/commercetools-ios-sdk) along with current iOS trends, and quickly start with your own mobile shop. We are constantly working on adding new features, and you can always check the status by looking at the project's [Waffle board](https://waffle.io/commercetools/commercetools-sunrise-ios).

This is the list of features you can find in the current version of the Sunrise app:
- Products overview: customer can browse for products on the overview screen, and navigate to product details. Optionally for authenticated customer, Sunrise provides the ability to customize products overview experience, by choosing whether to browse entire online inventory, or just the products which are in stock in your favorite store.
- Product details: all product related details, customized depending on selected preference on the overview screen.
- Click 'n' collect: from the product details, customer can reserve an item to be picked up from one of the stores selected on the score selection screen.
- Carts: products can be added to cart from the details page, and managed on the cart tab (delete items, change quantity, etc).
- Search: textual search, with results presented on the product overview screen.
- My account:
  - Login and registration screen in case the customer has not previously logged in.
  - Orders and reservations overview, when the customer is logged in. Customer's preferred store can also be seen under my preferences section, and changed from the subsequent screens containing map and list view of the available stores.

## Push Notifications

Another important aspect of a mobile shop template is the ability to receive notifications important to the customer. Sunrise iOS project provides an example on how to implement a notification that is triggered when a customer reserves an item to be picked up in a store.

### Storing Customer Tokens

In order to be able to deliver a notification to the customer's device, you first need to save the push token somewhere. There are many possible scenarios, and the approach used in Sunrise project is simply storing it in a [Customer](http://dev.commercetools.com/http-api-projects-customers.html#customer)'s [custom field](http://dev.commercetools.com/http-api-projects-custom-fields.html#customfields).

### Triggers

Depending on the business case, you might want to trigger customer notifications based on a certain event or change that occurred on the e-commerce platform. The best way to accomplish that is to [subscribe](http://dev.commercetools.com/http-api-projects-subscriptions.html) to one or more [messages](http://dev.commercetools.com/http-api-projects-messages.html) provided by the Commercetools platform.

### Delivering Notifications

Sunrise uses serverless push notification solution. We have prepared both [IronWorker](https://www.iron.io/platform/ironworker/) and [AWS Lambda](https://aws.amazon.com/lambda/) function, which work when triggered from [IronMQ](https://www.iron.io/platform/ironmq/) or [AWS SNS](https://aws.amazon.com/sns/) respectively, for messages delivered using the Commercetools platform subscription.
- [IronWorker example](https://github.com/nikola-mladenovic/notification-service-iron-worker)
- [AWS Lambda function example](https://github.com/nikola-mladenovic/notification-service-aws-lambda)

### Rich Content Notifications (Notification Content Extension)

Sunrise provides an example on how to use keychain access group to share the same customer access tokens between the main iOS app, and a notification content extension (although, the same goes for any kind of iOS extension).
Notification delivery methods from the examples above prepare the payload with the proper `category` value, and includes additional information needed to load the rich content.

#### Reservation Confirmation Notification

Triggered on `OrderCreated` message. Function for delivering the notification retrieves the `apnsToken` from the customer's custom field, for the `customerId` specified in the `OrderCreated` message payload.

![phone notification](https://cloud.githubusercontent.com/assets/14024032/22203139/dbb949c8-e16b-11e6-8088-09258ace2fbe.png)

![watch notificaiton](https://cloud.githubusercontent.com/assets/14024032/22203151/f321d4ea-e16b-11e6-8454-29189681ea94.png)

[](definitions for the top badges)

[travis]:https://travis-ci.org/commercetools/commercetools-ios-sdk
[travis img]:https://travis-ci.org/commercetools/commercetools-ios-sdk.svg?branch=master

[license]:LICENSE
[license img]:https://img.shields.io/badge/License-Apache%202-blue.svg
