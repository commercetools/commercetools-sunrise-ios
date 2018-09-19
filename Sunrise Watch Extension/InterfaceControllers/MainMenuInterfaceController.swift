//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift

class MainMenuInterfaceController: WKInterfaceController {
    
    @IBOutlet var signInGroup: WKInterfaceGroup!
    @IBOutlet var mainMenuGroup: WKInterfaceGroup!
    
    private let disposables = CompositeDisposable()

    var interfaceModel: MainMenuInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        signInGroup.setAlpha(0)
        signInGroup.setHidden(true)
        
        interfaceModel = MainMenuInterfaceModel()
        invalidateUserActivity()
    }
    
    deinit {
        disposables.dispose()
    }

    override func contextForSegue(withIdentifier segueIdentifier: String) -> Any? {
        switch segueIdentifier {
            case "NewProducts":
                return ProductOverviewInterfaceModel(mainMenuInterfaceModel: interfaceModel, sort: ["createdAt desc"])
            case "OnSale":
                return ProductOverviewInterfaceModel(mainMenuInterfaceModel: interfaceModel, filterQuery: ["variants.prices.discounted:exists"])
            default:
                return nil
        }
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        disposables += interfaceModel.isSignInMessagePresent.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] presentSignIn in
            self?.animate(withDuration: 0.3) {
                self?.signInGroup.setAlpha(0)
                self?.mainMenuGroup.setAlpha(0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.signInGroup.setHidden(!presentSignIn)
                self?.mainMenuGroup.setHidden(presentSignIn)
                self?.animate(withDuration: 0.3) {
                    self?.signInGroup.setAlpha(presentSignIn ? 1 : 0)
                    self?.mainMenuGroup.setAlpha(presentSignIn ? 0 : 1)
                }
            }
        })
        
        disposables += interfaceModel.presentSearchResultsSignal
        .observeValues { [weak self] in
            self?.pushController(withName: "ProductOverviewInterfaceController", context: $0)
        }
    }
    
    @IBAction func search() {
        presentTextInputController(withSuggestions: interfaceModel?.recentSearches.value, allowedInputMode: .plain) {
            guard let searchTerm = $0?.first as? String else { return }
            self.interfaceModel?.performSearchObserver.send(value: searchTerm)
        }
    }
    
}
