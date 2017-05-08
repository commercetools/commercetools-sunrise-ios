//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class VoiceLevelView : UIView {

    @IBInspectable var sinceColor: UIColor = .black

    private let frequency: CGFloat = 1.5
    private let idleAmplitude: CGFloat = 0.01
    private let phaseShift: CGFloat = 0.15
    private let numberOfSines = 6
    private let primaryLineWidth: CGFloat = 2.0
    private let secondaryLineWidth: CGFloat = 1.0

    private var amplitude: CGFloat = 0.0
    private var phase: CGFloat = 0.0

    func update(amplitude: CGFloat) {
        self.amplitude = max(amplitude, idleAmplitude)
        phase += phaseShift
        setNeedsDisplay()
    }

    override open func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.clear(bounds)

        backgroundColor?.set()
        context?.fill(rect)

        (0...numberOfSines - 1).forEach {
            drawSineCurve(index: $0)
        }
    }

    lazy var maxAmplitude: CGFloat = { [unowned self] in
        return self.bounds.height / 2.0 - self.primaryLineWidth
    }()

    private func drawSineCurve(index: Int) {
        let path = UIBezierPath()
        let mid = bounds.width / 2.0
        path.lineWidth = index == 0 ? primaryLineWidth : secondaryLineWidth

        let progress = 1.0 - CGFloat(index) / CGFloat(numberOfSines)
        let normedAmplitude = (1.5 * progress - 0.5) * amplitude
        let multiplier = min(1.0, (2 * progress / 3) + (1 / 3))
        sinceColor.withAlphaComponent(multiplier * sinceColor.cgColor.alpha).set()

        for x in Swift.stride(from: 0, to: bounds.width + 1, by: 1) {
            // parabolic scaling
            let scaling = -pow(1 / mid * (x - mid), 2) + 1
            let y = scaling * maxAmplitude * normedAmplitude * sin(CGFloat(2 * Double.pi) * frequency * (x / bounds.width)  + phase) + bounds.height / 2.0
            if x == 0 {
                path.move(to: CGPoint(x:x, y:y))
            } else {
                path.addLine(to: CGPoint(x:x, y:y))
            }
        }
        path.stroke()
    }
}
