import UIKit
import MapKit
import Parse

// MARK: - Collection View Cell for Recent Runs
//class RecentRunCollectionViewCell: UICollectionViewCell {
//    private let containerView = UIView()
//    private let mapView = MKMapView()
//    private let typeLabel = UILabel()
//    private let distanceLabel = UILabel()
//    private let dateLabel = UILabel()
//    private let durationLabel = UILabel()
//    private let gradientLayer = CAGradientLayer()
//    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupUI()
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        containerView.layer.cornerRadius = 16
//        containerView.clipsToBounds = true
//        
//        gradientLayer.frame = CGRect(x: 0, y: containerView.bounds.height - 100, width: containerView.bounds.width, height: 100)
//    }
//    
//    private func setupUI() {
//        // Setup container view
//        containerView.backgroundColor = uicolorFromHex(rgbValue: 0x1A2456)
//        containerView.layer.cornerRadius = 16
//        containerView.clipsToBounds = true
//        containerView.translatesAutoresizingMaskIntoConstraints = false
//        contentView.addSubview(containerView)
//        
//        // Setup map view
//        mapView.isUserInteractionEnabled = false
//        mapView.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(mapView)
//        
//        // Setup gradient for text overlay
//        gradientLayer.colors = [
//            UIColor.black.withAlphaComponent(0).cgColor,
//            UIColor.black.withAlphaComponent(0.7).cgColor
//        ]
//        gradientLayer.locations = [0, 1]
//        containerView.layer.addSublayer(gradientLayer)
//        
//        // Setup type label
//        typeLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
//        typeLabel.textColor = UIColor.white.withAlphaComponent(0.8)
//        typeLabel.textAlignment = .left
//        typeLabel.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(typeLabel)
//        
//        // Setup distance label
//        distanceLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
//        distanceLabel.textColor = .white
//        distanceLabel.textAlignment = .left
//        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(distanceLabel)
//        
//        // Setup date label
//        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
//        dateLabel.textColor = UIColor.white.withAlphaComponent(0.8)
//        dateLabel.textAlignment = .right
//        dateLabel.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(dateLabel)
//        
//        // Setup duration label
//        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
//        durationLabel.textColor = .white
//        durationLabel.textAlignment = .right
//        durationLabel.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(durationLabel)
//        
//        // Add constraints
//        NSLayoutConstraint.activate([
//            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
//            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
//            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
//            
//            mapView.topAnchor.constraint(equalTo: containerView.topAnchor),
//            mapView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//            mapView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//            mapView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
//            
//            typeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
//            typeLabel.bottomAnchor.constraint(equalTo: distanceLabel.topAnchor, constant: -4),
//            
//            distanceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
//            distanceLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
//            
//            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
//            dateLabel.bottomAnchor.constraint(equalTo: durationLabel.topAnchor, constant: -4),
//            
//            durationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
//            durationLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
//        ])
//        
//        // Add shadow to card
//        contentView.layer.shadowColor = UIColor.black.cgColor
//        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
//        contentView.layer.shadowRadius = 6
//        contentView.layer.shadowOpacity = 0.3
//        contentView.layer.masksToBounds = false
//    }
//    
//    func configure(with run: RunLog) {
//        typeLabel.text = "Outdoor Run"
//        
//        // Format distance
//        if let distance = run.distance, let distanceValue = Double(distance) {
//            distanceLabel.text = String(format: "%.2f km", distanceValue)
//        } else {
//            distanceLabel.text = "-- km"
//        }
//        
//        // Format date
//        if let date = run.createdAt {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "MMM d, yyyy"
//            dateLabel.text = formatter.string(from: date)
//        } else {
//            dateLabel.text = "--"
//        }
//        
//        // Format duration
//        durationLabel.text = run.duration ?? "--:--"
//        
//        // Configure map if route is available
//        if let coordinates = run.coordinateArray, !coordinates.isEmpty {
//            let route = convertPFGeoPointsToCoordinates(coordinates)
//            showRoute(coordinates: route)
//        } else {
//            // If no route, show a placeholder
//            mapView.backgroundColor = uicolorFromHex(rgbValue: 0x0F163E)
//        }
//    }
//    
//    func configure(with run: IndoorRunLog) {
//        typeLabel.text = "Indoor Run"
//        
//        // Format distance
//        if let distance = run.distance, let distanceValue = Double(distance) {
//            distanceLabel.text = String(format: "%.2f km", distanceValue)
//        } else {
//            distanceLabel.text = "-- km"
//        }
//        
//        // Format date
//        if let date = run.createdAt {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "MMM d, yyyy"
//            dateLabel.text = formatter.string(from: date)
//        } else {
//            dateLabel.text = "--"
//        }
//        
//        // Format duration
//        durationLabel.text = run.duration ?? "--:--"
//        
//        // Indoor runs don't have a route, show treadmill icon or pattern
//        mapView.backgroundColor = uicolorFromHex(rgbValue: 0x0F163E)
//        
//        // Add a treadmill icon
//        let imageView = UIImageView(image: UIImage(systemName: "figure.run"))
//        imageView.tintColor = UIColor.white.withAlphaComponent(0.3)
//        imageView.contentMode = .scaleAspectFit
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        mapView.addSubview(imageView)
//        
//        NSLayoutConstraint.activate([
//            imageView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
//            imageView.centerYAnchor.constraint(equalTo: mapView.centerYAnchor),
//            imageView.widthAnchor.constraint(equalToConstant: 60),
//            imageView.heightAnchor.constraint(equalToConstant: 60)
//        ])
//    }
//    
//    private func showRoute(coordinates: [CLLocationCoordinate2D]) {
//        // Reset the map
//        mapView.removeOverlays(mapView.overlays)
//        
//        // Create a polyline with the coordinates
//        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
//        mapView.addOverlay(polyline)
//        
//        // Set the region to show the entire route
//        let mapRect = polyline.boundingMapRect
//        mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
//    }
//    
//    private func convertPFGeoPointsToCoordinates(_ geoPoints: [PFGeoPoint]) -> [CLLocationCoordinate2D] {
//        return geoPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
//    }
//}

