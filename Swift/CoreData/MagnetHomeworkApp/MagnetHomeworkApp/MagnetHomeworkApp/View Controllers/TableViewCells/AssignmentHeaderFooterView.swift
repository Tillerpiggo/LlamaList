//
//  AssignmentTableViewHeaderFooterView.swift
//  MagnetHomeworkApp
//
//  Created by Tyler Gee on 11/23/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit

protocol AssignmentHeaderFooterCellDelegate {
    func showHideButtonPressed(isExpanded: Bool, forSection section: Int)
}

class AssignmentHeaderFooterView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var showHideButton: UIButton!
    @IBOutlet weak var showHideLabel: UILabel!
    @IBOutlet weak var backgroundColorView: UIView!
    
    
    
    
    var delegate: AssignmentHeaderFooterCellDelegate?
    var section: Int?
    var isExpanded: Bool = true
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let animation = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.type = .fade
        animation.duration = 0.1
        showHideLabel?.layer.add(animation, forKey: "kCATransitionFade")
        titleLabel.textColor = .white
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurEffectView)
        
        backgroundColorView.backgroundColor = .backgroundColor
        
        updateShowHideButton()
    }
    
    @IBAction func showHideButtonPressed(_ sender: Any) {
        print("ISEXPANDED: \(isExpanded)")
        isExpanded = !isExpanded
        print("ISEXPANDED: \(isExpanded)\n")
        
        delegate?.showHideButtonPressed(isExpanded: isExpanded, forSection: section!)
        
        updateShowHideButton()
    }
    
    func updateShowHideButton() {
        if isExpanded {
            showHideLabel.text = "Hide"
        } else {
            showHideLabel.text = "Expand"
        }
    }
}
