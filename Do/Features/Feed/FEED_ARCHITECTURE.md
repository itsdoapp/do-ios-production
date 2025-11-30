# Feed Architecture - World-Class Social Network Design

## Overview
Design a feed system that rivals Instagram, TikTok, and Twitter with smart ranking, personalization, and optimal performance.

---

## 1. FEED STRATEGY

### Hybrid Feed Approach (Best of Both Worlds)
```
┌─────────────────────────────────────────┐
│         HYBRID FEED ALGORITHM           │
├─────────────────────────────────────────┤
│                                         │
│  Following Feed (60-70%)                │
│  ├─ Recent posts from followed users   │
│  ├─ Ranked by engagement + recency     │
│  └─ Time-decay algorithm               │
│                                         │
│  For You Feed (30-40%)                  │
│  ├─ Personalized recommendations       │
│  ├─ Similar interests                  │
│  ├─ Trending content                   │
│  └─ Network expansion                  │
│                                         │
└─────────────────────────────────────────┘
```

### Feed Composition Strategy
1. **New Users (0-5 following):**
   - 100% For You (discovery mode)
   - Show popular content
   - Suggest users to follow
   - Contact import prompts

2. **Growing Users (6-20 following):**
   - 40% Following feed
   - 60% For You feed
   - Balanced discovery + connection

3. **Active Users (21+ following):**
   - 70% Following feed
   - 30% For You feed
   - Maintain engagement with network

---

## 2. RANKING ALGORITHM

### Multi-Factor Scoring System

```javascript
POST_SCORE = (
    ENGAGEMENT_SCORE * 0.35 +
    RECENCY_SCORE * 0.25 +
    SOCIAL_SCORE * 0.20 +
    CONTENT_SCORE * 0.15 +
    DIVERSITY_SCORE * 0.05
)
```

#### A. Engagement Score (35% weight)
```
Engagement = (
    reactions * 3 +
    comments * 5 +
    shares * 7 +
    saves * 4 +
    video_completion_rate * 10
) / time_since_post_hours
```

**Why these weights?**
- Shares = highest intent (7x) - user vouches for content
- Comments = conversation (5x) - deeper engagement
- Saves = future value (4x) - content worth revisiting
- Reactions = quick feedback (3x) - baseline engagement
- Video completion = quality signal (10x) - held attention

#### B. Recency Score (25% weight)
```
Time Decay Function:
- 0-1 hour: 1.0 (100%)
- 1-3 hours: 0.9 (90%)
- 3-6 hours: 0.7 (70%)
- 6-12 hours: 0.5 (50%)
- 12-24 hours: 0.3 (30%)
- 24-48 hours: 0.15 (15%)
- 48+ hours: 0.05 (5%)
```

**Why time decay?**
- Keeps feed fresh
- Prevents stale content
- Balances with evergreen posts
- Workout posts have longer relevance

#### C. Social Score (20% weight)
```
Social = (
    is_following * 2.0 +
    mutual_friends * 1.5 +
    previous_interactions * 1.2 +
    similar_interests * 1.0
)
```

**Factors:**
- Following relationship = 2x boost
- Mutual connections = 1.5x (trust signal)
- Past interactions = 1.2x (proven interest)
- Interest overlap = 1.0x (relevance)

#### D. Content Score (15% weight)
```
Content Quality = (
    has_media * 1.5 +
    caption_length_optimal * 1.2 +
    workout_data_complete * 1.3 +
    post_type_preference * 1.1
)
```

**Quality signals:**
- Media presence (images/video)
- Optimal caption length (50-200 chars)
- Complete workout data
- User's preferred content types

#### E. Diversity Score (5% weight)
```
Diversity = (
    content_type_variety +
    creator_variety +
    topic_variety
) / 3
```

**Why diversity?**
- Prevents echo chambers
- Exposes new content types
- Discovers new creators
- Maintains feed freshness

---

## 3. FETCHING STRATEGY

### Smart Pagination & Caching

