//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class CartViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loginPromptView: UIView!
    @IBOutlet weak var snapshotBackgroundColorView: UIView!
    @IBOutlet weak var whiteBackgroundColorView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    private var screenSnapshot: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.15) {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        UIView.animate(withDuration: 0.15) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        }
        backgroundImageView.alpha = 0
        snapshotBackgroundColorView.alpha = 0
        whiteBackgroundColorView.alpha = 0
        loginPromptView.alpha = 0
        super.viewDidDisappear(animated)
    }

    @IBAction func checkout(_ sender: UIButton) {
        guard let snapshot = performSnapshot() else { return }
        screenSnapshot = snapshot
        backgroundImageView.image = snapshot
        backgroundImageView.alpha = 1
        let blurred = self.blur(image: snapshot)
        UIView.transition(with: backgroundImageView, duration: 0.15, options: .transitionCrossDissolve, animations: {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 0
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 0
            self.backgroundImageView.image = blurred
        }, completion: { _ in
            self.whiteBackgroundColorView.alpha = 1
            UIView.animate(withDuration: 0.15) {
                self.backgroundImageView.alpha = 0.5
                self.snapshotBackgroundColorView.alpha = 0.5
                self.loginPromptView.alpha = 1
            }
        })
    }

    func performSnapshot() -> UIImage? {
        guard let window = UIApplication.shared.delegate?.window ?? nil else { return nil }
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, window.isOpaque, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        window.layer.render(in: context)
        let fullSnapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return fullSnapshot
    }
}

extension CartViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return indexPath.row == 0 ? tableView.dequeueReusableCell(withIdentifier: "CartSummaryCell")! : tableView.dequeueReusableCell(withIdentifier: "CartItemCell")!
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

        }
    }

}

extension CartViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? 245 : 198
    }
}
