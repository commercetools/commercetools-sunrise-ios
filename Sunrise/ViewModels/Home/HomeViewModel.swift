//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

class HomeViewModel: BaseViewModel {

    enum HomeElement {
        case banner
        case inlinePOP
    }
    
    // Inputs
    let selectedElementObserver: Signal<IndexPath, NoError>.Observer
    
    // Outputs
    

    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    override init() {
        let (selectedElementSignal, selectedElementObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedElementObserver = selectedElementObserver

        super.init()

        disposables += selectedElementSignal
        .observe(on: UIScheduler())
        .observeValues {
            switch $0.row {
                case 0:
                    AppRouting.showCategory(id: "b8250c0d-a29e-42d5-8c11-97d7a98bb462")
                case 1:
                    AppRouting.showCategory(id: "96ac6204-4631-41d3-9540-22b7629f468d")
                case 3:
                    AppRouting.showProductOverview(with: ["variants.scopedPriceDiscounted:true"])
                default:
                    return
            }
        }
    }
    
    deinit {
        disposables.dispose()
    }

    func inlineProductOverviewViewModel(at indexPath: IndexPath) -> InlineProductOverviewViewModel? {
        if indexPath.row == 2 {
            return InlineProductOverviewViewModel(title: NSLocalizedString("New Products", comment: "New Products"), sort: ["createdAt desc"])
        }
        return nil
    }

    // MARK: - Data Source

    var numberOfElements: Int {
        return 4
    }

    func element(at indexPath: IndexPath) -> HomeElement {
        return [0, 1, 3].contains(indexPath.row) ? .banner : .inlinePOP
    }

    func bannerImage(at indexPath: IndexPath) -> UIImage? {
        switch indexPath.row {
            case 0:
                return #imageLiteral(resourceName: "summer_accessories_banner")
            case 1:
                return #imageLiteral(resourceName: "looks_we_love_banner")
            case 3:
                return #imageLiteral(resourceName: "on_sale_banner")
            default:
                return nil
        }
    }

    func aspectRatioForBanner(at indexPath: IndexPath) -> CGFloat {
        return [0, 1].contains(indexPath.row) ? 1.37 : 2.68
    }
}
