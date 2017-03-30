//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import SVProgressHUD

class CategoriesViewController: UIViewController {
        
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var rootCategoriesStackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!

    private var rootCategorySeparatorImage: UIImageView {
        let imageView = UIImageView(image: UIImage(named: "category-separator"))
        imageView.contentMode = .center
        return imageView
    }

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: CategoriesViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = CategoriesViewModel()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 72
        tableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.title = viewModel?.title
    }

    func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { isLoading in
            isLoading ? SVProgressHUD.show() : SVProgressHUD.dismiss()
        }

        viewModel.rootCategoryNames.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] categoryNames in
            UIView.animate(withDuration: 0.2, animations: {
                self?.rootCategoriesStackView.alpha = 0
            }, completion: { _ in
                self?.populateRootCategories(with: categoryNames)
                UIView.animate(withDuration: 0.2) {
                    viewModel.activeRootCategoryName.value = viewModel.activeRootCategoryName.value
                    self?.rootCategoriesStackView.alpha = 1
                }
            })
        })

        viewModel.backgroundImage.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] backgroundImage in
            guard let backgroundImage = backgroundImage else { return }
            let transition = CATransition()
            transition.duration = 0.5
            transition.type = kCATransitionFade
            self?.backgroundImage.layer.add(transition, forKey: nil)
            self?.backgroundImage.image = backgroundImage
        })

        viewModel.activeRootCategoryName.combinePrevious(nil).signal
        .observe(on: UIScheduler())
        .observeValues { [weak self] previous, current in
            self?.changeRootCategory(from: previous, to: current)
        }

        disposables += viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .fade)
            tableView.reloadRows(at: changeset.modifications, with: .fade)
            tableView.insertRows(at: changeset.insertions, with: .fade)
            tableView.endUpdates()
        })

        disposables += viewModel.performProductOverviewSegueSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] indexPath in
            self?.performSegue(withIdentifier: "showProductOverview", sender: indexPath)
        })

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let indexPath = sender as? IndexPath, let productOverviewViewController = segue.destination as? ProductOverviewViewController, let viewModel = viewModel {
           let productOverviewViewModel = viewModel.productOverviewViewModelForCategory(at: indexPath)
            productOverviewViewController.viewModel = productOverviewViewModel
            navigationItem.title = ""
        }
    }

    // MARK: - Buttons for root categories

    private func populateRootCategories(with names: [String?]) {
        rootCategoriesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        names.forEach { categoryName in
            rootCategoriesStackView.addArrangedSubview(createRootCategoryButton(with: categoryName))
            rootCategoriesStackView.addArrangedSubview(rootCategorySeparatorImage)
        }
        rootCategoriesStackView.arrangedSubviews.last?.removeFromSuperview()
    }

    private func changeRootCategory(from previous: String?, to current: String?) {
        let previouslyActiveButton = getRootCategoryButton(with: previous)
        let currentlyActiveButton = getRootCategoryButton(with: current)

        previouslyActiveButton?.setTitleColor(UIColor.white, for: .normal)
        previouslyActiveButton?.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        currentlyActiveButton?.setTitleColor(UIColor(red:0.99, green:0.73, blue:0.25, alpha:1.0), for: .normal)
        currentlyActiveButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }

    private func createRootCategoryButton(with text: String?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(text, for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        if let viewModel = viewModel {
            button.reactive.pressed = CocoaAction(viewModel.selectRootCategoryAction) { _ in return text ?? "" }
        }
        return button
    }

    private func getRootCategoryButton(with text: String?) -> UIButton? {
        return rootCategoriesStackView.arrangedSubviews.filter {
            if let button = $0 as? UIButton {
                return button.title(for: .normal) == text
            }
            return false
        }.first as? UIButton
    }
}

extension CategoriesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }
        let categoryCell = tableView.dequeueReusableCell(withIdentifier: viewModel.cellType(at: indexPath) == .smallCategory ? "SmallCategoryCell" : "BigCategoryCell") as! CategoryCell
        if viewModel.cellType(at: indexPath) == .bigCategory {
            categoryCell.separatorView?.alpha = viewModel.cellRepresentsCollapsibleTitle(at: indexPath) ? 0 : 1
            categoryCell.closeArrowImageView?.alpha = viewModel.cellRepresentsCollapsibleTitle(at: indexPath) ? 1 : 0
        }
        categoryCell.categoryName.text = viewModel.categoryName(at: indexPath)

        return categoryCell
    }
}

extension CategoriesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedRowObserver.send(value: indexPath)
    }
}
