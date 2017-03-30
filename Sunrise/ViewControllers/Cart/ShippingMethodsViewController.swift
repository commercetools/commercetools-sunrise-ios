//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class ShippingMethodsViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray

    @IBOutlet weak var tableView: UITableView!

    var viewModel: ShippingMethodsViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private let refreshControl = UIRefreshControl()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = ShippingMethodsViewModel()
        tableView.layer.borderColor = borderColor.cgColor
        tableView.tableFooterView = UIView()

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }

    func bindViewModel() {
        guard let viewModel = viewModel else { return }

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] isLoading in
            if isLoading {
                self?.refreshControl.beginRefreshing()
            } else {
                self?.refreshControl.endRefreshing()
                self?.tableView.reloadData()
            }
        }

        disposables += viewModel.performSegueSignal.observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.performSegue(withIdentifier: "showPayment", sender: self)
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    @objc private func refresh() {
        viewModel?.refreshObserver.send(value: ())
    }
}

extension ShippingMethodsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows(in: section) ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }
        let addressCell = tableView.dequeueReusableCell(withIdentifier: "ShippingMethodCell") as! ShippingMethodCell

        addressCell.nameAndDescriptionLabel.text = viewModel.nameAndDescription(at: indexPath)
        addressCell.priceLabel.text = viewModel.price(at: indexPath)

        return addressCell
    }
}

extension ShippingMethodsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedIndexPathObserver.send(value: indexPath)
    }
}