```swift
┌─────────────────────────────────────────┐
│          FETCHING LAYERS                │
├─────────────────────────────────────────┤
│                                         │
│  Layer 1: Memory Cache (Instant)       │
│  └─ Last 50 posts in RAM              │
│                                         │
│  Layer 2: Disk Cache (Fast)            │
│  └─ Last 200 posts on device          │
│                                         │
│  Layer 3: Network (Fresh)              │
│  └─ AWS Lambda + DynamoDB              │
│                                         │
└─────────────────────────────────────────┘
```

### Fetch Optimization

#### Initial Load (Cold Start)
```
1. Check disk cache (last session)
2. Show cached posts immediately
3. Fetch fresh posts in background
4. Merge and deduplicate
5. Update UI smoothly
```

#### Pagination Strategy
```
- Initial: 20 posts
- Scroll load: 10 posts per page
- Prefetch: When 5 posts from bottom
- Max cache: 200 posts
- Clear old: Posts > 500 from top
```

#### Background Refresh
```
- Pull-to-refresh: Full refresh
- App foreground: Fetch new posts only
- Every 5 minutes: Check for updates
- Smart: Only if user scrolled to top
```

---

## 4. INTERACTION FETCHING

### Batch Interaction Strategy

```javascript
// AWS Lambda: Get User Interactions
GET /interactions/batch
{
  "userId": "user123",
  "postIds": ["post1", "post2", ...], // up to 100
}

Response:
{
  "interactions": {
    "post1": { "type": "heart", "createdAt": "..." },
    "post2": { "type": "goat", "createdAt": "..." },
    ...
  }
}
```

### Interaction Caching
```swift
// Local cache structure
userInteractions: [String: InteractionType] = [
    "postId1": .heart,
    "postId2": .goat,
    "postId3": .star
]

// Update strategy:
1. Load from cache immediately
2. Fetch batch updates in background
3. Merge new interactions
4. Update UI for changed posts only
```

### Real-time Updates
```
- User reacts: Update local cache + API call
- Optimistic UI: Show immediately
- Rollback: If API fails
- Sync: Background reconciliation
```

---

## 5. FOLLOW RELATIONSHIP OPTIMIZATION

### Follow Graph Caching

```javascript
// DynamoDB Structure
Follows Table:
{
  PK: "USER#userId",
  SK: "FOLLOWS#targetUserId",
  followedAt: "2024-01-01T...",
  accepted: true,
  notificationsEnabled: true
}

// GSI for reverse lookup
GSI1:
{
  PK: "USER#targetUserId",
  SK: "FOLLOWER#userId"
}
```

### Client-Side Cache
```swift
class FollowManager {
    // In-memory cache
    private var followingSet: Set<String> = []
    private var followersSet: Set<String> = []
    private var mutualSet: Set<String> = []
    
    // Disk persistence
    private let cacheKey = "followGraph"
    
    // Update strategy
    func updateCache() async {
        // Fetch from AWS
        // Update sets
        // Persist to disk
        // Notify observers
    }
}
```

### Follow Checks
```swift
// O(1) lookup instead of API call
func isFollowing(_ userId: String) -> Bool {
    return followingSet.contains(userId)
}

// Batch check for feed
func filterFollowing(_ userIds: [String]) -> Set<String> {
    return Set(userIds).intersection(followingSet)
}
```

---

## 6. CONTACT IMPORT SYSTEM

### Contact Sync Flow

```
┌─────────────────────────────────────────┐
│        CONTACT IMPORT FLOW              │
├─────────────────────────────────────────┤
│                                         │
│  1. Request Permission                  │
│     └─ iOS Contacts Framework          │
│                                         │
│  2. Hash Phone Numbers                  │
│     └─ SHA256(phone + salt)            │
│                                         │
│  3. Send to AWS Lambda                  │
│     └─ Batch: 100 hashes at a time     │
│                                         │
│  4. Match Against Users                 │
│     └─ DynamoDB GSI on phoneHash       │
│                                         │
│  5. Return Matches                      │
│     └─ User profiles to suggest        │
│                                         │
│  6. Show Suggestions                    │
│     └─ "Follow your contacts"          │
│                                         │
└─────────────────────────────────────────┘
```

