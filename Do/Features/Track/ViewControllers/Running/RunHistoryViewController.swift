//
//  RunHistoryViewControllerDelegate.swift
//  Do.
//
//  Created by Mikiyas Meseret on 4/9/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import Parse
import CoreData
import MapKit  
import CoreLocation

// MARK: - Delegate Protocol

protocol RunHistoryViewControllerDelegate: AnyObject {
    func didSelectOutdoorRun(_ run: RunLog)
    func didSelectIndoorRun(_ run: IndoorRunLog)
    func didDismiss()
}

// Make methods optional
extension RunHistoryViewControllerDelegate {
    func didSelectOutdoorRun(_ run: RunLog) {}
    func didSelectIndoorRun(_ run: IndoorRunLog) {}
    func didDismiss() {}
}

// Define CalendarDay model
struct CalendarDay {
    enum Intensity: Int {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
    }
    
    var date: Date?
    var totalDistance: Double
    var totalDuration: Double
    var intensity: Intensity
}

// MARK: - CalendarDayCell
class CalendarDayCell: UICollectionViewCell {
    private let dayLabel = UILabel()
    private let intensityIndicator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Setup cell appearance
        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        layer.cornerRadius = 8
        
        // Setup day label
        dayLabel.textAlignment = .center
        dayLabel.textColor = .white
        dayLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        // Setup intensity indicator - make it larger and position it as a background tint
        intensityIndicator.layer.cornerRadius = 4
        intensityIndicator.isHidden = true
        
        // Add subviews in proper order - intensity indicator behind the label
        contentView.addSubview(intensityIndicator)
        contentView.addSubview(dayLabel)
        
        // Configure constraints
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        intensityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Center the day label
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Make the intensity indicator take up most of the cell bottom area
            intensityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            intensityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            intensityIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            intensityIndicator.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.3)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with day: CalendarDay, isSelected: Bool = false) {
        // Configure day label
        if let date = day.date {
            let calendar = Calendar.current
            dayLabel.text = "\(calendar.component(.day, from: date))"
            
            // Check if this day is today
            if calendar.isDateInToday(date) {
                dayLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
                dayLabel.textColor = UIColor(hex: 0x4CD964)
            } else {
                dayLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                dayLabel.textColor = .white
            }
        } else {
            // Empty day
            dayLabel.text = ""
            dayLabel.textColor = .white
        }
        
        // Configure selection state
        if isSelected {
            backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.2)
            layer.borderWidth = 2
            layer.borderColor = UIColor(hex: 0x4CD964).cgColor
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.05)
            layer.borderWidth = 0
        }
        
        // Configure intensity indicator with improved visibility
        if day.intensity != .none && day.date != nil {
            intensityIndicator.isHidden = false
            
            switch day.intensity {
            case .low:
                intensityIndicator.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.3)
            case .medium:
                intensityIndicator.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.6)
            case .high:
                intensityIndicator.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.9)
            default:
                intensityIndicator.isHidden = true
            }
        } else {
            intensityIndicator.isHidden = true
        }
    }
}

class RunHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate {
    
    // MARK: - Properties
    
    var delegate: RunHistoryViewControllerDelegate?
    
    private var outdoorRunLogs: [RunLog] = []
    private var indoorRunLogs: [IndoorRunLog] = []
    private var filteredRuns: [Any] = []
    private var calendarDays: [CalendarDay] = [] // Calendar day models
    private var selectedDate: Date? // Selected date for filtering
    
    private var isLoading = false
    private var hasMoreData = true
    private var showingCalendarView = false // Track if calendar is visible
    
    // New properties for badges and map
    private var userBadges: [Badge] = []
    private var badgeCollectionView: UICollectionView?
    private var showBadges = true
    
    // MARK: - UI Elements
    
    private let titleLabel = UILabel() // New title label for "Run History"
    private let filterControl = UISegmentedControl(items: ["All", "Outdoor", "Indoor"])
    private let filterChipsContainer = UIView() // Container for filter chips
    private let tableView = UITableView()
    private var statsHeaderView = UIView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let mainScrollView = UIScrollView() // Main scroll view to contain calendar and table
    private let contentContainerView = UIView() // Container for all scrollable content
    
    // Calendar heatmap components
    private let calendarViewContainer = UIView()
    private let calendarCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    private let monthLabel = UILabel()
    private let previousMonthButton = UIButton(type: .system)
    private let nextMonthButton = UIButton(type: .system)
    private var currentCalendarDate = Date() // Track which month is displayed
    
    // Calendar constants
    private let daysInWeek = 7
    private let maxWeeks = 6
    private var daySize: CGFloat = 40
    
    // Data
    private var currentPage = 0
    private let pageSize = 50
    private var backgroundQueue = DispatchQueue(label: "com.do.runhistory.background", qos: .utility)
    
    // UI Components
    private let refreshControl = UIRefreshControl()
    
    // New properties
    private let cellHeight: CGFloat = 150 // Increased from 120
    
    // UI elements for badges and map
    private let badgesContainerView = UIView()
    private let badgeToggleButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        // Configure for popover presentation
        modalPresentationStyle = .popover
        
        // Set preferred size for popover presentation - slightly smaller than before
        // to ensure it fits well within the popover bounds
        preferredContentSize = CGSize(
            width: UIScreen.main.bounds.width * 0.9, 
            height: UIScreen.main.bounds.height * 0.7
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial setup for views and UI
        setupUI()
        
        // Configure all UI components in the correct order
        setupFilterChips()
        setupBadgesView()
        setupCalendarView()
        
        // Set initial constraints between views to establish proper hierarchy
        setupViewHierarchy()
        
        // Load data after UI is set up
        loadRunningHistory(page: 0)
        loadUserBadges()
        
        // Add a dismissal button if this is presented modally
        if presentingViewController != nil {
            let dismissButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(dismissViewController))
            dismissButton.tintColor = .white
            navigationItem.rightBarButtonItem = dismissButton
        }
        
        // Configure navigation bar to match background
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.backgroundColor = UIColor(hex: 0x060B16)
        navigationController?.navigationBar.barTintColor = UIColor(hex: 0x060B16)
        
