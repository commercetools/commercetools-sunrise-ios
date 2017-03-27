//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class AddressSelectionViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray
    
    @IBOutlet weak var tableView: UITableView!

    var viewModel: AddressSelectionViewModel? {
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

        viewModel = AddressSelectionViewModel()
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
            self?.performSegue(withIdentifier: "showShippingMethods", sender: self)
        }

        observeAlertMessageSignal(viewModel: viewModel)
    }

    @objc private func refresh() {
        viewModel?.refreshObserver.send(value: ())
    }
}

extension AddressSelectionViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.numberOfSections ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows(in: section) ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel?.title(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }
        let addressCell = tableView.dequeueReusableCell(withIdentifier: viewModel.cellType(at: indexPath) == .addNew ? "AddAddressCell" : "AddressCell") as! AddressCell

        if viewModel.cellType(at: indexPath) == .addNew {
            addressCell.hasBorder = true
            addressCell.hasBackgroundColor = false
        } else {
            addressCell.titleLabel?.text = viewModel.title(at: indexPath)
            addressCell.firstNameLabel?.text = viewModel.firstName(at: indexPath)
            addressCell.lastNameLabel?.text = viewModel.lastName(at: indexPath)
            addressCell.streetNameLabel?.text = viewModel.streetName(at: indexPath)
            addressCell.cityLabel?.text = viewModel.city(at: indexPath)
            addressCell.postalCodeLabel?.text = viewModel.postalCode(at: indexPath)
            addressCell.regionLabel?.text = viewModel.region(at: indexPath)
            addressCell.countryLabel?.text = viewModel.country(at: indexPath)
            addressCell.hasBorder = !viewModel.isDefault(at: indexPath)
            addressCell.hasBackgroundColor = viewModel.isDefault(at: indexPath)
        }

        return addressCell
    }
}

extension AddressSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedIndexPathObserver.send(value: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.systemFont(ofSize: 16)
        headerView.textLabel?.textColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
    }
}
