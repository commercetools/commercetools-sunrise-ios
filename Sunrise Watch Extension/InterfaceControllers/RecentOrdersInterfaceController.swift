//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class RecentOrdersInterfaceController: WKInterfaceController {
    
    @IBOutlet var listGroup: WKInterfaceGroup!
    @IBOutlet var listTable: WKInterfaceTable!
    
    @IBOutlet var loadingGroup: WKInterfaceGroup!
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var emptyStateLabel: WKInterfaceLabel!
    @IBOutlet var loadMoreButton: WKInterfaceButton!
    
    private let disposables = CompositeDisposable()
    
    private var interfaceModel: RecentOrdersInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }
    
    deinit {
        disposables.dispose()
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        listGroup.setRelativeHeight(1, withAdjustment: 0)
        interfaceModel = RecentOrdersInterfaceModel()
    }

    override func didAppear() {
        super.didAppear()
        invalidateUserActivity()
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        return interfaceModel?.orderDetailsInterfaceModel(for: rowIndex)
    }
    
    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }
        
        disposables += interfaceModel.isLoading.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues { [weak self] isLoading in
            self?.animate(withDuration: 0.3) {
                self?.loadingGroup.setAlpha(0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.loadingGroup.setHidden(!isLoading)
                self?.animate(withDuration: 0.3) {
                    self?.loadingGroup.setAlpha(isLoading ? 1 : 0)
                }
                if isLoading {
                    self?.loadingImage.startAnimating()
                } else {
                    self?.loadingImage.stopAnimating()
                }
            }
        }
        
        disposables += interfaceModel.isLoadMoreHidden.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.loadMoreButton.setHidden($0)
        }
        
        disposables += interfaceModel.numberOfRows.producer
        .skip(first: 1)
        .observe(on: UIScheduler())
        .startWithValues { [weak self] numberOfRows in
            self?.loadMoreButton.setHidden(self?.interfaceModel?.isLoadMoreHidden.value ?? true)
            self?.listTable.setNumberOfRows(numberOfRows, withRowType: OrderItemRowController.identifier)
            if numberOfRows > 0 {
                self?.listGroup.sizeToFitHeight()
                self?.loadingGroup.setVerticalAlignment(.top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.animate(withDuration: 0.3) {
                    self?.emptyStateLabel.setAlpha(numberOfRows == 0 ? 1 : 0)
                }
            }
            guard let interfaceModel = self?.interfaceModel, numberOfRows > 0 else { return }
            (0...numberOfRows - 1).forEach { row in
                if let rowController = self?.listTable.rowController(at: row) as? OrderItemRowController {
                    rowController.orderStatusLabel.setAttributedText(interfaceModel.orderStatus(at: row))
                    rowController.itemsLabel.setText(interfaceModel.items(at: row))
                    rowController.orderDescriptionLabel.setAttributedText(interfaceModel.orderDescription(at: row))
                    rowController.orderTotalLabel.setText(interfaceModel.orderTotal(at: row))
                }
            }
        }
    }
    
    @IBAction func loadMore() {
        interfaceModel?.loadMoreObserver.send(value: ())
        animate(withDuration: 0.3) {
            self.loadMoreButton.setAlpha(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loadMoreButton.setHidden(true)
                self.loadMoreButton.setAlpha(1)
            }
        }
    }
}
