//
//  editPlanCell.swift
//  Do
//
//  Collection view cell for editing plan sessions
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit

class editPlanCell: UICollectionViewCell {
    static let reuseIdentifier = "editPlanCell"
    
    let dayLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-DemiBold", size: 14)
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()
    
    let sessionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-DemiBold", size: 16)
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()
    
    let movementCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-Regular", size: 12)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .left
        return label
    }()
    
    let avgTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-Regular", size: 12)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .left
        return label
    }()
    
    let plusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "plus.circle")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let deleteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "trash")
        imageView.tintColor = .red
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let boxView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(boxView)
        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.addSubview(dayLabel)
        boxView.addSubview(sessionLabel)
        boxView.addSubview(movementCountLabel)
        boxView.addSubview(avgTimeLabel)
        boxView.addSubview(plusImageView)
        boxView.addSubview(deleteImageView)
        
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionLabel.translatesAutoresizingMaskIntoConstraints = false
        movementCountLabel.translatesAutoresizingMaskIntoConstraints = false
        avgTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        plusImageView.translatesAutoresizingMaskIntoConstraints = false
        deleteImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            boxView.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            boxView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            boxView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            boxView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            
            dayLabel.topAnchor.constraint(equalTo: boxView.topAnchor, constant: 10),
            dayLabel.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 15),
            dayLabel.widthAnchor.constraint(equalToConstant: 100),
            
            sessionLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 5),
            sessionLabel.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 15),
            sessionLabel.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -50),
            
            movementCountLabel.topAnchor.constraint(equalTo: sessionLabel.bottomAnchor, constant: 5),
            movementCountLabel.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 15),
            movementCountLabel.bottomAnchor.constraint(equalTo: boxView.bottomAnchor, constant: -10),
            
            avgTimeLabel.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            avgTimeLabel.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -15),
            
            plusImageView.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            plusImageView.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -15),
            plusImageView.widthAnchor.constraint(equalToConstant: 24),
            plusImageView.heightAnchor.constraint(equalToConstant: 24),
            
            deleteImageView.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            deleteImageView.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -15),
            deleteImageView.widthAnchor.constraint(equalToConstant: 24),
            deleteImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}




