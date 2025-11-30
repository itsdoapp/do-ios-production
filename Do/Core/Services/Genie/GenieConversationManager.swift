import Foundation
import SwiftUI

/// Manages multiple Genie conversations (like ChatGPT) with lazy loading and performance optimization
@MainActor
class GenieConversationManager: ObservableObject {
    static let shared = GenieConversationManager()
    
    @Published var conversations: [GenieConversation] = []
    @Published var currentConversationId: String?
    @Published var isLoadingConversations = false
    
    private var conversationCache: [String: GenieConversation] = [:]
    private var messagesCache: [String: [ChatMessage]] = [:]
    private let conversationStore = GenieConversationStoreService.shared
    private var loadTask: Task<Void, Never>?
    
    private init() {
        // Load conversations lazily when first accessed
    }
    
    // MARK: - Public API
    
    /// Load conversations list (lazy, non-blocking)
    func loadConversations() {
        guard !isLoadingConversations else { return }
        isLoadingConversations = true
        
        loadTask?.cancel()
        // Use background priority to prevent blocking UI
        loadTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            do {
                guard let userId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
                    await MainActor.run {
                        self.isLoadingConversations = false
                    }
                    return
                }
                
                // Fetch from AWS backend (non-blocking)
                let awsConversations = try await conversationStore.listConversations(ownerId: userId, limit: 50)
                
                // Map conversations - keep it simple and fast
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let genieConversations = awsConversations.map { conv -> GenieConversation in
                    let lastMessageDate = dateFormatter.date(from: conv.lastMessageAt) ?? Date()
                    
                    // Ensure title is not empty - use fallback if needed
                    let displayTitle = conv.title.isEmpty || conv.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Conversation" : conv.title
                    
                    return GenieConversation(
                        id: conv.conversationId,
                        title: displayTitle,
                        lastMessageAt: lastMessageDate,
                        messageCount: 0 // Will be loaded on demand when conversation is opened
                    )
                }
                
                // Sort by last message time (newest first)
                let sortedConversations = genieConversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
                
                await MainActor.run {
                    self.conversations = sortedConversations
                    // Cache conversations
                    for conv in sortedConversations {
                        self.conversationCache[conv.id] = conv
                    }
                    self.isLoadingConversations = false
                    print("✅ [ConversationManager] Loaded \(sortedConversations.count) conversations")
                }
            } catch {
                print("❌ [ConversationManager] Error loading conversations: \(error)")
                // Don't block UI on errors - just log and continue
                await MainActor.run {
                    self.isLoadingConversations = false
                }
            }
        }
    }
    
    /// Create a new conversation (non-blocking)
    func createNewConversation(title: String? = nil) async -> GenieConversation? {
        guard let userId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
            print("⚠️ [ConversationManager] No userId available for conversation creation")
            return nil
        }
        
        // Generate a friendly default title if none provided
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let conversationTitle = title ?? "Chat \(dateFormatter.string(from: Date()))"
        
        do {
            // Create in background to avoid blocking
            let awsConv = try await conversationStore.createConversation(
                title: conversationTitle,
                ownerId: userId
            )
            
            let genieConversation = GenieConversation(
                id: awsConv.conversationId,
                title: awsConv.title,
                lastMessageAt: Date(),
                messageCount: 0
            )
            
            await MainActor.run {
                // Add to top of list (optimistic update)
                self.conversations.insert(genieConversation, at: 0)
                self.conversationCache[genieConversation.id] = genieConversation
                // Note: currentConversationId will be set by caller
            }
            
            print("✅ [ConversationManager] Created new conversation: \(genieConversation.id)")
            return genieConversation
        } catch {
            print("❌ [ConversationManager] Error creating conversation: \(error)")
            // Return nil on error - caller can handle gracefully
            return nil
        }
    }
    
    /// Load messages for a conversation (lazy, cached)
    func loadMessages(for conversationId: String) async -> [ChatMessage] {
        // Check cache first
        if let cached = messagesCache[conversationId] {
            return cached
        }
        
        do {
            // Fetch from AWS
            guard let awsConv = try await conversationStore.getConversation(id: conversationId) else {
                return []
            }
            
            let awsMessages = try await conversationStore.fetchMessages(for: conversationId, limit: 200)
            
            let chatMessages = awsMessages.compactMap { awsMsg -> ChatMessage? in
                let isUser = awsMsg.role == "user"
                
                // Parse actions/thinking from usageJSON if available
                var actions: [GenieAction]? = nil
                var thinking: [String]? = nil
                var tokensUsed: Int = 0
                
                if let usageJSON = awsMsg.usageJSON,
                   let data = usageJSON.data(using: .utf8),
                   let usage = try? JSONDecoder().decode(LLMUsage.self, from: data) {
                    tokensUsed = usage.totalTokens
                    // Could parse actions/thinking from usageJSON if stored
                }
                
                return ChatMessage(
                    text: awsMsg.text,
                    isUser: isUser,
                    tokensUsed: tokensUsed,
                    thinking: thinking,
                    actions: actions
                )
            }
            
            // Cache messages
            await MainActor.run {
                self.messagesCache[conversationId] = chatMessages
            }
            
            print("✅ [ConversationManager] Loaded \(chatMessages.count) messages for conversation \(conversationId)")
            return chatMessages
        } catch {
            print("❌ [ConversationManager] Error loading messages: \(error)")
            return []
        }
    }
    
    /// Save a message to current conversation (async, non-blocking)
    func saveMessage(_ message: ChatMessage, to conversationId: String?) async {
        guard let conversationId = conversationId else {
            return
        }
        
        // Skip saving messages with empty text (e.g., meditation actions that are handled separately)
        // The backend requires non-empty text, and these messages aren't displayed anyway
        guard !message.text.isEmpty else {
            print("⚠️ [ConversationManager] Skipping save of message with empty text (likely action-only message)")
            return
        }
        
        do {
            // Encode usage if available
            var usageJSON: String? = nil
            if message.tokensUsed > 0 {
                let usage = LLMUsage(
                    promptTokens: 0,
                    completionTokens: message.tokensUsed,
                    totalTokens: message.tokensUsed, model: nil
                )
                if let data = try? JSONEncoder().encode(usage) {
                    usageJSON = String(data: data, encoding: .utf8)
                }
            }
            
            try await conversationStore.appendMessage(
                to: conversationId,
                role: message.isUser ? "user" : "assistant",
                text: message.text,
                usageJSON: usageJSON,
                model: nil
            )
            
            // Update cache
            await MainActor.run {
                if self.messagesCache[conversationId] != nil {
                    self.messagesCache[conversationId]?.append(message)
                }
                
                // Update last message time in conversation list
                if let index = self.conversations.firstIndex(where: { $0.id == conversationId }) {
                    self.conversations[index].lastMessageAt = Date()
                    // Re-sort by last message time
                    self.conversations.sort { $0.lastMessageAt > $1.lastMessageAt }
                }
                
                // Extract insights from conversation when assistant responds (after conversation turn completes)
                // This ensures we capture the full context of each exchange
                if let messages = self.messagesCache[conversationId],
                   !message.isUser && messages.count >= 2 {
                    // Extract insights after assistant responds (non-blocking, async)
                    Task.detached(priority: .utility) {
                        await GenieUserLearningService.shared.extractConversationInsights(
                        conversationId: conversationId,
                        messages: messages
                    )
                    }
                }
            }
        } catch {
            print("❌ [ConversationManager] Error saving message: \(error)")
        }
    }
    
    /// Switch to a different conversation
    func switchToConversation(_ conversationId: String) {
        currentConversationId = conversationId
    }
    
    /// Update conversation title (optimistic update)
    func updateConversationTitle(conversationId: String, title: String) async {
        // Update local cache first (optimistic update)
        await MainActor.run {
            if let index = self.conversations.firstIndex(where: { $0.id == conversationId }) {
                self.conversations[index].title = title
            }
            if var cached = self.conversationCache[conversationId] {
                cached.title = title
                self.conversationCache[conversationId] = cached
            }
        }
        
        // Update backend (if endpoint exists - for now just update locally)
        // TODO: Add backend endpoint for updating conversation title
        print("✅ [ConversationManager] Updated conversation title: \(conversationId) -> \"\(title)\"")
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversationId: String) async {
        // Remove from cache and list first (optimistic update)
        await MainActor.run {
            self.conversations.removeAll { $0.id == conversationId }
            self.conversationCache.removeValue(forKey: conversationId)
            self.messagesCache.removeValue(forKey: conversationId)
            
            if self.currentConversationId == conversationId {
                self.currentConversationId = self.conversations.first?.id
            }
        }
        
        // Delete from AWS backend
        do {
            try await conversationStore.deleteConversation(id: conversationId)
            print("✅ [ConversationManager] Deleted conversation: \(conversationId)")
        } catch {
            print("❌ [ConversationManager] Error deleting conversation: \(error)")
            // Could restore from cache if needed
        }
    }
}

// MARK: - Models

struct GenieConversation: Identifiable {
    let id: String
    var title: String
    var lastMessageAt: Date
    var messageCount: Int
}

