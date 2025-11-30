//
//  RatingInputView.swift
//  Do
//
//  View for inputting ratings
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit

class RatingInputView: UIView {
    var completion: ((Double) -> Void)?
    
    private var starButtons: [UIButton] = []
    private var currentRating: Double = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for i in 1...5 {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "star"), for: .normal)
            button.setImage(UIImage(systemName: "star.fill"), for: .selected)
            button.tintColor = uicolorFromHex(rgbValue: 0xF7931F)
            button.tag = i
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            starButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    @objc private func starTapped(_ sender: UIButton) {
        let rating = Double(sender.tag)
        currentRating = rating
        
        // Update star states
        for (index, button) in starButtons.enumerated() {
            button.isSelected = index < sender.tag
        }
        
        completion?(rating)
    }
}

