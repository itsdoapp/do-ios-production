import SwiftUI
import UIKit

/// UITextView subclass that properly constrains width for text wrapping
class ConstrainedWidthTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        // CRITICAL: Return minimal width - let Auto Layout constraints handle the actual width
        // This prevents the text view from expanding infinitely
        // The HStack and frame constraints will properly size this view
        let constrainedWidth: CGFloat = 100 // Minimal intrinsic width - will be overridden by constraints
        
        // Calculate height based on text content with available width
        // Use bounds if available, otherwise estimate
        let availableWidth = self.bounds.width > 0 ? self.bounds.width : constrainedWidth
        let containerWidth = max(availableWidth - self.textContainerInset.left - self.textContainerInset.right, 50)
        let size = CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        let textHeight = self.sizeThatFits(size).height
        
        // Return minimal width (constraints will handle actual width) and calculated height
        return CGSize(width: UIView.noIntrinsicMetric, height: max(textHeight, 44))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // CRITICAL: Explicitly set text container width to force wrapping
        // Calculate available width (view width minus horizontal padding)
        if self.bounds.width > 0 {
            let availableWidth = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            // Always update the container width, even if it seems the same
            // This ensures wrapping happens immediately when text changes
            self.textContainer.size.width = max(availableWidth, 0)
            // Force layout recalculation
            self.layoutManager.ensureLayout(for: self.textContainer)
            // Invalidate glyphs to force re-wrapping with correct parameters
            let textLength = (self.text ?? "").count
            if textLength > 0 {
                self.layoutManager.invalidateGlyphs(forCharacterRange: NSRange(location: 0, length: textLength), changeInLength: 0, actualCharacterRange: nil)
            }
        }
    }
}

