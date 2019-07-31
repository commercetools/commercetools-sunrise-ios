//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Intents
import Commercetools

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is OrderProductIntent:
            return OrderProductIntentHandler()
        case is ReserveProductIntent:
            return ReserveProductIntentHandler()
        default:
            fatalError("Unhandled intent type: \(intent)")
        }
    }
    
}

class OrderProductIntentHandler: NSObject, OrderProductIntentHandling {
    
    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
    }
    
    func confirm(intent: OrderProductIntent, completion: @escaping (OrderProductIntentResponse) -> Void) {
        guard Commercetools.config?.validate() == true, let previousOrderId = intent.previousOrderId else {
            completion(OrderProductIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        guard Commercetools.authState == .customerToken else {
            completion(OrderProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
            return
        }
        
        Order.byId(previousOrderId) { result in
            guard result.isSuccess else {
                completion(OrderProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
                return
            }
            completion(OrderProductIntentResponse(code: .ready, userActivity: nil))
        }
    }
    
    func handle(intent: OrderProductIntent, completion: @escaping (OrderProductIntentResponse) -> Void) {
        guard Commercetools.config?.validate() == true, let previousOrderId = intent.previousOrderId else {
            completion(OrderProductIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Order.byId(previousOrderId) { result in
            guard let previousOrder = result.model, result.isSuccess else {
                completion(OrderProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
                return
            }
            
            previousOrder.createReorderCart { cart in
                guard let cart = cart, result.isSuccess else {
                    completion(OrderProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
                    return
                }
                Order.create(OrderDraft(id: cart.id, version: cart.version)) { result in
                    if result.isSuccess {
                        completion(OrderProductIntentResponse(code: .success, userActivity: nil))
                    } else {
                        completion(OrderProductIntentResponse(code: .failure, userActivity: nil))
                    }
                }
            }
        }
    }
}

class ReserveProductIntentHandler: NSObject, ReserveProductIntentHandling {

    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
    }

    func confirm(intent: ReserveProductIntent, completion: @escaping (ReserveProductIntentResponse) -> Void) {
        guard Commercetools.config?.validate() == true, let previousReservationId = intent.previousReservationId else {
            completion(ReserveProductIntentResponse(code: .failure, userActivity: nil))
            return
        }

        guard Commercetools.authState == .customerToken else {
            completion(ReserveProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
            return
        }

        Order.byId(previousReservationId) { result in
            guard result.isSuccess else {
                completion(ReserveProductIntentResponse(code: .failureNotLoggedIn, userActivity: nil))
                return
            }
            completion(ReserveProductIntentResponse(code: .ready, userActivity: nil))
        }
    }

    func handle(intent: ReserveProductIntent, completion: @escaping (ReserveProductIntentResponse) -> Void) {
        guard Commercetools.config?.validate() == true, let previousReservationId = intent.previousReservationId else {
            completion(ReserveProductIntentResponse(code: .failure, userActivity: nil))
            return
        }

        Order.byId(previousReservationId, expansion: ["lineItems[0].distributionChannel"]) { result in
            guard let previousReservation = result.model, let product = previousReservation.lineItems.first, let sku = product.variant.sku, let store = product.distributionChannel?.obj, result.isSuccess else {
                completion(ReserveProductIntentResponse(code: .failure, userActivity: nil))
                return
            }

            Order.reserveProduct(sku: sku, in: store).startWithResult {
                if case .failure(_) = $0 {
                    completion(ReserveProductIntentResponse(code: .failure, userActivity: nil))
                } else {
                    completion(ReserveProductIntentResponse(code: .success, userActivity: nil))
                }
            }
        }
    }
}
