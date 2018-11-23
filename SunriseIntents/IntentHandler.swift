//
//  IntentHandler.swift
//  SunriseIntents
//
//  Created by Nikola Mladenovic on 11/21/18.
//  Copyright © 2018 Commercetools. All rights reserved.
//

import Intents
import Commercetools

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        guard intent is OrderProductIntent else {
            fatalError("Unhandled intent type: \(intent)")
        }
        return OrderProductIntentHandler()
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