// MARK: - Table View Cell for Run History
class RunHistoryTableViewCell: UITableViewCell {
    private let containerView = UIView()
    private let runTypeImageView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let distanceLabel = UILabel()
    private let durationLabel = UILabel()
    private let paceLabel = UILabel()
    private let distanceIcon = UIImageView()
    private let durationIcon = UIImageView()
    private let paceIcon = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = 16
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Setup container view
        containerView.backgroundColor = uicolorFromHex(rgbValue: 0x1A2456)
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Setup run type image
        runTypeImageView.contentMode = .scaleAspectFit
        runTypeImageView.tintColor = .white
        runTypeImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(runTypeImageView)
        
        // Setup title label
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Setup date label
        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(dateLabel)
        
        // Setup icons
        setupMetricIcon(distanceIcon, systemName: "figure.run")
        setupMetricIcon(durationIcon, systemName: "clock")
        setupMetricIcon(paceIcon, systemName: "timer")
        
        // Setup metric labels
        setupMetricLabel(distanceLabel)
        setupMetricLabel(durationLabel)
        setupMetricLabel(paceLabel)
        
        // Add constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            runTypeImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            runTypeImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            runTypeImageView.widthAnchor.constraint(equalToConstant: 24),
            runTypeImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: runTypeImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Distance metric
            distanceIcon.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 16),
            distanceIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            distanceIcon.widthAnchor.constraint(equalToConstant: 16),
            distanceIcon.heightAnchor.constraint(equalToConstant: 16),
            
            distanceLabel.centerYAnchor.constraint(equalTo: distanceIcon.centerYAnchor),
            distanceLabel.leadingAnchor.constraint(equalTo: distanceIcon.trailingAnchor, constant: 8),
            
            // Duration metric
            durationIcon.centerYAnchor.constraint(equalTo: distanceIcon.centerYAnchor),
            durationIcon.leadingAnchor.constraint(equalTo: distanceLabel.trailingAnchor, constant: 16),
            durationIcon.widthAnchor.constraint(equalToConstant: 16),
            durationIcon.heightAnchor.constraint(equalToConstant: 16),
            
            durationLabel.centerYAnchor.constraint(equalTo: durationIcon.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: durationIcon.trailingAnchor, constant: 8),
            
            // Pace metric
            paceIcon.centerYAnchor.constraint(equalTo: distanceIcon.centerYAnchor),
            paceIcon.leadingAnchor.constraint(equalTo: durationLabel.trailingAnchor, constant: 16),
            paceIcon.widthAnchor.constraint(equalToConstant: 16),
            paceIcon.heightAnchor.constraint(equalToConstant: 16),
            
            paceLabel.centerYAnchor.constraint(equalTo: paceIcon.centerYAnchor),
            paceLabel.leadingAnchor.constraint(equalTo: paceIcon.trailingAnchor, constant: 8),
        ])
        
        // Add shadow
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.2
        contentView.layer.masksToBounds = false
    }
    
    private func setupMetricIcon(_ imageView: UIImageView, systemName: String) {
        imageView.image = UIImage(systemName: systemName)
        imageView.tintColor = uicolorFromHex(rgbValue: 0x4E7BFF)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
    }
    
    private func setupMetricLabel(_ label: UILabel) {
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
    }
    
    func configure(with run: RunLog) {
        // Set run type
        runTypeImageView.image = UIImage(systemName: "arrow.up.forward")
        titleLabel.text = "Outdoor Run"
        
        // Format date
        if let date = run.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d, yyyy · h:mm a"
            dateLabel.text = formatter.string(from: date)
        } else {
            dateLabel.text = "Unknown date"
        }
        
        // Format metrics
        if let distance = run.distance, let distanceValue = Double(distance) {
            distanceLabel.text = String(format: "%.2f km", distanceValue)
        } else {
            distanceLabel.text = "-- km"
        }
        
        durationLabel.text = run.duration ?? "--:--"
        paceLabel.text = run.avgPace ?? "--'--\""
    }
    
    func configure(with run: IndoorRunLog) {
        // Set run type
        runTypeImageView.image = UIImage(systemName: "house")
        titleLabel.text = "Indoor Run"
        
        // Format date
        if let date = run.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d, yyyy · h:mm a"
            dateLabel.text = formatter.string(from: date)
        } else {
            dateLabel.text = "Unknown date"
        }
        
        // Format metrics
        if let distance = run.distance, let distanceValue = Double(distance) {
            distanceLabel.text = String(format: "%.2f km", distanceValue)
        } else {
            distanceLabel.text = "-- km"
        }
        
        durationLabel.text = run.duration ?? "--:--"
        paceLabel.text = run.avgPace ?? "--'--\""
    }
    
    private func convertPFGeoPointsToCoordinates(_ geoPoints: [PFGeoPoint]) -> [CLLocationCoordinate2D] {
        return geoPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
} 