/// Lightweight UITextView wrapper that doesn't trigger SwiftUI body re-evaluation on focus
/// Uses UITextView instead of UITextField for multiline support (like SwiftUI's axis: .vertical)
struct FastTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = ConstrainedWidthTextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = .white
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textView.layer.cornerRadius = 20
        textView.layer.masksToBounds = true
        
        // CRITICAL: Minimal configuration for fastest focus (no heavy services)
        textView.autocorrectionType = .yes // Enable autocorrect for better typing experience
        textView.autocapitalizationType = .sentences
        textView.textContentType = nil // Disable content type suggestions
        textView.spellCheckingType = .yes // Enable spell checking
        textView.keyboardAppearance = .dark
        // Orange cursor color matching Genie theme
        textView.tintColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)
        
        // CRITICAL: Ensure text view is editable and user interaction is enabled
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        
        // Padding
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        
        // CRITICAL: Configure text container to wrap text instead of stretching
        // Set widthTracksTextView to false so we can explicitly control the container width
        // This ensures proper wrapping behavior
        textView.textContainer.widthTracksTextView = false // We'll set width explicitly
        textView.textContainer.heightTracksTextView = false // We control height manually
        textView.textContainer.lineBreakMode = .byWordWrapping // Wrap by words
        textView.textContainer.maximumNumberOfLines = 0 // No line limit (we constrain height manually)
        
        // Initially set a reasonable container width (will be updated in layoutSubviews)
        textView.textContainer.size = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        
        // Multiline support with height constraint (1-6 lines: 44-132pt)
        textView.isScrollEnabled = false // Disable scroll to allow natural height growth
        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.priority = UILayoutPriority(999) // High but not required
        heightConstraint.isActive = true
        // Store constraint in coordinator for dynamic height updates
        context.coordinator.heightConstraint = heightConstraint
        
        // Set initial text - keep text empty and use placeholder overlay
        textView.text = text.isEmpty ? "" : text
        textView.textColor = text.isEmpty ? UIColor.white.withAlphaComponent(0.5) : .white
        
        // Add placeholder label overlay (UITextView doesn't have built-in placeholder)
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        placeholderLabel.font = UIFont.systemFont(ofSize: 16)
        placeholderLabel.isHidden = !text.isEmpty
        placeholderLabel.tag = 999 // Tag to identify placeholder label
        // CRITICAL: Make placeholder label non-interactive so it doesn't block touches
        placeholderLabel.isUserInteractionEnabled = false
        textView.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -16)
        ])
        context.coordinator.placeholderLabel = placeholderLabel
        
        // Minimal accessibility - let UITextView handle it naturally
        textView.isAccessibilityElement = true
        
        // CRITICAL: Ensure text view can become first responder and accept input
        textView.delegate = context.coordinator
        
        // Add tap gesture to ensure text view becomes first responder when tapped
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.cancelsTouchesInView = false // Don't cancel touches - let text view handle them
        textView.addGestureRecognizer(tapGesture)
        context.coordinator.tapGesture = tapGesture
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update placeholder label visibility based on actual text view content
        let placeholderLabel = uiView.subviews.first { $0.tag == 999 } as? UILabel
        let hasText = !(uiView.text ?? "").isEmpty
        
        // CRITICAL: If parent binding is empty (e.g., after sending message), immediately clear text view
        // This must happen even during editing to clear the field after sending
        if text.isEmpty {
            if hasText {
                // Parent was cleared - immediately clear the text view
                uiView.text = ""
                uiView.textColor = .white // Keep white (placeholder will show)
                placeholderLabel?.isHidden = false
                context.coordinator.isUserTyping = false
                context.coordinator.pendingText = nil
                // Cancel any pending updates
                context.coordinator.updateTimer?.invalidate()
                return
            }
        }
        
        // CRITICAL: Only update text view if user is not actively editing
        // This prevents interference with typing
        // BUT: Don't block updates if the binding changed externally (e.g., after sending message)
        if (context.coordinator.isEditing || context.coordinator.isUserTyping) && !text.isEmpty {
            // User is typing and there's text in the binding - don't interfere
            // Just update placeholder visibility
            placeholderLabel?.isHidden = hasText
            return
        }
        
        // User is not typing - safe to sync text view with binding
        if !text.isEmpty {
            // Binding has text - update text view if different
            if uiView.text != text {
                uiView.text = text
                uiView.textColor = .white // Always white when there's text
                placeholderLabel?.isHidden = true
            }
        }
        
        // CRITICAL: Update text container width when view bounds change
        // This ensures wrapping works when the SwiftUI frame changes
        let availableWidth = max(uiView.bounds.width - uiView.textContainerInset.left - uiView.textContainerInset.right, 0)
        if availableWidth > 0 && uiView.textContainer.size.width != availableWidth {
            uiView.textContainer.size.width = availableWidth
            uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        }
        
        // Force layout update
        uiView.layoutIfNeeded()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: FastTextField
        var isUserTyping = false
        var heightConstraint: NSLayoutConstraint?
        var isEditing = false // Track if text view is currently being edited
        var placeholderLabel: UILabel? // Reference to placeholder label
        var tapGesture: UITapGestureRecognizer? // Tap gesture for ensuring first responder
        
        // Debounce timer for binding updates to prevent excessive SwiftUI re-evaluations
        var updateTimer: Timer? // Made internal for access from updateUIView
        var pendingText: String?
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            // Ensure text view becomes first responder when tapped
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }
        
        init(_ parent: FastTextField) {
            self.parent = parent
        }
        
        deinit {
            updateTimer?.invalidate()
        }
        
        // Optimized text update that batches rapid changes and prevents updates during focus
        private func scheduleTextUpdate(_ newText: String) {
            pendingText = newText
            
            // Cancel any pending update
            updateTimer?.invalidate()
            
            // CRITICAL: Always allow text updates when editing or typing
            // The guard should only prevent updates when NOT editing, but we need to allow updates during editing
            // Schedule update after a delay to batch rapid changes
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                guard let self = self, let text = self.pendingText else { return }
                // Only update if text actually changed to avoid unnecessary SwiftUI re-evaluation
                if text != self.parent.text {
                    // Update binding asynchronously to prevent blocking focus
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.parent.text = text
                        self.isUserTyping = false
                    }
                } else {
                    self.isUserTyping = false
                }
                self.pendingText = nil
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            isUserTyping = true
            
            // Get text immediately
            let newText = textView.text ?? ""
            
            // CRITICAL: Always ensure text color is white when there's text
            textView.textColor = .white
            
            // Update placeholder visibility
            placeholderLabel?.isHidden = !newText.isEmpty
            
            // CRITICAL: If parent text is empty (cleared externally, e.g., after sending),
            // clear the text view immediately, even if user is still typing
            // BUT: Only do this if we're not currently editing (to avoid interrupting active typing)
            if parent.text.isEmpty && !newText.isEmpty && !isEditing {
                // Parent was cleared externally - clear the text view too
                textView.text = ""
                textView.textColor = .white // Keep white (placeholder will show)
                placeholderLabel?.isHidden = false
                isUserTyping = false
                // Cancel pending updates
                updateTimer?.invalidate()
                pendingText = nil
                return
            }
            
            // Don't process placeholder text as actual text (shouldn't happen with overlay)
            if newText == parent.placeholder {
                textView.text = ""
                textView.textColor = .white
                placeholderLabel?.isHidden = false
                isUserTyping = false
                return
            }
            
            // CRITICAL: Force text container width update to ensure wrapping
            // This must happen on every text change to ensure proper wrapping
            let availableWidth = max(textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right, 0)
            if availableWidth > 0 {
                textView.textContainer.size.width = availableWidth
                // Force immediate layout recalculation
                textView.layoutManager.ensureLayout(for: textView.textContainer)
            }
            
            // Force layout update
            textView.layoutIfNeeded()
            
            // Auto-resize text view based on content (up to 6 lines max)
            // Do this synchronously since we're already on main thread from delegate
            let newSize = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
            let maxHeight: CGFloat = 132 // ~6 lines
            let minHeight: CGFloat = 44  // 1 line
            let constrainedHeight = min(max(newSize.height, minHeight), maxHeight)
            
            // Update height constraint immediately (layout work, happens on main thread)
            heightConstraint?.constant = constrainedHeight
            
            // Debounce binding update to batch rapid text changes and prevent excessive body re-evaluations
            scheduleTextUpdate(newText)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // CRITICAL: Mark as editing to allow binding updates, but don't update binding here
            // This prevents SwiftUI body re-evaluation when focus is gained
            isEditing = true
            isUserTyping = false // Reset typing flag when starting to edit
            
            // Always ensure text color is white when editing
            textView.textColor = .white
            
            // Hide placeholder when user starts editing
            placeholderLabel?.isHidden = true
            
            // If text view has placeholder text as actual text, clear it
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = .white
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // Mark as not editing
            isEditing = false
            isUserTyping = false
            
            // Show placeholder if text is empty
            let finalText = textView.text ?? ""
            placeholderLabel?.isHidden = !finalText.isEmpty
            
            // Force final binding update when editing ends
            if finalText != parent.text {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.text = finalText
                }
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Handle return key to submit
            if text == "\n" {
                let currentText = textView.text ?? ""
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parent.onSubmit?()
                }
                return false // Don't insert newline
            }
            // Always allow text changes - this is critical for typing to work
            return true
        }
    }
}

