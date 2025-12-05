import SwiftUI
import Combine

// MARK: - Camera Options Sheet

struct CameraOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    let onPhotoCapture: (UIImage) -> Void
    let onVideoCapture: (URL) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button(action: {
                    // Capture photo
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take Photo")
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Record video
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "video")
                        Text("Record Video")
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Meditation Options Sheet

struct MeditationOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    let onMeditationSelected: (MeditationFocus, Int) -> Void
    
    @State private var selectedFocus: MeditationFocus = .stress
    @State private var duration = 10
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Focus selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(MeditationFocus.allCases, id: \.self) { focus in
                                Button(action: { selectedFocus = focus }) {
                                    VStack {
                                        Text(focus.icon)
                                            .font(.system(size: 32))
                                        Text(focus.rawValue)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedFocus == focus ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2))
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Duration selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration: \(duration) minutes")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(duration) },
                        set: { duration = Int($0) }
                    ), in: 3...30, step: 1)
                }
                
                Spacer()
                
                // Start button
                Button(action: {
                    onMeditationSelected(selectedFocus, duration)
                    dismiss()
                }) {
                    Text("Start Meditation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Guided Meditation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct GenieView: View {
    let context: GenieContext
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    // Removed @FocusState - using UIKit TextField which handles focus natively without SwiftUI overhead
    
    // Upsell & Warning States
    @State private var showingUpsell = false
    @State private var showingTokenPurchase = false
    @State private var upsellData: UpsellData?
    @State private var showBalanceWarning = false
    @State private var currentWarning: BalanceWarning?
    
    // Multimodal States - use Combine subscriptions instead of @ObservedObject to prevent full body re-evaluation
    // CRITICAL: Subscribe only to specific publishers we need, not all @Published properties
    private let actionHandler = GenieActionHandler.shared
    @State private var subscriptionCoordinator = SubscriptionCoordinator()
    
    // Coordinator class to manage Combine subscriptions (since structs can't store mutable sets)
    private class SubscriptionCoordinator {
        var cancellables = Set<AnyCancellable>()
    }
    // Voice and vision services accessed lazily via computed properties (only in handlers, not in body)
    private var voiceService: GenieVoiceService { GenieVoiceService.shared }
    private var visionService: GenieVisionService { GenieVisionService.shared }
    @State private var showAttachmentMenu = false
    @State private var showFoodCamera = false
    @State private var showEquipmentScanner = false
    @State private var showFridgeScanner = false
    
    // Sheet coordinator to prevent evaluating all sheets on every body evaluation
    @StateObject private var sheetCoordinator = SheetCoordinator()
    
    // Conversation management
    @StateObject private var conversationManager = GenieConversationManager.shared
    @State private var showConversationsList = false
    
    // AI-powered suggestions
    @ObservedObject private var suggestionService = GenieSuggestionService.shared
    
    init(context: GenieContext) {
        self.context = context
        // Create viewModel - this is lightweight (just sets context, no API calls)
        _viewModel = StateObject(wrappedValue: ChatViewModel(context: context))
        
        // Load conversations lazily in background (non-blocking)
        Task.detached(priority: .utility) {
            await GenieConversationManager.shared.loadConversations()
        }
        
        // Pre-load user insights in background (non-blocking, cached)
        // This ensures insights are available when conversation starts
        Task.detached(priority: .utility) {
            _ = await GenieUserLearningService.shared.getConversationInsights()
        }
    }
    
    // Setup Combine subscriptions to actionHandler publishers
    // This replaces @ObservedObject to prevent full body re-evaluation on every @Published change
    private func setupActionHandlerSubscriptions() {
        // Subscribe to specific publishers we care about, not all @Published properties
        actionHandler.$showingVideoResults
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .videoResults
                } else if self.sheetCoordinator.activeSheet == .videoResults {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingMeditation
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .meditation
                } else if self.sheetCoordinator.activeSheet == .meditation {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingMealPlan
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .mealPlan
                } else if self.sheetCoordinator.activeSheet == .mealPlan {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingMealSuggestions
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .mealSuggestions
                } else if self.sheetCoordinator.activeSheet == .mealSuggestions {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingRestaurantSearch
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .restaurantSearch
                } else if self.sheetCoordinator.activeSheet == .restaurantSearch {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingGroceryList
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .groceryList
                } else if self.sheetCoordinator.activeSheet == .groceryList {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingCookbook
            .receive(on: DispatchQueue.main)
            .sink { [ self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .cookbook
                } else if self.sheetCoordinator.activeSheet == .cookbook {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingVisionBoard
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .visionBoard
                } else if self.sheetCoordinator.activeSheet == .visionBoard {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingManifestation
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .manifestation
                } else if self.sheetCoordinator.activeSheet == .manifestation {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingAffirmation
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .affirmation
                } else if self.sheetCoordinator.activeSheet == .affirmation {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingBedtimeStory
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .bedtimeStory
                } else if self.sheetCoordinator.activeSheet == .bedtimeStory {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingMotivation
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .motivation
                } else if self.sheetCoordinator.activeSheet == .motivation {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingMovementPreview
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .movementPreview
                } else if self.sheetCoordinator.activeSheet == .movementPreview {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingSessionPreview
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .sessionPreview
                } else if self.sheetCoordinator.activeSheet == .sessionPreview {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
        
        actionHandler.$showingPlanPreview
            .receive(on: DispatchQueue.main)
            .sink { [self] showing in
                if showing {
                    self.sheetCoordinator.activeSheet = .planPreview
                } else if self.sheetCoordinator.activeSheet == .planPreview {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.sheetCoordinator.activeSheet = nil
                    }
                }
            }
            .store(in: &subscriptionCoordinator.cancellables)
    }
    
    var body: some View {
        mainContent
            .sheet(item: Binding(
                get: { 
                    // Exclude meditation from sheet - it will be shown as fullScreenCover
                    if case .meditation = sheetCoordinator.activeSheet {
                        return nil
                    }
                    return sheetCoordinator.activeSheet
                },
                set: { sheetCoordinator.activeSheet = $0 }
            )) { sheetItem in
                sheetCoordinator.view(for: sheetItem, upsellData: upsellData, 
                                    onPhotoCapture: handlePhotoCapture, 
                                    onVideoCapture: handleVideoCapture)
            }
            .fullScreenCover(isPresented: Binding(
                get: { 
                    if case .meditation = sheetCoordinator.activeSheet {
                        return true
                    }
                    return false
                },
                set: { if !$0 { sheetCoordinator.activeSheet = nil } }
            )) {
                if let meditation = GenieActionHandler.shared.currentMeditation {
                    MeditationPlayerView(meditation: meditation)
                }
            }
            .fullScreenCover(isPresented: $showFoodCamera) {
                FoodCameraView(onFoodLogged: {
                    showFoodCamera = false
                })
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showEquipmentScanner) {
                EquipmentCameraView()
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showFridgeScanner) {
                FridgeCameraView()
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showConversationsList) {
                ConversationsListView(
                    conversationManager: conversationManager,
                    onSelectConversation: { conversationId in
                        Task {
                            await switchToConversation(conversationId)
                        }
                    },
                    onCreateNew: {
                        Task {
                            await createNewConversation()
                        }
                    }
                )
            }
    }
    
    // MARK: - Conversation Management
    
    private func switchToConversation(_ conversationId: String) async {
        // Update conversation ID immediately for UI feedback
        await MainActor.run {
            conversationManager.currentConversationId = conversationId
        }
        
        // Load messages for this conversation (lazy, cached) - non-blocking
        let messages = await conversationManager.loadMessages(for: conversationId)
        
        await MainActor.run {
            viewModel.messages = messages
            viewModel.sessionId = conversationId // Update session ID to conversation ID
            
            // Reload suggestions for empty conversations
            if messages.isEmpty {
                suggestionService.reset()
                suggestionService.loadSuggestions(for: context)
            }
        }
    }
    
    private func createNewConversation() async {
        // Show empty state immediately for better UX
        await MainActor.run {
            viewModel.messages = []
            // Clear any existing conversation context
        }
        
        // Create conversation in background (non-blocking)
        if let newConv = await conversationManager.createNewConversation() {
            await switchToConversation(newConv.id)
            
            // Reset and reload suggestions for new conversation
            await MainActor.run {
                suggestionService.reset()
                suggestionService.loadSuggestions(for: context)
            }
        } else {
            // If creation failed, show error state or fallback
            print("⚠️ [GenieView] Failed to create new conversation - user can still send messages")
        }
    }
    
    // Break down body into smaller pieces to help compiler type-check
    private var mainContent: some View {
        applyViewModifiers(to: ZStack {
            // Solid background for instant render - no gradient overhead
            Color.brandBlue
                .ignoresSafeArea()
            
            contentStack
        })
    }
    
    // Extract all modifiers to separate function to help compiler type-check
    // CRITICAL: Minimize onChange handlers - they're evaluated during body evaluation and cause hangs
    private func applyViewModifiers<V: View>(to view: V) -> some View {
        view
            .task(id: viewModel.balanceWarning?.level) {
                // Use .task instead of .onChange to prevent evaluation during body refresh
                guard let warning = viewModel.balanceWarning else { return }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s debounce
                await MainActor.run {
                    handleBalanceWarning(warning)
                }
            }
            .task(id: viewModel.upsellData?.upsell.recommendation ?? "") {
                // Use .task instead of .onChange for upsell data
                guard let data = viewModel.upsellData else { return }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s debounce
                await MainActor.run {
                    upsellData = data
                    sheetCoordinator.activeSheet = .upsell
                }
            }
            // Defer notification handling to prevent blocking
            .task {
                // Listen for subscription updates
                for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("SubscriptionUpdated")) {
                    // Reload balance when subscription is updated - async to prevent blocking
                    // Pass clearCache: true to ensure fresh data
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                        await MainActor.run {
                            viewModel.loadBalance(clearCache: true)
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // Additional 1 second
                        await MainActor.run {
                            viewModel.loadBalance(clearCache: true)
                        }
                    }
                }
            }
            .task {
                // Listen for token purchases
                for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("TokensPurchased")) {
                    print("🧞 [GenieView] TokensPurchased notification received - clearing cache and reloading balance")
                    // Reload balance when tokens are purchased - add delay for webhook processing
                    // Pass clearCache: true to ensure fresh data
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for webhook to process
                        await MainActor.run {
                            viewModel.loadBalance(clearCache: true)
                        }
                    }
                }
            }
            .task {
                // Listen for token balance updates from any query (text, image, video)
                for await notification in NotificationCenter.default.notifications(named: NSNotification.Name("TokenBalanceUpdated")) {
                    if let userInfo = notification.userInfo,
                       let balance = userInfo["balance"] as? Int,
                       let tokensUsed = userInfo["tokensUsed"] as? Int {
                        print("🧞 [GenieView] TokenBalanceUpdated notification received: balance=\(balance), used=\(tokensUsed)")
                        await MainActor.run {
                            let previousBalance = viewModel.tokenBalance
                            viewModel.tokenBalance = max(0, balance)
                            print("🧞 [GenieView] 💰 Balance updated via notification: \(previousBalance) → \(viewModel.tokenBalance)")
                        }
                    }
                }
            }
            // Simplified sheet state sync - only sync when sheet is dismissed
            .onChange(of: sheetCoordinator.activeSheet) { sheet in
                // Only update local state when sheet is dismissed to minimize work
                if sheet == nil {
                    showingTokenPurchase = false
                    showAttachmentMenu = false
                    showFoodCamera = false
                    showEquipmentScanner = false
                    // Clear upsell data when sheet is dismissed
                    upsellData = nil
                    
                    // Reload balance when token purchase sheet is dismissed (user may have purchased tokens)
                    // Pass clearCache: true to ensure fresh data
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for webhook processing
                        await MainActor.run {
                            viewModel.loadBalance(clearCache: true)
                        }
                    }
                }
            }
            .onAppear {
                #if DEBUG
                let timeSinceAppStart = Date().timeIntervalSince(AppDelegate.appStartTime)
                print("🔍 [GenieView] onAppear at +\(String(format: "%.2f", timeSinceAppStart))s")
                print("🔍 [GenieView] ViewModel messages count: \(viewModel.messages.count)")
                #endif
                
                // CRITICAL: Defer Combine subscription setup to prevent blocking SwiftUI body evaluation
                // This was causing 4-6 second hangs during onAppear
                Task { @MainActor in
                    // Wait for next run loop to let SwiftUI finish initial render
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                    setupActionHandlerSubscriptions()
                    print("✅ [GenieView] ActionHandler subscriptions setup complete")
                }
                
                // Load token balance immediately (non-blocking)
                // This ensures balance appears quickly without blocking UI
                Task.detached(priority: .userInitiated) {
                    await MainActor.run {
                        // Check if user needs initialization
                        let hasInitialized = UserDefaults.standard.bool(forKey: "genie_initialized")
                        
                        if !hasInitialized {
                            // Initialize new user with free tokens
                            Task {
                                do {
                                    try await GenieAPIService.shared.initializeUser()
                                    UserDefaults.standard.set(true, forKey: "genie_initialized")
                                    print("🧞 [Genie] ✅ User initialized with free tokens")
                                    
                                    // Load balance after initialization
                                    viewModel.loadBalance(clearCache: true)
                                } catch {
                                    print("🧞 [Genie] ❌ Error initializing user: \(error)")
                                    // Still try to load balance even if initialization fails
                                    viewModel.loadBalance()
                                }
                            }
                        } else {
                            // User already initialized, just load balance immediately
                            print("🧞 [Genie] User already initialized - loading balance...")
                            viewModel.loadBalance()
                        }
                    }
                }
                
                // Load AI-powered personalized suggestions (non-blocking)
                // Fallback suggestions show immediately, AI suggestions update when ready
                suggestionService.loadSuggestions(for: context)
            }
    }
    
    private var contentStack: some View {
        VStack(spacing: 0) {
            // Header - stable and doesn't need re-rendering on input focus
            header
                .id("genie-header") // Stable identity
            
            // Balance Warning Banner (if needed)
            balanceWarningBanner
            
            // Messages
            messagesContent
            
            // Input - isolated view to prevent full body re-evaluation on focus change
            // This eliminates the 30-second delay when tapping TextField
            inputBar
                .id("genie-input-bar") // Stable identity
        }
    }
    
    @ViewBuilder
    private var balanceWarningBanner: some View {
        if showBalanceWarning, let warning = currentWarning {
            TokenBalanceWarningBanner(
                warning: warning,
                onTopUp: {
                    sheetCoordinator.activeSheet = .tokenPurchase
                },
                onDismiss: {
                    withAnimation(.spring(response: 0.3)) {
                        showBalanceWarning = false
                    }
                }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(1)
        }
    }
    
    @ViewBuilder
    private var messagesContent: some View {
        if viewModel.messages.isEmpty {
            emptyState
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            // Dismiss keyboard when tapping on empty state
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                )
        } else {
            messagesList
                .id("genie-messages-list") // Stable identity
                // Note: Removed .drawingGroup() - was causing TextViewAdaptor rendering issues
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.brandOrange)
                    Text("Genie")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("How can I help you today?")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Conversations button (ChatGPT-style)
            Button(action: {
                showConversationsList.toggle()
            }) {
                Image(systemName: "message.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            // Token balance (tappable) - load balance lazily in background
            Button(action: {
                // Load balance in background if not loaded (non-blocking)
                if viewModel.tokenBalance == -1 {
                    Task.detached(priority: .utility) {
                        await MainActor.run {
                            viewModel.loadBalance()
                        }
                    }
                }
                sheetCoordinator.activeSheet = .tokenPurchase
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                    Text(viewModel.tokenBalance == -1 ? "..." : "\(viewModel.tokenBalance)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(tokenBalanceColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(tokenBalanceBackgroundColor)
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                // Load balance immediately when button appears (if not already loaded)
                if viewModel.tokenBalance == -1 {
                    Task.detached(priority: .userInitiated) {
                        await MainActor.run {
                            viewModel.loadBalance()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color.brandBlue
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
    }
    
    // MARK: - Empty State (ChatGPT-style)
    
    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Centered content (ChatGPT-style)
                    VStack(spacing: 24) {
                        // Genie icon/logo - centered
                        Circle()
                            .fill(Color.brandOrange.opacity(0.15))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(Color.brandOrange)
                            )
                            .padding(.top, geometry.size.height * 0.15) // Responsive spacing
                        
                        // Welcome message - fun and motivational
                        Text("How can I help you?")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 32)
                        
                        // AI-powered suggestion chips (fallback shown immediately, AI updates when ready)
                        // Full-width layout - each card takes full width
                        VStack(spacing: 12) {
                            ForEach(suggestionService.suggestions, id: \.self) { suggestion in
                                suggestionChip(suggestion)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height * 0.6) // Center vertically
                    
                    Spacer()
                }
            }
        }
    }
    
    // ChatGPT-style compact suggestion chip
    private func suggestionChip(_ text: String) -> some View {
        Button(action: {
            // Use async to prevent blocking
            Task { @MainActor in
                inputText = text
                // Small delay to let UI update
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                sendMessage()
            }
        }) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Messages List
    
    @State private var lastScrollTime: Date = Date()
    @State private var scrollTask: Task<Void, Never>?
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(viewModel.messages.filter { !$0.text.isEmpty }) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            // Optimize rendering - only render visible items
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if viewModel.isLoading {
                        if viewModel.loadingState != .idle && viewModel.loadingState != .complete && viewModel.loadingState.message.isEmpty == false {
                            LoadingStatusView(state: viewModel.loadingState, thinking: viewModel.currentThinking)
                                .id("loading-status")
                        } else {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively) // Allow scroll to dismiss keyboard
            // Use .task with id instead of .onChange to prevent blocking body evaluation
            .task(id: viewModel.messages.count) {
                // Debounce scroll calls - only scroll if enough time has passed
                let now = Date()
                let timeSinceLastScroll = now.timeIntervalSince(await MainActor.run { lastScrollTime })
                guard viewModel.messages.count > 0, timeSinceLastScroll > 0.3 else { return }
                await MainActor.run {
                    lastScrollTime = now
                }
                
                // Cancel any pending scroll task
                scrollTask?.cancel()
                
                // Schedule new scroll with debounce - use async task to prevent blocking
                scrollTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s debounce for layout to settle
                    guard !Task.isCancelled else { return }
                    
                    // Only scroll if layout is stable and we have messages
                    guard let lastMessage = self.viewModel.messages.last else { return }
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .task(id: viewModel.isLoading) {
                guard viewModel.isLoading else { return }
                
                // Cancel any pending scroll task
                scrollTask?.cancel()
                
                // Schedule scroll with debounce - use async task
                scrollTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s for loading indicator to appear and layout
                    guard !Task.isCancelled else { return }
                    // Scroll to loading status or typing indicator
                    if viewModel.loadingState != .idle && viewModel.loadingState != .complete {
                        proxy.scrollTo("loading-status", anchor: .bottom)
                    } else {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Dismiss keyboard when tapping on messages area
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .onAppear {
                // Initial scroll to bottom after layout completes
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s for initial layout
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Bar
    
    // CRITICAL: Use @ViewBuilder to create isolated view structure
    // This prevents full body re-evaluation when TextField gets focus
    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(alignment: .bottom, spacing: 8) {
                // Press-and-hold microphone button
                VoiceInputButton(
                    isListening: voiceRecordingService.isRecording,
                    partialText: voiceService.partialText,
                    onStartRecording: {
                        startVoiceRecording()
                    },
                    onStopRecording: {
                        stopVoiceRecording()
                    }
                )
                
                // iMessage-style "+" button for attachments
                Button(action: {
                    showAttachmentMenu = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.brandOrange)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Add attachment")
                .buttonStyle(.plain)
                .sheet(isPresented: $showAttachmentMenu) {
                    AttachmentMenuView(
                        onSnapCalorieSelected: {
                            print("📸 [GenieView] Snap Calorie selected - closing menu")
                            // Dismiss sheet first
                            showAttachmentMenu = false
                            
                            // Delay to allow sheet to dismiss before presenting fullScreenCover
                            Task { @MainActor in
                                print("📸 [GenieView] Waiting for sheet to dismiss...")
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                print("📸 [GenieView] Showing FoodCamera")
                            showFoodCamera = true
                            }
                        },
                        onEquipmentSelected: {
                            print("🏋️ [GenieView] Equipment selected - closing menu")
                            // Dismiss sheet first
                            showAttachmentMenu = false
                            
                            // Delay to allow sheet to dismiss before presenting fullScreenCover
                            Task { @MainActor in
                                print("🏋️ [GenieView] Waiting for sheet to dismiss...")
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                print("🏋️ [GenieView] Showing EquipmentCamera")
                            showEquipmentScanner = true
                            }
                        },
                        onFridgeSelected: {
                            print("🧊 [GenieView] Fridge selected - closing menu")
                            // Dismiss sheet first
                            showAttachmentMenu = false
                            
                            // Delay to allow sheet to dismiss before presenting fullScreenCover
                            Task { @MainActor in
                                print("🧊 [GenieView] Waiting for sheet to dismiss...")
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                print("🧊 [GenieView] Showing FridgeCamera")
                                showFridgeScanner = true
                            }
                        }
                    )
                }
                
                // Text input or voice recording UI
                if voiceRecordingService.isRecording || voiceRecordingService.recordedAudioURL != nil {
                    VoiceRecordingView(
                        recordingService: voiceRecordingService,
                        onSend: {
                            sendVoiceRecording()
                        },
                        onDelete: {
                            voiceRecordingService.deleteRecording()
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                FastTextField(
                    text: $inputText,
                        placeholder: "Ask Genie anything...",
                    onSubmit: {
                        if !inputText.isEmpty && !viewModel.isLoading {
                            sendMessage()
                        }
                    }
                )
                .frame(minHeight: 44, maxHeight: 132)
                .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Send button - ChatGPT style (only when text exists)
                if canSend {
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        sendMessage()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.brandOrange)
                                .frame(width: 32, height: 32)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .accessibilityLabel("Send")
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            Color.brandBlue
                .shadow(color: .black.opacity(0.15), radius: 4, y: -2)
        )
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
    
    // MARK: - Multimodal Handlers
    
    @StateObject private var voiceRecordingService = VoiceRecordingService.shared
    @State private var voiceRecordingTask: Task<Void, Never>?
    @State private var recordedVoiceText: String?
    @State private var showingVoicePreview = false
    
    private func startVoiceRecording() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Run recording on background thread to prevent UI hang
        Task {
            do {
                try await voiceRecordingService.startRecording()
            } catch {
                print("🎤 [Voice] Error starting recording: \(error)")
                await MainActor.run {
                    // Show error to user
                    voiceRecordingService.deleteRecording()
                }
            }
        }
    }
    
    private func stopVoiceRecording() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        voiceRecordingService.stopRecording()
        
        // Start transcription in background (non-blocking)
        // Don't wait for it - let it happen asynchronously
        if voiceRecordingService.recordedAudioURL != nil {
            Task.detached(priority: .utility) {
                do {
                    let text = try await voiceRecordingService.transcribeAudio()
                    await MainActor.run {
                        recordedVoiceText = text
                    }
            } catch {
                    print("🎤 [Voice] Error transcribing: \(error)")
                }
            }
        }
    }
    
    private func sendVoiceRecording() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Get current text if available, otherwise start async transcription
        Task {
            // Check if we already have transcribed text
            if let existingText = recordedVoiceText, !existingText.isEmpty {
                // We have text, send immediately
                await viewModel.sendMessage(existingText, isVoiceInput: true)
                
                // Clean up
                await MainActor.run {
                    voiceRecordingService.deleteRecording()
                    recordedVoiceText = nil
                }
            } else if voiceRecordingService.recordedAudioURL != nil {
                // No text yet, start transcription and send when ready
                // This happens in background so UI doesn't hang
                Task.detached(priority: .utility) {
                    do {
                        let text = try await voiceRecordingService.transcribeAudio()
                        // Send message once transcription is complete
                        await viewModel.sendMessage(text, isVoiceInput: true)
                        
                        // Clean up
                        await MainActor.run {
                            voiceRecordingService.deleteRecording()
                            recordedVoiceText = nil
                        }
                    } catch {
                        print("🎤 [Voice] Error transcribing: \(error)")
                        // Clean up even on error
                        await MainActor.run {
                            voiceRecordingService.deleteRecording()
                            recordedVoiceText = nil
                        }
                    }
                }
            }
        }
    }
    
    private func handleVoiceInput() {
        // Legacy method - now handled by press-and-hold button
        startVoiceRecording()
    }
    
    private func sendMessage(wasVoiceInput: Bool = false) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Clear input immediately for responsive UI
        inputText = ""
        
        // Force clear the text view immediately (in case it's still editing)
        DispatchQueue.main.async {
            // Dismiss keyboard first
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        // Ensure we have a conversation (create if needed)
        if conversationManager.currentConversationId == nil {
            Task {
                if let newConv = await conversationManager.createNewConversation() {
                    await MainActor.run {
                        conversationManager.currentConversationId = newConv.id
                        viewModel.sessionId = newConv.id
                    }
                    viewModel.sendMessage(text, isVoiceInput: wasVoiceInput)
                }
            }
        } else {
            // Send message - this is already async in viewModel
            viewModel.sendMessage(text, isVoiceInput: wasVoiceInput)
        }
        
        // Speak response if voice was used
        if wasVoiceInput {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait for response
                if let lastMessage = viewModel.messages.last, !lastMessage.isUser {
                    voiceService.speak(lastMessage.text)
                }
            }
        }
    }
    
    private func handlePhotoCapture(_ image: UIImage) {
        Task {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let base64 = imageData.base64EncodedString()
            
            // Send image query
//            viewModel.sendImageQuery(query: "What do you see in this image?", imageBase64: base64)
        }
    }
    
    private func handleVideoCapture(_ videoURL: URL) {
        Task {
            // Extract frames and send
            let frames = try? await extractFrames(from: videoURL)
            if let frames = frames {
                let frameData = frames.compactMap { $0.jpegData(compressionQuality: 0.7)?.base64EncodedString() }
//                viewModel.sendVideoQuery(query: "Analyze my form", frames: frameData)
            }
        }
    }
    
    private func extractFrames(from videoURL: URL) async throws -> [UIImage] {
        return try await visionService.extractKeyFrames(from: videoURL, count: 5)
    }
    
    // MARK: - Helper Functions
    
    private var tokenBalanceColor: Color {
        // Guard against invalid tokenBalance values to prevent NaN
        let balance = max(0, viewModel.tokenBalance) // Ensure non-negative
        if balance == 0 {
            return .red
        } else if balance <= 10 {
            return .orange
        } else if balance <= 50 {
            return .yellow
        } else {
            return .white
        }
    }
    
    private var tokenBalanceBackgroundColor: Color {
        // Guard against invalid tokenBalance values to prevent NaN
        let balance = max(0, viewModel.tokenBalance) // Ensure non-negative
        if balance == 0 {
            return Color.red.opacity(0.2)
        } else if balance <= 10 {
            return Color.orange.opacity(0.2)
        } else {
            return Color.white.opacity(0.15)
        }
    }
    
    private func handleBalanceWarning(_ warning: BalanceWarning?) {
        guard let warning = warning else { return }
        
        // Only show warning once per session for non-critical levels
        if warning.level == "medium" && showBalanceWarning {
            return
        }
        
        currentWarning = warning
        withAnimation(.spring(response: 0.3)) {
            showBalanceWarning = true
        }
        
        // Auto-dismiss medium warnings after 5 seconds
        if warning.level == "medium" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.spring(response: 0.3)) {
                    showBalanceWarning = false
                }
            }
        }
    }
    
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    // Cache computed values to prevent recalculation
    private var isUserMessage: Bool { message.isUser }
    private var hasAnalysis: Bool { !message.isUser && message.parsedAnalysis != nil }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUserMessage {
                Spacer(minLength: 60)
                messageContent
            } else {
                // Genie avatar - simplified to prevent layout issues
                Circle()
                    .fill(Color.brandOrange.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brandOrange)
                    )
                    .drawingGroup() // Composite avatar for performance
                
                messageContent
                Spacer(minLength: 60)
            }
        }
        .drawingGroup() // Composite entire bubble for performance
    }
    
    private var messageContent: some View {
        VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 6) {
            // Use cached parsed analysis to avoid re-parsing on every render
            if hasAnalysis, let analysisResponse = message.parsedAnalysis {
                AnalysisResponseView(analysis: analysisResponse)
                    .drawingGroup() // Composite for performance
            } else if !message.text.isEmpty {
                // Only show text if it's not empty (meditation actions have empty text)
                // Use SwiftUI's built-in markdown support for proper list rendering
                Text(.init(message.text))
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(4)
                    .foregroundColor(isUserMessage ? Color.brandBlue : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                isUserMessage ? 
                                Color.white :
                                Color.white.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isUserMessage ? Color.clear : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            }
            
            if !isUserMessage && message.tokensUsed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("\(message.tokensUsed) tokens used")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 4)
            }
            
            // Thinking panel removed - thinking is only shown during loading, not saved in messages
            
            // Action buttons (meditation, videos, equipment, etc.)
            if !isUserMessage, let actions = message.actions, !actions.isEmpty {
                ActionButtonsView(actions: actions)
                    .padding(.top, 8)
                    .drawingGroup() // Composite for performance
            }
        }
    }
}

// MARK: - Action Buttons View

struct ActionButtonsView: View {
    let actions: [GenieAction]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(actions) { action in
                ActionButton(action: action)
            }
        }
    }
}

