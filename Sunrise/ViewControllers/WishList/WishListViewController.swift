//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class WishListViewController: UIViewController {

    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    private let gradientLayer = CAGradientLayer()

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: WishListViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()

        viewModel = WishListViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard gradientView.layer.sublayers?.isEmpty != false else { return }
        gradientLayer.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .automatic)
            tableView.reloadRows(at: changeset.modifications, with: .none)
            tableView.insertRows(at: changeset.insertions, with: .automatic)
            tableView.endUpdates()

            tableView.alpha = self?.viewModel?.numberOfLineItems == 0 ? 0 : 1
        }

        disposables += AppRouting.cartViewController?.viewModel?.addToCartAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            guard self?.view.window != nil else { return }
            SVProgressHUD.dismiss()
            switch event {
                case .completed:
                    AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
                    self?.presentAfterAddingToCartOptions()
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: self?.viewModel?.couldNotAddToCartTitle,
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
            }
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
        viewModel.refreshObserver.send(value: ())
    }

    @IBAction func continueShopping(_ sender: UIButton) {
        AppRouting.showMainTab()
    }

    private func presentAfterAddingToCartOptions() {
        let alertController = UIAlertController(
                title: viewModel?.addToCartSuccessTitle,
                message: viewModel?.addToCartSuccessMessage,
                preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: viewModel?.continueTitle, style: .default, handler: { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        }))
        alertController.addAction(UIAlertAction(title: viewModel?.cartOverviewTitle, style: .default, handler: { [weak self] _ in
            AppRouting.switchToCartTab()
            self?.navigationController?.popToRootViewController(animated: false)
        }))
        present(alertController, animated: true, completion: nil)
    }
}

extension WishListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfLineItems ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WishListCell") as! WishListCell
        guard let viewModel = viewModel else { return cell }
        cell.productNameLabel.text = viewModel.lineItemName(at: indexPath)
        cell.priceLabel.text = viewModel.lineItemPrice(at: indexPath)
        cell.priceLabel.textColor = viewModel.lineItemOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
        let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 12)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
        cell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.lineItemOldPrice(at: indexPath), attributes: oldPriceAttributes)
        cell.productImageView.sd_setImage(with: URL(string: viewModel.lineItemImageUrl(at: indexPath)), placeholderImage: UIImage(named: "transparent"))
        disposables += cell.addToBagButton.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.addToBagObserver.send(value: indexPath) }
        disposables += cell.wishListButton.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.deleteObserver.send(value: indexPath) }
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel?.deleteObserver.send(value: indexPath)
        }
    }
}

extension WishListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sku = viewModel?.lineItemSku(at: indexPath) else { return }
        AppRouting.showProductDetails(sku: sku)
    }
}