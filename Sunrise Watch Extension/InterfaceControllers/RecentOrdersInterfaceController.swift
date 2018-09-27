//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage
import NKWatchActivityIndicator

class RecentOrdersInterfaceController: WKInterfaceController {
    
    @IBOutlet var listGroup: WKInterfaceGroup!
    @IBOutlet var listTable: WKInterfaceTable!
    
    @IBOutlet var loadingGroup: WKInterfaceGroup!
    @IBOutlet var leftLoadingDot: WKInterfaceImage!
    @IBOutlet var rightLoadingDot: WKInterfaceImage!
    
    private let disposables = CompositeDisposable()
    private var activityAnimation: NKWActivityIndicatorAnimation?
    
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
        
        activityAnimation = NKWActivityIndicatorAnimation(type: .twoDotsAnimation, controller: self, images: [leftLoadingDot, rightLoadingDot])
        
        listGroup.setAlpha(0)
        listGroup.setHidden(true)
        
        interfaceModel = RecentOrdersInterfaceModel()
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        return interfaceModel?.orderDetailsInterfaceModel(for: rowIndex)
    }
    
    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }
        
        disposables += interfaceModel.isLoading.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            self?.animate(withDuration: 0.3) {
                [self?.listGroup, self?.loadingGroup].forEach { $0?.setAlpha(0) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.listGroup.setHidden(isLoading)
                self?.loadingGroup.setHidden(!isLoading)
                self?.animate(withDuration: 0.3) {
                    self?.listGroup.setAlpha(isLoading ? 0 : 1)
                    self?.loadingGroup.setAlpha(isLoading ? 1 : 0)
                }
                if isLoading {
                    self?.activityAnimation?.startAnimating()
                } else {
                    self?.activityAnimation?.stopAnimating()
                }
            }
        })
        
        disposables += interfaceModel.numberOfRows.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] numberOfRows in
            self?.listTable.setNumberOfRows(numberOfRows, withRowType: OrderItemRowController.identifier)
            guard let interfaceModel = self?.interfaceModel, numberOfRows > 0 else { return }
            (0...numberOfRows - 1).forEach { row in
                if let rowController = self?.listTable.rowController(at: row) as? OrderItemRowController {
                    rowController.orderNumberLabel.setText(interfaceModel.orderNumber(at: row))
                    rowController.orderDescriptionLabel.setText(interfaceModel.orderDescription(at: row))
                }
            }
        })
    }
}