struct ActionButton: View {
    let action: GenieAction
    
    var body: some View {
        Button {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            // Handle action
            if action.type == "meditation" {
                // For meditation, ensure UI is shown
                GenieActionHandler.shared.showingMeditation = true
                // Then handle the action (which will start audio)
            GenieActionHandler.shared.handleAction(action)
            } else if action.type == "motivation" {
                // For motivation, ensure UI is shown
                GenieActionHandler.shared.showingMotivation = true
                GenieActionHandler.shared.handleAction(action)
            } else if action.type == "bedtime_story" {
                // For bedtime story, ensure UI is shown
                GenieActionHandler.shared.showingBedtimeStory = true
                GenieActionHandler.shared.handleAction(action)
            } else if action.type == "create_movement" {
                // For movement creation, handle the action first (prepares data)
                GenieActionHandler.shared.handleAction(action)
                // Then show preview when user clicks button
                GenieActionHandler.shared.showingMovementPreview = true
            } else if action.type == "create_session" {
                // For session creation, handle the action first (prepares data)
                GenieActionHandler.shared.handleAction(action)
                // Then show preview when user clicks button
                GenieActionHandler.shared.showingSessionPreview = true
            } else if action.type == "create_plan" {
                // For plan creation, handle the action first (prepares data)
                GenieActionHandler.shared.handleAction(action)
                // Then show preview when user clicks button
                GenieActionHandler.shared.showingPlanPreview = true
            } else {
                GenieActionHandler.shared.handleAction(action)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconForAction(action.type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brandOrange)
                
                Text(labelForAction(action.type))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandOrange.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandOrange.opacity(0.4), lineWidth: 1)
            )
        }
    }
    
    private func iconForAction(_ type: String) -> String {
        switch type {
        case "meditation": return "sparkles"
        case "video_results": return "play.rectangle.fill"
        case "equipment_identified": return "figure.strengthtraining.traditional"
        case "nutrition_data": return "leaf.fill"
        case "create_movement": return "figure.strengthtraining.traditional"
        case "create_session": return "list.bullet.rectangle"
        case "create_plan": return "calendar"
        case "form_feedback": return "checkmark.seal.fill"
        case "vision_board": return "photo.on.rectangle.angled"
        case "manifestation": return "sparkles.rectangle.stack"
        case "affirmation": return "quote.bubble.fill"
        default: return "circle.fill"
        }
    }
    
    private func labelForAction(_ type: String) -> String {
        switch type {
        case "meditation": return "Start Meditation"
        case "video_results": return "Watch Videos"
        case "equipment_identified": return "View Equipment"
        case "nutrition_data": return "Log Nutrition"
        case "create_movement": return "Preview Movement"
        case "create_session": return "Preview Session"
        case "create_plan": return "Preview Plan"
        case "form_feedback": return "View Feedback"
        case "vision_board": return "View Vision Board"
        case "manifestation": return "View Manifestation"
        case "affirmation": return "View Affirmations"
        default: return "View"
        }
    }
}

