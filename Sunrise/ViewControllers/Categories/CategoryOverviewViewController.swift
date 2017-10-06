//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class CategoryOverviewViewController: UIViewController {

    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var productsCollectionView: UICollectionView!
    @IBOutlet weak var searchSuggestionsTableView: UITableView!
    @IBOutlet weak var magnifyingGlassImageView: UIImageView!
    @IBOutlet weak var categorySelectionButton: UIButton!
    @IBOutlet weak var searchFilterButton: UIButton!
    @IBOutlet weak var filterButton: UIButton!

    @IBOutlet weak var searchViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldMagnifyingGlassLeadingSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var categorySelectionButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthActiveConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthInactiveConstraint: NSLayoutConstraint!

    let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        gradientLayer.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 13)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        
        let placeholderAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red:0.34, green:0.37, blue:0.40, alpha:1.0)]
        searchField.attributedPlaceholder = NSAttributedString(string: "search", attributes: placeholderAttributes)
        
        searchSuggestionsTableView.tableFooterView = UIView()
        
        NotificationCenter.default.addObserver(forName: Foundation.Notification.Name.Navigation.BackButtonTapped, object: nil, queue: .main) { [weak self] _ in
            guard let searchField = self?.searchField else { return }
            searchField.text = ""
            self?.searchField.resignFirstResponder()
        }
        
        NotificationCenter.default.addObserver(forName: Foundation.Notification.Name.Navigation.ResetSearch, object: nil, queue: .main) { [unowned self] _ in
            UIView.animate(withDuration: 0.3, animations: {
                self.productsCollectionView.alpha = 0
                self.filterButton.alpha = 0
                self.searchViewHeightConstraint.constant = 55
                self.view.layoutIfNeeded()
                self.searchField.text = ""
                self.searchEditingDidEnd(self.searchField)
            }, completion: { _ in
                UIView.animate(withDuration: 0.3) {
                    self.searchView.alpha = 1
                    self.categoriesCollectionView.alpha = 1
                }
            })
        }
    }

    @IBAction func searchEditingDidBegin(_ sender: UITextField) {
        UIView.animate(withDuration: 0.3, animations: {
            self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon_active")
            self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 0
            self.categorySelectionButton.alpha = 0
            self.searchFilterButton.alpha = 0
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
            self.searchFieldLineWidthInactiveConstraint.isActive = false
            self.searchFieldLineWidthActiveConstraint.isActive = true
            [self.productsCollectionView, self.categoriesCollectionView].forEach { $0?.alpha = 0 }
            self.searchView.layoutIfNeeded()
        }, completion: { _ in
            self.scrollViewDidScroll(self.searchSuggestionsTableView)
            self.categorySelectionButtonHeightConstraint.constant = 0
            UIView.animate(withDuration: 0.3) {
                self.searchSuggestionsTableView.alpha = 1
            }
        })
    }

    @IBAction func searchEditingDidEnd(_ sender: UITextField) {
        UIView.animate(withDuration: 0.3, animations: {
            if (sender.text ?? "").count == 0 {
                self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon")
                self.searchFieldLineWidthActiveConstraint.isActive = false
                self.searchFieldLineWidthInactiveConstraint.isActive = true
                self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 20
                self.searchSuggestionsTableView.alpha = 0
                self.searchFilterButton.alpha = 0
                self.searchView.layoutIfNeeded()
            }
            SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        }, completion: { _ in
            if (sender.text ?? "").count == 0 {
                self.scrollViewDidScroll(self.categoriesCollectionView)
                self.categorySelectionButtonHeightConstraint.constant = 37
                UIView.animate(withDuration: 0.3) {
                    self.categoriesCollectionView.alpha = 1
                    self.categorySelectionButton.alpha = 1
                }
            }
        })
    }
}

extension CategoryOverviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseIdentifier = collectionView == categoriesCollectionView ? "CategoryCell" : "ProductCell"
        return collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
    }
}

extension CategoryOverviewViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView == categoriesCollectionView else { return }
        UIView.animate(withDuration: 0.3, animations: {
            self.searchView.alpha = 0
            self.categoriesCollectionView.alpha = 0
            self.searchViewHeightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.productsCollectionView.alpha = 1
                self.filterButton.alpha = 1
            }
        })
    }
}

extension CategoryOverviewViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt sizeForItemAtIndexPath: IndexPath) -> CGSize {
        let screenWidth = view.bounds.size.width
        let cellWidth = (screenWidth - 30) / 2
        let cellHeight = collectionView == categoriesCollectionView ? 0.883 * cellWidth : 311
        return CGSize(width: cellWidth, height: cellHeight)
    }
}

extension CategoryOverviewViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        if 0...57 ~= yOffset {
            gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 13 + yOffset)
        } else if yOffset > 57 && gradientLayer.bounds.height < 70 {
            gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 70)
        }
    }
}

extension CategoryOverviewViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let categoryCell = tableView.dequeueReusableCell(withIdentifier: "SearchSuggestion") as! SearchSuggestionCell

        return categoryCell
    }
}

extension CategoryOverviewViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        searchField.text = "Black top"
        searchField.resignFirstResponder()
        UIView.animate(withDuration: 0.3, animations: {
            self.searchSuggestionsTableView.alpha = 0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.productsCollectionView.alpha = 1
                self.searchFilterButton.alpha = 1
            }
        })
    }
}
