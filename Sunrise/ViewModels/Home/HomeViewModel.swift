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
        case title
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
        .observeValues { [unowned self] in
            switch $0.row {
                case 0:
                    AppRouting.showCategory(id: "b8250c0d-a29e-42d5-8c11-97d7a98bb462")
                case 1:
                    AppRouting.showCategory(id: "96ac6204-4631-41d3-9540-22b7629f468d")
                case 3:
                    AppRouting.showCategory(id: self.isAuthenticated ? (MyStyleViewModel.isWomenSetting ? "1d9f82b4-4fb8-4830-91b0-61b876da7b93" : "c35ef50c-c62a-42bf-851d-2a0692d07f24") : "c470ff8a-ca75-4283-9113-f53e273a4f4b")
                case 5:
                    AppRouting.showCategory(id: "f8587a7d-7756-4072-8b1f-6360357218c2")
                case 6:
                    AppRouting.showCategory(id: "e2191d36-21ab-4ea7-9cee-d9ff576948d1")
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
        return 7
    }

    func element(at indexPath: IndexPath) -> HomeElement {
        switch indexPath.row {
            case 0, 1, 3, 5, 6:
                return .banner
            case 2:
                return .inlinePOP
            case 4:
                return .title
            default:
                fatalError("Element type for indexPath: \(indexPath) not defined")
        }
    }

    func bannerImage(at indexPath: IndexPath) -> UIImage? {
        let isGermanLocaleActive = Locale.current.identifier.contains("de")
        switch indexPath.row {
            case 0:
                return isGermanLocaleActive ? #imageLiteral(resourceName: "summer_accessories_banner_de") : #imageLiteral(resourceName: "summer_accessories_banner_de")
            case 1:
                return isGermanLocaleActive ? #imageLiteral(resourceName: "looks_we_love_banner_de") : #imageLiteral(resourceName: "looks_we_love_banner")
            case 3:
                return isGermanLocaleActive ? #imageLiteral(resourceName: "on_sale_banner_de") : #imageLiteral(resourceName: "on_sale_banner")
            case 5:
                return isGermanLocaleActive ? #imageLiteral(resourceName: "women_banner_de") : #imageLiteral(resourceName: "women_banner")
            case 6:
                return isGermanLocaleActive ? #imageLiteral(resourceName: "man_banner_de") : #imageLiteral(resourceName: "man_banner")
            default:
                return nil
        }
    }

    func aspectRatioForBanner(at indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
            case 0, 1:
                return 1.37
            case 3, 5, 6:
                return 2.68
            default:
                return 0
        }
    }

    func title(at indexPath: IndexPath) -> String? {
        return indexPath.row == 4 ? NSLocalizedString("Shop by category", comment: "Shop by category") : nil
    }
}