### Privacy-First Approach
```swift
// NEVER send raw phone numbers
func hashPhoneNumber(_ phone: String) -> String {
    let normalized = phone.replacingOccurrences(
        of: "[^0-9]", 
        with: "", 
        options: .regularExpression
    )
    let salted = normalized + "DO_APP_SALT_2024"
    return salted.sha256()
}

// Batch upload
func uploadContactHashes(_ hashes: [String]) async {
    // Send in batches of 100
    // AWS Lambda matches against phoneHash index
    // Returns user profiles
}
```

### Contact Sync Timing
```
- First launch: Prompt after signup
- Settings: Manual sync option
- Background: Weekly sync (if enabled)
- Smart: After following 5+ people
```

---

## 7. FEED MIXING ALGORITHM

### Interleaving Strategy

```swift
func mixFeed(
    following: [Post],
    forYou: [Post],
    ratio: Double = 0.7 // 70% following
) -> [Post] {
    var mixed: [Post] = []
    var followingIndex = 0
    var forYouIndex = 0
    
    let followingCount = Int(Double(following.count + forYou.count) * ratio)
    
    while mixed.count < following.count + forYou.count {
        // Add following posts
        if followingIndex < following.count && 
           mixed.count < followingCount {
            mixed.append(following[followingIndex])
            followingIndex += 1
        }
        
        // Interleave For You posts
        if forYouIndex < forYou.count &&
           mixed.count % 3 == 2 { // Every 3rd post
            mixed.append(forYou[forYouIndex])
            forYouIndex += 1
        }
    }
    
    return mixed
}
```

### Pattern Examples
```
Following (F) + For You (Y):

70/30 ratio:
F F Y F F Y F F Y F F Y ...

New user (0/100 ratio):
Y Y Y Y Y Y Y Y Y Y ...

Growing user (40/60 ratio):
F Y Y F Y Y F Y Y F Y Y ...
```

---

## 8. PERFORMANCE TARGETS

### Response Times
```
Initial Load:
- Cache hit: < 100ms
- Network: < 500ms
- Total: < 1000ms

Pagination:
- Next page: < 300ms
- Prefetch: Background

Interactions:
- Local update: < 50ms
- API sync: < 200ms
- Rollback: < 100ms
```

### Data Limits
```
Memory:
- Active posts: 50 posts
- Post cache: 200 posts
- Image cache: 100 images

Network:
- Initial: 20 posts
- Pagination: 10 posts
- Max batch: 50 posts

Storage:
- Feed cache: 10 MB
- Image cache: 50 MB
- Total: < 100 MB
```

---

## 9. AWS LAMBDA FUNCTIONS NEEDED

### Feed Service
```
1. getFollowingFeed
   - Input: userId, limit, lastKey
   - Output: Posts from followed users
   - Ranking: Engagement + recency

2. getForYouFeed
   - Input: userId, limit, lastKey
   - Output: Personalized recommendations
   - Ranking: Multi-factor scoring

3. getHybridFeed
   - Input: userId, limit, ratio, lastKey
   - Output: Mixed feed
   - Logic: Interleave following + FYP
```

### Interaction Service
```
4. batchGetInteractions
   - Input: userId, postIds[]
   - Output: User's interactions map
   - Cache: 5 minutes

5. createInteraction
   - Input: userId, postId, type
   - Output: Interaction created
   - Side effect: Update post counts

6. deleteInteraction
   - Input: userId, postId
   - Output: Interaction deleted
   - Side effect: Decrement counts
```

### Social Graph Service
```
7. getFollowGraph
   - Input: userId
   - Output: following[], followers[], mutual[]
   - Cache: 1 hour

8. checkFollowStatus
   - Input: userId, targetUserIds[]
   - Output: Status map
   - Batch: Up to 100 users
```

