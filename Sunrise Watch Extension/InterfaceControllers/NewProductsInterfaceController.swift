//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage
import NKWatchActivityIndicator

class NewProductsInterfaceController: WKInterfaceController {

    @IBOutlet var productsGroup: WKInterfaceGroup!
    @IBOutlet var productsTable: WKInterfaceTable!
    
    @IBOutlet var loadingGroup: WKInterfaceGroup!
    @IBOutlet var leftLoadingDot: WKInterfaceImage!
    @IBOutlet var rightLoadingDot: WKInterfaceImage!

    private var activityAnimation: NKWActivityIndicatorAnimation?

    private var interfaceModel: NewProductsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        activityAnimation = NKWActivityIndicatorAnimation(type: .twoDotsAnimation, controller: self, images: [leftLoadingDot, rightLoadingDot])

        productsGroup.setAlpha(0)
        productsGroup.setHidden(true)

        interfaceModel = NewProductsInterfaceModel()
    }

    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        return interfaceModel?.productDetailsInterfaceModel(for: rowIndex)
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        interfaceModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            self?.animate(withDuration: 0.3) {
                [self?.productsGroup, self?.loadingGroup].forEach { $0?.setAlpha(0) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.productsGroup.setHidden(isLoading)
                self?.loadingGroup.setHidden(!isLoading)
                self?.animate(withDuration: 0.3) {
                    self?.productsGroup.setAlpha(isLoading ? 0 : 1)
                    self?.loadingGroup.setAlpha(isLoading ? 1 : 0)
                }
                if isLoading {
                    self?.activityAnimation?.startAnimating()
                } else {
                    self?.activityAnimation?.stopAnimating()
                }
            }
        })

        interfaceModel.numberOfRows.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] numberOfRows in
            self?.productsTable.setNumberOfRows(numberOfRows, withRowType: ProductRowController.identifier)
            guard let interfaceModel = self?.interfaceModel, numberOfRows > 0 else { return }
            (0...numberOfRows - 1).forEach { row in
                if let rowController = self?.productsTable.rowController(at: row) as? ProductRowController {
                    rowController.productName.setText(interfaceModel.productName(at: row))
                    rowController.productPrice.setText(interfaceModel.productPrice(at: row))
                    if let url = URL(string: interfaceModel.productImageUrl(at: row)) {
                        SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { image, _, _, _, _, _ in
                            if let image = image, let rowController = self?.productsTable.rowController(at: row) as? ProductRowController {
                                rowController.productImage.setImage(image)
                            }
                        })
                    }
                }
            }
        })
    }
}
