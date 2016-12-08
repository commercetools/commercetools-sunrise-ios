//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage
import NKWatchActivityIndicator

class ReservationsInterfaceController: WKInterfaceController {
    
    @IBOutlet var signInGroup: WKInterfaceGroup!
    @IBOutlet var reservationsGroup: WKInterfaceGroup!
    @IBOutlet var reservationsTable: WKInterfaceTable!
    
    @IBOutlet var loadingGroup: WKInterfaceGroup!
    @IBOutlet var leftLoadingDot: WKInterfaceImage!
    @IBOutlet var rightLoadingDot: WKInterfaceImage!
    
    private var activityAnimation: NKWActivityIndicatorAnimation?
    
    private var interfaceModel: ReservationsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        activityAnimation = NKWActivityIndicatorAnimation(type: .twoDotsAnimation, controller: self, images: [leftLoadingDot, rightLoadingDot])
        
        [signInGroup, reservationsGroup].forEach { $0.setAlpha(0) }
        [signInGroup, reservationsGroup].forEach { $0.setHidden(true) }
        
        interfaceModel = ReservationsInterfaceModel.sharedInstance
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        return interfaceModel?.reservationDetailsInterfaceModel(for: rowIndex)
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        interfaceModel.presentSignInMessage.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] presentSignIn in
            self?.animate(withDuration: 0.3) {
                self?.signInGroup.setAlpha(presentSignIn ? 1 : 0)
                if presentSignIn {
                    self?.reservationsGroup.setAlpha(0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.signInGroup.setHidden(!presentSignIn)
                if presentSignIn {
                    self?.reservationsGroup.setHidden(true)
                }
            }
        })

        interfaceModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            if isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.reservationsGroup.setHidden(false)
                }
            }
            self?.animate(withDuration: 0.3) {
                self?.reservationsGroup.setAlpha(isLoading ? 0 : 1)
            }
            self?.loadingGroup.setHidden(!isLoading)
            if isLoading {
                self?.activityAnimation?.startAnimating()
            } else {
                self?.activityAnimation?.stopAnimating()
            }
        })

        interfaceModel.presentReservationSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] interfaceModel in
            self?.presentController(withName: "ReservationDetailsInterfaceController", context: interfaceModel)
        })

        interfaceModel.numberOfRows.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] numberOfRows in
            self?.reservationsTable.setNumberOfRows(numberOfRows, withRowType: ReservationRowController.identifier)
            guard let interfaceModel = self?.interfaceModel, numberOfRows > 0 else { return }
            (0...numberOfRows - 1).forEach { row in
                if let rowController = self?.reservationsTable.rowController(at: row) as? ReservationRowController {
                    rowController.productName.setText(interfaceModel.reservationName(at: row))
                    rowController.productPrice.setText(interfaceModel.reservationPrice(at: row))
                    if let url = URL(string: interfaceModel.productImageUrl(at: row)) {
                        SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { image, _, _, _, _, _ in
                            if let image = image, let rowController = self?.reservationsTable.rowController(at: row) as? ReservationRowController {
                                rowController.productImage.setImage(image)
                            }
                        })
                    }
                }
            }
        })
    }
}