// MARK: - Loading Status View

struct LoadingStatusView: View {
    let state: QueryLoadingState
    let thinking: [String]
    @State private var animating = false
    @State private var showThinking = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Genie avatar
            Circle()
                .fill(Color.brandOrange.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.brandOrange)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Status message
                Text(state.message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                
                // Show thinking trace if available (only during loading)
                if !thinking.isEmpty {
                    Button(action: { withAnimation { showThinking.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 12))
                            Text(showThinking ? "Hide thinking" : "Show thinking")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                    }
                    
                    if showThinking {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(thinking.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Progress indicator (only if no thinking or thinking is collapsed)
                if thinking.isEmpty || !showThinking {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.brandOrange.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .scaleEffect(animating ? 1.0 : 0.6)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animating
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Genie avatar - simplified to prevent layout issues
            Circle()
                .fill(Color.brandOrange.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.brandOrange)
                )
            
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 60)
        }
        .onAppear {
            // Defer animation start to avoid blocking initial render
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                animating = true
            }
        }
        .drawingGroup() // Composite to single layer
    }
}

// MARK: - Thinking Disclosure (removed - thinking now shown only during loading in LoadingStatusView)

// MARK: - View Model

// MARK: - Loading State

enum QueryLoadingState: Equatable {
    case idle
    case checkingAccount
    case checkingBalance
    case generatingMeditation
    case creatingAudio
    case fetchingResults
    case processing
    case complete
    