### Contact Service
```
9. matchContacts
   - Input: phoneHashes[]
   - Output: Matched user profiles
   - Privacy: Never store raw numbers

10. getSuggestedUsers
    - Input: userId, limit
    - Output: Users to follow
    - Logic: Mutual friends, interests
```

---

## 10. CLIENT IMPLEMENTATION

### FeedViewModel Structure
```swift
@MainActor
class FeedViewModel: ObservableObject {
    // State
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var feedType: FeedType = .hybrid
    
    // Caching
    private var postCache: PostCache
    private var interactionCache: InteractionCache
    private var followCache: FollowCache
    
    // Services
    private let feedService: FeedAPIService
    private let interactionService: InteractionAPIService
    private let socialService: SocialGraphService
    
    // Smart loading
    func loadFeed() async {
        // 1. Check cache
        // 2. Determine strategy
        // 3. Fetch & rank
        // 4. Mix feeds
        // 5. Load interactions
        // 6. Update UI
    }
}
```

### Cache Manager
```swift
class FeedCacheManager {
    // Memory cache (fast)
    private var memoryCache: [String: Post] = [:]
    
    // Disk cache (persistent)
    private let diskCache: DiskCache
    
    // Strategy
    func get(postId: String) -> Post? {
        // Check memory first
        // Then disk
        // Return nil if not found
    }
    
    func set(_ post: Post) {
        // Update memory
        // Persist to disk
        // Manage size limits
    }
}
```

---

## 11. IMPLEMENTATION PHASES

### Phase 1: Foundation (Week 1)
- [ ] Create FeedViewModel with caching
- [ ] Implement basic Following feed
- [ ] Add pagination support
- [ ] Memory + disk cache

### Phase 2: Ranking (Week 2)
- [ ] Implement scoring algorithm
- [ ] Add time decay function
- [ ] Create For You feed
- [ ] Test ranking quality

### Phase 3: Interactions (Week 3)
- [ ] Batch interaction fetching
- [ ] Local interaction cache
- [ ] Optimistic UI updates
- [ ] Real-time sync

### Phase 4: Social Graph (Week 4)
- [ ] Follow graph caching
- [ ] Fast follow checks
- [ ] Mutual friends detection
- [ ] Social score calculation

### Phase 5: Hybrid Feed (Week 5)
- [ ] Feed mixing algorithm
- [ ] Dynamic ratio adjustment
- [ ] A/B testing framework
- [ ] Performance optimization

### Phase 6: Contacts (Week 6)
- [ ] Contact import UI
- [ ] Phone number hashing
- [ ] AWS Lambda matching
- [ ] Suggestion system

### Phase 7: Polish (Week 7)
- [ ] Performance tuning
- [ ] Error handling
- [ ] Loading states
- [ ] Analytics integration

---

## 12. SUCCESS METRICS

### Engagement Metrics
```
- Session length: > 5 minutes
- Posts viewed: > 20 per session
- Interaction rate: > 10%
- Return rate: > 60% daily
```

### Performance Metrics
```
- Feed load time: < 1 second
- Scroll smoothness: 60 FPS
- Cache hit rate: > 80%
- API error rate: < 1%
```

### Growth Metrics
```
- Contact import rate: > 40%
- Follow rate: > 5 per user
- Content creation: > 2 posts/week
- Retention: > 70% week 1
```

---

## 13. BEST PRACTICES FROM TOP APPS

### Instagram
- Hybrid feed (following + explore)
- Strong visual focus
- Story highlights
- Reels integration

### TikTok
- Aggressive For You algorithm
- Video completion signals
- Quick content discovery
- Addictive scroll

### Twitter
- Chronological option
- Trending topics
- Real-time updates
- Conversation threads

### Our Approach
- Best of all worlds
- Fitness-first content
- Community building
- Performance focus

---

## NEXT STEPS

1. Review this architecture
2. Approve approach
3. Start Phase 1 implementation
4. Iterate based on data
5. Scale as needed

This architecture will create a world-class feed experience! 🚀