        // Initialize calendar view with data
        updateCalendarDays()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if we need to refresh the data (e.g., after a new run was added)
        if UserDefaults.standard.bool(forKey: "shouldRefreshRunHistory") {
            refreshData()
            UserDefaults.standard.set(false, forKey: "shouldRefreshRunHistory")
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Modern deep gradient background - darker and more immersive
        view.backgroundColor = UIColor(hex: 0x060B16) // Darker base color
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: 0x060B16).cgColor, // Near black with blue tint
            UIColor(hex: 0x172339).cgColor  // Deep navy blue
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup title label with modern typography - moved to very top
        titleLabel.text = "Running History"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .heavy) // Larger, bolder font
        titleLabel.textAlignment = .left
        view.addSubview(titleLabel)
        
        // Setup main scroll view for all content
        mainScrollView.backgroundColor = .clear
        mainScrollView.showsVerticalScrollIndicator = true
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)
        
        // Add content container to scroll view
        contentContainerView.backgroundColor = .clear
        mainScrollView.addSubview(contentContainerView)
        
        // Create stats header view
        statsHeaderView = createStatsHeaderView()
        statsHeaderView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(statsHeaderView)
        
        // Setup table view with modern appearance - match background with other containers
        tableView.backgroundColor = UIColor(hex: 0x131D2E)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RunLogCell.self, forCellReuseIdentifier: "RunLogCell")
        tableView.refreshControl = refreshControl
        tableView.isScrollEnabled = false // Disable scrolling as it's now in a scroll view
        
        // Add subtle rounded corners to table
        tableView.layer.cornerRadius = 16 // Increased corner radius
        tableView.clipsToBounds = true
        
        // Add shadow to tableView for depth
        tableView.layer.shadowColor = UIColor.black.cgColor
        tableView.layer.shadowOffset = CGSize(width: 0, height: 4)
        tableView.layer.shadowRadius = 8
        tableView.layer.shadowOpacity = 0.3
        
        contentContainerView.addSubview(tableView)
        
        // Style the loading indicator
        loadingView.hidesWhenStopped = true
        loadingView.color = UIColor(hex: 0x4CD964)
        loadingView.transform = CGAffineTransform(scaleX: 1.8, y: 1.8) // Larger indicator
        view.addSubview(loadingView)
        
        // Style the refresh control
        refreshControl.tintColor = UIColor(hex: 0x4CD964)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        
        // Setup constraints for the basic structure
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title label constraints - moved to very top with less padding
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Main scroll view constraints - closer to title
            mainScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content container constraints
            contentContainerView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            
            // Just set the width constraint for content container, all other constraints will be set in setupViewHierarchy
            contentContainerView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),
            
            // Stats header view basic constraints - no bottom constraint yet
            statsHeaderView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            statsHeaderView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            
            // Loading view constraints
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Update tableView setup
        tableView.rowHeight = 128 // Adjusted height to better fit the cell content
        tableView.estimatedRowHeight = 128
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 24, right: 0) // More bottom padding
    }
    
    private func setupFilterChips() {
        filterChipsContainer.backgroundColor = UIColor(hex: 0x131D2E) // Match calendar background
        filterChipsContainer.layer.cornerRadius = 16
        // Add shadow for depth
        filterChipsContainer.layer.shadowColor = UIColor.black.cgColor
        filterChipsContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        filterChipsContainer.layer.shadowRadius = 6
        filterChipsContainer.layer.shadowOpacity = 0.2
        
        // Add to content container
        filterChipsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(filterChipsContainer)
        
        // Create horizontal stack for filter chips
        let chipsStack = UIStackView()
        chipsStack.axis = .horizontal
        chipsStack.spacing = 10
        chipsStack.distribution = .fillProportionally // Changed from fillEqually to fillProportionally
        chipsStack.alignment = .fill
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        filterChipsContainer.addSubview(chipsStack)
        
        // Create filter chips with icons
        let allChip = createFilterChip(title: "All Runs", iconName: "figure.run.circle.fill", isSelected: true, tag: 0)
        let outdoorChip = createFilterChip(title: "Outdoor", iconName: "sun.max.fill", isSelected: false, tag: 1)
        let indoorChip = createFilterChip(title: "Indoor", iconName: "house.fill", isSelected: false, tag: 2)
        
        // Add chips to stack
        chipsStack.addArrangedSubview(allChip)
        chipsStack.addArrangedSubview(outdoorChip)
        chipsStack.addArrangedSubview(indoorChip)
        
        // Set constraints (only internal constraints)
        NSLayoutConstraint.activate([
            chipsStack.topAnchor.constraint(equalTo: filterChipsContainer.topAnchor, constant: 16),
            chipsStack.leadingAnchor.constraint(equalTo: filterChipsContainer.leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(equalTo: filterChipsContainer.trailingAnchor, constant: -16),
            chipsStack.bottomAnchor.constraint(equalTo: filterChipsContainer.bottomAnchor, constant: -16),
            
            // Set horizontal constraints on the container
            filterChipsContainer.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            filterChipsContainer.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16)
        ])
    }
    
    private func createFilterChip(title: String, iconName: String, isSelected: Bool, tag: Int) -> UIView {
        // Create container for the chip
        let chipView = UIView()
        chipView.layer.cornerRadius = 20
        chipView.tag = tag
        
        // Set background color based on selection state with animation-friendly properties
        chipView.layer.borderWidth = 1
        chipView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        // Set background color based on selection state
        if isSelected {
            chipView.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.2)
            chipView.layer.borderColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.5).cgColor
        } else {
            chipView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        }
        
        // Create horizontal stack for icon and label
        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        chipView.addSubview(contentStack)
        
        // Create icon for the chip
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = isSelected ? UIColor(hex: 0x4CD964) : .white
        
        // Create label for the chip
        let chipLabel = UILabel()
        chipLabel.text = title
        chipLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        chipLabel.textColor = isSelected ? UIColor(hex: 0x4CD964) : .white
        chipLabel.setContentCompressionResistancePriority(.required, for: .horizontal) // Ensure text doesn't compress
        
        // Add icon and label to stack
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(chipLabel)
        
        // Make chip tappable
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(filterChipTapped(_:)))
        chipView.addGestureRecognizer(tapGesture)
        chipView.isUserInteractionEnabled = true
        
        // Setup constraints
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: chipView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: chipView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: chipView.bottomAnchor, constant: -12),
            
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            // Add minimum width for chips to ensure proper spacing
            chipView.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])
        
        return chipView
    }
    
    @objc private func filterChipTapped(_ sender: UITapGestureRecognizer) {
        guard let chipView = sender.view else { return }
        
        // Update UI for selected chip with animation
        for subview in filterChipsContainer.subviews {
            if let stackView = subview as? UIStackView {
                for chip in stackView.arrangedSubviews {
                    UIView.animate(withDuration: 0.3) {
                        if chip.tag == chipView.tag {
                            // Selected state
                            chip.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.2)
                            chip.layer.borderColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.5).cgColor
                            
                            // Update icon and text color
                            if let contentStack = chip.subviews.first as? UIStackView,
                               let iconView = contentStack.arrangedSubviews.first as? UIImageView,
                               let label = contentStack.arrangedSubviews.last as? UILabel {
                                iconView.tintColor = UIColor(hex: 0x4CD964)
                                label.textColor = UIColor(hex: 0x4CD964)
                            }
                            
                            // Scale up animation
                            chip.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                        } else {
                            // Unselected state
                            chip.backgroundColor = UIColor.white.withAlphaComponent(0.05)
                            chip.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
                            
                            // Update icon and text color
                            if let contentStack = chip.subviews.first as? UIStackView,
                               let iconView = contentStack.arrangedSubviews.first as? UIImageView,
                               let label = contentStack.arrangedSubviews.last as? UILabel {
                                iconView.tintColor = .white
                                label.textColor = .white
                            }
                            
                            // Reset scale
                            chip.transform = .identity
                        }
                    }
                }
            }
        }
        
        // Apply filter based on tag
        selectedDate = nil // Clear date filter when changing segments
        switch chipView.tag {
        case 1:
            filteredRuns = outdoorRunLogs
        case 2:
            filteredRuns = indoorRunLogs
        default:
            // Combine and sort by date
            var combined: [Any] = []
            combined.append(contentsOf: outdoorRunLogs)
            combined.append(contentsOf: indoorRunLogs)
            
            filteredRuns = combined.sorted { (first, second) -> Bool in
                let firstDate: Date?
                let secondDate: Date?
                
                if let run = first as? RunLog {
                    firstDate = run.createdAt
                } else if let run = first as? IndoorRunLog {
                    firstDate = run.createdAt
                } else {
                    firstDate = nil
                }
                
                if let run = second as? RunLog {
                    secondDate = run.createdAt
                } else if let run = second as? IndoorRunLog {
                    secondDate = run.createdAt
                } else {
                    secondDate = nil
                }
                
                if let firstDate = firstDate, let secondDate = secondDate {
                    return firstDate > secondDate
                }
                return false
            }
        }
        
        // Add haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
        
        updateStatistics()
        if showingCalendarView {
            updateCalendarView()
        }
        
        tableView.reloadData()
        
        // Update table height after filter change
        DispatchQueue.main.async {
            self.updateTableViewHeight()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadRunningHistory(page: Int = 0, refreshData: Bool = false) {
        if isLoading || (!hasMoreData && !refreshData) {
            return
        }
        
        if refreshData {
            currentPage = 0
            hasMoreData = true
            outdoorRunLogs.removeAll()
            indoorRunLogs.removeAll()
        } else {
            currentPage = page
        }
        
        isLoading = true
        loadingView.startAnimating()
        
        // Check if we have cached data from RunHistoryService
        if page == 0 && !refreshData {
            let cachedOutdoor = RunHistoryService.shared.outdoorRuns
            let cachedIndoor = RunHistoryService.shared.indoorRuns
            if !cachedOutdoor.isEmpty || !cachedIndoor.isEmpty {
                // Use cached data
                self.outdoorRunLogs = cachedOutdoor
                self.indoorRunLogs = cachedIndoor
                self.applyFilter()
                self.updateStatistics()
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
                self.loadingView.stopAnimating()
                self.isLoading = false
                return
            }
        }
        
        // Continue with regular loading if no cache is available
        backgroundQueue.async {
        let dispatchGroup = DispatchGroup()
        
            // Fetch outdoor runs
        dispatchGroup.enter()
            self.getRunningLogs { (runs, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching outdoor runs: \(error.localizedDescription)")
                    return
                }
                
                if refreshData {
                    self.outdoorRunLogs = runs ?? []
                } else {
                    // Append new runs to existing ones
                    self.outdoorRunLogs.append(contentsOf: runs ?? [])
                }
            }
            
            // Fetch indoor runs
        dispatchGroup.enter()
            self.getTreadmillLogs { (runs, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching indoor runs: \(error.localizedDescription)")
                    return
                }
                
                if refreshData {
                    self.indoorRunLogs = runs ?? []
                } else {
                    // Append new runs to existing ones
                    self.indoorRunLogs.append(contentsOf: runs ?? [])
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Update RunHistoryService cache with first page results
                if page == 0 {
                    RunHistoryService.shared.outdoorRuns = self.outdoorRunLogs
                    RunHistoryService.shared.indoorRuns = self.indoorRunLogs
                }
                
                // If we received fewer items than requested, we've reached the end
                // Note: These functions don't appear to support pagination through parameters
                // so this pagination logic might not work correctly
                if self.outdoorRunLogs.isEmpty && self.indoorRunLogs.isEmpty {
                    self.hasMoreData = false
                }
                
                self.applyFilter()
                self.updateStatistics()
                self.tableView.reloadData()
            self.refreshControl.endRefreshing()
                self.loadingView.stopAnimating()
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch Run Logs Methods
    
    /// Fetch outdoor running logs from AWS with pagination support
    private func getRunningLogs(completion: @escaping ([RunLog]?, Error?) -> Void) {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            completion(nil, NSError(domain: "RunHistoryViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }
        
        var allRunLogs: [RunLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getRuns(
                userId: userId,
                limit: 100,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { result in
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(allRunLogs, nil)
                        return
                    }
                    
                    // Convert AWSActivity to RunLog (filter out indoor runs)
                    let runLogs = data.activities.compactMap { activity -> RunLog? in
                        guard !activity.isIndoorRun else { return nil }
                        return self.convertAWSActivityToRunLog(activity)
                    }
                    
                    allRunLogs.append(contentsOf: runLogs)
                    
                    // Continue pagination if there's more data
                    if data.hasMore, let token = data.nextToken {
                        print("📥 [RunHistoryViewController] Fetching next page of outdoor runs (current: \(allRunLogs.count))...")
                        fetchPage(nextToken: token)
                    } else {
                        print("✅ [RunHistoryViewController] Fetched all outdoor runs: \(allRunLogs.count) total")
                        completion(allRunLogs, nil)
                    }
                    
                case .failure(let error):
                    print("❌ [RunHistoryViewController] Error fetching running logs: \(error.localizedDescription)")
                    // Return what we have so far, even if there was an error
                    if !allRunLogs.isEmpty {
                        completion(allRunLogs, nil)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
        
        // Start fetching from the first page
        fetchPage(nextToken: nil)
    }
    
    /// Fetch treadmill/indoor running logs from AWS with pagination support
    private func getTreadmillLogs(completion: @escaping ([IndoorRunLog]?, Error?) -> Void) {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            completion(nil, NSError(domain: "RunHistoryViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }
        
        var allIndoorLogs: [IndoorRunLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getRuns(
                userId: userId,
                limit: 100,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { result in
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(allIndoorLogs, nil)
                        return
                    }
                    
                    // Convert AWSActivity to IndoorRunLog (filter for indoor runs only)
                    let indoorLogs = data.activities.compactMap { activity -> IndoorRunLog? in
                        guard activity.isIndoorRun else { return nil }
                        return self.convertAWSActivityToIndoorRunLog(activity)
                    }
                    
                    allIndoorLogs.append(contentsOf: indoorLogs)
                    
                    // Continue pagination if there's more data
                    if data.hasMore, let token = data.nextToken {
                        print("📥 [RunHistoryViewController] Fetching next page of indoor runs (current: \(allIndoorLogs.count))...")
                        fetchPage(nextToken: token)
                    } else {
                        print("✅ [RunHistoryViewController] Fetched all indoor runs: \(allIndoorLogs.count) total")
                        completion(allIndoorLogs, nil)
                    }
                    
                case .failure(let error):
                    print("❌ [RunHistoryViewController] Error fetching treadmill logs: \(error.localizedDescription)")
                    // Return what we have so far, even if there was an error
                    if !allIndoorLogs.isEmpty {
                        completion(allIndoorLogs, nil)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
        
        // Start fetching from the first page
        fetchPage(nextToken: nil)
    }
    
    // MARK: - Conversion Methods
    
    /// Convert AWSActivity to RunLog
    private func convertAWSActivityToRunLog(_ activity: AWSActivity) -> RunLog? {
        guard !activity.isIndoorRun else { return nil }
        
        var runLog = RunLog()
        runLog.id = activity.id
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            runLog.createdAt = date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            runLog.createdAtFormatted = formatter.string(from: date)
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            runLog.createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        runLog.createdBy = activity.userId
        runLog.duration = formatDuration(activity.duration)
        
        // Use UserPreferences for metric system
        let useMetric = UserPreferences.shared.useMetricSystem
        runLog.distance = formatDistance(activity.distance, useMetric: useMetric)
        runLog.caloriesBurned = activity.calories
        runLog.type = "outdoor"
        runLog.runType = activity.runType ?? "outdoor_run"
        
        // Parse activityData JSON string for pace and location data
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Parse average pace
                    if let avgPace = json["averagePace"] as? String {
                        runLog.avgPace = avgPace
                    }
                    
                    // Parse location data if available
                    if let locationData = json["locationData"] as? [[String: Any]] {
                        runLog.locationData = locationData
                    }
                    
                    // Parse coordinate array if available
                    if let coordinateArray = json["coordinateArray"] as? [[String: Double]] {
                        runLog.coordinateArray = coordinateArray
                    }
                }
            } catch {
                print("⚠️ [RunHistoryViewController] Failed to parse activityData: \(error)")
            }
        }
        
        return runLog
    }
    
    /// Convert AWSActivity to IndoorRunLog
    private func convertAWSActivityToIndoorRunLog(_ activity: AWSActivity) -> IndoorRunLog? {
        guard activity.isIndoorRun else { return nil }
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var createdAt: Date?
        if let date = dateFormatter.date(from: activity.createdAt) {
            createdAt = date
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let createdAtFormatted = createdAt.map { formatter.string(from: $0) }
        
        var indoorLog = IndoorRunLog()
        indoorLog.id = activity.id
        indoorLog.createdBy = activity.userId
        indoorLog.createdAt = createdAt
        indoorLog.createdAtFormatted = createdAtFormatted
        indoorLog.duration = formatDuration(activity.duration)
        
        // Use UserPreferences for metric system
        let useMetric = UserPreferences.shared.useMetricSystem
        indoorLog.distance = formatDistance(activity.distance, useMetric: useMetric)
        indoorLog.caloriesBurned = activity.calories
        indoorLog.type = "indoor"
        indoorLog.runType = activity.runType ?? "treadmill_run"
        
        // Parse activityData JSON string
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Parse average pace
                    if let avgPace = json["averagePace"] as? String {
                        indoorLog.avgPace = avgPace
                    }
                    
                    // Parse treadmill data points
                    if let treadmillDataPoints = json["treadmillDataPoints"] as? [[String: Any]] {
                        indoorLog.treadmillDataPoints = treadmillDataPoints.compactMap { dict -> TreadmillDataPoint? in
                            return TreadmillDataPoint.fromDictionary(dict)
                        }
                    }
                }
            } catch {
                print("⚠️ [RunHistoryViewController] Failed to parse activityData: \(error)")
            }
        }
        
        return indoorLog
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatDistance(_ meters: Double, useMetric: Bool) -> String {
        if useMetric {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }
    
    // MARK: - Data Manipulation
    
    @objc private func filterChanged() {
        selectedDate = nil // Clear date filter when changing segments
        applyFilter()
        updateStatistics()
        if showingCalendarView {
            updateCalendarView()
        }
        
        // Update the table height after filtering
        DispatchQueue.main.async {
            self.updateTableViewHeight()
        }
    }
    
    @objc private func refreshData() {
        // Clear RunHistoryService cache when refreshing
        RunHistoryService.shared.outdoorRuns.removeAll()
        RunHistoryService.shared.indoorRuns.removeAll()
        loadRunningHistory(page: 0, refreshData: true)
    }
    
    private func applyFilter() {
        switch filterControl.selectedSegmentIndex {
        case 1: // Outdoor runs
            filteredRuns = outdoorRunLogs
        case 2: // Indoor runs
            filteredRuns = indoorRunLogs
        default: // All runs
            // Combine and sort by date
            var combined: [Any] = []
            combined.append(contentsOf: outdoorRunLogs)
            combined.append(contentsOf: indoorRunLogs)
            
            filteredRuns = combined.sorted { (first, second) -> Bool in
                let firstDate: Date?
                let secondDate: Date?
                
                if let run = first as? RunLog {
                    firstDate = run.createdAt
                } else if let run = first as? IndoorRunLog {
                    firstDate = run.createdAt
                } else {
                    firstDate = nil
                }
                
                if let run = second as? RunLog {
                    secondDate = run.createdAt
                } else if let run = second as? IndoorRunLog {
                    secondDate = run.createdAt
                } else {
                    secondDate = nil
                }
                
                if let firstDate = firstDate, let secondDate = secondDate {
                    return firstDate > secondDate
                }
                return false
            }
        }
        
        tableView.reloadData()
        
        // Update table height after data changes
        DispatchQueue.main.async {
            self.updateTableViewHeight()
        }
    }
    
    // Method to get filtered runs based on current filters
    private func getFilteredRuns() -> [Any] {
        // Apply date filter if a specific date is selected
        if let selectedDate = selectedDate {
            return filteredRuns.filter { run in
                if let outdoorRun = run as? RunLog, let date = outdoorRun.createdAt {
                    return Calendar.current.isDate(date, inSameDayAs: selectedDate)
                } else if let indoorRun = run as? IndoorRunLog, let date = indoorRun.createdAt {
                    return Calendar.current.isDate(date, inSameDayAs: selectedDate)
                }
                return false
            }
        }
        
        // If no date filter is active, return all filtered runs
        return filteredRuns
    }
    
    // MARK: - Stats Card Creation

    private func createStatsCard(title: String, iconName: String, value: String, unit: String, color: UIColor) -> UIView {
        // Create a simple card view
        let cardView = UIView()
        cardView.backgroundColor = UIColor(hex: 0x131D2E)
        cardView.layer.cornerRadius = 16
        
        // Add shadow
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1
        
        // Create main content stack view
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.distribution = .equalSpacing
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)
        
        // Create header stack (icon + title)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        
        // Create icon
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = color
        
        // Create icon background
        let iconBackground = UIView()
        iconBackground.backgroundColor = color.withAlphaComponent(0.15)
        iconBackground.layer.cornerRadius = 12
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        
        iconBackground.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            
            iconBackground.widthAnchor.constraint(equalToConstant: 28),
            iconBackground.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        
        // Add icon and title to header stack
        headerStack.addArrangedSubview(iconBackground)
        headerStack.addArrangedSubview(titleLabel)
        
        // Create value stack
        let valueStack = UIStackView()
        valueStack.axis = .horizontal
        valueStack.spacing = 4
        valueStack.alignment = .lastBaseline
        
        // Create value label
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.tag = 1001 // Tag for potential animation targeting
        
        // Create unit label
        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        unitLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        
        // Add value and unit to value stack
        valueStack.addArrangedSubview(valueLabel)
        if !unit.isEmpty {
            valueStack.addArrangedSubview(unitLabel)
        }
        
        // Add all components to main stack
        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(valueStack)
        
        // Set constraints for content stack
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
        
        return cardView
    }
    
    // Change the updateStatistics method to no longer have the override keyword
    func updateStatistics() {
        // Get the currently filtered runs
        let currentRuns = getFilteredRuns()
        
        // Calculate totals
        var totalDistance: Double = 0
        var totalDuration: Double = 0
        var totalCalories: Double = 0
        
        // Calculate average pace (using actual paces, not just duration/distance)
        var paceValues: [Double] = []
        
        // Parse data from all filtered runs
        for run in currentRuns {
            // Extract distance
            if let outdoorRun = run as? RunLog {
                // Handle outdoor run
                if let distVal = outdoorRun.distance as? NSNumber {
                    totalDistance += distVal.doubleValue
                } else if let distanceStr = outdoorRun.distance as? String, let dist = Double(distanceStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                    totalDistance += dist
                } else if let distanceVal = outdoorRun.distance as? Double {
                    totalDistance += distanceVal
                }
                
                // Extract duration using the duration property directly
                if let durationStr = outdoorRun.duration, !durationStr.isEmpty {
                    let seconds = convertTimeStringToSeconds(durationStr)
                    totalDuration += Double(seconds)
                }
                
                // Extract pace from avgPace property
                if let paceStr = outdoorRun.avgPace, !paceStr.isEmpty {
                    if let paceSeconds = convertPaceStringToSeconds(paceStr) {
                        paceValues.append(Double(paceSeconds))
                    }
                }
                
                // Extract calories - use caloriesBurned
                if let caloriesVal = outdoorRun.caloriesBurned {
                    totalCalories += caloriesVal
                }
            } else if let indoorRun = run as? IndoorRunLog {
                // Handle indoor run
                if let distVal = indoorRun.distance as? NSNumber {
                    totalDistance += distVal.doubleValue
                } else if let distanceStr = indoorRun.distance as? String, let dist = Double(distanceStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                    totalDistance += dist
                } else if let distanceVal = indoorRun.distance as? Double {
                    totalDistance += distanceVal
                }
                
                // Extract duration using the duration property directly
                if let durationStr = indoorRun.duration, !durationStr.isEmpty {
                    let seconds = convertTimeStringToSeconds(durationStr)
                    totalDuration += Double(seconds)
                }
                
                // Extract pace from avgPace property
                if let paceStr = indoorRun.avgPace, !paceStr.isEmpty {
                    if let paceSeconds = convertPaceStringToSeconds(paceStr) {
                        paceValues.append(Double(paceSeconds))
                    }
                }
                
                // Extract calories - use caloriesBurned
                if let caloriesVal = indoorRun.caloriesBurned {
                    totalCalories += caloriesVal
                }
            }
        }
        
        // Calculate average pace from collected pace values or fallback to distance/duration
        var avgPaceSeconds: Int = 0
        if !paceValues.isEmpty {
            // Use actual average of pace values when available
            let avgPaceValue = paceValues.reduce(0, +) / Double(paceValues.count)
            avgPaceSeconds = Int(avgPaceValue)
        } else if totalDistance > 0 && totalDuration > 0 {
            // Fallback to calculated pace
            avgPaceSeconds = Int(totalDuration / totalDistance)
        }
        
        // Update the stat cards directly
        updateStatCard(title: "DISTANCE", value: totalDistance, formatString: totalDistance < 100 ? "%.2f" : "%.1f")
        updateStatCard(title: "AVG PACE", paceSeconds: avgPaceSeconds)
        updateStatCard(title: "TOTAL TIME", timeSeconds: Int(totalDuration))
        updateStatCard(title: "CALORIES", value: totalCalories, formatString: "%.0f")
        
        // Check for any new badges
        checkForNewBadges()
    }
    
    // Helper method to convert pace strings like "5:30/km" to seconds
    private func convertPaceStringToSeconds(_ paceString: String) -> Int? {
        // Remove the "/km" or "/mi" suffix
        let paceOnly = paceString.replacingOccurrences(of: "/.*$", with: "", options: .regularExpression)
        
        // Split by colon
        let components = paceOnly.components(separatedBy: ":")
        if components.count == 2,
           let minutes = Int(components[0]),
           let seconds = Int(components[1]) {
            return minutes * 60 + seconds
        }
        return nil
    }
    
    // Helper method to convert time strings like "25:30" or "1:25:30" to seconds
    private func convertTimeStringToSeconds(_ timeString: String) -> Int {
        let components = timeString.components(separatedBy: ":")
        
        if components.count == 3 {
            // Format: HH:MM:SS
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  let seconds = Int(components[2]) else {
                return 0
            }
            return hours * 3600 + minutes * 60 + seconds
        } else if components.count == 2 {
            // Format: MM:SS
            guard let minutes = Int(components[0]),
                  let seconds = Int(components[1]) else {
                return 0
            }
            return minutes * 60 + seconds
        }
        
        // If we can't parse it, try to convert the entire string to a number
        if let totalSeconds = Double(timeString) {
            return Int(totalSeconds)
        }
        
        return 0
    }
    
    // Helper method to find and update a stat card with numeric value
    private func updateStatCard(title: String, value: Double, formatString: String) {
        // Get all stack views in statsHeaderView
        let stackViews = statsHeaderView.subviews.compactMap { $0 as? UIStackView }
        
        for rowStack in stackViews {
            for case let cardView as UIView in rowStack.arrangedSubviews {
                // Search through all content stacks inside the card view
                for subview in cardView.subviews {
                    if let contentStack = subview as? UIStackView {
                        // Check if this card has the correct title
                        let foundCard = contentStack.arrangedSubviews.contains { stackItem in
                            if let headerStack = stackItem as? UIStackView {
                                return headerStack.arrangedSubviews.contains { item in
                                    if let label = item as? UILabel, label.text == title {
                                        return true
                                    }
                                    return false
                                }
                            }
                            return false
                        }
                        
                        if foundCard, contentStack.arrangedSubviews.count > 1,
                           let valueStack = contentStack.arrangedSubviews[1] as? UIStackView,
                           let valueLabel = valueStack.arrangedSubviews.first as? UILabel {
                            
                            // Get current displayed value for animation
                            let currentText = valueLabel.text ?? "--"
                            let currentValue = Double(currentText.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
                            
                            // Animate the counter
                            animateCounter(
                                label: valueLabel,
                                startValue: currentValue,
                                endValue: value,
                                duration: 1.0,
                                formatString: formatString,
                                animationType: .easeOut
                            )
                            
                            return
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to update pace value
    private func updateStatCard(title: String, paceSeconds: Int) {
        // Get all stack views in statsHeaderView
        let stackViews = statsHeaderView.subviews.compactMap { $0 as? UIStackView }
        
        for rowStack in stackViews {
            for case let cardView as UIView in rowStack.arrangedSubviews {
                // Search through all content stacks inside the card view
                for subview in cardView.subviews {
                    if let contentStack = subview as? UIStackView {
                        // Check if this card has the correct title
                        let foundCard = contentStack.arrangedSubviews.contains { stackItem in
                            if let headerStack = stackItem as? UIStackView {
                                return headerStack.arrangedSubviews.contains { item in
                                    if let label = item as? UILabel, label.text == title {
                                        return true
                                    }
                                    return false
                                }
                            }
                            return false
                        }
                        
                        if foundCard, contentStack.arrangedSubviews.count > 1,
                           let valueStack = contentStack.arrangedSubviews[1] as? UIStackView,
                           let valueLabel = valueStack.arrangedSubviews.first as? UILabel {
                            
                            // Get current pace value for animation
                            let currentText = valueLabel.text ?? "--:--"
                            var currentPaceSeconds = 0
                            
                            if currentText != "--:--" {
                                let components = currentText.components(separatedBy: ":")
                                if components.count == 2,
                                   let minutes = Int(components[0]),
                                   let seconds = Int(components[1]) {
                                    currentPaceSeconds = minutes * 60 + seconds
                                }
                            }
                            
                            // Animate the pace update
                            animatePaceCounter(
                                label: valueLabel,
                                startSeconds: currentPaceSeconds,
                                endSeconds: paceSeconds,
                                duration: 1.0
                            )
                            
                            return
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to update time value
    private func updateStatCard(title: String, timeSeconds: Int) {
        // Get all stack views in statsHeaderView
        let stackViews = statsHeaderView.subviews.compactMap { $0 as? UIStackView }
        
        for rowStack in stackViews {
            for case let cardView as UIView in rowStack.arrangedSubviews {
                // Search through all content stacks inside the card view
                for subview in cardView.subviews {
                    if let contentStack = subview as? UIStackView {
                        // Check if this card has the correct title
                        let foundCard = contentStack.arrangedSubviews.contains { stackItem in
                            if let headerStack = stackItem as? UIStackView {
                                return headerStack.arrangedSubviews.contains { item in
                                    if let label = item as? UILabel, label.text == title {
                                        return true
                                    }
                                    return false
                                }
                            }
                            return false
                        }
                        
                        if foundCard, contentStack.arrangedSubviews.count > 1,
                           let valueStack = contentStack.arrangedSubviews[1] as? UIStackView,
                           let valueLabel = valueStack.arrangedSubviews.first as? UILabel {
                            
                            // Get current time value for animation
                            let currentText = valueLabel.text ?? "--:--"
                            var currentTimeSeconds = 0
                            
                            if currentText != "--:--" {
                                let components = currentText.components(separatedBy: ":")
                                if components.count == 2,
                                   let minutes = Int(components[0]),
                                   let seconds = Int(components[1]) {
                                    currentTimeSeconds = minutes * 60 + seconds
                                } else if components.count == 3,
                                          let hours = Int(components[0]),
                                          let minutes = Int(components[1]),
                                          let seconds = Int(components[2]) {
                                    currentTimeSeconds = hours * 3600 + minutes * 60 + seconds
                                }
                            }
                            
                            // Animate the time update
                            animateTimeCounter(
                                label: valueLabel,
                                startSeconds: currentTimeSeconds,
                                endSeconds: timeSeconds,
                                duration: 1.0
                            )
                            
                            return
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Animation Helpers

    enum AnimationType {
        case linear
        case easeIn
        case easeOut
        case easeInOut
    }
    
    private func animateCounter(label: UILabel, startValue: Double, endValue: Double, duration: TimeInterval, formatString: String, animationType: AnimationType) {
        // Create a display link for smooth animation
        let display = CADisplayLink(target: self, selector: #selector(updateCounterLabel))
        
        // Configure animation properties
        let animation = CounterAnimationManager(
            label: label,
            startValue: startValue,
            endValue: endValue,
            duration: duration,
            formatString: formatString,
            animationType: animationType
        )
        
        // Store animation context in display link
        display.add(to: .current, forMode: .common)
        CounterAnimationManager.animations[display] = animation
        
        // Start the animation
        animation.startTime = CACurrentMediaTime()
        
        // Schedule cleanup after animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            display.invalidate()
            CounterAnimationManager.animations.removeValue(forKey: display)
        }
    }
    
    private func animateTimeCounter(label: UILabel, startSeconds: Int, endSeconds: Int, duration: TimeInterval) {
        // Create a display link for smooth animation
        let display = CADisplayLink(target: self, selector: #selector(updateTimeLabel))
        
        // Configure animation properties
        let animation = TimeAnimationManager(
            label: label,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            duration: duration
        )
        
        // Store animation context in display link
        display.add(to: .current, forMode: .common)
        TimeAnimationManager.animations[display] = animation
        
        // Start the animation
        animation.startTime = CACurrentMediaTime()
        
        // Schedule cleanup after animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            display.invalidate()
            TimeAnimationManager.animations.removeValue(forKey: display)
        }
    }
    
    private func animatePaceCounter(label: UILabel, startSeconds: Int, endSeconds: Int, duration: TimeInterval) {
        // Create a display link for smooth animation
        let display = CADisplayLink(target: self, selector: #selector(updatePaceLabel))
        
        // Configure animation properties
        let animation = TimeAnimationManager(
            label: label,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            duration: duration
        )
        
        // Store animation context in display link
        display.add(to: .current, forMode: .common)
        TimeAnimationManager.animations[display] = animation
        
        // Start the animation
        animation.startTime = CACurrentMediaTime()
        
        // Schedule cleanup after animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            display.invalidate()
            TimeAnimationManager.animations.removeValue(forKey: display)
        }
    }
    
    // Animation manager classes to store animation state
    class CounterAnimationManager {
        static var animations = [CADisplayLink: CounterAnimationManager]()
        
        weak var label: UILabel?
        let startValue: Double
        let endValue: Double
        let duration: TimeInterval
        let formatString: String
        let animationType: AnimationType
        var startTime: CFTimeInterval = 0
        
        init(label: UILabel, startValue: Double, endValue: Double, duration: TimeInterval, formatString: String, animationType: AnimationType) {
            self.label = label
            self.startValue = startValue
            self.endValue = endValue
            self.duration = duration
            self.formatString = formatString
            self.animationType = animationType
        }
    }
    
    class TimeAnimationManager {
        static var animations = [CADisplayLink: TimeAnimationManager]()
        
        weak var label: UILabel?
        let startSeconds: Int
        let endSeconds: Int
        let duration: TimeInterval
        var startTime: CFTimeInterval = 0
        
        init(label: UILabel, startSeconds: Int, endSeconds: Int, duration: TimeInterval) {
            self.label = label
            self.startSeconds = startSeconds
            self.endSeconds = endSeconds
            self.duration = duration
        }
    }
    
    @objc private func updateCounterLabel(displayLink: CADisplayLink) {
        guard let animation = CounterAnimationManager.animations[displayLink],
              let label = animation.label else {
            displayLink.invalidate()
            CounterAnimationManager.animations.removeValue(forKey: displayLink)
            return
        }
        
        let elapsed = CACurrentMediaTime() - animation.startTime
        let progress = min(elapsed / animation.duration, 1.0)
        
        // Apply easing function based on animation type
        let easedProgress: Double
        switch animation.animationType {
        case .linear:
            easedProgress = progress
        case .easeIn:
            easedProgress = progress * progress
        case .easeOut:
            easedProgress = 1 - pow(1 - progress, 2)
        case .easeInOut:
            easedProgress = progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2
        }
        
        let value = animation.startValue + (animation.endValue - animation.startValue) * easedProgress
        label.text = String(format: animation.formatString, value)
        
        // Add subtle scale animation for emphasis
        if progress < 1.0 {
            let pulse = 1.0 + 0.05 * sin(progress * Double.pi * 8)
            label.transform = CGAffineTransform(scaleX: pulse, y: pulse)
        } else {
            label.transform = .identity
        }
    }
    
    @objc private func updateTimeLabel(displayLink: CADisplayLink) {
        guard let animation = TimeAnimationManager.animations[displayLink],
              let label = animation.label else {
            displayLink.invalidate()
            TimeAnimationManager.animations.removeValue(forKey: displayLink)
            return
        }
        
        let elapsed = CACurrentMediaTime() - animation.startTime
        let progress = min(elapsed / animation.duration, 1.0)
        
        // Apply easing function (ease out for smoother finish)
        let easedProgress = 1 - pow(1 - progress, 2)
        
        let currentSeconds = Int(Double(animation.startSeconds) + Double(animation.endSeconds - animation.startSeconds) * easedProgress)
        
        // Format time as MM:SS or HH:MM:SS
        let hours = currentSeconds / 3600
        let minutes = (currentSeconds % 3600) / 60
        let seconds = currentSeconds % 60
        
        if hours > 0 {
            label.text = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            label.text = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Add subtle scale animation for emphasis
        if progress < 1.0 {
            let pulse = 1.0 + 0.05 * sin(progress * Double.pi * 8)
            label.transform = CGAffineTransform(scaleX: pulse, y: pulse)
        } else {
            label.transform = .identity
        }
    }
    
    @objc private func updatePaceLabel(displayLink: CADisplayLink) {
        guard let animation = TimeAnimationManager.animations[displayLink],
              let label = animation.label else {
            displayLink.invalidate()
            TimeAnimationManager.animations.removeValue(forKey: displayLink)
            return
        }
        
        let elapsed = CACurrentMediaTime() - animation.startTime
        let progress = min(elapsed / animation.duration, 1.0)
        
        // Apply easing function (ease out for smoother finish)
        let easedProgress = 1 - pow(1 - progress, 2)
        
        let currentSeconds = Int(Double(animation.startSeconds) + Double(animation.endSeconds - animation.startSeconds) * easedProgress)
        
        // Format pace as MM:SS
        let minutes = currentSeconds / 60
        let seconds = currentSeconds % 60
        
        // Get the correct pace unit
        let useMetric = UserPreferences.shared.useMetricSystem
        let paceUnit = useMetric ? "/km" : "/mi"
        
        label.text = String(format: "%d:%02d", minutes, seconds)
        
        // Add subtle scale animation for emphasis
        if progress < 1.0 {
            let pulse = 1.0 + 0.05 * sin(progress * Double.pi * 8)
            label.transform = CGAffineTransform(scaleX: pulse, y: pulse)
        } else {
            label.transform = .identity
        }
    }
    
    // MARK: - Helper Functions
    
    @objc private func dismissViewController() {
        // Call delegate before dismissing
        delegate?.didDismiss()
        
        // Dismiss the view controller
        dismiss(animated: true, completion: nil)
    }
    
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRuns.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RunLogCell", for: indexPath) as? RunLogCell else {
            return UITableViewCell()
        }
        
        let run = filteredRuns[indexPath.row]
        let isOutdoorRun = run is RunLog
        
        cell.configure(with: run, isOutdoorRun: isOutdoorRun)
        
        // Set cell background to match rest of UI
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 128 // Adjusted height for better cell layout
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get the selected run
        let filteredRuns = getFilteredRuns()
        guard indexPath.row < filteredRuns.count else { return }
        
        let selectedRun = filteredRuns[indexPath.row]
        presentRunAnalysis(for: selectedRun)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // If we're displaying the last cell, update the table height
        if indexPath.row == filteredRuns.count - 1 {
            updateTableViewHeight()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Only handle scrolling for the main scroll view, not the table view
        if scrollView != mainScrollView {
            return
        }
        
        // Check if we should load more data (reached near bottom)
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offsetY > contentHeight - height * 1.5 {
            if !isLoading && hasMoreData {
                loadRunningHistory(page: currentPage + 1)
            }
        }
    }
    
    // MARK: - Calendar Setup and Functions
    
    private func setupCalendarView() {
        // Setup calendar container with matching dark background
        calendarViewContainer.backgroundColor = UIColor(hex: 0x131D2E)
        calendarViewContainer.layer.cornerRadius = 16
        calendarViewContainer.layer.shadowColor = UIColor.black.cgColor
        calendarViewContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        calendarViewContainer.layer.shadowOpacity = 0.3
        calendarViewContainer.layer.shadowRadius = 8
        calendarViewContainer.isHidden = false // Make visible by default
        showingCalendarView = true // Set to true since calendar is visible
        
        // Add to content container
        calendarViewContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(calendarViewContainer)
        
        // Calendar header
        let headerView = UIView()
        headerView.backgroundColor = UIColor(hex: 0x1A2536)
        headerView.layer.cornerRadius = 16
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        calendarViewContainer.addSubview(headerView)
        
        // Setup month navigation header
        monthLabel.text = formatMonthYear(date: currentCalendarDate)
        monthLabel.textColor = .white
        monthLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        headerView.addSubview(monthLabel)
        
        // Previous month button
        previousMonthButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousMonthButton.tintColor = .white
        previousMonthButton.addTarget(self, action: #selector(showPreviousMonth), for: .touchUpInside)
        headerView.addSubview(previousMonthButton)
        
        // Next month button
        nextMonthButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextMonthButton.tintColor = .white
        nextMonthButton.addTarget(self, action: #selector(showNextMonth), for: .touchUpInside)
        headerView.addSubview(nextMonthButton)
        
        // Setup day of week labels (S M T W T F S)
        let weekdayStack = UIStackView()
        weekdayStack.axis = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.spacing = 4
        headerView.addSubview(weekdayStack)
        
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        for day in weekdays {
            let label = UILabel()
            label.text = day
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            label.textAlignment = .center
            weekdayStack.addArrangedSubview(label)
        }
        
        // Create more robust collection view layout with proper sizing
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        
        // Calculate proper item size based on container width
        let screenWidth = UIScreen.main.bounds.width
        let containerWidth = screenWidth - 32 // Account for leading/trailing margins (16 each)
        let availableWidth = containerWidth - 32 // Account for internal padding (16 each)
        let itemWidth = floor((availableWidth - (6 * 4)) / 7) // 7 columns, 6 spaces between them
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        
        // Update the global daySize to match
        daySize = itemWidth
        
        // Apply the layout to the collection view
        calendarCollectionView.setCollectionViewLayout(layout, animated: false)
        calendarCollectionView.backgroundColor = .clear
        calendarCollectionView.delegate = self
        calendarCollectionView.dataSource = self
        calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "CalendarDayCell")
        calendarCollectionView.isScrollEnabled = false
        calendarViewContainer.addSubview(calendarCollectionView)
        
        // Add a heat map legend
        let legendView = createHeatMapLegend()
        legendView.translatesAutoresizingMaskIntoConstraints = false
        calendarViewContainer.addSubview(legendView)
        
        // Setup constraints
        headerView.translatesAutoresizingMaskIntoConstraints = false
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        previousMonthButton.translatesAutoresizingMaskIntoConstraints = false
        nextMonthButton.translatesAutoresizingMaskIntoConstraints = false
        weekdayStack.translatesAutoresizingMaskIntoConstraints = false
        calendarCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Calendar container width constraints - match content container width with margins
            calendarViewContainer.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            calendarViewContainer.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            
            // Header view
            headerView.topAnchor.constraint(equalTo: calendarViewContainer.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor),
            
            // Month header
            monthLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            monthLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            // Navigation buttons
            previousMonthButton.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
            previousMonthButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            previousMonthButton.widthAnchor.constraint(equalToConstant: 44),
            previousMonthButton.heightAnchor.constraint(equalToConstant: 44),
            
            nextMonthButton.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
            nextMonthButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            nextMonthButton.widthAnchor.constraint(equalToConstant: 44),
            nextMonthButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Weekday labels
            weekdayStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 16),
            weekdayStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            weekdayStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            weekdayStack.heightAnchor.constraint(equalToConstant: 20),
            weekdayStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
            
            // Calendar collection view - explicitly set the width to match container width minus padding
            calendarCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            calendarCollectionView.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor, constant: 16),
            calendarCollectionView.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor, constant: -16),
            // Calculate height based on number of weeks and item size
            calendarCollectionView.heightAnchor.constraint(equalToConstant: CGFloat(maxWeeks) * (itemWidth + 4)),
            
            // Legend view
            legendView.topAnchor.constraint(equalTo: calendarCollectionView.bottomAnchor, constant: 8),
            legendView.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor, constant: 16),
            legendView.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor, constant: -16),
            legendView.bottomAnchor.constraint(equalTo: calendarViewContainer.bottomAnchor, constant: -16),
            legendView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Generate calendar data
        calendarDays = generateDaysInMonth(for: currentCalendarDate)
        processDaysWithRunData()
    }
    
    private func createHeatMapLegend() -> UIView {
        let legendView = UIView()
        legendView.backgroundColor = UIColor(hex: 0x131D2E)
        
        // Create a horizontal stack for the legend items
        let legendStack = UIStackView()
        legendStack.axis = .horizontal
        legendStack.distribution = .equalSpacing
        legendStack.alignment = .center
        legendStack.spacing = 12
        legendStack.translatesAutoresizingMaskIntoConstraints = false
        legendView.addSubview(legendStack)
        
        // Create legend items
        let legendItems: [(color: UIColor, text: String)] = [
            (UIColor(hex: 0x4CD964).withAlphaComponent(0.3), "Light"),
            (UIColor(hex: 0x4CD964).withAlphaComponent(0.6), "Medium"),
            (UIColor(hex: 0x4CD964).withAlphaComponent(0.9), "High")
        ]
        
        for (color, text) in legendItems {
            let itemStack = UIStackView()
            itemStack.axis = .horizontal
            itemStack.spacing = 4
            itemStack.alignment = .center
            
            // Create color indicator
            let colorView = UIView()
            colorView.backgroundColor = color
            colorView.layer.cornerRadius = 4
            
            // Create label
            let label = UILabel()
            label.text = text
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            
            // Add constraints to color view
            colorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
                colorView.widthAnchor.constraint(equalToConstant: 16),
                colorView.heightAnchor.constraint(equalToConstant: 8)
            ])
            
            // Add to stack
            itemStack.addArrangedSubview(colorView)
            itemStack.addArrangedSubview(label)
            
            // Add to legend stack
            legendStack.addArrangedSubview(itemStack)
        }
        
        // Title
        let legendTitle = UILabel()
        legendTitle.text = "Activity:"
        legendTitle.textColor = UIColor.white.withAlphaComponent(0.8)
        legendTitle.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        legendStack.insertArrangedSubview(legendTitle, at: 0)
        
        // Constrain stack to view
        NSLayoutConstraint.activate([
            legendStack.leadingAnchor.constraint(equalTo: legendView.leadingAnchor, constant: 8),
            legendStack.trailingAnchor.constraint(lessThanOrEqualTo: legendView.trailingAnchor, constant: -8),
            legendStack.centerYAnchor.constraint(equalTo: legendView.centerYAnchor),
            legendStack.centerXAnchor.constraint(equalTo: legendView.centerXAnchor)
        ])
        
        return legendView
    }
    
    @objc private func showPreviousMonth() {
        guard let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentCalendarDate) else { return }
        currentCalendarDate = previousMonth
        updateCalendarView()
    }
    
    @objc private func showNextMonth() {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentCalendarDate) else { return }
        currentCalendarDate = nextMonth
        updateCalendarView()
    }
    
    private func updateCalendarView() {
        monthLabel.text = formatMonthYear(date: currentCalendarDate)
        updateCalendarDays()
        calendarCollectionView.reloadData()
    }
    
    private func formatMonthYear(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func setupCalendarIfNeeded() {
        // Only setup calendar components if they haven't been set up already
        if calendarViewContainer.superview == nil {
            
            // Setup calendar container with dark theme
            calendarViewContainer.backgroundColor = UIColor(hex: 0x0F1729)
            calendarViewContainer.layer.cornerRadius = 16
            calendarViewContainer.layer.shadowColor = UIColor.black.cgColor
            calendarViewContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
            calendarViewContainer.layer.shadowOpacity = 0.3
            calendarViewContainer.layer.shadowRadius = 10
            calendarViewContainer.isHidden = true
            view.addSubview(calendarViewContainer)
            
            // Month label setup
            monthLabel.text = formatMonth(date: currentCalendarDate)
            monthLabel.textColor = .white
            monthLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            monthLabel.textAlignment = .center
            calendarViewContainer.addSubview(monthLabel)
            
            // Navigation buttons
            previousMonthButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            previousMonthButton.tintColor = .white
            previousMonthButton.addTarget(self, action: #selector(showPreviousMonth), for: .touchUpInside)
            calendarViewContainer.addSubview(previousMonthButton)
            
            nextMonthButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
            nextMonthButton.tintColor = .white
            nextMonthButton.addTarget(self, action: #selector(showNextMonth), for: .touchUpInside)
            calendarViewContainer.addSubview(nextMonthButton)
            
            // Day of week labels
            let weekdayStack = UIStackView()
            weekdayStack.axis = .horizontal
            weekdayStack.distribution = .fillEqually
            weekdayStack.spacing = 0
            calendarViewContainer.addSubview(weekdayStack)
            
            // Add day labels (Su Mo Tu We Th Fr Sa)
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            for day in weekdays {
                let label = UILabel()
                label.text = day
                label.textColor = UIColor.white.withAlphaComponent(0.6)
                label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                label.textAlignment = .center
                weekdayStack.addArrangedSubview(label)
            }
            
            // Setup collection view
            calendarCollectionView.backgroundColor = .clear
            calendarCollectionView.delegate = self
            calendarCollectionView.dataSource = self
            calendarCollectionView.isScrollEnabled = false
            calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "CalendarDayCell")
            calendarViewContainer.addSubview(calendarCollectionView)
            
            // Setup constraints
            calendarViewContainer.translatesAutoresizingMaskIntoConstraints = false
            monthLabel.translatesAutoresizingMaskIntoConstraints = false
            previousMonthButton.translatesAutoresizingMaskIntoConstraints = false
            nextMonthButton.translatesAutoresizingMaskIntoConstraints = false
            weekdayStack.translatesAutoresizingMaskIntoConstraints = false
            calendarCollectionView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                // Container placement
                calendarViewContainer.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 16),
                calendarViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                calendarViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                
                // Month header
                monthLabel.topAnchor.constraint(equalTo: calendarViewContainer.topAnchor, constant: 16),
                monthLabel.centerXAnchor.constraint(equalTo: calendarViewContainer.centerXAnchor),
                
                // Navigation buttons
                previousMonthButton.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor, constant: 16),
                previousMonthButton.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
                previousMonthButton.widthAnchor.constraint(equalToConstant: 32),
                previousMonthButton.heightAnchor.constraint(equalToConstant: 32),
                
                nextMonthButton.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor, constant: -16),
                nextMonthButton.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
                nextMonthButton.widthAnchor.constraint(equalToConstant: 32),
                nextMonthButton.heightAnchor.constraint(equalToConstant: 32),
                
                // Weekday labels
                weekdayStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 16),
                weekdayStack.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor, constant: 16),
                weekdayStack.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor, constant: -16),
                weekdayStack.heightAnchor.constraint(equalToConstant: 20),
                
                // Collection view
                calendarCollectionView.topAnchor.constraint(equalTo: weekdayStack.bottomAnchor, constant: 8),
                calendarCollectionView.leadingAnchor.constraint(equalTo: calendarViewContainer.leadingAnchor, constant: 16),
                calendarCollectionView.trailingAnchor.constraint(equalTo: calendarViewContainer.trailingAnchor, constant: -16),
                calendarCollectionView.heightAnchor.constraint(equalToConstant: CGFloat(maxWeeks) * (daySize + 4)),
                calendarCollectionView.bottomAnchor.constraint(equalTo: calendarViewContainer.bottomAnchor, constant: -16)
            ])
            
            // Adjust table view to make room for calendar
            let existingTableTopConstraint = tableView.constraints.first { constraint in
                if let firstItem = constraint.firstItem as? UIView, firstItem == tableView,
                   let secondItem = constraint.secondItem as? UIView, secondItem == filterControl,
                   constraint.firstAttribute == .top && constraint.secondAttribute == .bottom {
                    return true
                }
                return false
            }
            
            if let existingConstraint = existingTableTopConstraint {
                existingConstraint.isActive = false
                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: calendarViewContainer.bottomAnchor, constant: 16)
                ])
            }
            
            // Generate initial calendar data
            calendarDays = generateDaysInMonth(for: currentCalendarDate)
        }
    }
    
    private func updateCalendarDays() {
        calendarDays = generateDaysInMonth(for: currentCalendarDate)
        processDaysWithRunData()
        calendarCollectionView.reloadData()
    }
    
    private func generateDaysInMonth(for date: Date) -> [CalendarDay] {
        let calendar = Calendar.current
        
        // Get the start of the month
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        
        // Get the first weekday (0 = Sunday, 1 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Calculate days in month
        let range = calendar.range(of: .day, in: .month, for: date)
        let daysInMonth = range?.count ?? 30
        
        var days: [CalendarDay] = []
        
        // Add empty days for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(CalendarDay(date: nil, totalDistance: 0, totalDuration: 0, intensity: .none))
        }
        
        // Add days for the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day-1, to: startOfMonth) {
                days.append(CalendarDay(date: date, totalDistance: 0, totalDuration: 0, intensity: .none))
            }
        }
        
        // Fill remaining cells to complete the grid (if needed)
        let remainingCells = maxWeeks * daysInWeek - days.count
        if remainingCells > 0 {
            for _ in 0..<remainingCells {
                days.append(CalendarDay(date: nil, totalDistance: 0, totalDuration: 0, intensity: .none))
            }
        }
        
        return days
    }
    
    private func processDaysWithRunData() {
        // Reset intensities
        for i in 0..<calendarDays.count {
            if calendarDays[i].date != nil {
                calendarDays[i].intensity = .none
                calendarDays[i].totalDistance = 0
                calendarDays[i].totalDuration = 0
            }
        }
        
        // Combine all runs (outdoor and indoor)
        let allRuns = outdoorRunLogs + indoorRunLogs as [Any]
        
        for run in allRuns {
            var date: Date? = nil // Initialize with nil
            var runDistance: Double = 0
            var runDuration: Double = 0
        
        if let outdoorRun = run as? RunLog {
                date = outdoorRun.createdAt
                
                // Extract distance
                if let distVal = outdoorRun.distance as? NSNumber {
                    runDistance = distVal.doubleValue
                } else if let distanceStr = outdoorRun.distance as? String, let dist = Double(distanceStr) {
                    runDistance = dist
                } else if let distance = outdoorRun.distance as? Double {
                    runDistance = distance
                }
                
                // Extract duration
                if let duration = outdoorRun.duration as? NSNumber {
                    runDuration = duration.doubleValue
                } else if let durationStr = outdoorRun.duration as? String, let duration = Double(durationStr) {
                    runDuration = duration
                } else if let duration = outdoorRun.duration as? Double {
                    runDuration = duration
                } else if let duration = outdoorRun.duration as? Int {
                    runDuration = Double(duration)
                }
        } else if let indoorRun = run as? IndoorRunLog {
                date = indoorRun.createdAt
                
                // Extract distance
                if let distVal = indoorRun.distance as? NSNumber {
                    runDistance = distVal.doubleValue
                } else if let distanceStr = indoorRun.distance as? String, let dist = Double(distanceStr) {
                    runDistance = dist
                } else if let distance = indoorRun.distance as? Double {
                    runDistance = distance
                }
                
                // Extract duration
                if let duration = indoorRun.duration as? NSNumber {
                    runDuration = duration.doubleValue
                } else if let durationStr = indoorRun.duration as? String, let duration = Double(durationStr) {
                    runDuration = duration
                } else if let duration = indoorRun.duration as? Double {
                    runDuration = duration
                } else if let duration = indoorRun.duration as? Int {
                    runDuration = Double(duration)
                }
                
                // Extract calories value safely
                var totalCalories: Double = 0.0
                if let calories = indoorRun.caloriesBurned as? NSNumber {
                    totalCalories += calories.doubleValue
                } else if let caloriesStr = indoorRun.caloriesBurned as? String, let value = Double(caloriesStr) {
                    totalCalories += value
                } else if let calories = indoorRun.caloriesBurned as? Double {
                    totalCalories += calories
                }
            }
            
            guard let runDate = date else { continue }
            
            // Find matching calendar day
            if let index = findDayIndexInCalendar(for: runDate) {
                calendarDays[index].totalDistance += runDistance
                calendarDays[index].totalDuration += runDuration
                
                // Determine intensity based on combined metrics (distance and duration)
                let intensity = calculateIntensity(
                    distance: calendarDays[index].totalDistance,
                    duration: calendarDays[index].totalDuration
                )
                
                // Update the intensity
                    calendarDays[index].intensity = intensity
            }
        }
    }
    
    private func findDayIndexInCalendar(for date: Date) -> Int? {
        let calendar = Calendar.current
        
        for (index, day) in calendarDays.enumerated() {
            guard let dayDate = day.date else { continue }
            
            if calendar.isDate(dayDate, inSameDayAs: date) {
                return index
            }
        }
        
        return nil
    }
    
    private func calculateIntensity(distance: Double, duration: Double) -> CalendarDay.Intensity {
        // More sophisticated intensity calculation based on both distance and duration
        
        // Convert duration from seconds to minutes for easier calculation
        let durationMinutes = duration / 60.0
        
        // Scoring system (0-100)
        var score: Double = 0
        
        // Distance-based scoring (0-70 points)
        if distance > 20 {
            score += 70 // Marathon or ultra distance
        } else if distance > 15 {
            score += 60 // More than 15km
        } else if distance > 10 {
            score += 50 // More than 10km
        } else if distance > 5 {
            score += 40 // More than 5km
        } else if distance > 3 {
            score += 30 // More than 3km
        } else if distance > 1 {
            score += 20 // More than 1km
        } else if distance > 0 {
            score += 10 // Any distance
        }
        
        // Duration-based scoring (0-30 points)
        if durationMinutes > 120 {
            score += 30 // 2+ hours
        } else if durationMinutes > 90 {
            score += 25 // 90+ minutes
        } else if durationMinutes > 60 {
            score += 20 // 60+ minutes
        } else if durationMinutes > 45 {
            score += 15 // 45+ minutes
        } else if durationMinutes > 30 {
            score += 10 // 30+ minutes
        } else if durationMinutes > 15 {
            score += 5 // 15+ minutes
        } else if durationMinutes > 0 {
            score += 2 // Any duration
        }
        
        // Map score to intensity
        if score >= 60 {
            return .high
        } else if score >= 30 {
            return .medium
        } else if score > 0 {
            return .low
        } else {
            return .none
        }
    }
    
    private func formatMonth(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    @objc private func didSelectCalendarDay(_ date: Date) {
        let calendar = Calendar.current
        
        // Check if the day has any activity data
        if let index = findDayIndexInCalendar(for: date),
           calendarDays[index].totalDistance > 0 {
            
            // Show activity summary in a tooltip
            showActivitySummary(for: calendarDays[index])
        }
        
        // If the same date is selected again, clear the filter
        if let selectedDate = selectedDate, Calendar.current.isDate(selectedDate, inSameDayAs: date) {
            self.selectedDate = nil
        } else {
            selectedDate = date
        }
        
        // Apply date filter
        applyFilters()
        calendarCollectionView.reloadData()
    }
    
    private func showActivitySummary(for day: CalendarDay) {
        guard let date = day.date else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: date)
        
        // Format the distance and duration
        let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
        let distanceString = String(format: "%.2f %@", day.totalDistance, distanceUnit)
        
        // Convert duration from seconds to HH:MM:SS format
        let hours = Int(day.totalDuration) / 3600
        let minutes = (Int(day.totalDuration) % 3600) / 60
        let seconds = Int(day.totalDuration) % 60
        let durationString: String
        if hours > 0 {
            durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            durationString = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Determine intensity description
        let intensityDescription: String
        switch day.intensity {
        case .high:
            intensityDescription = "High intensity workout day"
        case .medium:
            intensityDescription = "Medium intensity workout day"
        case .low:
            intensityDescription = "Light workout day"
        case .none:
            intensityDescription = "No workout activity"
        }
        
        // Create alert with activity details
        let alertController = UIAlertController(
            title: "Activity on \(dateString)",
            message: "\(intensityDescription)\n\nTotal Distance: \(distanceString)\nTotal Duration: \(durationString)",
            preferredStyle: .alert
        )
        
        // Close button
        alertController.addAction(UIAlertAction(title: "Close", style: .default))
        
        // View all activities button (only if there are multiple activities)
        alertController.addAction(UIAlertAction(title: "View Activities", style: .default) { [weak self] _ in
            // This will already happen because the date filter is applied in didSelectCalendarDay
        })
        
        present(alertController, animated: true)
    }
    
    private func applyFilters() {
        // First apply the type filter (All, Outdoor, Indoor)
        applyFilter()
        
        // Then apply date filter if needed
        if let selectedDate = selectedDate {
            let calendar = Calendar.current
            filteredRuns = filteredRuns.filter { run in
                let runDate: Date?
            
            if let outdoorRun = run as? RunLog {
                    runDate = outdoorRun.createdAt
            } else if let indoorRun = run as? IndoorRunLog {
                    runDate = indoorRun.createdAt
                } else {
                    runDate = nil
                }
                
                guard let date = runDate else { return false }
                return calendar.isDate(date, inSameDayAs: selectedDate)
            }
        }
        
        // Update UI
        updateStatistics()
        tableView.reloadData()
    }
    
    // Update how pace is calculated in updateStatistics() method
    private func calculateAveragePace(distance: Double, duration: Double) -> String {
        if distance <= 0 || duration <= 0 {
            return "--:--"
        }
        
        let useMetric = UserPreferences.shared.useMetricSystem
        
        // Calculate time per unit distance (minutes per mile/km)
        // For pace, lower is better (less time to cover the distance)
        let timeInMinutes = duration / 60.0
        let distanceInPreferredUnit = useMetric ? distance * 1.60934 : distance // Convert to km if metric
        
        let minutesPerUnit = timeInMinutes / distanceInPreferredUnit
        
        // Format as MM:SS
        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Layout Updates
    
    private func updateTableViewHeight() {
        // Adjust table view's height to its content size plus insets
        if filteredRuns.isEmpty {
            // Show a message for empty state
            let emptyStateLabel = UILabel()
            emptyStateLabel.text = "No runs found for the selected filters.\nStart a new run to see it here!"
            emptyStateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
            emptyStateLabel.textAlignment = .center
            emptyStateLabel.numberOfLines = 0
            emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
            
            // Remove any existing empty state label first
            contentContainerView.subviews.forEach { view in
                if let label = view as? UILabel, label.tag == 999 {
                    label.removeFromSuperview()
                }
            }
            
            // Add tag to identify this label
            emptyStateLabel.tag = 999
            contentContainerView.addSubview(emptyStateLabel)
            
            NSLayoutConstraint.activate([
                emptyStateLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 40),
                emptyStateLabel.leadingAnchor.constraint(equalTo: tableView.leadingAnchor, constant: 20),
                emptyStateLabel.trailingAnchor.constraint(equalTo: tableView.trailingAnchor, constant: -20),
                emptyStateLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
            ])
            
            tableView.isHidden = true
        } else {
            // Remove empty state label if it exists
            contentContainerView.subviews.forEach { view in
                if let label = view as? UILabel, label.tag == 999 {
                    label.removeFromSuperview()
                }
            }
            
            tableView.isHidden = false
            
            // Calculate table height based on number of rows
            let numberOfRows = tableView.numberOfRows(inSection: 0)
            var tableHeight: CGFloat = 0
            
            if numberOfRows > 0 {
                tableHeight = CGFloat(numberOfRows) * tableView.rowHeight
                
                // Add table insets
                tableHeight += tableView.contentInset.top + tableView.contentInset.bottom
                
                // Add extra padding at the bottom
                tableHeight += 16
            } else {
                // Minimum height if no rows
                tableHeight = 100
            }
            
            // Remove existing height constraint if it exists
            NSLayoutConstraint.deactivate(tableView.constraints.filter { $0.firstAttribute == .height })
            
            // Add new height constraint
            tableView.heightAnchor.constraint(equalToConstant: tableHeight).isActive = true
        }
        
        // No need to modify position constraints - these are set in setupViewHierarchy
        
        // Update the scroll view's content size
        DispatchQueue.main.async {
            // This allows the layout to complete before we calculate sizes
            let contentHeight = self.tableView.frame.maxY + 24 // Add bottom padding
            self.mainScrollView.contentSize = CGSize(width: self.mainScrollView.frame.width, height: contentHeight)
        }
    }
    
    // MARK: - Badges Setup
    
    private func setupBadgesView() {
        // Configure badges container
        badgesContainerView.backgroundColor = UIColor(hex: 0x131D2E)
        badgesContainerView.layer.cornerRadius = 16
        badgesContainerView.layer.shadowColor = UIColor.black.cgColor
        badgesContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        badgesContainerView.layer.shadowRadius = 8
        badgesContainerView.layer.shadowOpacity = 0.3
        contentContainerView.addSubview(badgesContainerView)
        
        // Create badge toggle button
        badgeToggleButton.setImage(UIImage(systemName: "trophy.fill"), for: .normal)
        badgeToggleButton.tintColor = UIColor(hex: 0xFFD700)
        badgeToggleButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        badgeToggleButton.layer.cornerRadius = 15
        badgeToggleButton.addTarget(self, action: #selector(toggleBadges), for: .touchUpInside)
        badgesContainerView.addSubview(badgeToggleButton)
        
        // Create title label for badges section
        let badgesTitle = UILabel()
        badgesTitle.text = "Your Achievements"
        badgesTitle.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        badgesTitle.textColor = .white
        badgesContainerView.addSubview(badgesTitle)
        
        // Add achievement description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Unlock badges by reaching running milestones"
        descriptionLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        descriptionLabel.numberOfLines = 1
        badgesContainerView.addSubview(descriptionLabel)
        
        // Create collection view layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 85, height: 110) // Slightly larger items for better visibility
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        // Create collection view for badges
        let badgeCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        badgeCollection.backgroundColor = .clear
        badgeCollection.showsHorizontalScrollIndicator = false
        badgeCollection.register(BadgeCell.self, forCellWithReuseIdentifier: "BadgeCell")
        badgeCollection.delegate = self
        badgeCollection.dataSource = self
        badgesContainerView.addSubview(badgeCollection)
        self.badgeCollectionView = badgeCollection
        
        // Setup constraints
        badgesContainerView.translatesAutoresizingMaskIntoConstraints = false
        badgeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        badgesTitle.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeCollection.translatesAutoresizingMaskIntoConstraints = false
        
        // Add constraints - only for internal layout
        NSLayoutConstraint.activate([
            // Badge toggle button
            badgeToggleButton.topAnchor.constraint(equalTo: badgesContainerView.topAnchor, constant: 16),
            badgeToggleButton.trailingAnchor.constraint(equalTo: badgesContainerView.trailingAnchor, constant: -16),
            badgeToggleButton.widthAnchor.constraint(equalToConstant: 30),
            badgeToggleButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Badges title
            badgesTitle.topAnchor.constraint(equalTo: badgesContainerView.topAnchor, constant: 16),
            badgesTitle.leadingAnchor.constraint(equalTo: badgesContainerView.leadingAnchor, constant: 16),
            badgesTitle.trailingAnchor.constraint(lessThanOrEqualTo: badgeToggleButton.leadingAnchor, constant: -8),
            
            // Description label
            descriptionLabel.topAnchor.constraint(equalTo: badgesTitle.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: badgesContainerView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeToggleButton.leadingAnchor, constant: -8),
            
            // Badge collection
            badgeCollection.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            badgeCollection.leadingAnchor.constraint(equalTo: badgesContainerView.leadingAnchor),
            badgeCollection.trailingAnchor.constraint(equalTo: badgesContainerView.trailingAnchor),
            badgeCollection.heightAnchor.constraint(equalToConstant: 130),
            badgeCollection.bottomAnchor.constraint(equalTo: badgesContainerView.bottomAnchor, constant: -16)
        ])
    }
    

    
    @objc private func toggleBadges() {
        showBadges = !showBadges
        
        UIView.animate(withDuration: 0.3) {
            self.badgeCollectionView?.alpha = self.showBadges ? 1.0 : 0.0
            
            // Update badge toggle button image
            let imageName = self.showBadges ? "trophy.fill" : "trophy"
            self.badgeToggleButton.setImage(UIImage(systemName: imageName), for: .normal)
            
            // Apply a small bounce animation
            self.badgeToggleButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.badgeToggleButton.transform = .identity
            }
        }
        
        // Show/hide badge container without changing constraints
        badgesContainerView.isHidden = !showBadges
        
        // Update content size after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateTableViewHeight()
        }
    }
    

    
    // MARK: - Badges Loading and Management
    
    private func loadUserBadges() {
        // Enhanced badges with more variety and visual appeal
        let badges = [
            Badge(id: "first_run", name: "First Run", description: "Completed your first run with Do.", iconName: "figure.run", color: UIColor(hex: 0x4CD964), isEarned: true),
            Badge(id: "distance_5k", name: "5K Club", description: "Ran your first 5K distance. Keep pushing your limits!", iconName: "5.circle.fill", color: UIColor(hex: 0x5AC8FA), isEarned: true),
            Badge(id: "distance_10k", name: "10K Pro", description: "Completed a 10K run. You're reaching new heights!", iconName: "10.circle.fill", color: UIColor(hex: 0x007AFF), isEarned: false),
            Badge(id: "distance_half", name: "Half Marathon", description: "Completed a half marathon (21.1K). Amazing endurance!", iconName: "medal", color: UIColor(hex: 0xFFCC00), isEarned: false),
            Badge(id: "distance_full", name: "Marathoner", description: "Completed a full marathon (42.2K). You're unstoppable!", iconName: "trophy.fill", color: UIColor(hex: 0xFF9500), isEarned: false),
            Badge(id: "weekly_streak", name: "7-Day Streak", description: "Ran for seven consecutive days. Consistency wins!", iconName: "flame.fill", color: UIColor(hex: 0xFF3B30), isEarned: true),
            Badge(id: "monthly_streak", name: "30-Day Streak", description: "Ran for thirty consecutive days. Extraordinary dedication!", iconName: "flame.circle.fill", color: UIColor(hex: 0xFF2D55), isEarned: false),
            Badge(id: "early_bird", name: "Early Bird", description: "Completed a run before 7 AM. Rise and shine!", iconName: "sunrise.fill", color: UIColor(hex: 0xFF9500), isEarned: false),
            Badge(id: "night_owl", name: "Night Owl", description: "Ran after 9 PM. Darkness can't stop you!", iconName: "moon.stars.fill", color: UIColor(hex: 0x5856D6), isEarned: true),
            Badge(id: "elevation", name: "Mountain Climber", description: "Accumulated 500m of elevation gain. Reaching new heights!", iconName: "mountain.2.fill", color: UIColor(hex: 0x8E8E93), isEarned: false),
            Badge(id: "speed_demon", name: "Speed Demon", description: "Maintained a pace under 4:30 min/km for a 5K. Zoom!", iconName: "bolt.fill", color: UIColor(hex: 0xFFCC00), isEarned: false),
            Badge(id: "all_weather", name: "All-Weather Runner", description: "Ran in rain, snow, or extreme heat. Nothing stops you!", iconName: "cloud.sun.rain.fill", color: UIColor(hex: 0x34AADC), isEarned: true)
        ]
        
        self.userBadges = badges
        self.badgeCollectionView?.reloadData()
        
        // Add staggered animation to badges
        animateBadgeDisplay()
        
        checkForNewBadges()
    }
    
    private func animateBadgeDisplay() {
        guard let collectionView = self.badgeCollectionView else { return }
        
        // Start badges off-screen and invisible
        let cells = collectionView.visibleCells
        
        // Initial state for each cell
        for cell in cells {
            cell.transform = CGAffineTransform(translationX: 0, y: 50)
            cell.alpha = 0
        }
        
        // Animate each cell with a delay
        for (index, cell) in cells.enumerated() {
            // Calculate delay - stagger by 0.05s per cell
            let delay = 0.05 * Double(index)
            
            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: .curveEaseOut,
                animations: {
                    cell.transform = .identity
                    cell.alpha = 1
                }
            )
        }
    }
    
    private func checkForNewBadges() {
        // Check for newly earned badges based on run history
        if outdoorRunLogs.isEmpty && indoorRunLogs.isEmpty {
            return
        }
        
        // Track which badges were earned before checking
        let previouslyEarnedBadges = userBadges.filter { $0.isEarned }.count
        
        // First Run Badge - simple check if we have any runs
            if let firstRunBadge = userBadges.first(where: { $0.id == "first_run" }),
               !firstRunBadge.isEarned {
                awardBadge(id: "first_run")
            }
            
        // Calculate total stats across all runs for achievement evaluation
        var totalDistance: Double = 0
        var longestRun: Double = 0
        var runDays = Set<String>()
        var streakDays = [Date]()
        var fastestPace: Double = Double.greatestFiniteMagnitude
        var hasEarlyMorningRun = false
        var hasNightRun = false
        var totalElevationGain: Double = 0
        
        // Format for converting dates to day strings
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        
        // Process outdoor runs
        for run in outdoorRunLogs {
            // Extract distance
            var distance: Double = 0
                    if let distVal = run.distance as? NSNumber {
                        distance = distVal.doubleValue
            } else if let distanceStr = run.distance as? String,
                      let dist = Double(distanceStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                distance = dist
                    } else if let distanceVal = run.distance as? Double {
                        distance = distanceVal
                    }
                    
                    // Convert to kilometers if using miles
                    if !UserPreferences.shared.useMetricSystem {
                        distance *= 1.60934
                    }
                    
            // Update total and longest
            totalDistance += distance
            longestRun = max(longestRun, distance)
            
            // Check for pace badges
            if let paceStr = run.avgPace, let paceSeconds = convertPaceStringToSeconds(paceStr) {
                // Convert pace to minutes per km for consistency
                let pacePerKm = UserPreferences.shared.useMetricSystem ? Double(paceSeconds) / 60.0 : Double(paceSeconds) / 60.0 / 1.60934
                
                // Update fastest pace
                fastestPace = min(fastestPace, pacePerKm)
            }
            
            // Check for time-of-day badges
            if let date = run.createdAt {
                // Add to run days
                runDays.insert(dayFormatter.string(from: date))
                streakDays.append(date)
                
                // Check time of day
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                
                if hour < 7 {
                    hasEarlyMorningRun = true
                } else if hour >= 21 {
                    hasNightRun = true
                }
            }
            
            // Check elevation gain
            if let gainStr = run.elevationGain,
               let gain = Double(gainStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                totalElevationGain += gain
            }
        }
        
        // Process indoor runs for relevant stats
        for run in indoorRunLogs {
            var distance: Double = 0
            if let distVal = run.distance as? NSNumber {
                distance = distVal.doubleValue
            } else if let distanceStr = run.distance as? String,
                      let dist = Double(distanceStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                distance = dist
            } else if let distanceVal = run.distance as? Double {
                distance = distanceVal
            }
            
            // Convert to kilometers if using miles
            if !UserPreferences.shared.useMetricSystem {
                distance *= 1.60934
            }
            
            // Update total distance
            totalDistance += distance
            
            // Add to run days
            if let date = run.createdAt {
                runDays.insert(dayFormatter.string(from: date))
                streakDays.append(date)
                
                // Check time of day
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                
                if hour < 7 {
                    hasEarlyMorningRun = true
                } else if hour >= 21 {
                    hasNightRun = true
                }
            }
        }
        
        // Distance Badges
        // 5K Badge
        if let badge = userBadges.first(where: { $0.id == "distance_5k" }),
           !badge.isEarned, longestRun >= 5.0 {
            awardBadge(id: "distance_5k")
        }
        
        // 10K Badge
        if let badge = userBadges.first(where: { $0.id == "distance_10k" }),
           !badge.isEarned, longestRun >= 10.0 {
            awardBadge(id: "distance_10k")
        }
        
        // Half Marathon Badge
        if let badge = userBadges.first(where: { $0.id == "distance_half" }),
           !badge.isEarned, longestRun >= 21.1 {
            awardBadge(id: "distance_half")
        }
        
        // Marathon Badge
        if let badge = userBadges.first(where: { $0.id == "distance_full" }),
           !badge.isEarned, longestRun >= 42.2 {
            awardBadge(id: "distance_full")
        }
        
        // Weekly Streak Badge (7 consecutive days)
        if let badge = userBadges.first(where: { $0.id == "weekly_streak" }),
           !badge.isEarned, runDays.count >= 7 {
            // Sort dates and check for any 7-day periods
            if hasConsecutiveDays(streakDays, count: 7) {
                awardBadge(id: "weekly_streak")
            }
        }
        
        // Monthly Streak Badge (30 consecutive days)
        if let badge = userBadges.first(where: { $0.id == "monthly_streak" }),
           !badge.isEarned, runDays.count >= 30 {
            // Sort dates and check for any 30-day periods
            if hasConsecutiveDays(streakDays, count: 30) {
                awardBadge(id: "monthly_streak")
            }
        }
        
        // Time of day badges
        // Early Bird
        if let badge = userBadges.first(where: { $0.id == "early_bird" }),
           !badge.isEarned, hasEarlyMorningRun {
            awardBadge(id: "early_bird")
        }
        
        // Night Owl
        if let badge = userBadges.first(where: { $0.id == "night_owl" }),
           !badge.isEarned, hasNightRun {
            awardBadge(id: "night_owl")
        }
        
        // Elevation Badge
        if let badge = userBadges.first(where: { $0.id == "elevation" }),
           !badge.isEarned, totalElevationGain >= 500 {
            awardBadge(id: "elevation")
        }
        
        // Speed Demon Badge (sub 4:30 min/km pace for any run)
        if let badge = userBadges.first(where: { $0.id == "speed_demon" }),
           !badge.isEarned, fastestPace < 4.5 {
            awardBadge(id: "speed_demon")
        }
        
        // Refresh badge collection if new badges were earned
        if previouslyEarnedBadges < userBadges.filter({ $0.isEarned }).count {
            badgeCollectionView?.reloadData()
        }
    }
    
    // Helper method to check for consecutive days
    private func hasConsecutiveDays(_ dates: [Date], count: Int) -> Bool {
        guard dates.count >= count else { return false }
        
        // Sort dates
        let sortedDates = dates.sorted()
        
        // Create a set of date strings for efficient lookup
        let calendar = Calendar.current
        var dayStrings = Set<String>()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for date in sortedDates {
            dayStrings.insert(formatter.string(from: date))
        }
        
        // Check for consecutive days
        for i in 0..<sortedDates.count {
            // Start with this date
            var currentDate = sortedDates[i]
            var consecutiveCount = 1
            
            // Check next 'count-1' consecutive days
            for _ in 1..<count {
                // Get next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                let dayString = formatter.string(from: currentDate)
                
                if dayStrings.contains(dayString) {
                    consecutiveCount += 1
                } else {
                    // Chain broken
                    break
                }
            }
            
            if consecutiveCount >= count {
                return true
            }
        }
        
        return false
    }
    
    private func awardBadge(id: String) {
        // Find and award the badge
        if let index = userBadges.firstIndex(where: { $0.id == id }) {
            userBadges[index].isEarned = true
            
//            // Show a congratulatory message
//            DispatchQueue.main.async {
//                self.showBadgeEarnedAlert(badge: self.userBadges[index])
//            }
        }
    }
    
    private func showBadgeEarnedAlert(badge: Badge) {
        // Create and configure alert
        let alertController = UIAlertController(
            title: "New Badge Earned! 🎉",
            message: "Congratulations! You've earned the '\(badge.name)' badge.\n\n\(badge.description)",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Nice!", style: .default))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    // MARK: - Map Data Update
    
    
    private func extractCoordinatesFromLocationData(_ locationData: [[String: Any]]) -> [CLLocationCoordinate2D]? {
        var coordinates: [CLLocationCoordinate2D] = []
        
        for point in locationData {
            // Try different possible formats that might be in locationData
            
            // Format 1: Direct lat/lng keys
            if let lat = point["latitude"] as? Double,
               let lng = point["longitude"] as? Double {
                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                continue
            }
            
            // Format 2: Shortened lat/lng keys
            if let lat = point["lat"] as? Double,
               let lng = point["lng"] as? Double {
                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                continue
            }
            
            // Format 3: Location dictionary containing coordinate data
            if let location = point["location"] as? [String: Any] {
                if let lat = location["latitude"] as? Double,
                   let lng = location["longitude"] as? Double {
                    coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    continue
                }
                
                if let lat = location["lat"] as? Double,
                   let lng = location["lng"] as? Double {
                    coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    continue
                }
            }
            
            // Format 4: CLLocation encoded as dictionary
            if let locationDict = point["CLLocation"] as? [String: Any],
               let coordinate = locationDict["coordinate"] as? [String: Any],
               let latitude = coordinate["latitude"] as? Double,
               let longitude = coordinate["longitude"] as? Double {
                coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                continue
            }
        }
        
        return coordinates.isEmpty ? nil : coordinates
    }
    
    
    // MARK: - Stats Card Creation

    private func createStatsHeaderView() -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        // Create horizontal top row stack view
        let topRowStack = UIStackView()
        topRowStack.axis = .horizontal
        topRowStack.distribution = .fillEqually
        topRowStack.spacing = 12
        topRowStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Create horizontal bottom row stack view
        let bottomRowStack = UIStackView()
        bottomRowStack.axis = .horizontal
        bottomRowStack.distribution = .fillEqually
        bottomRowStack.spacing = 12
        bottomRowStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Get unit preferences
        let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
        let paceUnit = UserPreferences.shared.useMetricSystem ? "/km" : "/mi"
        
        // Create four stat cards
        let distanceCard = createStatsCard(title: "DISTANCE", iconName: "figure.run", value: "--", unit: distanceUnit, color: UIColor(hex: 0x4CD964))
        let paceCard = createStatsCard(title: "AVG PACE", iconName: "speedometer", value: "--", unit: paceUnit, color: UIColor(hex: 0x007AFF))
        let timeCard = createStatsCard(title: "TOTAL TIME", iconName: "clock", value: "--", unit: "", color: UIColor(hex: 0xFF9500))
        let caloriesCard = createStatsCard(title: "CALORIES", iconName: "flame.fill", value: "--", unit: "kcal", color: UIColor(hex: 0xFF3B30))
        
        // Add cards to row stacks
        topRowStack.addArrangedSubview(distanceCard)
        topRowStack.addArrangedSubview(paceCard)
        
        bottomRowStack.addArrangedSubview(timeCard)
        bottomRowStack.addArrangedSubview(caloriesCard)
        
        // Add rows to header view
        headerView.addSubview(topRowStack)
        headerView.addSubview(bottomRowStack)
        
        // Set constraints
        NSLayoutConstraint.activate([
            topRowStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            topRowStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            topRowStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            bottomRowStack.topAnchor.constraint(equalTo: topRowStack.bottomAnchor, constant: 12),
            bottomRowStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            bottomRowStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            bottomRowStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
        
        return headerView
    }
    
    // New method to properly arrange views in the hierarchy
    private func setupViewHierarchy() {
        // Make sure contentContainerView is properly sized
        NSLayoutConstraint.activate([
            contentContainerView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor)
        ])
        
        // Add horizontal constraints for all main container views
        NSLayoutConstraint.activate([
            statsHeaderView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            statsHeaderView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            
            filterChipsContainer.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            filterChipsContainer.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            
            badgesContainerView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            badgesContainerView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            
            tableView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16)
        ])
        
        // Adjust table view position based on the established view hierarchy
        let tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 200) // Initial height
        tableHeightConstraint.priority = .defaultHigh
        tableHeightConstraint.isActive = true
        
        // Set up the vertical flow of components
        NSLayoutConstraint.activate([
            // First, stats header at the top
            statsHeaderView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 16),
            
            // Then filter chips
            filterChipsContainer.topAnchor.constraint(equalTo: statsHeaderView.bottomAnchor, constant: 16)
        ])
        
        // Add vertical constraints for views that might not exist yet
        NSLayoutConstraint.activate([
            badgesContainerView.topAnchor.constraint(equalTo: filterChipsContainer.bottomAnchor, constant: 16),
            calendarViewContainer.topAnchor.constraint(equalTo: badgesContainerView.bottomAnchor, constant: 16),
            tableView.topAnchor.constraint(equalTo: calendarViewContainer.bottomAnchor, constant: 16)
        ])
        
        // Always add bottom constraint
        NSLayoutConstraint.activate([
            tableView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -16)
        ])
        
        // Update the scroll view content size initially
        DispatchQueue.main.async {
            self.updateTableViewHeight()
        }
    }
}

// MARK: - Badge Model

struct Badge {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let color: UIColor
    var isEarned: Bool
    
    // Computed property for a faded color when badge is not earned
    var displayColor: UIColor {
        return isEarned ? color : color.withAlphaComponent(0.3)
    }
}


// MARK: - Badges Collection View Extension

extension RunHistoryViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    // UICollectionViewDataSource - Implementation for badges collection
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == badgeCollectionView {
            return userBadges.count
        } else {
            // Handle calendar collection view
            return calendarDays.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == badgeCollectionView {
            // Handle badge collection view cells
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BadgeCell", for: indexPath) as! BadgeCell
            let badge = userBadges[indexPath.item]
            cell.configure(with: badge)
            return cell
        } else if collectionView == calendarCollectionView {
            // Handle calendar collection cell
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CalendarDayCell", for: indexPath) as? CalendarDayCell else {
                return UICollectionViewCell()
            }
            
            let day = calendarDays[indexPath.item]
            
            // Check if this day is selected
            var isSelected = false
            if let selectedDate = selectedDate, let dayDate = day.date,
               Calendar.current.isDate(dayDate, inSameDayAs: selectedDate) {
                isSelected = true
            }
            
            // Configure the cell
            cell.configure(with: day, isSelected: isSelected)
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    // Animate each cell as it appears
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == badgeCollectionView {
            // Animate the cell with a delay based on its position
            let delay = 0.05 * Double(indexPath.item)
            
            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: .curveEaseOut,
                animations: {
                    cell.alpha = 1
                    cell.transform = .identity
                }
            )
        }
    }
    
    // UICollectionViewDelegate - Handle badge selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == badgeCollectionView {
            // Show badge details when tapped
            let badge = userBadges[indexPath.item]
            
            let alertController = UIAlertController(
                title: badge.name,
                message: badge.description + (badge.isEarned ? "\n\nYou've earned this badge!" : "\n\nKeep running to earn this badge!"),
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "Close", style: .default))
            present(alertController, animated: true)
        } else {
            // Handle calendar collection selection (already implemented)
        let day = calendarDays[indexPath.item]
        guard let date = day.date else { return }
        
        didSelectCalendarDay(date)
        }
    }
}



    
  


class RunLogCell: UITableViewCell {
    
    // MARK: - UI Elements
    
    private let containerView = UIView()
    private let typeIconView = UIImageView()
    private let dateLabel = UILabel()
    private let distanceLabel = UILabel()
    private let durationLabel = UILabel()
    private let paceLabel = UILabel()
    private let statsStackView = UIStackView()
    
    // New UI elements for modern design
    private let routePreviewView = UIView()
    private let metricsContainerView = UIView()
    private let actionButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    // MARK: - Setup
    
    private func setupCell() {
        // Setup container view with modern card design - darker background
        containerView.backgroundColor = UIColor(hex: 0x131D2E) // Darker card background to match stats cards
        containerView.layer.cornerRadius = 12 // Smaller corner radius
        
        // Add better shadow for depth
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2) // Smaller shadow
        containerView.layer.shadowRadius = 6 // Reduced shadow radius
        containerView.layer.shadowOpacity = 0.15
        
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Add container to cell content view
        contentView.addSubview(containerView)
        
        // Create typeIconContainer
        let typeIconContainer = UIView()
        typeIconContainer.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.15)
        typeIconContainer.layer.cornerRadius = 14 // Smaller radius
        containerView.addSubview(typeIconContainer)
        
        // Setup type icon view
        typeIconView.tintColor = UIColor(hex: 0x4CD964)
        typeIconView.contentMode = .scaleAspectFit
        typeIconContainer.addSubview(typeIconView)
        
        // Setup date label with modern font
        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium) // Smaller font
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        containerView.addSubview(dateLabel)
        
        // Setup distance label
        distanceLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold) // Smaller for better fit
        distanceLabel.textColor = .white
        containerView.addSubview(distanceLabel)
        
        // Setup duration and pace labels
        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold) // Smaller font
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        paceLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold) // Smaller font
        paceLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        containerView.addSubview(durationLabel)
        containerView.addSubview(paceLabel)
        
        // Setup stats stack view
        statsStackView.axis = .vertical
        statsStackView.spacing = 4 // Less spacing
        statsStackView.distribution = .equalSpacing
        containerView.addSubview(statsStackView)
        
        // Setup constraints with modern spacing
        containerView.translatesAutoresizingMaskIntoConstraints = false
        typeIconContainer.translatesAutoresizingMaskIntoConstraints = false
        typeIconView.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        paceLabel.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container view constraints - more space for larger cells
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6), // Less padding
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16), // Less side margin
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            // Type icon container constraints - smaller fixed size
            typeIconContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            typeIconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            typeIconContainer.widthAnchor.constraint(equalToConstant: 28), // Smaller fixed size
            typeIconContainer.heightAnchor.constraint(equalToConstant: 28), // Smaller fixed size
            
            // Type icon view constraints
            typeIconView.centerXAnchor.constraint(equalTo: typeIconContainer.centerXAnchor),
            typeIconView.centerYAnchor.constraint(equalTo: typeIconContainer.centerYAnchor),
            typeIconView.widthAnchor.constraint(equalToConstant: 16), // Fixed size for icon
            typeIconView.heightAnchor.constraint(equalToConstant: 16),
            
            // Date label constraints - aligned with icon container
            dateLabel.centerYAnchor.constraint(equalTo: typeIconContainer.centerYAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: typeIconContainer.trailingAnchor, constant: 10),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -10),
            
            // Distance label constraints - smaller top margin
            distanceLabel.topAnchor.constraint(equalTo: typeIconContainer.bottomAnchor, constant: 8),
            distanceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            distanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -10),
            
            // Duration label constraints
            durationLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 4), // Less spacing
            durationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            
            // Pace label aligned with duration but horizontal spacing
            paceLabel.topAnchor.constraint(equalTo: durationLabel.topAnchor),
            paceLabel.leadingAnchor.constraint(equalTo: durationLabel.trailingAnchor, constant: 12),
            paceLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -10),
            
            // Stats stack view constraints - less bottom padding
            statsStackView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 6),
            statsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            statsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            statsStackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -10)
        ])
    }
    
    private func addLabelToStackWithTitle(_ title: String, value: String) {
        let statRow = UIStackView()
        statRow.axis = .horizontal
        statRow.spacing = 4 // Reduced spacing
        statRow.alignment = .center
        
        let iconView = UIImageView(image: UIImage(systemName: "circle.fill"))
        iconView.tintColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.7)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set fixed width for the icon to avoid constraint conflicts
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 4), // Smaller bullet point
            iconView.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium) // Smaller font
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold) // Smaller font
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        statRow.addArrangedSubview(iconView)
        statRow.addArrangedSubview(titleLabel)
        
        // Add flexible space
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statRow.addArrangedSubview(spacerView)
        
        statRow.addArrangedSubview(valueLabel)
        
        statsStackView.addArrangedSubview(statRow)
    }
    
    // MARK: - Configuration
    
    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.text = nil
        distanceLabel.text = nil
        durationLabel.text = nil
        paceLabel.text = nil
    }
    
    func configure(with run: Any, isOutdoorRun: Bool) {
        // Get user preferences for units
        let useMetric = UserPreferences.shared.useMetricSystem
            
            if let outdoorRun = run as? RunLog {
            // Outdoor run configuration with runner icon
            typeIconView.image = UIImage(systemName: "figure.run")
            typeIconView.tintColor = UIColor(hex: 0x4CD964)
            
            // Ensure the icon container has the right color
            typeIconView.superview?.backgroundColor = UIColor(hex: 0x4CD964).withAlphaComponent(0.15)
            
            // Format date with modern style
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none // Removed time to save space
            if let date = outdoorRun.createdAt {
                dateLabel.text = dateFormatter.string(from: date)
            }
            
            // Extract and process values
            var distanceVal: Double = 0.0
            var durationVal: Double = 0.0
            
            // Extract distance
            if let distance = outdoorRun.distance as? NSNumber {
                distanceVal = distance.doubleValue
            } else if let distanceStr = outdoorRun.distance as? String {
                distanceVal = Double(distanceStr) ?? 0.0
            } else if let distance = outdoorRun.distance as? Double {
                distanceVal = distance
            }
            
            // Extract duration
            if let duration = outdoorRun.duration as? NSNumber {
                durationVal = duration.doubleValue
            } else if let durationStr = outdoorRun.duration as? String {
                durationVal = Double(durationStr) ?? 0.0
            } else if let duration = outdoorRun.duration as? Double {
                durationVal = duration
            } else if let duration = outdoorRun.duration as? Int {
                durationVal = Double(duration)
            }
            
            // Format and set labels
            let displayDistance = useMetric ? distanceVal * 1.60934 : distanceVal
            let distanceUnit = useMetric ? "km" : "mi"
            distanceLabel.text = String(format: "%.1f %@", displayDistance, distanceUnit)
            
            // Set duration label
            if durationVal > 0 {
                durationLabel.text = formatTime(seconds: durationVal)
            } else if let rawDuration = outdoorRun.duration as? String {
                durationLabel.text = rawDuration
            } else {
                durationLabel.text = "--:--"
            }
            
            // Calculate and set pace
            if durationVal > 0 && distanceVal > 0 {
                let paceInMinsPerMile = durationVal / 60.0 / distanceVal
                let paceValue = useMetric ? paceInMinsPerMile / 1.60934 : paceInMinsPerMile
                let paceUnit = useMetric ? "/km" : "/mi"
                
                let mins = Int(paceValue)
                let secs = Int((paceValue - Double(mins)) * 60)
                paceLabel.text = String(format: "%d:%02d %@", mins, secs, paceUnit)
            } else {
                paceLabel.text = "--:-- /mi"
            }
            
            } else if let indoorRun = run as? IndoorRunLog {
            // Indoor run configuration with treadmill icon
            typeIconView.image = UIImage(systemName: "figure.walk")
            typeIconView.tintColor = UIColor(hex: 0xFF9500)
            
            // Ensure the icon container has the right color
            typeIconView.superview?.backgroundColor = UIColor(hex: 0xFF9500).withAlphaComponent(0.15)
            
            // Format date with modern style
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none // Removed time to save space
            if let date = indoorRun.createdAt {
                dateLabel.text = dateFormatter.string(from: date)
            }
            
            // Extract and process values
            var distanceVal: Double = 0.0
            var durationVal: Double = 0.0
            
            // Extract distance
            if let distance = indoorRun.distance as? NSNumber {
                distanceVal = distance.doubleValue
            } else if let distanceStr = indoorRun.distance as? String {
                distanceVal = Double(distanceStr) ?? 0.0
            } else if let distance = indoorRun.distance as? Double {
                distanceVal = distance
            }
            
            // Extract duration
            if let duration = indoorRun.duration as? NSNumber {
                durationVal = duration.doubleValue
            } else if let durationStr = indoorRun.duration as? String {
                durationVal = Double(durationStr) ?? 0.0
            } else if let duration = indoorRun.duration as? Double {
                durationVal = duration
            } else if let duration = indoorRun.duration as? Int {
                durationVal = Double(duration)
            }
            
            // Format and set labels
            let displayDistance = useMetric ? distanceVal * 1.60934 : distanceVal
            let distanceUnit = useMetric ? "km" : "mi"
            distanceLabel.text = String(format: "%.1f %@", displayDistance, distanceUnit)
            
            // Set duration label
            if durationVal > 0 {
                durationLabel.text = formatTime(seconds: durationVal)
            } else if let rawDuration = indoorRun.duration as? String {
                durationLabel.text = rawDuration
            } else {
                durationLabel.text = "--:--"
            }
            
            // Calculate and set pace
            if durationVal > 0 && distanceVal > 0 {
                let paceInMinsPerMile = durationVal / 60.0 / distanceVal
                let paceValue = useMetric ? paceInMinsPerMile / 1.60934 : paceInMinsPerMile
                let paceUnit = useMetric ? "/km" : "/mi"
                
                let mins = Int(paceValue)
                let secs = Int((paceValue - Double(mins)) * 60)
                paceLabel.text = String(format: "%d:%02d %@", mins, secs, paceUnit)
            } else {
                paceLabel.text = "--:-- /mi"
            }
        }
        
        // Add subtle shine animation to show highlight on cell
        animateCellHighlight()
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func animateCellHighlight() {
        // Add subtle highlight animation for when cell appears
        let highlightView = UIView(frame: containerView.bounds)
        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        highlightView.alpha = 0
        containerView.addSubview(highlightView)
        
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut, animations: {
            highlightView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, animations: {
                highlightView.alpha = 0
            }) { _ in
                highlightView.removeFromSuperview()
            }
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.2) {
            self.containerView.alpha = highlighted ? 0.8 : 1.0
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        UIView.animate(withDuration: 0.2) {
            self.containerView.alpha = selected ? 0.8 : 1.0
            self.containerView.transform = selected ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
} 

// MARK: - Run Analysis Presentation
extension RunHistoryViewController {
    private func presentRunAnalysis(for run: Any) {
        let analysisVC = RunAnalysisViewController()
        analysisVC.run = run
        analysisVC.modalPresentationStyle = .fullScreen
        present(analysisVC, animated: true)
    }
} 

// MARK: - Badge Cell
class BadgeCell: UICollectionViewCell {
    private let iconView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let lockIconView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = UIColor(white: 1.0, alpha: 0.07)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        // Setup icon container
        iconView.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        iconView.layer.cornerRadius = 25
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        // Setup icon image
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        // Setup title label
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Setup lock icon for unearned badges
        lockIconView.image = UIImage(systemName: "lock.fill")
        lockIconView.tintColor = UIColor.white.withAlphaComponent(0.7)
        lockIconView.contentMode = .scaleAspectFit
        lockIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lockIconView)
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 50),
            iconView.heightAnchor.constraint(equalToConstant: 50),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            
            lockIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            lockIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            lockIconView.widthAnchor.constraint(equalToConstant: 16),
            lockIconView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with badge: Badge) {
        titleLabel.text = badge.name
        iconImageView.image = UIImage(systemName: badge.iconName)
        iconView.backgroundColor = badge.displayColor.withAlphaComponent(0.2)
        iconImageView.tintColor = badge.displayColor
        
        // Show/hide lock icon based on earned status
        lockIconView.isHidden = badge.isEarned
        
        // Apply visual effects based on earned status
        alpha = badge.isEarned ? 1.0 : 0.7
        
        // Apply initial transform for animation
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8).translatedBy(x: 0, y: 20)
        alpha = 0
    }
}


