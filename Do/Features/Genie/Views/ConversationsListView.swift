import SwiftUI

/// Modern ChatGPT-style conversations list with Genie branding
struct ConversationsListView: View {
    @ObservedObject var conversationManager: GenieConversationManager
    let onSelectConversation: (String) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background matching Genie
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color(hex: "1A2148")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with modern button
                    VStack(spacing: 16) {
                        // New conversation button - prominent and modern
                        Button(action: {
                            onCreateNew()
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.brandOrange, Color("FFB84D")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: Color.brandOrange.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("New Conversation")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Start chatting with Genie")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                    
                    // Conversations list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if conversationManager.isLoadingConversations {
                                // Loading state
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .tint(Color.brandOrange)
                                    Text("Loading conversations...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if conversationManager.conversations.isEmpty {
                                // Empty state - modern and friendly
                                VStack(spacing: 20) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    VStack(spacing: 8) {
                                        Text("No conversations yet")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text("Start a new conversation to get started")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                // Conversations list - sorted by last message time (newest first)
                                ForEach(filteredConversations) { conversation in
                                    ConversationRow(
                                        conversation: conversation,
                                        isSelected: conversationManager.currentConversationId == conversation.id,
                                        onTap: {
                                            onSelectConversation(conversation.id)
                                            dismiss()
                                        },
                                        onDelete: {
                                            Task {
                                                await conversationManager.deleteConversation(conversation.id)
                                            }
                                        }
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .toolbarBackground(Color.brandBlue, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                // Set navigation bar title color to white
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                // Convert hex color to UIColor
                let hexColor = UIColor(red: 0x0F/255.0, green: 0x16/255.0, blue: 0x3E/255.0, alpha: 1.0)
                appearance.backgroundColor = hexColor
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                
                // Load conversations when view appears
                conversationManager.loadConversations()
            }
        }
    }
    
    // Filter conversations by search text
    private var filteredConversations: [GenieConversation] {
        if searchText.isEmpty {
            return conversationManager.conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
        } else {
            return conversationManager.conversations
                .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.lastMessageAt > $1.lastMessageAt }
        }
    }
}

private struct ConversationRow: View {
    let conversation: GenieConversation
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteButton
        }
        .confirmationDialog(
            "Delete Conversation",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            conversationIcon
            conversationInfo
            Spacer()
            chevronIcon
        }
        .padding(18)
        .background(rowBackground)
        .contentShape(Rectangle())
    }
    
    private var conversationIcon: some View {
        ZStack {
            Circle()
                .fill(iconGradient)
                .frame(width: 52, height: 52)
                .shadow(color: iconShadowColor, radius: 8)
            
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(iconForegroundColor)
        }
    }
    
    private var iconGradient: LinearGradient {
        isSelected ? selectedIconGradient : unselectedIconGradient
    }
    
    private var selectedIconGradient: LinearGradient {
        LinearGradient(
            colors: [Color.brandOrange, Color("FFB84D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var unselectedIconGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var iconShadowColor: Color {
        isSelected ? Color.brandOrange.opacity(0.3) : Color.clear
    }
    
    private var iconForegroundColor: Color {
        isSelected ? .white : .white.opacity(0.8)
    }
    
    private var conversationInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conversation.title.isEmpty ? "New Conversation" : conversation.title)
                .font(.system(size: 17, weight: titleFontWeight))
                .foregroundColor(titleColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            messageMetadata
        }
    }
    
    private var titleFontWeight: Font.Weight {
        isSelected ? .semibold : .medium
    }
    
    private var titleColor: Color {
        isSelected ? Color.brandOrange : .white
    }
    
    private var messageMetadata: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            Text(formatRelativeTime(conversation.lastMessageAt))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            if conversation.messageCount > 0 {
                messageCountView
            }
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private var messageCountView: some View {
        Group {
            Text("•")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Text("\(conversation.messageCount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text(conversation.messageCount == 1 ? "message" : "messages")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.3))
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(backgroundColor)
            .overlay(rowBorder)
            .shadow(color: isSelected ? Color.brandOrange.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 2)
    }
    
    private var backgroundColor: Color {
        isSelected ? Color.brandOrange.opacity(0.15) : Color.white.opacity(0.08)
    }
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        isSelected ? Color.brandOrange.opacity(0.5) : Color.white.opacity(0.15)
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    ConversationsListView(
        conversationManager: GenieConversationManager.shared,
        onSelectConversation: { _ in },
        onCreateNew: { }
    )
}