    var message: String {
        switch self {
        case .idle: return ""
        case .checkingAccount: return "Checking your account..."
        case .checkingBalance: return "Checking balance..."
        case .generatingMeditation: return "Generating meditation..."
        case .creatingAudio: return "Creating audio..."
        case .fetchingResults: return "Fetching results..."
        case .processing: return "Processing..."
        case .complete: return ""
        }
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var tokenBalance: Int = -1 // -1 indicates not loaded
    @Published var isLoading = false
    @Published var loadingState: QueryLoadingState = .idle
    @Published var balanceWarning: BalanceWarning?
    @Published var upsellData: UpsellData?
    @Published var currentThinking: [String] = [] // Thinking trace shown during loading only
    
    private let context: GenieContext
    var sessionId: String = UUID().uuidString // Make mutable for conversation switching
    private var hasShownWarningThisSession = false
    private var isLoadingBalance = false // Guard against concurrent calls
    
    init(context: GenieContext) {
        self.context = context
        #if DEBUG
        let timeSinceAppStart = Date().timeIntervalSince(AppDelegate.appStartTime)
        print("🔍 [GenieViewModel] ChatViewModel initialized at +\(String(format: "%.2f", timeSinceAppStart))s with context: \(context)")
        #endif
        print("🧞 [Genie] ChatViewModel initialized with context: \(context)")
    }
    
    func loadBalance(clearCache: Bool = false) {
        // Prevent concurrent calls
        guard !isLoadingBalance else {
            print("🧞 [Genie] ⏭️ Balance load already in progress, skipping duplicate call")
            return
        }
        
        isLoadingBalance = true
        print("🧞 [Genie] Loading token balance... (clearCache: \(clearCache))")
        
        // Clear cache if requested (e.g., after token purchase)
        if clearCache {
            GenieAPIService.shared.clearTokenBalanceCache()
        }
        
        // Use non-blocking async task on background priority
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                // Always get fresh data (don't use cache) when explicitly loading balance
                let response = try await GenieAPIService.shared.getTokenBalance(useCache: !clearCache)
                
                await MainActor.run {
                    // Ensure balance is valid (non-negative) to prevent NaN issues
                    self.tokenBalance = max(0, response.balance)
                    self.isLoadingBalance = false
                    print("🧞 [Genie] ✅ Token balance loaded: \(response.balance)")
                }
            } catch {
                print("🧞 [Genie] ❌ Error loading balance: \(error)")
                
                // Set default balance on error to not block UI
                await MainActor.run {
                    self.tokenBalance = 0
                    self.isLoadingBalance = false
                    print("🧞 [Genie] ⚠️ Set default balance to 0 due to error")
                }
                
            }
        }
    }
    
    @MainActor func sendMessage(_ text: String, isVoiceInput: Bool = false) {
        print("🧞 [Genie] 📤 Sending message: \"\(text)\"")
        print("🧞 [Genie] Context: \(context)")
        print("🧞 [Genie] Session ID: \(sessionId)")
        if isVoiceInput {
            print("🧞 [Genie] 🎤 Voice input detected")
        }
        
        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        
        // Save user message to conversation (async, non-blocking)
        if let conversationId = GenieConversationManager.shared.currentConversationId {
            Task.detached(priority: .utility) {
                await GenieConversationManager.shared.saveMessage(
                    userMessage,
                    to: conversationId
                )
            }
        }
        
        isLoading = true
        loadingState = .checkingAccount
        currentThinking = [] // Clear previous thinking
        
        Task {
            do {
                // Step 1: Check account
                await MainActor.run {
                    loadingState = .checkingAccount
                }
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s for UI feedback
                
                // Step 2: Check balance (quick check)
                await MainActor.run {
                    loadingState = .checkingBalance
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                
                // Step 3: Detect if this is a meditation query
                let isMeditationQuery = text.lowercased().contains("meditate") || 
                                       text.lowercased().contains("meditation") ||
                                       text.lowercased().contains("stress") ||
                                       text.lowercased().contains("anxiety") ||
                                       text.lowercased().contains("breathing") ||
                                       text.lowercased().contains("breathe")
                
                if isMeditationQuery {
                    await MainActor.run {
                        loadingState = .generatingMeditation
                    }
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                    
                    // Show audio creation step
                    await MainActor.run {
                        loadingState = .creatingAudio
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s for audio generation
                } else {
                    await MainActor.run {
                        loadingState = .fetchingResults
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                }
                
                // Step 4: Processing
                await MainActor.run {
                    loadingState = .processing
                }
                
                print("🧞 [Genie] 🌐 Calling API...")
                
                // Build conversation history from previous messages (last 10 messages for context)
                let historyMessages = messages.prefix(messages.count - 1) // Exclude the current message we just added
                    .suffix(10) // Last 10 messages
                    .map { msg in
                        ConversationMessage(
                            role: msg.isUser ? "user" : "assistant",
                            text: msg.text
                        )
                    }
                
                print("🧞 [Genie] Sending \(historyMessages.count) previous messages as context")
                let response = try await GenieAPIService.shared.query(text, sessionId: sessionId, isVoiceInput: isVoiceInput, conversationHistory: historyMessages.isEmpty ? nil : Array(historyMessages))
                
                // Show thinking trace during loading (will be cleared when response arrives)
                if let thinking = response.thinking, !thinking.isEmpty {
                    await MainActor.run {
                        currentThinking = thinking
                    }
                    
                    // Check thinking trace for audio generation
                    let thinkingText = thinking.joined(separator: " ").lowercased()
                    if thinkingText.contains("generating audio") || thinkingText.contains("creating audio") {
                        await MainActor.run {
                            loadingState = .creatingAudio
                        }
                        try? await Task.sleep(nanoseconds: 300_000_000) // Give time for audio generation
                    }
                }
                
                print("🧞 [Genie] ✅ API Response received")
                print("🧞 [Genie] Response: \(response.response)")
                print("🧞 [Genie] Tokens used: \(response.tokensUsed)")
                print("🧞 [Genie] Tokens remaining: \(response.tokensRemaining)")
                
                    // CRITICAL: Update token balance immediately after receiving response
                    // This ensures the UI reflects the new balance right away
                    await MainActor.run {
                        let previousBalance = self.tokenBalance
                        let newBalance = max(0, response.tokensRemaining) // Ensure non-negative
                        self.tokenBalance = newBalance
                        print("🧞 [Genie] 💰 Token balance updated: \(previousBalance) → \(newBalance) (used: \(response.tokensUsed))")
                        
                        // Verify balance makes sense (should decrease if tokens were used)
                        if response.tokensUsed > 0 && previousBalance >= 0 {
                            let expectedBalance = previousBalance - response.tokensUsed
                            if abs(newBalance - expectedBalance) > 1 {
                                print("⚠️ [Genie] Balance mismatch detected! Expected: \(expectedBalance), Got: \(newBalance). Refreshing from server...")
                                // Refresh balance from server to ensure accuracy
                                Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // Small delay
                                    await MainActor.run {
                                        self.loadBalance(clearCache: true)
                                    }
                                }
                            }
                        }
                        
                        // Clear thinking trace now that response has arrived
                        currentThinking = []
                    
                    // Handle actions from agent and generate user-friendly responses
                    if let actions = response.actions, !actions.isEmpty {
                        let hasMeditationAction = actions.contains { $0.type == "meditation" }
                        let hasStoryAction = actions.contains { $0.type == "bedtime_story" }
                        let hasMotivationAction = actions.contains { $0.type == "motivation" }
                        let hasMovementAction = actions.contains { $0.type == "create_movement" }
                        let hasSessionAction = actions.contains { $0.type == "create_session" }
                        let hasPlanAction = actions.contains { $0.type == "create_plan" }
                        
                        // Generate friendly response text for meditation/story/motivation/workout actions
                        var friendlyResponseText = response.response
                        
                        if hasMeditationAction, let meditationAction = actions.first(where: { $0.type == "meditation" }) {
                            // Get actual duration from action data (not hardcoded)
                            let duration = meditationAction.data["duration"]?.intValue ?? 
                                          meditationAction.data["duration"]?.doubleValue.map({ Int($0) }) ?? 10
                            let focus = meditationAction.data["focus"]?.stringValue ?? "stress"
                            let focusDisplay = focus.capitalized
                            
                            // Generate friendly meditation message with actual duration
                            friendlyResponseText = "I've created a personalized \(duration)-minute \(focusDisplay) meditation for you. Ready to start?"
                        } else if hasMotivationAction, let motivationAction = actions.first(where: { $0.type == "motivation" }) {
                            let duration = motivationAction.data["duration"]?.intValue ?? motivationAction.data["duration"]?.doubleValue.map({ Int($0) }) ?? 10
                            let title = motivationAction.data["title"]?.stringValue ?? "Motivational Session"
                            
                            // Generate friendly motivation message
                            friendlyResponseText = "I've prepared a \(duration)-minute motivational session for you: \"\(title)\". Ready to get started?"
                        } else if hasStoryAction, let storyAction = actions.first(where: { $0.type == "bedtime_story" }) {
                            let duration = storyAction.data["duration"]?.intValue ?? 10
                            let tone = storyAction.data["tone"]?.stringValue ?? "calming"
                            let toneDisplay = tone.capitalized
                            
                            // Generate friendly story message
                            friendlyResponseText = "I've written a \(duration)-minute \(toneDisplay) bedtime story for you. Would you like to listen?"
                        } else if hasMovementAction, let movementAction = actions.first(where: { $0.type == "create_movement" }) {
                            let movementName = movementAction.data["name"]?.stringValue ?? movementAction.data["movement1Name"]?.stringValue ?? "movement"
                            friendlyResponseText = "I've created a movement called \"\(movementName)\" for you. Would you like to preview it?"
                        } else if hasSessionAction, let sessionAction = actions.first(where: { $0.type == "create_session" }) {
                            let sessionName = sessionAction.data["name"]?.stringValue ?? "workout session"
                            friendlyResponseText = "I've created a workout session called \"\(sessionName)\" for you. Would you like to preview it?"
                        } else if hasPlanAction, let planAction = actions.first(where: { $0.type == "create_plan" }) {
                            let planName = planAction.data["name"]?.stringValue ?? "workout plan"
                            friendlyResponseText = "I've created a workout plan called \"\(planName)\" for you. Would you like to preview it?"
                        }
                        
                        // Always add message with friendly text (even for meditation/story)
                        // NOTE: Don't save thinking trace - it's only shown during loading
                            let genieMessage = ChatMessage(
                            text: friendlyResponseText,
                                isUser: false,
                                tokensUsed: response.tokensUsed,
                            thinking: nil, // Don't save thinking in messages
                                actions: response.actions
                            )
                            messages.append(genieMessage)
                            
                            // Save Genie response to conversation (async, non-blocking)
                            if let conversationId = GenieConversationManager.shared.currentConversationId {
                                Task.detached(priority: .utility) {
                                    await GenieConversationManager.shared.saveMessage(
                                        genieMessage,
                                        to: conversationId
                                    )
                                }
                            }
                        } else {
                        // No actions - check if this is a meditation/story response that should have had an action
                        // IMPORTANT: Only detect meditation if there are clear meditation indicators
                        // Don't match on generic words like "focus" that appear in workout responses
                        let responseLower = response.response.lowercased()
                        let isMeditationResponse = (responseLower.contains("meditation") || 
                                                  responseLower.contains("meditate")) &&
                                                  (responseLower.contains("breathing") ||
                                                   responseLower.contains("mindfulness") ||
                                                   responseLower.contains("script") ||
                                                   responseLower.contains("guided") ||
                                                   responseLower.contains("session") && responseLower.contains("meditation"))
                        
                        // Story detection - be very specific to avoid false positives
                        // Only detect if it's clearly a story/narrative response, not injury/rehab queries
                        let isStoryResponse = (responseLower.contains("story") || 
                                              responseLower.contains("tale") ||
                                              responseLower.contains("narrative")) &&
                                              !responseLower.contains("knee") &&
                                              !responseLower.contains("pain") &&
                                              !responseLower.contains("injury") &&
                                              !responseLower.contains("rehab") &&
                                              !responseLower.contains("recovery") &&
                                              !responseLower.contains("hurt") &&
                                              !responseLower.contains("ache")
                        
                        var displayText = response.response
                        
                        // If it's a meditation response without action, parse and create action
                        var createdActions: [GenieAction] = []
                        
                        if isMeditationResponse && !isStoryResponse {
                            // Extract meditation data from response
                            let (duration, focus, script) = parseMeditationFromResponse(response.response)
                            
                            // Create meditation action from parsed data
                            let meditationActionData: [String: AnyCodable] = [
                                "duration": AnyCodable(duration),
                                "focus": AnyCodable(focus),
                                "script": AnyCodable(script),
                                "playAudio": AnyCodable(true),
                                "isMotivation": AnyCodable(false)
                            ]
                            
                            let meditationAction = GenieAction(
                                type: "meditation",
                                data: meditationActionData
                            )
                            
                            createdActions.append(meditationAction)
                            displayText = "I've prepared a \(duration)-minute meditation for you. Ready to start?"
                            
                            print("🧘 [GenieView] Created meditation action from text response: \(duration) min, focus: \(focus)")
                        } else if isStoryResponse {
                            // If it's a story response without action, generate friendly message
                            displayText = "I've written a story for you. Would you like to listen?"
                        }
                        
                        // Combine existing actions with created ones
                        var allActions = response.actions ?? []
                        allActions.append(contentsOf: createdActions)
                        
                        // NOTE: Don't save thinking trace - it's only shown during loading
                        let genieMessage = ChatMessage(
                            text: displayText,
                            isUser: false,
                            tokensUsed: response.tokensUsed,
                            thinking: nil, // Don't save thinking in messages
                            actions: allActions.isEmpty ? nil : allActions
                        )
                        messages.append(genieMessage)
                        
                        // Prepare meditation actions (but don't start playing yet)
                        // The meditation will be ready when the message appears
                        // Audio will start when user clicks "Get Started"
                        for action in createdActions {
                            print("🧘 [GenieView] Preparing meditation action (will start on button click)...")
                            // Store the action but don't show UI yet - wait for button click
                            // The action will be handled when user clicks "Get Started"
                        }
                        
                        // Save Genie response to conversation (async, non-blocking)
                        if let conversationId = GenieConversationManager.shared.currentConversationId {
                            Task.detached(priority: .utility) {
                                await GenieConversationManager.shared.saveMessage(
                                    genieMessage,
                                    to: conversationId
                                )
                            }
                        }
                        
                        // Log warning if backend should have returned an action
                        if isMeditationResponse || isStoryResponse {
                            print("⚠️ [GenieView] Backend returned text-only response for \(isMeditationResponse ? "meditation" : "story") query. Created action from response.")
                        }
                    }
                    
                    // Balance already updated above - no need to update again here
                    // tokenBalance = response.tokensRemaining (removed - already updated)
                    
                    // Update conversation title if provided in response
                    if let title = response.title, !title.isEmpty,
                       let conversationId = GenieConversationManager.shared.currentConversationId {
                        print("📝 [GenieView] Updating conversation title: \"\(title)\"")
                        Task {
                            await GenieConversationManager.shared.updateConversationTitle(conversationId: conversationId, title: title)
                        }
                    }
                }
                    
                await MainActor.run {
                    // Handle actions from agent
                    if let actions = response.actions, !actions.isEmpty {
                        print("🎯 [GenieView] Agent sent \(actions.count) action(s)")
                        print("🎯 [GenieView] Action types: \(actions.map { $0.type }.joined(separator: ", "))")
                        
                        for (index, action) in actions.enumerated() {
                            print("🎯 [GenieView] Processing action \(index + 1)/\(actions.count): \(action.type)")
                            GenieActionHandler.shared.handleAction(action)
                        }
                        
                        print("✅ [GenieView] All actions processed")
                    } else {
                        print("ℹ️ [GenieView] No actions in response - agent sent text-only response")
                    }
                    
                    // Handle balance warning
                    if let warning = response.balanceWarning {
                        handleBalanceWarning(warning)
                    }
                    
                    loadingState = .complete
                    isLoading = false
                }
            } catch let error as GenieError {
                print("🧞 [Genie] ❌ GenieError: \(error)")
                
                await MainActor.run {
                    // Handle insufficient tokens with smart upsell
                    if case .insufficientTokens(let data) = error {
                        print("🧞 [Genie] 💰 Insufficient tokens - showing upsell")
                        print("🧞 [Genie] 💰 Actual balance from server: \(data.balance), required: \(data.required)")
                        
                        // CRITICAL: Update token balance immediately with actual balance from error response
                        // The cache was stale, so we use the server's actual balance
                        let previousBalance = self.tokenBalance
                        self.tokenBalance = max(0, data.balance)
                        print("🧞 [Genie] 💰 Updated balance from error response: \(previousBalance) → \(self.tokenBalance)")
                        
                        // Don't remove user message - keep it visible so user knows what they asked
                        // Show error message with helpful context
                        let errorMessage = ChatMessage(
                            text: "I'd love to help, but you don't have enough tokens right now. Tap the token balance above to get more.",
                            isUser: false
                        )
                        messages.append(errorMessage)
                        self.upsellData = data
                    } else {
                        let errorMessage = ChatMessage(
                            text: getErrorMessage(for: error),
                            isUser: false
                        )
                        messages.append(errorMessage)
                    }
                    
                    loadingState = .idle
                    isLoading = false
                }
            } catch {
                print("🧞 [Genie] ❌ Unexpected error: \(error)")
                
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        text: "Sorry, I encountered an error. Please try again.",
                        isUser: false
                    )
                    messages.append(errorMessage)
                    loadingState = .idle
                    isLoading = false
                    
                }
            }
        }
    }
    
    private func handleBalanceWarning(_ warning: BalanceWarning) {
        // Only show critical/low warnings once per session
        if (warning.level == "critical" || warning.level == "low") && hasShownWarningThisSession {
            return
        }
        
        balanceWarning = warning
        
        if warning.level == "critical" || warning.level == "low" {
            hasShownWarningThisSession = true
        }
    }
    
    
    /// Parse meditation data from text response when backend doesn't return an action
    func parseMeditationFromResponse(_ response: String) -> (duration: Int, focus: String, script: String) {
        // Extract duration
        var duration = 10 // Default
        if let durationMatch = response.range(of: #"(\d+)\s*min"#, options: .regularExpression) {
            let durationStr = String(response[durationMatch])
            duration = Int(durationStr.replacingOccurrences(of: " min", with: "").replacingOccurrences(of: "minute", with: "").trimmingCharacters(in: .whitespaces)) ?? 10
        }
        
        // Extract focus (stress, anxiety, sleep, etc.)
        var focus = "stress" // Default
        let focusKeywords = ["stress", "anxiety", "sleep", "focus", "energy", "gratitude", "breathing", "mindfulness"]
        let lowerResponse = response.lowercased()
        for keyword in focusKeywords {
            if lowerResponse.contains(keyword) {
                focus = keyword
                break
            }
        }
        
        // Extract script - try to find the actual meditation content
        // Look for common patterns like "**Audio Script:**", "Here's the script:", etc.
        var script = response
        
        // Try to find script section
        if let scriptStart = response.range(of: #"(?i)(script|meditation|guidance|instructions):"#, options: .regularExpression) {
            script = String(response[scriptStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let scriptStart = response.range(of: #"(?i)\*\*.*script\*\*"#, options: .regularExpression) {
            script = String(response[scriptStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Clean up script - remove markdown and extra formatting
        script = MarkdownFormatter.cleanMarkdown(script)
        
        // If script is still too short or mostly intro text, use the full response
        if script.count < 200 {
            script = MarkdownFormatter.cleanMarkdown(response)
        }
        
        // Ensure script is not empty
        if script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            script = "Take a comfortable position. Close your eyes if you'd like. Bring your awareness to your breath. Notice the sensation of the air as it enters and leaves your body. If your mind starts to wander, gently bring your focus back to your breath. Continue for \(duration) minutes."
        }
        
        print("🧘 [GenieView] Parsed meditation: \(duration) min, focus: \(focus), script length: \(script.count) chars")
        
        return (duration, focus, script)
    }
    
    private func getErrorMessage(for error: GenieError) -> String {
        switch error {
        case .insufficientTokens:
            return "You're out of tokens! Tap the token balance above to get more."
        case .invalidURL:
            return "Configuration error. Please contact support."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .serverError(let code):
            if code == 500 {
                return "The server encountered an error accessing required resources. Our team has been notified with detailed diagnostics."
            } else if code == 503 {
                return "The service is temporarily unavailable. Please try again in a moment."
            } else {
                return "Server error (\(code)). Please try again."
            }
        case .notAuthenticated:
            return "Authentication failed. Please sign in again."
        case .invalidRequest(let message):
            return message
        }
    }
}

// MARK: - Attachment Plus Button (Long Press)

struct AttachmentPlusButton: View {
    let onLongPressSnapCalorie: () -> Void
    let onLongPressEquipment: () -> Void
    let onTap: () -> Void
    
    @State private var isLongPressing = false
    @State private var longPressType: AttachmentType? = nil
    @State private var pulseAnimation: CGFloat = 1.0
    @State private var pressStartTime: Date?
    
    enum AttachmentType {
        case snapCalorie
        case equipment
        
        var icon: String {
            switch self {
            case .snapCalorie: return "camera.fill"
            case .equipment: return "figure.strengthtraining.traditional"
            }
        }
        
        var color: Color {
            switch self {
            case .snapCalorie: return Color("4CAF50")
            case .equipment: return Color("2196F3")
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Pulsating rings when long pressing
            if isLongPressing, let type = longPressType {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(type.color.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulseAnimation + CGFloat(index) * 0.2)
                        .opacity(1.0 - (pulseAnimation - 1.0) * 0.5)
                }
            }
            
            // Main button
            Button(action: onTap) {
                Image(systemName: longPressType?.icon ?? "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isLongPressing ? .white : Color.brandOrange)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isLongPressing ? (longPressType?.color ?? Color.brandOrange).opacity(0.3) : Color.white.opacity(0.1))
                    )
                    .scaleEffect(isLongPressing ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isLongPressing {
                            pressStartTime = Date()
                            // Determine which side of button was pressed
                            let horizontalOffset = value.location.x
                            let buttonCenter: CGFloat = 18 // half of 36
                            
                            // Left side = snap calorie, right side = equipment
                            if horizontalOffset < buttonCenter {
                                longPressType = .snapCalorie
                            } else {
                                longPressType = .equipment
                            }
                            
                            // Start long press detection
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        // Haptic feedback on long press start
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        
                                        isLongPressing = true
                                        // Start pulse animation
                                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false)) {
                                            pulseAnimation = 1.5
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if isLongPressing {
                            // Haptic feedback on completion
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            
                            // Long press completed - trigger action
                            switch longPressType {
                            case .snapCalorie:
                                onLongPressSnapCalorie()
                            case .equipment:
                                onLongPressEquipment()
                            case .none:
                                break
                            }
                        } else {
                            // Light haptic if cancelled
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // Reset state
                        withAnimation(.easeOut(duration: 0.2)) {
                            isLongPressing = false
                            pulseAnimation = 1.0
                            longPressType = nil
                        }
                        pressStartTime = nil
                    }
            )
        }
    }
}

// MARK: - Voice Input Button (Press and Hold)

/// Press-and-hold microphone button with visual feedback
private struct VoiceInputButton: View {
    let isListening: Bool
    let partialText: String
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    @State private var isPressed = false
    @State private var animationScale: CGFloat = 1.0
    @State private var pulseAnimation: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: {}) {
                ZStack {
                    // Multiple pulsating rings when recording
                    if isListening {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(Color.red.opacity(0.4), lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .scaleEffect(pulseAnimation + CGFloat(index) * 0.2)
                                .opacity(1.0 - (pulseAnimation - 1.0) * 0.5)
                        }
                    }
                    
                    // Main button background
                    Circle()
                        .fill(isListening ? Color.red.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    // Main button icon
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isListening ? .white : Color.brandOrange)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed && !isListening {
                            isPressed = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                animationScale = 1.2
                            }
                            onStartRecording()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                animationScale = 1.0
                            }
                            onStopRecording()
                        }
                    }
            )
            
            // Show partial text while recording
            if isListening && !partialText.isEmpty {
                Text(partialText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: 100)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.2))
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onChange(of: isListening) { listening in
            if listening {
                // Start pulse animation
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseAnimation = 1.5
                }
            } else {
                // Stop pulse animation
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseAnimation = 1.0
                }
            }
        }
    }
}

