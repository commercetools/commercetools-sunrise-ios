//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa

class InlineProductOverviewViewController: UIViewController {
    
    @IBOutlet weak var sectionTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var gradientView: UIView!

    private let gradientLayer = CAGradientLayer()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: InlineProductOverviewViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        gradientLayer.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.6).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        sectionTitle.text = viewModel.title

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [weak self] _ in self?.collectionView.reloadData() }

        disposables += reactive.trigger(for: #selector(viewWillAppear(_:)))
        .observeValues { [weak self] _ in
            self?.collectionView.reloadData()
            self?.viewModel?.refreshObserver.send(value: ())
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}

extension InlineProductOverviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel?.numberOfProducts(in: section) ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductOverviewCell
        guard let viewModel = viewModel else { return cell }
        cell.productNameLabel.text = viewModel.productName(at: indexPath)
        cell.productImageView.sd_setImage(with: URL(string: viewModel.productImageUrl(at: indexPath)))
        let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 12)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
        cell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.productOldPrice(at: indexPath), attributes: oldPriceAttributes)
        cell.priceLabel.text = viewModel.productPrice(at: indexPath)
        cell.priceLabel.textColor = viewModel.productOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
        cell.wishListButton.isSelected = viewModel.isProductInWishList(at: indexPath)
        disposables += cell.wishListButton.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in
            cell.wishListButton.isSelected = !cell.wishListButton.isSelected
            self?.viewModel?.toggleWishListObserver.send(value: indexPath)
        }
        return cell
    }
}

extension InlineProductOverviewViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sku = viewModel?.sku(at: indexPath) else { return }
        AppRouting.showProductDetails(sku: sku)
    }
}
