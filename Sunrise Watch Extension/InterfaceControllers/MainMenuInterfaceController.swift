//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift

class MainMenuInterfaceController: WKInterfaceController {
    
    @IBOutlet var signInGroup: WKInterfaceGroup!
    @IBOutlet var mainMenuGroup: WKInterfaceGroup!
    @IBOutlet var loadingGroup: WKInterfaceGroup!
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var productsTable: WKInterfaceTable!
    
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
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        return interfaceModel?.detailsInterfaceModel(for: rowIndex, segueIdentifier: segueIdentifier)
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        disposables += interfaceModel.isSignInMessagePresent.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] presentSignIn in
            self?.animate(withDuration: 0.3) {
                self?.signInGroup.setAlpha(0)
                self?.mainMenuGroup.setAlpha(0)
                self?.loadingGroup.setAlpha(0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.signInGroup.setHidden(!presentSignIn)
                self?.mainMenuGroup.setHidden(presentSignIn)
                self?.loadingGroup.setHidden(true)
                self?.animate(withDuration: 0.3) {
                    self?.signInGroup.setAlpha(presentSignIn ? 1 : 0)
                    self?.mainMenuGroup.setAlpha(presentSignIn ? 0 : 1)
                }
            }
        })
        
        disposables += interfaceModel.isLoading.signal
        .skipRepeats()
        .observe(on: UIScheduler())
        .observeValues { [weak self] isLoading in
            self?.animate(withDuration: 0.3) {
                [self?.mainMenuGroup, self?.loadingGroup].forEach { $0?.setAlpha(0) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.mainMenuGroup.setHidden(isLoading)
                self?.loadingGroup.setHidden(!isLoading)
                self?.animate(withDuration: 0.3) {
                    self?.mainMenuGroup.setAlpha(isLoading ? 0 : 1)
                    self?.loadingGroup.setAlpha(isLoading ? 1 : 0)
                }
                if isLoading {
                    self?.loadingImage.startAnimating()
                } else {
                    self?.loadingImage.stopAnimating()
                }
            }
        }
        
        disposables += interfaceModel.performProductSegueSignal
        .filter { $0.1 > 0 }
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.productsTable.setNumberOfRows($0.1, withRowType: $0.0.rowType)
            self?.productsTable.performSegue(forRow: 0)
        }
        
        disposables += interfaceModel.performProductSegueSignal
        .filter { $0.1 == 0 }
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.pushController(withName: $0.0.emptyStateInterfaceController, context: nil)
        }
        
        disposables += interfaceModel.presentProductDetailsSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.pushController(withName: "ProductDetailsInterfaceController", context: $0)
        }
        
        disposables += interfaceModel.presentOrderDetailsSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.pushController(withName: "OrderDetailsInterfaceController", context: $0)
        }
    }
    
    @IBAction func search() {
        presentTextInputController(withSuggestions: interfaceModel?.recentSearches.value, allowedInputMode: .plain) {
            guard let searchTerm = $0?.first as? String else { return }
            self.interfaceModel?.showProductOverviewObserver.send(value: .search(searchTerm))
        }
    }
    
    @IBAction func showNewProducts() {
        interfaceModel?.showProductOverviewObserver.send(value: .newProducts)
    }
    
    @IBAction func showOnSaleProducts() {
        interfaceModel?.showProductOverviewObserver.send(value: .onSale)
    }
    
    @IBAction func showWishList() {
        interfaceModel?.showProductOverviewObserver.send(value: .wishList)
    }
}
