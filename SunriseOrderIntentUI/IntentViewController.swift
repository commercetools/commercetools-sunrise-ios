//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import IntentsUI
import ReactiveCocoa
import ReactiveSwift
import SDWebImage

class IntentViewController: UIViewController, INUIHostedViewControlling {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var headerView: UIView!
    
    @IBOutlet weak var numerOfItemsLabel: UILabel!
    @IBOutlet weak var orderTotalLabel: UILabel!
    
    private let disposables = CompositeDisposable()
    private static let kLineItemCellHeight = 198
    private var configureViewCompletion: ((Bool, Set<INParameter>, CGSize) -> Void)?
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: IntentViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableHeaderView = headerView
        
        viewModel = IntentViewModel()
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel else { return }
        
        disposables += numerOfItemsLabel.reactive.text <~ viewModel.numberOfRows.map { "\($0)" }
        disposables += orderTotalLabel.reactive.text <~ viewModel.orderTotal
        
        disposables += viewModel.numberOfRows.producer
        .filter { $0 > 0 }
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.tableView.reloadData()
            let width = self?.extensionContext?.hostedViewMaximumAllowedSize.width ?? 320
            self?.configureViewCompletion?(true, Set(), CGSize(width: width, height: CGFloat(IntentViewController.kLineItemCellHeight * $0 + 114)))
        }
        
        disposables += viewModel.errorSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.configureViewCompletion?(false, Set(), .zero)
        }
    }
        
    // MARK: - INUIHostedViewControlling

    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        guard let intent = interaction.intent as? OrderProductIntent, let previousOrderId = intent.previousOrderId else {
            completion(false, Set(), .zero)
            return
        }
        viewModel?.previousOrderIdObserver.send(value: previousOrderId)
        configureViewCompletion = completion
    }
    
    var desiredSize: CGSize {
        return self.extensionContext!.hostedViewMaximumAllowedSize
    }
    
}

extension IntentViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows.value ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lineItemCell = tableView.dequeueReusableCell(withIdentifier: "CartItemCell") as! CartLineItemCell
        guard let viewModel = viewModel else { return lineItemCell }
        
        lineItemCell.productNameLabel.text = viewModel.lineItemName(at: indexPath)
        lineItemCell.sizeLabel.text = viewModel.lineItemSize(at: indexPath)
        lineItemCell.colorView.backgroundColor = viewModel.lineItemColor(at: indexPath)
        lineItemCell.colorView.layer.borderWidth = viewModel.lineItemColor(at: indexPath) == .white ? 1 : 0
        lineItemCell.quantityLabel.text = viewModel.lineItemQuantity(at: indexPath)
        lineItemCell.priceLabel.text = viewModel.lineItemPrice(at: indexPath)
        lineItemCell.priceLabel.textColor = viewModel.lineItemOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
        lineItemCell.productImageView.sd_setImage(with: URL(string: viewModel.lineItemImageUrl(at: indexPath)), placeholderImage: UIImage(named: "transparent"))
        lineItemCell.oldAndActivePriceSpacingConstraint.constant = viewModel.lineItemOldPrice(at: indexPath).isEmpty ? 0 : 4
        let oldPriceAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Bold", size: 14)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
        lineItemCell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.lineItemOldPrice(at: indexPath), attributes: oldPriceAttributes)
        return lineItemCell
    }
}

extension IntentViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(IntentViewController.kLineItemCellHeight)
    }
}