// MARK: - Voice Preview Sheet

struct VoicePreviewSheet: View {
    let text: String
    let onSend: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Audio waveform icon
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(Color.brandOrange)
                        .padding(.top, 40)
                    
                    Text("Voice Message")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Transcribed text
                    ScrollView {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .frame(maxHeight: 200)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Delete button
                        Button(action: {
                            onDelete()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.3))
                            )
                        }
                        
                        // Send button
                        Button(action: {
                            onSend()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Send")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.brandOrange, Color("FF6B35")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Voice Button (Isolated View)

/// Isolated voice button view that observes GenieVoiceService independently
/// This prevents ObservableObject access in main GenieView body, eliminating re-evaluation triggers
private struct VoiceButton: View {
    @ObservedObject private var voiceService = GenieVoiceService.shared
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundColor(voiceService.isListening ? .red : Color.brandOrange)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(voiceService.isListening ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var tokensUsed: Int = 0
    var thinking: [String]? = nil
    var actions: [GenieAction]? = nil
    
    // Cache parsed analysis to avoid re-parsing on every render
    // Computed once when message is created
    let parsedAnalysis: AnalysisResponse?
    
    init(text: String, isUser: Bool, tokensUsed: Int = 0, thinking: [String]? = nil, actions: [GenieAction]? = nil) {
        self.text = text
        self.isUser = isUser
        self.tokensUsed = tokensUsed
        self.thinking = thinking
        self.actions = actions
        // Parse analysis once during initialization (only for non-user messages)
        self.parsedAnalysis = isUser ? nil : text.tryParseAnalysisJSON()
    }
}

// MARK: - Meditation Parsing Helper


