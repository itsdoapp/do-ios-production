// query-handler/index.js
// Smart query classifier and router with deep personalization
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const bedrock = new AWS.BedrockRuntime();
const polly = new AWS.Polly({ region: 'us-east-1' });
const s3 = new AWS.S3();

// ========================================
// INLINED MODULES (Robust Fallback)
// ========================================

// --- User Profile Builder ---
const buildUserProfile = async (userId) => {
  try {
    const result = await dynamodb.get({
      TableName: 'prod-users',
      Key: { userId }
    }).promise();
    
    const profile = result.Item || { userId, preferences: {} };
    
    // Ensure metadata exists for compatibility
    if (!profile.metadata) {
        profile.metadata = {
            profileCompleteness: 50, // Default
            lastActive: new Date().toISOString()
        };
    } else if (!profile.metadata.profileCompleteness) {
        profile.metadata.profileCompleteness = 50;
    }
    
    return profile;
  } catch (e) {
    console.error('[UserProfile] Error fetching profile:', e);
    return { 
        userId, 
        preferences: {},
        metadata: { profileCompleteness: 0 }
    };
  }
};
// NOTE: getUserContext is defined later in file

// --- Conversation Cache ---
const getCachedConversation = async (sessionId) => {
    // Fallback to DynamoDB fetch
    return await refreshFromDynamoDB(sessionId);
};

const addTurnToCache = async (sessionId, turn) => {
    // No-op for now, we rely on the main save logic
};

const needsFullContext = (query) => true; // Always fetch full context for safety

const refreshFromDynamoDB = async (sessionId) => {
  try {
    const result = await dynamodb.query({
      TableName: 'prod-genie-messages',
      KeyConditionExpression: 'conversationId = :sessionId',
      ExpressionAttributeValues: { ':sessionId': sessionId },
      Limit: 10,
      ScanIndexForward: false // Get latest first
    }).promise();
    
    // Reverse to get chronological order
    return (result.Items || []).reverse();
  } catch (e) {
    console.error('[Conversation] Error fetching history:', e);
    return [];
  }
};

const getCacheStats = () => ({ hits: 0, misses: 0, size: 0 });

// --- Intent Detector ---
const detectConversationIntent = (query, history, userContext) => {
  const lowerQuery = query.toLowerCase();
  let type = 'general';
  let category = null;
  
  if (lowerQuery.includes('meditat')) {
    type = 'meditation';
    category = 'mindfulness';
  } else if (lowerQuery.includes('workout') || lowerQuery.includes('exercise')) {
    type = 'fitness';
    category = 'workout';
  } else if (lowerQuery.includes('recipe') || lowerQuery.includes('food') || lowerQuery.includes('eat')) {
    type = 'nutrition';
    category = 'food';
  }
  
  return {
    type,
    category,
    confidence: 0.9,
    entities: {}
  };
};

// --- Enhanced Prompt Builder ---
const buildEnhancedPrompt = (query, context) => {
  return query; // Pass through for now
};
// NOTE: buildSystemPrompt is defined later in file

// --- Agent Tools ---
const getAvailableTools = () => [];
const executeToolCall = async (toolName, params) => null;

// --- Action Object Builder ---
const buildActionObject = (response, query) => null;
const extractActions = (text) => [];

const getUserProfile = async (userId) => buildUserProfile(userId);
const updateProfileFromConversation = async (userId, history) => {};
console.log('[ROBUST MODE] Using inlined robust implementations');


// 🆕 V3: Conversation Intelligence Imports
// DISABLED: // DISABLED: const {...} = require('./conversationCache');

// DISABLED: // DISABLED: const {...} = require('./intentDetector');

// DISABLED: // DISABLED: const {...} = require('./enhancedPromptBuilder');

// DISABLED: // DISABLED: const {...} = require('./agentTools');

// DISABLED: // DISABLED: const {...} = require('./userProfileBuilder');

// DISABLED: // DISABLED: const {...} = require('./actionObjectBuilder');


// Simple in-memory cache for user profiles (5 minute TTL)
const userProfileCache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes in milliseconds

// Helper to extract userId from event (handles both auth and no-auth scenarios)
// RETURNS: Cognito sub (used for token management and as primary user identifier)
function getUserId(event) {
  // Priority 1: Check X-User-Id header (iOS app sends Parse user ID here)
  // This ensures we use the same userId as the balance endpoint
  if (event.headers?.['X-User-Id'] || event.headers?.['x-user-id']) {
    const parseUserId = event.headers['X-User-Id'] || event.headers['x-user-id'];
    console.log(`[getUserId] Using X-User-Id header: ${parseUserId}`);
    return parseUserId;
  }
  
  // Priority 2: Try to get from JWT authorizer first (when auth is enabled)
  if (event.requestContext?.authorizer?.jwt?.claims) {
    const claims = event.requestContext.authorizer.jwt.claims;
    console.log(`[Auth] Using Cognito sub: ${claims.sub}`);
    return claims.sub;
  }
  
  // Fallback: decode JWT from Authorization header manually (when auth is disabled)
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    try {
      // Decode JWT payload (base64)
      const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
      console.log(`[Auth] Extracted Cognito sub from JWT: ${payload.sub}`);
      return payload.sub;
    } catch (e) {
      console.error('Failed to decode JWT:', e);
    }
  }
  
  throw new Error('No user ID found in request');
}

// Helper to get username from JWT (email - universal identifier)
function getUsername(event) {
  // Try to get from JWT authorizer first
  if (event.requestContext?.authorizer?.jwt?.claims) {
    const claims = event.requestContext.authorizer.jwt.claims;
    return claims['cognito:username'] || claims.email || claims.sub;
  }
  
  // Fallback: decode JWT from Authorization header
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    try {
      const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
      return payload['cognito:username'] || payload.email || payload.sub;
    } catch (e) {
      console.error('Failed to decode JWT:', e);
    }
  }
  
  return null;
}

// Map Cognito user pool ID to app user ID (federated identity ID)
async function getAppUserId(cognitoUserId, event = null) {
  try {
    // First, try to find by cognitoUserId field (if it exists in table)
    const params = {
      TableName: 'prod-users',
      IndexName: 'cognito-user-index', // Assuming there's a GSI on cognitoUserId
      KeyConditionExpression: 'cognitoUserId = :cognitoId',
      ExpressionAttributeValues: {
        ':cognitoId': cognitoUserId
      },
      Limit: 1
    };
    
    try {
      const result = await dynamodb.query(params).promise();
      if (result.Items && result.Items.length > 0) {
        console.log(`[UserMapping] Cognito ${cognitoUserId} → App ${result.Items[0].userId}`);
        return result.Items[0].userId;
      }
    } catch (queryError) {
      // Index might not exist, continue to scan
      console.log(`[UserMapping] GSI query failed, trying scan: ${queryError.message}`);
    }
    
    // Try direct scan for cognitoUserId field
    const scanParams = {
      TableName: 'prod-users',
      FilterExpression: 'cognitoUserId = :cognitoId',
      ExpressionAttributeValues: {
        ':cognitoId': cognitoUserId
      },
      Limit: 1
    };
    
    const scanResult = await dynamodb.scan(scanParams).promise();
    if (scanResult.Items && scanResult.Items.length > 0) {
      console.log(`[UserMapping] Found via scan: Cognito ${cognitoUserId} → App ${scanResult.Items[0].userId}`);
      return scanResult.Items[0].userId;
    }
    
    // Try to find by username/email from JWT if available
    if (event) {
      const username = getUsername(event);
      if (username) {
        console.log(`[UserMapping] Trying to find by username/email: ${username}`);
        
        // Try multiple lookup strategies
        const lowerUsername = username.toLowerCase();
        
        // Strategy 1: Direct lookup by username (if userId == username, which is common)
        const directUserLookup = await dynamodb.get({
          TableName: 'prod-users',
          Key: { userId: lowerUsername }
        }).promise();
        
        if (directUserLookup.Item) {
          console.log(`[UserMapping] ✅ Found by direct userId lookup: ${lowerUsername} → ${directUserLookup.Item.userId}`);
          return directUserLookup.Item.userId;
        }
        
        // Strategy 2: Scan by username or email field
        const userScanParams = {
          TableName: 'prod-users',
          FilterExpression: 'username = :username OR email = :email',
          ExpressionAttributeValues: {
            ':username': lowerUsername,
            ':email': lowerUsername
          },
          Limit: 1
        };
        
        const userScanResult = await dynamodb.scan(userScanParams).promise();
        if (userScanResult.Items && userScanResult.Items.length > 0) {
          console.log(`[UserMapping] ✅ Found by username/email scan: ${username} → App ${userScanResult.Items[0].userId}`);
          return userScanResult.Items[0].userId;
        }
        
        // Strategy 3: If username is an email, try extracting the local part
        if (username.includes('@')) {
          const localPart = username.split('@')[0].toLowerCase();
          const localPartLookup = await dynamodb.get({
            TableName: 'prod-users',
            Key: { userId: localPart }
          }).promise();
          
          if (localPartLookup.Item) {
            console.log(`[UserMapping] ✅ Found by email local part: ${localPart} → ${localPartLookup.Item.userId}`);
            return localPartLookup.Item.userId;
          }
        }
        
        console.log(`[UserMapping] ⚠️ Could not find user by username/email: ${username}`);
      }
    }
    
    // Last resort: Check if Cognito ID itself is a valid userId (might exist from old migration)
    const directLookup = await dynamodb.get({
      TableName: 'prod-users',
      Key: { userId: cognitoUserId }
    }).promise();
    
    if (directLookup.Item) {
      console.log(`[UserMapping] ⚠️ Cognito ID is a valid userId but checking if this is correct record`);
      
      // If we have username from JWT, try to match it with email/username in this record
      if (event) {
        const username = getUsername(event);
        if (username) {
          const recordEmail = (directLookup.Item.email || '').toLowerCase();
          const recordUsername = (directLookup.Item.username || '').toLowerCase();
          const jwtUsername = username.toLowerCase();
          
          // If the email/username doesn't match, this is likely the wrong record
          // Keep looking for the correct one
          if (recordEmail !== jwtUsername && recordUsername !== jwtUsername) {
            console.log(`[UserMapping] ⚠️ Cognito ID userId exists but email/username doesn't match JWT - skipping`);
            // Don't return it - fall through to return Cognito ID as-is (will likely fail balance check but at least won't use wrong user)
          } else {
            console.log(`[UserMapping] ✅ Cognito ID userId matches JWT username - using it`);
            return cognitoUserId;
          }
        }
      }
      
      // If no username match, this might be wrong - but we have no other option, so use it
      console.log(`[UserMapping] ⚠️ Using Cognito ID as userId (may be incorrect)`);
      return cognitoUserId;
    }
    
    // If still no mapping, just return the Cognito ID (it might be the app ID already)
    console.log(`[UserMapping] ⚠️ No mapping found, using Cognito ID as-is: ${cognitoUserId}`);
    return cognitoUserId;
  } catch (error) {
    console.error('[UserMapping] Error mapping user ID:', error);
    // Fallback to using the Cognito ID
    return cognitoUserId;
  }
}

// Query classification patterns
const PATTERNS = {
  database: [
    // Stats lookups
    /what (was|is) my (pace|time|distance|speed|hr|heart rate|calories)/i,
    /how (many|much|far|long) (miles|km|steps|calories|minutes)/i,
    /show (my|me) (stats|data|numbers|history|activities)/i,
    
    // Recent activity
    /my (last|recent|latest|previous) (run|bike|workout|hike|swim)/i,
    /when (was|did) (my|i) (last|recent)/i,
    
    // PRs
    /what('s| is) my (pr|personal record|best|fastest|longest)/i,
    
    // Counts
    /how many (workouts|runs|bikes|hikes) (today|this week|this month)/i,
    /total (distance|time|calories) (today|this week|this month)/i,
  ],
  
  simpleAI: [
    /what (workout|exercise) should i/i,
    /suggest (a|an) (workout|meal|exercise)/i,
    /should i (run|bike|workout|rest)/i,
    /is it (good|ok|safe) to/i,
  ],
  
  analysis: [
    'analyze', 'why', 'compare', 'trend', 'progress',
    'improve', 'performance', 'optimal', 'pattern'
  ],
  
  generation: [
    'create', 'generate', 'design', 'build', 'plan',
    'meditation', 'program', 'schedule', 'routine'
  ]
};

// Agent Capabilities Registry
// This lists all abilities the agent has - it should know what it can do and make autonomous decisions
const CAPABILITIES = {
  meditation: {
    name: 'Generate Meditation Sessions',
    description: 'Create personalized meditation scripts with audio playback. Supports stress relief, motivation, sleep, focus, energy, and gratitude. Generates high-quality audio with Amazon Polly.',
    triggers: ['meditate', 'calm', 'relax', 'mindfulness', 'motivate', 'sleep'],
    outputs: ['script', 'audio_url', 'duration', 'focus_type']
  },
  activity_analysis: {
    name: 'Analyze Activity Logs',
    description: 'Analyze runs, bikes, workouts, and other activities from user\'s own data. Provide insights on performance, patterns, trends, and recommendations. NEVER use data from other users.',
    triggers: ['analyze', 'how am i', 'progress', 'trend', 'performance'],
    outputs: ['structured_analysis', 'insights', 'recommendations']
  },
  insights: {
    name: 'Provide Personalized Insights',
    description: 'Generate insights based on user\'s activity patterns, consistency, goals, and data. Context-aware responses that reference actual workouts, dates, and metrics.',
    triggers: ['insight', 'why', 'help me understand', 'what does this mean'],
    outputs: ['insights', 'explanations', 'contextual_advice']
  },
  motivation: {
    name: 'Motivate Users',
    description: 'Provide encouragement and motivation based on user\'s context - achievements, consistency, goals, and current state. Adjust tone based on detected mood.',
    triggers: ['motivate', 'encourage', 'inspire', 'help me', 'i need'],
    outputs: ['motivational_response', 'encouragement']
  },
  create_movement: {
    name: 'Create Exercise Movements',
    description: 'Generate single exercise movements that can be tracked in the app. Includes name, sets, reps, weight, duration, category, and difficulty. Output matches app\'s movement struct.',
    triggers: ['create movement', 'add exercise', 'make exercise', 'new movement'],
    outputs: ['movement_json']
  },
  create_session: {
    name: 'Create Workout Sessions',
    description: 'Generate complete workout sessions with multiple movements. Includes name, description, movements array, difficulty, equipment needs, and tags. Output matches app\'s workoutSession struct.',
    triggers: ['create workout', 'make session', 'new session', 'workout plan'],
    outputs: ['session_json']
  },
  create_plan: {
    name: 'Create Workout Plans',
    description: 'Generate multi-day workout plans with sessions organized by day or week. Includes name, description, duration, sessions map, and difficulty. Output matches app\'s plan struct.',
    triggers: ['create plan', 'make plan', 'training program', 'workout program'],
    outputs: ['plan_json']
  },
  equipment_recognition: {
    name: 'Recognize Exercise Equipment',
    description: 'Identify gym equipment, machines, and exercise tools from images. Can provide equipment name, category, and recommended exercises.',
    triggers: ['what is this', 'identify equipment', 'recognize', 'what equipment'],
    requires_image: true,
    outputs: ['equipment_name', 'category', 'description']
  },
  nutrition_analysis: {
    name: 'Estimate Nutrition from Images',
    description: 'Analyze food images to estimate calories, macronutrients (protein, carbs, fat), and food items. Provides nutritional breakdown.',
    triggers: ['calories', 'nutrition', 'macro', 'food analysis'],
    requires_image: true,
    outputs: ['calories', 'macros', 'foods_list']
  },
  form_analysis: {
    name: 'Analyze Workout Form',
    description: 'Analyze exercise form and technique from images or videos. Provides feedback on posture, alignment, and recommendations for improvement.',
    triggers: ['check form', 'analyze form', 'technique', 'proper form'],
    requires_image: true,
    outputs: ['form_feedback', 'recommendations']
  },
  video_search: {
    name: 'Search and Display Workout Videos',
    description: 'Search YouTube for workout videos, exercise demonstrations, and tutorials. Can be chained with equipment recognition or movement creation.',
    triggers: ['video', 'tutorial', 'show me', 'how to', 'demonstration'],
    outputs: ['video_results']
  },
  voice_processing: {
    name: 'Process Voice Input',
    description: 'Handle conversational voice queries naturally. Adjust response style for voice interactions - more conversational and concise.',
    triggers: ['voice input', 'speech'],
    is_input_mode: true,
    outputs: ['text_response']
  },
  nutrition_analysis_advanced: {
    name: 'Analyze Food from Images',
    description: 'Analyze food images to estimate calories, macronutrients (protein, carbs, fat), food items, and serving sizes. Uses computer vision to identify foods accurately. CRITICAL: Must estimate portion sizes by analyzing visual cues (plate size, utensils, hand size, etc.) and calculate calories based on ACTUAL portion sizes visible, not standard serving sizes. Use multipliers (e.g., "1.5x standard serving") and weight/volume estimates (e.g., "150g", "1.5 cups") when possible. NEVER hallucinate nutritional data - only provide estimates based on what you can see.',
    triggers: ['calories', 'nutrition', 'macro', 'food analysis', 'what\'s in this', 'how many calories'],
    requires_image: true,
    outputs: ['nutrition_data', 'food_items', 'calorie_estimate']
  },
  meal_plan_creation: {
    name: 'Create Meal Plans',
    description: 'Generate weekly or daily meal plans that can be tracked in the app\'s food section. Plans include breakfast, lunch, dinner, and snacks with nutritional breakdown. Considers user goals, preferences, allergies, and calorie targets. Output matches FoodEntry and meal plan structures.',
    triggers: ['meal plan', 'food plan', 'weekly meals', 'create meal plan', 'nutrition plan'],
    outputs: ['meal_plan_json']
  },
  fridge_contents_suggestions: {
    name: 'Suggest Meals from Fridge Contents',
    description: 'Given a list of ingredients in the user\'s fridge/pantry, suggest meal ideas that align with their goals, preferences, and allergies. Provide recipes and nutritional information. Use only the ingredients provided - do not suggest meals requiring unavailable items.',
    triggers: ['fridge', 'pantry', 'what can i make', 'i have', 'suggest meal'],
    outputs: ['meal_suggestions', 'recipes', 'nutrition_info']
  },
  restaurant_search: {
    name: 'Find Restaurants Matching Goals',
    description: 'Use location and web search to find nearby restaurants with menu items that align with user\'s fitness goals, dietary preferences, and allergies. Can search by cuisine type, dietary restrictions, and nutritional criteria.',
    triggers: ['restaurant', 'food nearby', 'where to eat', 'find restaurant', 'nearby food'],
    requires_location: true,
    outputs: ['restaurant_results', 'menu_suggestions']
  },
  food_preference_tracking: {
    name: 'Track Food Preferences and Allergies',
    description: 'Learn and remember user\'s food preferences, dietary restrictions, allergies, and favorite foods from conversations and food logs. Use this information when creating meal plans, suggesting recipes, or finding restaurants.',
    triggers: ['i like', 'i don\'t like', 'allergic to', 'prefer', 'dislike'],
    outputs: ['preferences_updated']
  }
};

const classifyQuery = (query, intent = null) => {
  const lowerQuery = query.toLowerCase();
  
  // Check if this is a meditation query - calculate tokens based on duration
  if (intent && intent.action === 'meditation') {
    const duration = intent.params.duration || 10;
    // Base cost: 5 tokens for short meditations (1-5 min)
    // Scale up: +1 token per 5 minutes (6-10 min = 6 tokens, 11-15 min = 7 tokens, etc.)
    // Cap at 15 tokens for very long meditations (60+ min)
    const baseTokens = 5;
    const durationTokens = Math.ceil((duration - 1) / 5); // 0 for 1-5min, 1 for 6-10min, etc.
    const totalTokens = Math.min(15, baseTokens + durationTokens);
    
    console.log(`[Classification] Meditation query: ${duration} min → ${totalTokens} tokens (base: ${baseTokens}, duration: ${durationTokens})`);
    
    return {
      tier: 3,
      handler: 'ai',
      model: 'us.amazon.nova-pro-v1:0',
      tokens: totalTokens,
      baseTokens: totalTokens,
      cost: 0.03 * (totalTokens / 8), // Scale cost proportionally
      isMeditation: true,
      meditationDuration: duration
    };
  }
  
  // Route all queries to AI with context for now
  // This ensures consistent, context-aware responses
  
  // Check for complex multi-step queries that might benefit from agent
  const complexPatterns = [
    /create.*plan/i,
    /analyze.*and.*(suggest|recommend|create)/i,
    /compare.*and/i,
    /(multi|several|multiple).*(week|month|day)/i,
    /based on.*(history|past|previous)/i,
    /step by step/i,
    /detailed.*plan/i,
    /comprehensive/i
  ];
  
  if (complexPatterns.some(p => p.test(query))) {
    // Use Amazon Nova Pro for complex queries (vision, best reasoning)
    return {
      tier: 3,
      handler: 'ai',
      model: 'us.amazon.nova-pro-v1:0',
      tokens: 8,
      cost: 0.03
    };
  }
  
  // Check analysis keywords - use Nova Pro for reliability
  if (PATTERNS.analysis.some(k => lowerQuery.includes(k))) {
    return {
      tier: 3,
      handler: 'ai',
      model: 'us.amazon.nova-pro-v1:0',
      tokens: 5,
      cost: 0.015
    };
  }
  
  // Check generation keywords - use Nova Pro
  if (PATTERNS.generation.some(k => lowerQuery.includes(k))) {
    return {
      tier: 3,
      handler: 'ai',
      model: 'us.amazon.nova-pro-v1:0',
      tokens: 8,
      cost: 0.03
    };
  }
  
  // Default to Nova Lite for fast, cost-effective responses
  return {
    tier: 1,
    handler: 'ai',
    model: 'us.amazon.nova-lite-v1:0',
    tokens: 2,
    cost: 0.005
  };
};

// Detect action intents (meditation, equipment recognition, video search, etc.)
function detectActionIntent(query, hasImage = false) {
  // Extract just the question part if query contains [QUESTION] marker
  // This handles cases where the query includes [CONTEXT] and [QUESTION] markers
  let cleanQuery = query;
  if (query.includes('[QUESTION]')) {
    const questionMatch = query.match(/\[QUESTION\](.+)/is);
    if (questionMatch && questionMatch[1]) {
      cleanQuery = questionMatch[1].trim();
    }
  }
  
  const lowerQuery = cleanQuery.toLowerCase();
  
  // Meditation intents (including motivation, performance, healing, focus, etc.)
  // Also match common typos like "mediatate" for "meditate"
  // Match "mediatate", "meditate", "meditation", and other meditation-related terms
  if (/\b(mediat|meditat|meditation|calm|relax|breathe|mindfulness|zen|peace|motivate|motivation|inspire|inspiration|encourage|encouragement|tune me up|tune up|help me focus|focus in the morning|optimize performance|performance optimization|heal from injuries|recovery meditation|learn new habits|habit formation|focus exercise before work|pre-work focus|clear my mind|mental clarity|set intentions|intentions for the day)\b/i.test(cleanQuery)) {
    // Extract duration - use user's preference if not specified, but don't default to 10
    const extractedDuration = extractDuration(cleanQuery);
    // If no duration specified, we'll use user preference later, but for now use null to indicate it needs to be determined
    const duration = extractedDuration; // Will be set from user preference if null
    const focus = extractMeditationFocus(cleanQuery);
    const isMotivation = /\b(motivate|motivation|inspire|inspiration|encourage|encouragement)\b/i.test(cleanQuery);
    return {
      action: 'meditation',
      params: { duration, focus, isMotivation }
    };
  }
  
  // Equipment recognition (requires image)
  if (hasImage && /\b(identify|recognize|what is|what's this|equipment|machine|gym)\b/i.test(query)) {
    const needsVideo = /\b(video|tutorial|how to|show me|demonstration|exercise)\b/i.test(query);
    return {
      action: 'equipment_identification',
      params: { needsVideo }
    };
  }
  
  // Food/nutrition analysis (requires image)
  if (hasImage && /\b(calories|food|nutrition|macro|protein|carbs|fat|calorie|meal)\b/i.test(query)) {
    return {
      action: 'nutrition_analysis',
      params: {}
    };
  }
  
  // Form/technique check (requires image or video)
  if (hasImage && /\b(form|technique|check my|correct|proper|posture|alignment)\b/i.test(query)) {
    return {
      action: 'form_analysis',
      params: {}
    };
  }
  
  // Video search request
  if (/\b(video|tutorial|show me how|demonstration|watch|youtube)\b/i.test(query)) {
    const searchQuery = extractSearchQuery(query);
    if (searchQuery) {
      return {
        action: 'video_search',
        params: { query: searchQuery }
      };
    }
  }
  
  // Session creation request (workout sessions with multiple exercises)
  // Check this BEFORE movement creation to prioritize sessions
  const sessionPattern1 = /(?:^|\b)(?:create|make|new|build|design|plan|put together|set up|come up with|let's create).*(?:workout session|session|workout|leg day|arm day|chest day|back day|full body|upper body|lower body)\b/i;
  const sessionPattern2 = /\b(?:workout session|session|workout|leg day|arm day|chest day|back day).*(?:for|to|that|which|strengthen|target|focus|help|can do|in an hour)\b/i;
  
  if (sessionPattern1.test(cleanQuery) || sessionPattern2.test(cleanQuery)) {
    return {
      action: 'create_session',
      params: {}
    };
  }
  
  // Movement creation request (single exercise)
  if (/\b(create|add|make).*(?:movement|single exercise)\b/i.test(query)) {
    return {
      action: 'create_movement',
      params: {}
    };
  }
  
  // Meal plan creation
  if (/\b(meal plan|food plan|weekly meals|create meal plan|nutrition plan|meal planning)\b/i.test(query)) {
    const duration = extractDuration(query) || 7; // Default to 7 days if not specified
    return {
      action: 'meal_plan_creation',
      params: { duration }
    };
  }
  
  // Fridge contents / meal suggestions
  if (/\b(fridge|pantry|what can i make|i have|suggest meal|recipe|what to cook|ingredients)\b/i.test(query)) {
    return {
      action: 'fridge_contents_suggestions',
      params: {}
    };
  }
  
  // Restaurant search
  if (/\b(restaurant|food nearby|where to eat|find restaurant|nearby food|food near|eat out)\b/i.test(query)) {
    return {
      action: 'restaurant_search',
      params: {}
    };
  }
  
  // Food preference tracking
  if (/\b(i like|i don't like|allergic to|prefer|dislike|allergy|dietary|vegetarian|vegan|gluten|dairy)\b/i.test(query)) {
    return {
      action: 'food_preference_tracking',
      params: {}
    };
  }
  
  // Vision board creation
  if (/\b(vision board|create vision board|make vision board|vision board for|my vision|dream board|goal board)\b/i.test(cleanQuery)) {
    return {
      action: 'vision_board',
      params: {}
    };
  }
  
  // Manifestation
  if (/\b(manifest|manifestation|manifesting|what i want|attract|law of attraction|visualize my|create my reality)\b/i.test(cleanQuery)) {
    return {
      action: 'manifestation',
      params: {}
    };
  }
  
  // Affirmations
  if (/\b(affirmation|affirmations|daily affirmation|positive affirmation|affirm|self affirmation|mantra|daily mantra)\b/i.test(cleanQuery)) {
    return {
      action: 'affirmation',
      params: {}
    };
  }
  
  // Bedtime story requests
  if (/\b(bedtime story|tell me a story|read me a story|story for|bedtime tale|story for my|story for a|goodnight story|nighttime story|sleep story|relaxing story)\b/i.test(cleanQuery)) {
    const storyType = extractStoryType(cleanQuery);
    const duration = extractDuration(cleanQuery) || 10; // Default to 10 minutes
    return {
      action: 'bedtime_story',
      params: { 
        storyType: storyType?.type || 'bedtime',
        audience: storyType?.audience || 'adult',
        tone: storyType?.tone || 'calming',
        duration: duration
      }
    };
  }
  
  return null; // No special action detected
}

// Extract duration from query (e.g., "5 minutes", "10 min")
function extractDuration(query) {
  const match = query.match(/(\d{1,2})\s*(?:min|minute|minutes)/i);
  if (match) {
    const duration = parseInt(match[1]);
    return Math.max(1, Math.min(60, duration)); // Clamp between 1-60 minutes
  }
  return null;
}

// Extract specific meditation request details from user query
function extractSpecificMeditationRequest(query) {
  const lower = query.toLowerCase();
  
  // Extract specific emotions, situations, or needs mentioned
  const specificNeeds = [];
  
  // Emotional states
  if (/\b(stressed|stressing|overwhelmed|overwhelm|anxious|anxiety|worried|worry|frustrated|frustration|tired|exhausted|burned out|burnout)\b/i.test(query)) {
    const emotionMatch = query.match(/\b(stressed|stressing|overwhelmed|overwhelm|anxious|anxiety|worried|worry|frustrated|frustration|tired|exhausted|burned out|burnout)\b/i);
    if (emotionMatch) {
      specificNeeds.push(`The user is feeling ${emotionMatch[0].toLowerCase()}.`);
    }
  }
  
  // Specific situations
  if (/\b(before work|before meeting|before presentation|before interview|before exam|after work|after workout|after long day)\b/i.test(query)) {
    const situationMatch = query.match(/\b(before work|before meeting|before presentation|before interview|before exam|after work|after workout|after long day)\b/i);
    if (situationMatch) {
      specificNeeds.push(`The user needs this meditation ${situationMatch[0].toLowerCase()}.`);
    }
  }
  
  // Specific challenges
  if (/\b(decision|deciding|choosing|confused|uncertain|doubt|stuck|can't focus|distracted|scattered)\b/i.test(query)) {
    const challengeMatch = query.match(/\b(decision|deciding|choosing|confused|uncertain|doubt|stuck|can't focus|distracted|scattered)\b/i);
    if (challengeMatch) {
      specificNeeds.push(`The user is dealing with ${challengeMatch[0].toLowerCase()}.`);
    }
  }
  
  // Specific goals mentioned
  if (/\b(perform better|do better at work|sleep better|feel more confident|be more present|connect with|find peace|let go|release|move forward)\b/i.test(query)) {
    const goalMatch = query.match(/\b(perform better|do better at work|sleep better|feel more confident|be more present|connect with|find peace|let go|release|move forward)\b/i);
    if (goalMatch) {
      specificNeeds.push(`The user wants to ${goalMatch[0].toLowerCase()}.`);
    }
  }
  
  // Extract the actual question/request part if it contains [QUESTION] marker
  let cleanQuery = query;
  if (query.includes('[QUESTION]')) {
    const questionMatch = query.match(/\[QUESTION\](.+)/is);
    if (questionMatch && questionMatch[1]) {
      cleanQuery = questionMatch[1].trim();
    }
  }
  
  // If we found specific needs, combine them
  if (specificNeeds.length > 0) {
    return specificNeeds.join(' ');
  }
  
  // Otherwise, extract the core request (first sentence or key phrase)
  const sentences = cleanQuery.split(/[.!?]/).filter(s => s.trim().length > 10);
  if (sentences.length > 0) {
    // Remove common meditation request phrases to get to the specific need
    const coreRequest = sentences[0]
      .replace(/\b(help me|i want to|i need to|can you|please|create|make|give me|guide me through)\b/gi, '')
      .replace(/\b(meditate|meditation|a meditation|meditation for)\b/gi, '')
      .trim();
    
    if (coreRequest.length > 15 && coreRequest.length < 200) {
      return `The user's specific request: "${coreRequest}".`;
    }
  }
  
  return null;
}

// Extract story type, audience, and tone from query
function extractStoryType(query) {
  const lower = query.toLowerCase();
  
  // Default values
  let type = 'bedtime'; // bedtime, adventure, fantasy, nature, etc.
  let audience = 'adult'; // adult, kid, child, teenager
  let tone = 'calming'; // calming, funny, adventurous, magical, reflective
  
  // Detect audience
  if (/\b(for|my|a) (kid|child|children|son|daughter|little one|young|toddler|preschooler)\b/i.test(query)) {
    audience = 'kid';
  } else if (/\b(for|my|a) (teen|teenager|teenage)\b/i.test(query)) {
    audience = 'teenager';
  } else if (/\b(adult|grown|grown-up)\b/i.test(query)) {
    audience = 'adult';
  }
  
  // Detect tone
  if (/\b(funny|humorous|comedy|silly|lighthearted|cheerful)\b/i.test(query)) {
    tone = 'funny';
  } else if (/\b(adventure|adventurous|exciting|journey)\b/i.test(query)) {
    tone = 'adventurous';
  } else if (/\b(magical|fantasy|fairy|enchanted|wonder)\b/i.test(query)) {
    tone = 'magical';
    type = 'fantasy';
  } else if (/\b(reflective|philosophical|thoughtful|deep|meaningful)\b/i.test(query)) {
    tone = 'reflective';
  } else if (/\b(calming|peaceful|soothing|relaxing|gentle)\b/i.test(query)) {
    tone = 'calming';
  }
  
  // Detect story type/theme
  if (/\b(nature|forest|ocean|animals|wildlife)\b/i.test(query)) {
    type = 'nature';
  } else if (/\b(fantasy|magical|fairy|enchanted|prince|princess|dragon)\b/i.test(query)) {
    type = 'fantasy';
  } else if (/\b(adventure|journey|quest|explore|travel)\b/i.test(query)) {
    type = 'adventure';
  } else if (/\b(friendship|friends|companionship)\b/i.test(query)) {
    type = 'friendship';
  } else if (/\b(courage|brave|hero|heroic)\b/i.test(query)) {
    type = 'courage';
  }
  
  return { type, audience, tone };
}

// Extract meditation focus from query
function extractMeditationFocus(query) {
  const lower = query.toLowerCase();
  
  // Performance optimization
  if (/\b(tune me up|tune up|optimize performance|performance optimization|peak state|athletic performance)\b/i.test(lower)) return 'performance';
  
  // Healing and recovery
  if (/\b(heal from injuries|healing|recovery meditation|injury recovery|body awareness|self-compassion)\b/i.test(lower)) return 'healing';
  
  // Habit formation
  if (/\b(learn new habits|habit formation|behavior change|new habits|develop habits)\b/i.test(lower)) return 'habit_formation';
  
  // Morning focus
  if (/\b(focus in the morning|morning focus|morning routine|morning practice)\b/i.test(lower)) return 'morning_focus';
  
  // Pre-work preparation
  if (/\b(focus exercise before work|pre-work focus|pre-work|before work|work preparation)\b/i.test(lower)) return 'pre_work';
  
  // Mental clarity
  if (/\b(clear my mind|mental clarity|clarity|clear mind)\b/i.test(lower)) return 'clarity';
  
  // Intention setting
  if (/\b(set intentions|intentions for the day|set intention|daily intention)\b/i.test(lower)) return 'intention_setting';
  
  // Recovery (general)
  if (/\b(recovery|post-workout recovery|physical recovery|mental recovery)\b/i.test(lower)) return 'recovery';
  
  // Existing focus types
  if (/\b(motivate|motivation|inspire|inspiration|encourage|encouragement)\b/i.test(lower)) return 'motivation';
  if (/\b(stress|anxiety|worry)\b/i.test(lower)) return 'stress';
  if (/\b(sleep|rest|bedtime)\b/i.test(lower)) return 'sleep';
  if (/\b(focus|concentration|work|study)\b/i.test(lower)) return 'focus';
  if (/\b(energy|morning|wake)\b/i.test(lower)) return 'energy';
  if (/\b(gratitude|appreciation|thankful)\b/i.test(lower)) return 'gratitude';
  
  return 'stress'; // Default
}

// Select appropriate ambient sound type based on meditation focus, script content, and user query
// Analyzes script for mentions of specific sounds and user query for explicit preferences
function selectAmbientSoundType(focus, isMotivation = false, script = '', userQuery = '') {
  // First, check if script explicitly mentions a specific ambient sound
  const scriptLower = script.toLowerCase();
  if (scriptLower.includes('ocean') || scriptLower.includes('wave') || scriptLower.includes('tide') || scriptLower.includes('seashore') || scriptLower.includes('beach')) {
    return 'ocean';
  }
  if (scriptLower.includes('rain') || scriptLower.includes('raindrop') || scriptLower.includes('drizzle') || scriptLower.includes('storm')) {
    return 'rain';
  }
  if (scriptLower.includes('forest') || scriptLower.includes('tree') || scriptLower.includes('wood') || scriptLower.includes('nature') || scriptLower.includes('bird')) {
    return 'forest';
  }
  if (scriptLower.includes('zen') || scriptLower.includes('chime') || scriptLower.includes('singing bowl') || scriptLower.includes('bowl') || scriptLower.includes('gong')) {
    return 'zen';
  }
  
  // Check user query for explicit ambient sound preferences
  const queryLower = userQuery.toLowerCase();
  if (queryLower.includes('ocean') || queryLower.includes('wave') || queryLower.includes('beach')) {
    return 'ocean';
  }
  if (queryLower.includes('rain') || queryLower.includes('rainy') || queryLower.includes('storm')) {
    return 'rain';
  }
  if (queryLower.includes('forest') || queryLower.includes('nature') || queryLower.includes('wood')) {
    return 'forest';
  }
  if (queryLower.includes('zen') || queryLower.includes('chime') || queryLower.includes('bowl')) {
    return 'zen';
  }
  
  // Fall back to focus-based selection if no script/user hints
  // Motivation meditations use forest for energy
  if (isMotivation) {
    return 'forest';
  }
  
  // Map focus to ambient sound type
  switch (focus) {
    case 'stress':
    case 'anxiety':
      return 'ocean';
    case 'sleep':
    case 'rest':
      return 'rain';
    case 'focus':
    case 'concentration':
    case 'clarity':
    case 'morning_focus':
    case 'pre_work':
      return 'zen';
    case 'energy':
    case 'motivation':
      return 'forest';
    case 'gratitude':
    case 'healing':
    case 'recovery':
    case 'habit_formation':
    case 'intention_setting':
    case 'performance':
    default:
      return 'ocean'; // Default to ocean for calming effect
  }
}

// Clean meditation script: remove markdown, headers, normalize pauses
function cleanMeditationScript(script) {
  if (!script) return '';
  
  let cleaned = script;
  
  // Remove markdown headers (##, ###, etc.)
  cleaned = cleaned.replace(/^#{1,6}\s+.+$/gm, '');
  
  // Remove markdown bold (**text**)
  cleaned = cleaned.replace(/\*\*([^*]+)\*\*/g, '$1');
  
  // Remove markdown horizontal rules (---)
  cleaned = cleaned.replace(/^---+$/gm, '');
  
  // Remove section headers like "Settling In:", "Beginning the Meditation:", etc.
  cleaned = cleaned.replace(/^[A-Z][^:]*:[\s]*$/gm, '');
  
  // Remove "End of Meditation" or similar end markers
  cleaned = cleaned.replace(/\*\*End of Meditation\*\*/gi, '');
  cleaned = cleaned.replace(/End of Meditation/gi, '');
  
  // Normalize whitespace - multiple newlines to double newline
  cleaned = cleaned.replace(/\n{3,}/g, '\n\n');
  
  // Fix pause placement: 
  // - Remove standalone "..." lines
  // - Keep "... " at end of sentences but normalize spacing
  // - Ensure pauses are only at sentence endings, not mid-sentence
  cleaned = cleaned.replace(/^\s*\.\.\.\s*$/gm, ''); // Remove standalone ... lines
  cleaned = cleaned.replace(/\s+\.\.\.\s*\.\.\.\s*\.\.\./g, '...'); // Normalize multiple ...
  cleaned = cleaned.replace(/\.\.\.\s*\n/g, '...\n'); // Normalize spacing before newline
  
  // Split into sentences and add pauses naturally
  // Pauses should come after complete sentences, not mid-sentence
  const sentences = cleaned.split(/(?<=[.!?])\s+/);
  let result = [];
  
  for (let i = 0; i < sentences.length; i++) {
    const sentence = sentences[i].trim();
    if (!sentence) continue;
    
    // Remove existing ellipses from sentence
    let cleanSentence = sentence.replace(/\.\.\./g, '');
    
    // Add pause after sentences (but not after the last one unless it's a natural pause point)
    if (i < sentences.length - 1) {
      // Add pause after complete thoughts (every 2-3 sentences)
      if ((i + 1) % 2 === 0 || cleanSentence.endsWith('.')) {
        result.push(cleanSentence + '...');
      } else {
        result.push(cleanSentence);
      }
    } else {
      result.push(cleanSentence);
    }
  }
  
  // Join with proper spacing
  cleaned = result.join(' ');
  
  // Final cleanup
  cleaned = cleaned.trim();
  cleaned = cleaned.replace(/\n{2,}/g, '\n\n'); // Max double newlines
  cleaned = cleaned.replace(/\s+\.\.\./g, '...'); // Normalize space before pause
  
  return cleaned;
}

// Helper function to intelligently segment text into sentences for natural speech
function segmentTextIntoSentences(text) {
  // First, preserve breathing markers and intentional pauses
  // Replace "..." with a placeholder that we'll handle specially
  const breathingMarker = '___BREATHING_MARKER___';
  text = text.replace(/\.\.\./g, breathingMarker);
  
  // Split by paragraph breaks first
  const paragraphs = text.split(/\n\n+/);
  
  const sentences = [];
  
  for (const paragraph of paragraphs) {
    if (!paragraph.trim()) continue;
    
    // Split paragraph into sentences using better sentence boundary detection
    // Match: . ! ? followed by space and capital letter, or end of string
    // But avoid matching abbreviations (Mr., Dr., etc.) and decimals (3.5)
    const sentencePattern = /([.!?]+)(\s+|$)/g;
    let lastIndex = 0;
    let match;
    const paragraphSentences = [];
    
    while ((match = sentencePattern.exec(paragraph)) !== null) {
      const sentenceEnd = match.index + match[0].length;
      let sentence = paragraph.substring(lastIndex, sentenceEnd).trim();
      
      // Check if this is a real sentence boundary (not abbreviation)
      // Look ahead to see if next char is capital or end of string
      const nextChar = paragraph[sentenceEnd];
      const isRealBoundary = !nextChar || /[A-Z]/.test(nextChar) || /\s/.test(nextChar);
      
      if (sentence && isRealBoundary) {
        paragraphSentences.push(sentence);
        lastIndex = sentenceEnd;
      }
    }
    
    // Add remaining text
    const remaining = paragraph.substring(lastIndex).trim();
    if (remaining) {
      paragraphSentences.push(remaining);
    }
    
    // If no sentences found, use the whole paragraph
    if (paragraphSentences.length === 0) {
      paragraphSentences.push(paragraph.trim());
    }
    
    sentences.push(...paragraphSentences);
  }
  
  return { sentences, breathingMarker };
}

// Intelligent pause detection for natural meditation timing
function detectIntelligentPauses(text) {
  let processed = text;
  
  // 1. Breathing with counting: "breathe in for 4 counts" → adds 5s pause after
  processed = processed.replace(/\b(breathe\s+(?:in|out|deeply|slowly)\s+(?:for|through)\s+(\d+)\s+counts?)\b/gi, (match, fullMatch, count) => {
    const pauseTime = 5; // 5s pause for breathing exercises
    return `${fullMatch}<break time="${pauseTime}s"/>`;
  });
  
  // 2. Counting sequences: "1, 2, 3, 4" → adds 1s between each number
  // Match sequences like "1, 2, 3, 4" - must be at least 2 numbers
  processed = processed.replace(/(\b\d+\b(?:\s*,\s*\d+\b){1,})/g, (match) => {
    // Split by comma and add 1s pause between each number
    const parts = match.split(',').map(p => p.trim());
    return parts.map((num, idx) => {
      return idx < parts.length - 1 ? `${num}<break time="1s"/>` : num;
    }).join(', ');
  });
  
  // Also handle word numbers: "one, two, three, four"
  const numberWords = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
  // Match sequences of number words separated by commas
  for (let i = 0; i < numberWords.length - 1; i++) {
    const word = numberWords[i];
    const nextWord = numberWords[i + 1];
    // Match "word, nextWord" pattern
    const pattern = new RegExp(`\\b${word}\\s*,\\s*${nextWord}\\b`, 'gi');
    processed = processed.replace(pattern, (match) => {
      return match.replace(/,/, `<break time="1s"/>`);
    });
  }
  
  // 3. Count to X: "count to 4" → adds 5s pause after
  processed = processed.replace(/\b(count\s+to\s+\d+)\b/gi, (match) => {
    return `${match}<break time="5s"/>`;
  });
  
  // 4. Body scan: "notice your feet" → adds 2.5s pause after
  const bodyScanPatterns = [
    /\b(notice\s+(?:your|the)\s+(?:feet|toes|ankles|legs|knees|thighs|hips|pelvis|stomach|chest|back|shoulders|arms|hands|fingers|neck|face|head|forehead|eyes|jaw|mouth))\b/gi,
    /\b(bring\s+awareness\s+to\s+(?:your|the)\s+(?:feet|toes|ankles|legs|knees|thighs|hips|pelvis|stomach|chest|back|shoulders|arms|hands|fingers|neck|face|head|forehead|eyes|jaw|mouth))\b/gi,
    /\b(feel\s+(?:your|the)\s+(?:feet|toes|ankles|legs|knees|thighs|hips|pelvis|stomach|chest|back|shoulders|arms|hands|fingers|neck|face|head|forehead|eyes|jaw|mouth))\b/gi
  ];
  bodyScanPatterns.forEach(pattern => {
    processed = processed.replace(pattern, (match) => {
      return `${match}<break time="2.5s"/>`;
    });
  });
  
  // 5. Visualization: "imagine a..." → adds 2s pause after
  // Match "imagine" followed by various phrases, up to sentence end
  processed = processed.replace(/\b(imagine\s+(?:a|an|the|that|you|your|this|there|you're|you\s+are)\s+[^.!?]{0,80}?)([.!?]|$)/gi, (match, content, punctuation) => {
    return `${content}${punctuation || ''}<break time="2s"/>`;
  });
  
  // 6. Settling: "allow yourself to..." → adds 1.5s pause after
  processed = processed.replace(/\b(allow\s+(?:yourself|your\s+body|your\s+mind)\s+to\s+[^.!?]{0,60}?)([.!?]|$)/gi, (match, content, punctuation) => {
    return `${content}${punctuation || ''}<break time="1.5s"/>`;
  });
  processed = processed.replace(/\b(let\s+(?:yourself|your\s+body|your\s+mind)\s+[^.!?]{0,60}?)([.!?]|$)/gi, (match, content, punctuation) => {
    return `${content}${punctuation || ''}<break time="1.5s"/>`;
  });
  processed = processed.replace(/\b(give\s+yourself\s+permission\s+to\s+[^.!?]{0,60}?)([.!?]|$)/gi, (match, content, punctuation) => {
    return `${content}${punctuation || ''}<break time="1.5s"/>`;
  });
  
  // 7. Breath holds: "hold..." → adds 3s pause after
  processed = processed.replace(/\b(hold\s+(?:your\s+breath|it|that|this|the\s+breath|for\s+\d+\s+counts?))\b/gi, (match) => {
    return `${match}<break time="3s"/>`;
  });
  
  // Also handle "hold" at end of sentence or followed by ellipsis
  processed = processed.replace(/\bhold\b(\.\.\.|\.|$)/gi, (match, punctuation) => {
    return `hold${punctuation || ''}<break time="3s"/>`;
  });
  
  // 8. Repetitions: "repeat 3 times" → adds 6s pause (2s per rep)
  processed = processed.replace(/\b(repeat\s+(\d+)\s+times?)\b/gi, (match, fullMatch, count) => {
    const pauseTime = Math.min(10, parseInt(count) * 2); // 2s per rep, max 10s
    return `${fullMatch}<break time="${pauseTime}s"/>`;
  });
  
  // Also handle "do this X times" or "X times"
  processed = processed.replace(/\b(do\s+this\s+(\d+)\s+times?)\b/gi, (match, fullMatch, count) => {
    const pauseTime = Math.min(10, parseInt(count) * 2);
    return `${fullMatch}<break time="${pauseTime}s"/>`;
  });
  
  // Additional: "take a deep breath" → 4s pause
  processed = processed.replace(/\b(take\s+a\s+deep\s+breath)\b/gi, (match) => {
    return `${match}<break time="4s"/>`;
  });
  
  // Additional: "exhale slowly" → 3s pause
  processed = processed.replace(/\b(exhale\s+slowly|breathe\s+out\s+slowly)\b/gi, (match) => {
    return `${match}<break time="3s"/>`;
  });
  
  return processed;
}

// Convert meditation script to natural SSML with intelligent pauses and prosody
function convertToSSML(script, focus = 'stress') {
  // Step 1: Apply intelligent pause detection FIRST (before sentence segmentation)
  let processedScript = detectIntelligentPauses(script);
  
  // Step 2: Segment into sentences
  const { sentences, breathingMarker } = segmentTextIntoSentences(processedScript);
  
  const ssmlParts = [];
  
  // Start with base prosody for calm, meditative pace
  // Use more natural variations instead of uniform robotic tone
  ssmlParts.push('<prosody rate="85%" pitch="-3%" volume="+5%">');
  
  for (let i = 0; i < sentences.length; i++) {
    let sentence = sentences[i];
    
    // Handle breathing markers (meditation pauses) - these are already processed by detectIntelligentPauses
    // but we keep this for backward compatibility with existing markers
    if (sentence.includes(breathingMarker)) {
      // Replace breathing markers with longer pauses (only if not already processed)
      if (!sentence.includes('<break time=')) {
        sentence = sentence.replace(new RegExp(breathingMarker, 'g'), '<break time="3s"/>');
      }
    }
    
    // Clean up extra whitespace (but preserve SSML break tags)
    sentence = sentence.replace(/\s+/g, ' ').trim();
    
    if (!sentence) continue;
    
    // Detect sentence type for natural prosody variation
    const isQuestion = /\?/.test(sentence);
    const isInstruction = /\b(breathe|notice|feel|imagine|allow|let|take|hold|count|repeat)\b/i.test(sentence);
    const isGuidance = /\b(remember|know|understand|realize|observe|sense)\b/i.test(sentence);
    const isTransition = /\b(now|next|then|as|while|when|gradually|slowly)\b/i.test(sentence);
    
    // Add natural prosody variations based on sentence type
    let prosodyTag = '';
    if (isQuestion) {
      // Questions: slightly higher pitch, slower rate for contemplation
      prosodyTag = '<prosody rate="80%" pitch="+2%">';
    } else if (isInstruction) {
      // Instructions: clear, slightly slower, neutral pitch
      prosodyTag = '<prosody rate="82%" pitch="-1%">';
    } else if (isGuidance) {
      // Guidance: warm, slightly slower, gentle pitch
      prosodyTag = '<prosody rate="83%" pitch="-2%" volume="+3%">';
    } else if (isTransition) {
      // Transitions: natural pace, neutral pitch
      prosodyTag = '<prosody rate="87%" pitch="0%">';
    }
    
    // Add emphasis to key meditation words (before processing pauses)
    // Use word boundaries to avoid partial matches
    sentence = sentence
      .replace(/\b(breathe|breath|breathing)\b/gi, '<emphasis level="moderate">$1</emphasis>')
      .replace(/\b(notice|feel|observe|sense|aware)\b/gi, '<emphasis level="reduced">$1</emphasis>')
      .replace(/\b(relax|calm|peace|still|quiet)\b/gi, '<prosody pitch="-5%" rate="80%">$1</prosody>');
    
    // Add appropriate pauses based on context (only if no intelligent pause was already added)
    if (i > 0 && !sentence.includes('<break time=')) {
      // Check if previous sentence ended with strong punctuation
      const prevSentence = sentences[i - 1];
      const prevEndsStrong = /[.!?]$/.test(prevSentence.trim());
      
      if (prevEndsStrong) {
        // Longer pause after sentence-ending punctuation
        ssmlParts.push('<break time="1.2s"/>');
      } else {
        // Shorter pause for continuation
        ssmlParts.push('<break time="0.8s"/>');
      }
    }
    
    // Process punctuation within the sentence for natural pauses
    // Skip if intelligent pauses were already added
    let processedSentence = sentence;
    if (!sentence.includes('<break time=')) {
      processedSentence = sentence
        // Commas - brief pause for natural flow (but not if it's a breathing marker context)
        .replace(/,([^\d])/g, ',<break time="0.4s"/>$1')
        // Colons and semicolons - medium pause
        .replace(/[:;]([^\d])/g, '<break time="0.6s"/>$1')
        // Question marks - natural pause (if not at end)
        .replace(/\?([^\s])/g, '?<break time="0.8s"/>$1');
    }
    
    // Ensure sentence ends properly (only if no break tag at end)
    if (!/[.!?]$/.test(processedSentence.trim()) && !processedSentence.trim().endsWith('"/>')) {
      // Add subtle pause if no ending punctuation
      processedSentence += '<break time="0.5s"/>';
    }
    
    // Wrap sentence with prosody variation if needed
    if (prosodyTag) {
      ssmlParts.push(prosodyTag);
      ssmlParts.push(processedSentence);
      ssmlParts.push('</prosody>');
    } else {
      ssmlParts.push(processedSentence);
    }
  }
  
  ssmlParts.push('</prosody>');
  
  return ssmlParts.join(' ');
}

// Generate meditation audio using Amazon Polly
async function generateMeditationAudio(script, focus = 'stress') {
  try {
    // Check environment variable first
    const bucketName = process.env.MEDITATION_AUDIO_BUCKET;
    if (!bucketName) {
      console.error('[Polly] ❌ CRITICAL: MEDITATION_AUDIO_BUCKET environment variable not set!');
      throw new Error('MEDITATION_AUDIO_BUCKET environment variable not set');
    }
    console.log(`[Polly] ✅ S3 bucket configured: ${bucketName}`);
    
    // Select voice - use Joanna for all meditation types including motivation
    // Motivation is a form of meditation, so use the same calming, consistent voice
    const voiceMap = {
      'stress': 'Joanna',
      'anxiety': 'Joanna',
      'sleep': 'Joanna',
      'rest': 'Joanna',
      'focus': 'Joanna',
      'concentration': 'Joanna',
      'energy': 'Joanna',
      'motivation': 'Joanna',
      'gratitude': 'Joanna'
    };
    
    const voiceId = voiceMap[focus] || 'Joanna';
    console.log(`[Polly] Selected voice: ${voiceId} for focus: ${focus}`);
    
    // Convert script to natural SSML with intelligent sentence segmentation
    const ssmlContent = convertToSSML(script, focus);
    
    // Wrap in SSML speak tag
    const ssml = `<speak>${ssmlContent}</speak>`;
    
    console.log(`[Polly] Generating audio with voice ${voiceId}, script length: ${script.length} chars, SSML length: ${ssml.length} chars`);
    
    // Generate speech with neural engine (best quality, natural pace)
    const params = {
      Text: ssml,
      TextType: 'ssml',
      OutputFormat: 'mp3',
      VoiceId: voiceId,
      Engine: 'neural' // Neural engine with prosody for best quality
    };
    
    console.log(`[Polly] Calling polly.synthesizeSpeech with params:`, JSON.stringify({ ...params, Text: `${params.Text.substring(0, 100)}...` }));
    const data = await polly.synthesizeSpeech(params).promise();
    console.log(`[Polly] ✅ Polly synthesis successful, audio stream size: ${data.AudioStream ? 'present' : 'missing'}`);
    
    // Generate unique filename
    const timestamp = Date.now();
    const hash = require('crypto').createHash('md5').update(script).digest('hex').substring(0, 8);
    const filename = `meditation/${hash}-${timestamp}.mp3`;
    
    // Upload to S3
    console.log(`[Polly] Uploading to S3 bucket: ${bucketName}, key: ${filename}`);
    console.log(`[Polly] Audio stream type: ${typeof data.AudioStream}, is Buffer: ${Buffer.isBuffer(data.AudioStream)}`);
    
    try {
      await s3.putObject({
        Bucket: bucketName,
        Key: filename,
        Body: data.AudioStream,
        ContentType: 'audio/mpeg',
        CacheControl: 'max-age=604800' // Cache for 7 days (matches lifecycle policy)
      }).promise();
      
      console.log(`[Polly] ✅ Audio uploaded to S3: ${filename}`);
    } catch (s3Error) {
      console.error(`[Polly] ❌ S3 upload failed:`, s3Error);
      throw new Error(`S3 upload failed: ${s3Error.message}`);
    }
    
    // Generate signed URL (valid for 1 hour)
    const signedUrl = s3.getSignedUrl('getObject', {
      Bucket: bucketName,
      Key: filename,
      Expires: 3600 // 1 hour
    });
    
    // Also return permanent URL (if bucket is public or via CloudFront)
    const permanentUrl = `https://${bucketName}.s3.amazonaws.com/${filename}`;
    
    return {
      audioUrl: signedUrl,
      permanentUrl: permanentUrl,
      filename: filename,
      duration: Math.ceil(script.length / 10) // Rough estimate: 10 chars per second
    };
    
  } catch (error) {
    console.error('[Polly] Error generating audio:', error);
    console.error('[Polly] Error details:', JSON.stringify({
      message: error.message,
      code: error.code,
      statusCode: error.statusCode
    }));
    // Return null on error - fallback to iOS TTS
    return null;
  }
}

// Extract search query for video search
function extractSearchQuery(query) {
  // Remove command words and keep the subject
  const cleaned = query
    .replace(/\b(show me|watch|video|tutorial|how to|demonstration)\b/gi, '')
    .replace(/\b(equipment|exercise|workout|movement)\b/gi, '')
    .trim();
  return cleaned || null;
}

// Search YouTube videos (fallback to web search if no API key)
async function searchVideos(query, limit = 5) {
  const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;
  const https = require('https');
  
  if (YOUTUBE_API_KEY) {
    try {
      const searchUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=${limit}&q=${encodeURIComponent(query + ' workout exercise')}&type=video&key=${YOUTUBE_API_KEY}`;
      
      // Use native fetch if available (Node 18+), otherwise use https
      let data;
      if (typeof fetch !== 'undefined') {
        const response = await fetch(searchUrl);
        data = await response.json();
      } else {
        // Fallback to https module
        data = await new Promise((resolve, reject) => {
          https.get(searchUrl, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
              try {
                resolve(JSON.parse(body));
              } catch (e) {
                reject(e);
              }
            });
          }).on('error', reject);
        });
      }
      
      if (data.items && data.items.length > 0) {
        return data.items.map(item => ({
          videoId: item.id.videoId,
          title: item.snippet.title,
          thumbnail: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.default?.url,
          channel: item.snippet.channelTitle,
          url: `https://www.youtube.com/watch?v=${item.id.videoId}`
        }));
      }
    } catch (error) {
      console.error('[VideoSearch] YouTube API error:', error);
      // Fall through to placeholder
    }
  }
  
  // Fallback: Return placeholder with YouTube search URL
  console.log('[VideoSearch] No YouTube API key or API error, returning placeholder');
  return [{
    videoId: 'placeholder',
    title: `Search YouTube for: "${query} workout"`,
    thumbnail: null,
    channel: 'YouTube',
    url: `https://www.youtube.com/results?search_query=${encodeURIComponent(query + ' workout')}`
  }];
}

// Helper: Extract equipment name from AI response
function extractEquipmentName(response) {
  // Try to extract equipment name from common patterns
  const patterns = [
    /(?:this is|that's|this|it's)\s+(?:a\s+|an\s+)?([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i,
    /(?:equipment|machine|device):\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i,
    /(?:called|known as|named)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i
  ];
  
  for (const pattern of patterns) {
    const match = response.match(pattern);
    if (match && match[1]) {
      return match[1].trim();
    }
  }
  
  // Fallback: extract first capitalized words
  const words = response.split(/\s+/);
  let equipmentName = '';
  for (let i = 0; i < Math.min(words.length, 3); i++) {
    if (words[i][0] === words[i][0].toUpperCase() && /^[A-Za-z]+$/.test(words[i])) {
      equipmentName += words[i] + ' ';
    }
  }
  return equipmentName.trim() || null;
}

// Helper: Categorize equipment type
function categorizeEquipment(name) {
  if (!name) return 'other';
  
  const lower = name.toLowerCase();
  if (lower.includes('bench') || lower.includes('chest') || lower.includes('press')) return 'chest';
  if (lower.includes('squat') || lower.includes('leg') || lower.includes('knee')) return 'legs';
  if (lower.includes('pull') || lower.includes('row') || lower.includes('lat')) return 'back';
  if (lower.includes('shoulder') || lower.includes('deltoid')) return 'shoulders';
  if (lower.includes('curl') || lower.includes('tricep') || lower.includes('bicep')) return 'arms';
  if (lower.includes('cardio') || lower.includes('treadmill') || lower.includes('bike') || lower.includes('elliptical')) return 'cardio';
  return 'other';
}

// Helper: Parse nutrition data from AI response
function parseNutritionFromResponse(response) {
  const nutrition = {
    calories: 0,
    macros: { protein: 0, carbs: 0, fat: 0 },
    foods: []
  };
  
  // Extract calories
  const calorieMatch = response.match(/(\d+)\s*(?:calories|kcal|cal)/i);
  if (calorieMatch) {
    nutrition.calories = parseInt(calorieMatch[1]);
  }
  
  // Extract macros
  const proteinMatch = response.match(/(\d+(?:\.\d+)?)\s*g\s*(?:protein|pro)/i);
  const carbMatch = response.match(/(\d+(?:\.\d+)?)\s*g\s*(?:carbs|carbohydrates|carbohydrate)/i);
  const fatMatch = response.match(/(\d+(?:\.\d+)?)\s*g\s*(?:fat|fats)/i);
  
  if (proteinMatch) nutrition.macros.protein = parseFloat(proteinMatch[1]);
  if (carbMatch) nutrition.macros.carbs = parseFloat(carbMatch[1]);
  if (fatMatch) nutrition.macros.fat = parseFloat(fatMatch[1]);
  
  // Extract food items (simple heuristic - look for common food patterns)
  const foodPatterns = [
    /\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(?:with|and|,)/g,
    /(?:contains|includes|has)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/g
  ];
  
  for (const pattern of foodPatterns) {
    const matches = response.matchAll(pattern);
    for (const match of matches) {
      if (match[1] && match[1].length > 2) {
        nutrition.foods.push(match[1].trim());
      }
    }
  }
  
  return nutrition;
}

// Helper: Extract recommendations from form analysis
function extractRecommendations(response) {
  const recommendations = [];
  const lines = response.split('\n');
  
  for (const line of lines) {
    if (/recommend|suggest|should|try|improve|focus/i.test(line) && line.length > 10) {
      recommendations.push(line.trim());
    }
  }
  
  return recommendations.length > 0 ? recommendations : [response];
}

// Helper: Extract meal plan from text response (constructs FoodEntry-compatible structure)
function extractMealPlanFromText(response, days = 7) {
  const meals = [];
  const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  
  // Simple extraction - look for meal patterns in response
  // The AI should ideally return structured JSON, but we parse text as fallback
  const lines = response.split('\n');
  let currentMeal = null;
  
  for (const line of lines) {
    // Detect meal type
    for (const mealType of mealTypes) {
      if (line.toLowerCase().includes(mealType)) {
        if (currentMeal) meals.push(currentMeal);
        currentMeal = {
          mealType: mealType,
          name: line.trim(),
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0
        };
        break;
      }
    }
    
    // Extract nutrition if available
    if (currentMeal) {
      const calorieMatch = line.match(/(\d+)\s*cal/i);
      if (calorieMatch) currentMeal.calories = parseInt(calorieMatch[1]);
      
      const proteinMatch = line.match(/(\d+(?:\.\d+)?)\s*g\s*pro/i);
      if (proteinMatch) currentMeal.protein = parseFloat(proteinMatch[1]);
    }
  }
  
  if (currentMeal) meals.push(currentMeal);
  
  return meals.length > 0 ? meals : null;
}

// Helper: Extract meal suggestions from text
function extractMealSuggestionsFromText(response) {
  const suggestions = [];
  const lines = response.split('\n');
  
  for (const line of lines) {
    // Look for meal suggestions (usually start with numbers, dashes, or bullet points)
    if ((/^\d+\.|^[-•*]|^[A-Z][a-z]+/i.test(line.trim()) && line.length > 20) || 
        /suggest|recommend|you can make|try making/i.test(line)) {
      suggestions.push(line.trim().replace(/^[-•*\d+\.]\s*/, ''));
    }
  }
  
  return suggestions.length > 0 ? suggestions.slice(0, 10) : [response];
}

// Helper: Extract recipes from text
function extractRecipesFromText(response) {
  // Look for recipe-like patterns (ingredients lists, instructions)
  const recipes = [];
  const sections = response.split(/\n{2,}/);
  
  for (const section of sections) {
    if ((/ingredients|recipe|instructions|how to/i.test(section) && section.length > 50)) {
      recipes.push(section.trim());
    }
  }
  
  return recipes.length > 0 ? recipes : [];
}

// Helper: Extract restaurant suggestions
function extractRestaurantSuggestions(response) {
  const suggestions = [];
  const lines = response.split('\n');
  
  for (const line of lines) {
    // Look for restaurant names or recommendations
    if ((line.length > 10 && line.length < 100) && 
        (/restaurant|cafe|diner|bistro|grill/i.test(line) || 
         /^\d+\.|^[-•*]/i.test(line.trim()))) {
      suggestions.push(line.trim().replace(/^[-•*\d+\.]\s*/, ''));
    }
  }
  
  return suggestions.slice(0, 10);
}

// Helper: Extract workout session from AI response
function extractWorkoutSession(response, query) {
  // Try to extract JSON first
  const jsonMatch = response.match(/\{[\s\S]*"name"[\s\S]*"movements"[\s\S]*\}/);
  if (jsonMatch) {
    try {
      const parsed = JSON.parse(jsonMatch[0]);
      if (parsed.name && parsed.movements && Array.isArray(parsed.movements)) {
        return parsed;
      }
    } catch (e) {
      console.log('[ACTION] Could not parse workout session JSON, parsing from text');
    }
  }
  
  // Parse from text response - extract structured data
  const session = {
    name: null,
    description: null,
    difficulty: 'intermediate',
    equipmentNeeded: false,
    tags: [],
    movements: []
  };
  
  // Extract session name - look for title/header
  const namePatterns = [
    /(?:session|workout):\s*\*\*?([^*\n]{5,60})\*\*?/i,
    /^#+\s*([^\n]{5,60})/m,
    /(?:^|\n)\*\*?([A-Z][^\n*]{5,60})\*\*?:/m
  ];
  
  for (const pattern of namePatterns) {
    const match = response.match(pattern);
    if (match && match[1]) {
      session.name = match[1].trim().replace(/^#+\s*/, '');
      break;
    }
  }
  
  // If no name found, generate from query
  if (!session.name) {
    const queryMatch = query.match(/(?:create|make|new).*(?:session|workout|leg day|arm day|chest day|back day|full body|upper body|lower body)\s+(?:for|to|that|which|strengthen|target|focus|help|can do|in an hour)?\s*(.+)/i);
    if (queryMatch && queryMatch[1]) {
      session.name = queryMatch[1].trim().substring(0, 60);
    } else {
      session.name = 'Workout Session';
    }
  }
  
  // Extract description (first paragraph, before exercises)
  const descMatch = response.match(/(?:description|overview|summary):\s*(.+?)(?:\n\n|\n(?:###|##|#|\d+\.|[-•*]|Warm|Main|Cool))/is) ||
                    response.split(/\n{2,}/)[0];
  if (descMatch) {
    session.description = (typeof descMatch === 'string' ? descMatch : descMatch[1]).trim();
    // Remove markdown formatting
    session.description = session.description.replace(/\*\*|__|#+\s*/g, '').trim();
  }
  
  // Extract difficulty
  const difficultyMatch = response.match(/\b(beginner|intermediate|advanced|expert)\b/i);
  if (difficultyMatch) {
    session.difficulty = difficultyMatch[1].toLowerCase();
  }
  
  // Check for equipment needs
  session.equipmentNeeded = /\b(equipment|machine|barbell|dumbbell|weights|gym|bench|step|foam roller)\b/i.test(response);
  
  // Extract movements - look for exercise patterns
  // Skip headers, tips, equipment lists, etc.
  const exercisePatterns = [
    /\d+\.\s*\*\*?([^*\n]{5,50})\*\*?[:\s]*(\d+)\s*(?:sets?|x)[\s,]*(\d+(?:-\d+)?)\s*(?:reps?|rep)/gi,
    /\d+\.\s*\*\*?([^*\n]{5,50})\*\*?[:\s]*(\d+(?:\.\d+)?)\s*(?:seconds?|sec|s|minutes?|min)/gi,
    /\*\*?([A-Z][^*\n]{5,50})\*\*?[:\s]*(\d+)\s*(?:sets?|x)[\s,]*(\d+(?:-\d+)?)\s*(?:reps?|rep)/gi,
    /\*\*?([A-Z][^*\n]{5,50})\*\*?[:\s]*(\d+(?:\.\d+)?)\s*(?:seconds?|sec|s|minutes?|min)/gi
  ];
  
  const seenMovements = new Set();
  
  for (const pattern of exercisePatterns) {
    const matches = response.matchAll(pattern);
    for (const match of matches) {
      const movementName = match[1]?.trim();
      if (movementName && 
          movementName.length > 5 && 
          movementName.length < 100 &&
          !seenMovements.has(movementName.toLowerCase()) &&
          !movementName.match(/^(Warm|Main|Cool|Equipment|Tips|Duration|Frequency|Session|Workout|Dynamic|Static|Foam|Bodyweight|Strengthening|Knee|Leg|Arm|Chest|Back|Focus|Gradual|Listen)/i)) {
        
        seenMovements.add(movementName.toLowerCase());
        
        // Determine if timed or rep-based
        const isTimed = /seconds?|sec|s|minutes?|min|hold/i.test(match[0]);
        const setsCount = match[2] ? parseInt(match[2]) : 3;
        const repsOrSec = match[3] ? match[3] : (isTimed ? '60' : '10');
        
        // Create sets
        const sets = [];
        for (let i = 0; i < setsCount; i++) {
          if (isTimed) {
            const seconds = repsOrSec.includes('min') ? parseFloat(repsOrSec) * 60 : parseFloat(repsOrSec);
            sets.push({
              weight: null,
              reps: null,
              sec: String(Math.round(seconds)),
              isTimed: true
            });
          } else {
            sets.push({
              weight: null,
              reps: String(repsOrSec),
              sec: null,
              isTimed: false
            });
          }
        }
        
        session.movements.push({
          movement1Name: movementName,
          movement2Name: null,
          isSingle: true,
          isTimed: isTimed,
          category: null,
          difficulty: session.difficulty,
          description: null,
          firstSectionSets: sets
        });
      }
    }
  }
  
  // If no movements found with patterns, try simpler extraction
  if (session.movements.length === 0) {
    const lines = response.split('\n');
    for (const line of lines) {
      // Look for exercise names (capitalized, 5-50 chars, not headers)
      if (/^\d+\.\s*\*\*?([A-Z][^*\n]{5,50})\*\*?/i.test(line)) {
        const match = line.match(/^\d+\.\s*\*\*?([^*\n]{5,50})\*\*?/i);
        if (match && match[1]) {
          const movementName = match[1].trim();
          if (!movementName.match(/^(Warm|Main|Cool|Equipment|Tips|Duration|Frequency)/i)) {
            session.movements.push({
              movement1Name: movementName,
              movement2Name: null,
              isSingle: true,
              isTimed: false,
              category: null,
              difficulty: session.difficulty,
              description: null,
              firstSectionSets: [
                { weight: null, reps: '10', sec: null, isTimed: false },
                { weight: null, reps: '10', sec: null, isTimed: false },
                { weight: null, reps: '10', sec: null, isTimed: false }
              ]
            });
          }
        }
      }
    }
  }
  
  return session;
}

// Helper: Extract food preferences from query
function extractFoodPreferences(query) {
  const preferences = {
    likes: [],
    dislikes: [],
    allergies: [],
    restrictions: []
  };
  
  // Extract allergies
  const allergyMatch = query.match(/(?:allergic|allergy) to\s+([^.]+)/i);
  if (allergyMatch) {
    preferences.allergies = allergyMatch[1].split(',').map(s => s.trim());
  }
  
  // Extract likes
  const likeMatch = query.match(/i like\s+([^.]+)/i);
  if (likeMatch) {
    preferences.likes = likeMatch[1].split(',').map(s => s.trim());
  }
  
  // Extract dislikes
  const dislikeMatch = query.match(/(?:i don'?t like|dislike)\s+([^.]+)/i);
  if (dislikeMatch) {
    preferences.dislikes = dislikeMatch[1].split(',').map(s => s.trim());
  }
  
  // Extract dietary restrictions
  const restrictionKeywords = ['vegetarian', 'vegan', 'gluten-free', 'dairy-free', 'keto', 'paleo'];
  for (const keyword of restrictionKeywords) {
    if (new RegExp(keyword, 'i').test(query)) {
      preferences.restrictions.push(keyword);
    }
  }
  
  return preferences;
}

// Helper: Extract vision board data from response
function extractVisionBoardData(response, query) {
  const data = {
    title: null,
    goals: [],
    affirmations: [],
    description: null,
    theme: 'general'
  };
  
  // Extract title (first line or from query)
  const titleMatch = response.match(/^(?:title|vision board):\s*(.+)/im) || 
                     response.match(/^([A-Z][^.!?\n]{3,50})/);
  if (titleMatch) {
    data.title = titleMatch[1].trim();
  } else {
    // Extract from query
    const queryTitle = query.match(/(?:vision board|dream board|goal board)\s+(?:for|about)?\s*(.+)/i);
    if (queryTitle) {
      data.title = queryTitle[1].trim();
    }
  }
  
  // Extract goals (look for numbered lists, bullet points, or "goals:" patterns)
  const goalPatterns = [
    /(?:goals?|objectives?):\s*\n([\s\S]*?)(?:\n\n|\n[A-Z]|$)/i,
    /\d+\.\s*([A-Z][^.!?\n]{10,100})/g,
    /[-•*]\s*([A-Z][^.!?\n]{10,100})/g
  ];
  
  for (const pattern of goalPatterns) {
    const matches = response.matchAll(pattern);
    for (const match of matches) {
      const goal = match[1]?.trim();
      if (goal && goal.length > 10 && goal.length < 200) {
        data.goals.push(goal);
      }
    }
  }
  
  // Extract affirmations (look for "I am", "I will", etc.)
  const affirmationPattern = /(?:affirmation|mantra|i am|i will|i have|i attract)[^.!?\n]{10,150}/gi;
  const affirmationMatches = response.matchAll(affirmationPattern);
  for (const match of affirmationMatches) {
    const aff = match[0]?.trim();
    if (aff && aff.length > 10 && aff.length < 200) {
      data.affirmations.push(aff);
    }
  }
  
  // Extract theme from query
  const themeKeywords = {
    career: /\b(career|job|work|professional|business)\b/i,
    health: /\b(health|fitness|wellness|body|physical)\b/i,
    relationships: /\b(relationship|love|family|friends|connection)\b/i,
    wealth: /\b(wealth|money|financial|abundance|prosperity)\b/i,
    travel: /\b(travel|adventure|journey|destination|trip)\b/i,
    personal: /\b(personal|growth|development|self|spiritual)\b/i
  };
  
  for (const [theme, pattern] of Object.entries(themeKeywords)) {
    if (pattern.test(query) || pattern.test(response)) {
      data.theme = theme;
      break;
    }
  }
  
  // Use full response as description if no goals extracted
  if (data.goals.length === 0) {
    data.description = response;
  }
  
  return data;
}

// Helper: Extract manifestation data from response
function extractManifestationData(response, query) {
  const data = {
    intention: null,
    steps: [],
    visualization: null,
    timeframe: 'ongoing',
    affirmations: []
  };
  
  // Extract intention (from query or first sentence of response)
  const intentionMatch = query.match(/(?:manifest|want|desire|attract|create)\s+(.+)/i);
  if (intentionMatch) {
    data.intention = intentionMatch[1].trim();
  } else {
    const firstSentence = response.split(/[.!?]/)[0];
    if (firstSentence && firstSentence.length > 10 && firstSentence.length < 200) {
      data.intention = firstSentence.trim();
    }
  }
  
  // Extract steps (look for numbered or bulleted lists)
  const stepPatterns = [
    /(?:steps?|actions?|practices?):\s*\n([\s\S]*?)(?:\n\n|\n[A-Z]|$)/i,
    /\d+\.\s*([A-Z][^.!?\n]{15,200})/g,
    /[-•*]\s*([A-Z][^.!?\n]{15,200})/g
  ];
  
  for (const pattern of stepPatterns) {
    const matches = response.matchAll(pattern);
    for (const match of matches) {
      const step = match[1]?.trim();
      if (step && step.length > 15 && step.length < 250) {
        data.steps.push(step);
      }
    }
  }
  
  // Extract visualization guidance (look for "visualize", "imagine", "picture")
  const visualizationPattern = /(?:visualize|imagine|picture|envision|see yourself)[^.!?\n]{20,300}/gi;
  const visualizationMatches = response.matchAll(visualizationPattern);
  const visualizations = Array.from(visualizationMatches).map(m => m[0]?.trim()).filter(Boolean);
  if (visualizations.length > 0) {
    data.visualization = visualizations[0];
  }
  
  // Extract timeframe
  const timeframeMatch = response.match(/(?:within|in|by)\s+(\d+\s*(?:days?|weeks?|months?|years?))/i);
  if (timeframeMatch) {
    data.timeframe = timeframeMatch[1].toLowerCase();
  }
  
  // Extract affirmations
  const affirmationPattern = /(?:i am|i will|i have|i attract|i deserve|i am worthy)[^.!?\n]{10,150}/gi;
  const affirmationMatches = response.matchAll(affirmationPattern);
  for (const match of affirmationMatches) {
    const aff = match[0]?.trim();
    if (aff && aff.length > 10 && aff.length < 200) {
      data.affirmations.push(aff);
    }
  }
  
  return data;
}

// Helper: Extract affirmation data from response
function extractAffirmationData(response, query) {
  const data = {
    affirmations: [],
    category: 'general',
    frequency: 'daily',
    description: null
  };
  
  // Extract affirmations (look for "I am", "I will", statements)
  const affirmationPatterns = [
    /(?:i am|i will|i have|i attract|i deserve|i am worthy|i choose|i believe)[^.!?\n]{10,150}/gi,
    /\d+\.\s*([A-Z][^.!?\n]{10,150})/g,
    /[-•*]\s*([A-Z][^.!?\n]{10,150})/g,
    /"([^"]{20,150})"/g
  ];
  
  for (const pattern of affirmationPatterns) {
    const matches = response.matchAll(pattern);
    for (const match of matches) {
      const aff = (match[1] || match[0])?.trim();
      if (aff && aff.length > 10 && aff.length < 200 && !data.affirmations.includes(aff)) {
        data.affirmations.push(aff);
      }
    }
  }
  
  // If no affirmations extracted, use response as single affirmation
  if (data.affirmations.length === 0) {
    const sentences = response.split(/[.!?]/).filter(s => s.trim().length > 15 && s.trim().length < 200);
    if (sentences.length > 0) {
      data.affirmations = sentences.slice(0, 5).map(s => s.trim());
    }
  }
  
  // Extract category from query
  const categoryKeywords = {
    confidence: /\b(confidence|self-esteem|believe in myself|worthy)\b/i,
    health: /\b(health|fitness|wellness|strong|vitality)\b/i,
    abundance: /\b(abundance|wealth|prosperity|money|financial)\b/i,
    love: /\b(love|relationships|connection|romance)\b/i,
    success: /\b(success|achievement|accomplish|excel)\b/i,
    peace: /\b(peace|calm|tranquil|serenity|inner peace)\b/i,
    growth: /\b(growth|development|learning|evolving|progress)\b/i
  };
  
  for (const [category, pattern] of Object.entries(categoryKeywords)) {
    if (pattern.test(query) || pattern.test(response)) {
      data.category = category;
      break;
    }
  }
  
  // Extract frequency
  const frequencyMatch = query.match(/(?:daily|weekly|morning|evening|before|after)\s+affirmation/i);
  if (frequencyMatch) {
    if (/daily|every day/i.test(frequencyMatch[0])) data.frequency = 'daily';
    else if (/weekly/i.test(frequencyMatch[0])) data.frequency = 'weekly';
    else if (/morning/i.test(frequencyMatch[0])) data.frequency = 'morning';
    else if (/evening/i.test(frequencyMatch[0])) data.frequency = 'evening';
  }
  
  // Use response as description if needed
  data.description = response.length < 500 ? response : response.substring(0, 500) + '...';
  
  return data;
}

// Helper: Extract story data from response
function extractStoryData(response, query, params) {
  const data = {
    title: null,
    story: null,
    theme: params.storyType || 'bedtime',
    audience: params.audience || 'adult',
    tone: params.tone || 'calming'
  };
  
  // Extract title (first line or from query)
  const titlePatterns = [
    /^(?:title|story):\s*(.+)/im,
    /^"([^"]{10,60})"/,
    /^([A-Z][^.!?\n]{10,60})/m
  ];
  
  for (const pattern of titlePatterns) {
    const match = response.match(pattern);
    if (match && match[1]) {
      data.title = match[1].trim();
      // Remove title from story if found at start
      if (response.startsWith(match[0])) {
        data.story = response.substring(match[0].length).trim();
      }
      break;
    }
  }
  
  // If no title extracted, try to extract from query
  if (!data.title) {
    const queryTitle = query.match(/(?:story|tale) (?:about|of|for) (.+)/i);
    if (queryTitle && queryTitle[1].length < 50) {
      data.title = queryTitle[1].trim();
    }
  }
  
  // Use full response as story if not split
  if (!data.story) {
    data.story = response;
  }
  
  // Clean up story (remove markdown, headers, etc.)
  data.story = data.story
    .replace(/^#+\s*/gm, '') // Remove markdown headers
    .replace(/\*\*(.+?)\*\*/g, '$1') // Remove bold
    .replace(/\*(.+?)\*/g, '$1') // Remove italic
    .replace(/^---+\s*$/gm, '') // Remove horizontal rules
    .trim();
  
  return data;
}

const handleDatabaseQuery = async (query, userId) => {
  // Parse intent and timeframe
  const intent = parseIntent(query);
  
  switch(intent.type) {
    case 'GET_PACE':
      return await getPace(userId, intent.timeframe);
    case 'GET_DISTANCE':
      return await getDistance(userId, intent.timeframe);
    case 'GET_LAST_ACTIVITY':
      return await getLastActivity(userId, intent.activityType);
    case 'GET_PR':
      return await getPersonalRecord(userId, intent.activityType, intent.metric);
    case 'GET_COUNT':
      return await getActivityCount(userId, intent.activityType, intent.timeframe);
    default:
      return null; // Fallback to AI
  }
};

const parseIntent = (query) => {
  const lowerQuery = query.toLowerCase();
  
  // Pace queries
  if (/pace/.test(lowerQuery)) {
    return {
      type: 'GET_PACE',
      timeframe: parseTimeframe(query)
    };
  }
  
  // Distance queries
  if (/distance|miles|km/.test(lowerQuery)) {
    return {
      type: 'GET_DISTANCE',
      timeframe: parseTimeframe(query)
    };
  }
  
  // Last activity
  if (/last|recent|latest/.test(lowerQuery)) {
    return {
      type: 'GET_LAST_ACTIVITY',
      activityType: parseActivityType(query)
    };
  }
  
  // PR queries
  if (/pr|personal record|best|fastest/.test(lowerQuery)) {
    return {
      type: 'GET_PR',
      activityType: parseActivityType(query),
      metric: parseMetric(query)
    };
  }
  
  // Count queries
  if (/how many/.test(lowerQuery)) {
    return {
      type: 'GET_COUNT',
      activityType: parseActivityType(query),
      timeframe: parseTimeframe(query)
    };
  }
  
  return { type: 'UNKNOWN' };
};

const parseTimeframe = (query) => {
  const lowerQuery = query.toLowerCase();
  const now = Date.now();
  
  if (/yesterday/.test(lowerQuery)) {
    return {
      start: now - 86400000 * 2,
      end: now - 86400000
    };
  }
  
  if (/today/.test(lowerQuery)) {
    const startOfDay = new Date().setHours(0, 0, 0, 0);
    return {
      start: startOfDay,
      end: now
    };
  }
  
  if (/this week/.test(lowerQuery)) {
    const startOfWeek = now - (new Date().getDay() * 86400000);
    return {
      start: startOfWeek,
      end: now
    };
  }
  
  if (/this month/.test(lowerQuery)) {
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1).getTime();
    return {
      start: startOfMonth,
      end: now
    };
  }
  
  // Default to last 7 days
  return {
    start: now - (7 * 86400000),
    end: now
  };
};

const parseActivityType = (query) => {
  const lowerQuery = query.toLowerCase();
  
  if (/run|running/.test(lowerQuery)) return 'runs';
  if (/bike|biking|cycling/.test(lowerQuery)) return 'bikes';
  if (/hike|hiking/.test(lowerQuery)) return 'hikes';
  if (/workout|strength/.test(lowerQuery)) return 'workouts';
  if (/swim|swimming/.test(lowerQuery)) return 'swims';
  
  return 'runs'; // Default
};

const parseMetric = (query) => {
  const lowerQuery = query.toLowerCase();
  
  if (/pace/.test(lowerQuery)) return 'avgPace';
  if (/distance/.test(lowerQuery)) return 'distance';
  if (/time|duration/.test(lowerQuery)) return 'duration';
  
  return 'distance'; // Default
};

const getPace = async (userId, timeframe) => {
  const params = {
    TableName: 'prod-runs',
    IndexName: 'user-time-index',
    KeyConditionExpression: 'userId = :userId AND startTime BETWEEN :start AND :end',
    ExpressionAttributeValues: {
      ':userId': userId,
      ':start': timeframe.start,
      ':end': timeframe.end
    },
    Limit: 1,
    ScanIndexForward: false
  };
  
  const result = await dynamodb.query(params).promise();
  
  if (result.Items.length === 0) {
    return "You don't have any runs for that timeframe.";
  }
  
  const run = result.Items[0];
  const pace = formatPace(run.avgPace);
  const distance = formatDistance(run.distance);
  const date = formatDate(run.startTime);
  
  return `Your pace on ${date} was ${pace} over ${distance}.`;
};

const getDistance = async (userId, timeframe) => {
  const params = {
    TableName: 'prod-runs',
    IndexName: 'user-time-index',
    KeyConditionExpression: 'userId = :userId AND startTime BETWEEN :start AND :end',
    ExpressionAttributeValues: {
      ':userId': userId,
      ':start': timeframe.start,
      ':end': timeframe.end
    }
  };
  
  const result = await dynamodb.query(params).promise();
  
  const totalDistance = result.Items.reduce((sum, item) => sum + (item.distance || 0), 0);
  const count = result.Items.length;
  
  return `You ran ${formatDistance(totalDistance)} across ${count} runs.`;
};

const getLastActivity = async (userId, activityType) => {
  try {
    const params = {
      TableName: `prod-${activityType}`,
      IndexName: 'user-time-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      Limit: 1,
      ScanIndexForward: false // Get most recent first
    };
    
    console.log(`[DB] Querying ${activityType} for user ${userId}`);
    const result = await dynamodb.query(params).promise();
    console.log(`[DB] Found ${result.Items.length} ${activityType}`);
    
    if (result.Items.length === 0) {
      return `You don't have any ${activityType} recorded yet. Start tracking your activities to see insights here!`;
    }
    
    const activity = result.Items[0];
    const date = formatDate(activity.startTime);
    const distance = formatDistance(activity.distance);
    const duration = formatDuration(activity.duration);
    const pace = activity.pace ? formatPace(activity.pace) : null;
    
    let response = `Your last ${activityType.slice(0, -1)} was on ${date}: ${distance} in ${duration}`;
    if (pace && activityType === 'runs') {
      response += ` at ${pace}/mi pace`;
    }
    if (activity.calories) {
      response += `. You burned ${activity.calories} calories`;
    }
    response += '.';
    
    return response;
  } catch (error) {
    console.error(`[DB ERROR] Failed to query ${activityType}:`, error);
    return null; // Fallback to AI
  }
};

const getPersonalRecord = async (userId, activityType, metric) => {
  try {
    const params = {
      TableName: `prod-${activityType}`,
      IndexName: 'user-time-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      }
    };
    
    console.log(`[DB] Querying PRs for ${activityType}, user ${userId}`);
    const result = await dynamodb.query(params).promise();
    
    if (result.Items.length === 0) {
      return `You don't have any ${activityType} recorded yet.`;
    }
    
    const best = result.Items.reduce((best, current) => {
      if (metric === 'pace') {
        return (current.pace && current.pace < best.pace) ? current : best;
      } else if (metric === 'distance') {
        return (current.distance && current.distance > best.distance) ? current : best;
      }
      return best;
    });
    
    const value = metric === 'pace' ? formatPace(best.pace) : formatDistance(best.distance);
    const date = formatDate(best.startTime);
    
    return `Your PR for ${activityType} is ${value}, set on ${date}.`;
  } catch (error) {
    console.error(`[DB ERROR] Failed to get PR:`, error);
    return null;
  }
};

const getActivityCount = async (userId, activityType, timeframe) => {
  const params = {
    TableName: `prod-${activityType}`,
    IndexName: 'user-time-index',
    KeyConditionExpression: 'userId = :userId AND startTime BETWEEN :start AND :end',
    ExpressionAttributeValues: {
      ':userId': userId,
      ':start': timeframe.start,
      ':end': timeframe.end
    }
  };
  
  const result = await dynamodb.query(params).promise();
  
  return `You have ${result.Items.length} ${activityType} in that timeframe.`;
};

// Formatting helpers
const formatPaceFromSeconds = (seconds) => {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, '0')}/mile`;
};

const formatDistance = (meters) => {
  const miles = meters / 1609.34;
  return `${miles.toFixed(2)} miles`;
};

const formatDuration = (seconds) => {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? `${hours}h ${mins}m` : `${mins}m`;
};

const formatDate = (timestamp) => {
  return new Date(timestamp).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  });
};

// Main handler
exports.handler = async (event) => {
  const startTime = Date.now();
  const thinking = []; // Initialize thinking trace
  
  // Log environment setup for debugging
  // Note: AWS_REGION is automatically set by Lambda runtime
  console.log('[Lambda] Environment check:', {
    region: process.env.AWS_REGION || AWS.config.region || 'us-east-1',  // AWS_REGION is auto-set by Lambda
    meditationBucket: process.env.MEDITATION_AUDIO_BUCKET ? 'set' : 'missing',
    bedrockAgentId: process.env.BEDROCK_AGENT_ID ? 'set' : 'missing',
    nodeVersion: process.version
  });
  
  try {
    // DEBUG ENDPOINT: Return raw user context (FACTS) for inspection
    if (event.path === '/debug' || event.rawPath === '/debug') {
      const cognitoUserId = getUserId(event);
      const userId = await getAppUserId(cognitoUserId);
      console.log(`[Debug] Cognito ID: ${cognitoUserId}, App ID: ${userId}`);
      const userContext = await getUserContext(userId);
      
      // Build the same FACTS JSON that would be sent to the AI
      const factsJSON = {
        user: {
          name: userContext.name,
          goals: userContext.goals,
          streak_days: userContext.streak
        },
        last_workout: userContext.lastWorkout || null,
        patterns: {
          weekly_mileage: userContext.patterns.weeklyMileage,
          avg_pace: userContext.patterns.avgPace,
          workouts_this_week: userContext.patterns.workoutsThisWeek,
          consistency: userContext.patterns.consistency,
          needs_recovery: userContext.patterns.needsRecovery
        },
        recent_runs: userContext.recentRuns.map(r => ({
          distance_mi: r.distance,
          pace: r.pace,
          date: new Date(r.date).toISOString()
        })),
        recent_bikes: userContext.recentBikes.map(b => ({
          distance_mi: b.distance,
          speed_mph: b.speed,
          date: new Date(b.date).toISOString()
        })),
        meditation_sessions: userContext.meditation.length
      };
      
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          timestamp: new Date().toISOString(),
          facts: factsJSON,
          metadata: {
            runs_count: userContext.recentRuns.length,
            bikes_count: userContext.recentBikes.length,
            meditation_count: userContext.meditation.length,
            has_stats: !!userContext.patterns.weeklyMileage && userContext.patterns.weeklyMileage !== '0'
          }
        }, null, 2)
      };
    }
    
    // Extract userId from JWT token (Cognito sub) - use exactly like token-management does
    // The subscription/token system saves and reads using Cognito sub directly as userId
    const userId = getUserId(event);
    console.log(`[Auth] User ID (Cognito sub, used directly as userId like token-management): ${userId}`);
    thinking.push(`userId=${userId}`);
    
    // Parse request body - handle both text and image queries
    const requestBody = JSON.parse(event.body);
    const query = requestBody.query;
    const sessionId = requestBody.sessionId;
    
    // Log sessionId immediately for debugging
    console.log(`[SessionID] Received sessionId: "${sessionId}"`);
    const imageBase64 = requestBody.image || null; // Image in base64 format
    const clientTimestamp = requestBody.timestamp || null; // Client-provided timestamp
    const locale = requestBody.locale || null; // Client-provided locale/timezone
    const isVoiceInput = requestBody.isVoiceInput || false; // Flag for voice input
    const latitude = requestBody.latitude || null; // User's location latitude
    const longitude = requestBody.longitude || null; // User's location longitude
    
    console.log(`[QUERY] User: ${userId}, Query: "${query}"`);
    console.log(`[SECURITY] Using Cognito sub as userId (same as token-management): ${userId}`);
    if (imageBase64) {
      console.log(`[QUERY] Image provided: ${imageBase64.length} bytes`);
    }
    if (clientTimestamp) {
      console.log(`[QUERY] Client timestamp: ${clientTimestamp}, Locale: ${locale || 'not provided'}`);
    }
    if (isVoiceInput) {
      console.log(`[QUERY] Voice input detected`);
    }
    
    // Detect action intents (meditation, equipment recognition, etc.)
    const intent = detectActionIntent(query, !!imageBase64);
    if (intent) {
      console.log(`[INTENT] ✅ Detected action: ${intent.action}`, JSON.stringify(intent.params));
      thinking.push(`intent:${intent.action}`);
    } else {
      console.log(`[INTENT] ❌ No action intent detected for query: "${query.substring(0, 100)}"`);
    }
    
    // For meditation queries, set duration if not specified (will use user preference later if available)
    if (intent && intent.action === 'meditation' && !intent.params.duration) {
      // Temporarily set to 10 for classification, will update with user preference later
      intent.params.duration = 10;
      console.log(`[Meditation] No duration specified in query, will check user preference later`);
    }
    
    // Classify query (pass intent for meditation duration-based pricing)
    classification = classifyQuery(query, intent);
    thinking.push(`handler:${classification.handler}`);
    thinking.push(`tier:${classification.tier}`);
    console.log(`[CLASSIFICATION] Tier: ${classification.tier}, Handler: ${classification.handler}, Tokens: ${classification.tokens || classification.baseTokens || 0}`);
    
    // Check token balance - use Cognito sub as userId (same as balance endpoint)
    console.log(`[TokenCheck] Checking balance for userId: "${userId}" (Cognito sub)`);
    tokenBalance = await getTokenBalance(userId);
    const requiredTokens = classification.tokens || classification.baseTokens || 0;
    console.log(`[TokenCheck] Balance result: ${tokenBalance}, required: ${requiredTokens}`);
    thinking.push(`tokens: balance=${tokenBalance}, cost=${requiredTokens}`);
    
    if (requiredTokens > 0 && tokenBalance < requiredTokens) {
      console.log(`[TokenCheck] ❌ Insufficient tokens - balance: ${tokenBalance}, required: ${requiredTokens}`);
      // Get user's subscription status to provide personalized upsell
      const hasSubscription = tokenBalance > 0; // Simple heuristic for now
      
      return {
        statusCode: 402,
        body: JSON.stringify({
          error: 'Insufficient tokens',
          required: requiredTokens,
          balance: tokenBalance,
          queryType: classification.handler,
          tier: classification.tier,
          upsell: {
            hasSubscription,
            message: hasSubscription 
              ? `You need ${requiredTokens} more tokens for this ${classification.handler === 'agent' ? 'advanced' : ''} query.`
              : `This query requires ${requiredTokens} tokens to unlock AI-powered insights.`,
            recommendation: hasSubscription
              ? 'token_pack'  // Recommend one-time purchase
              : 'subscription',  // Recommend monthly subscription
            tokenPacks: [
              { id: 'quickBoost', name: 'Quick Boost', tokens: 100, bonus: 0, price: 499, popular: false },
              { id: 'powerPack', name: 'Power Pack', tokens: 300, bonus: 50, price: 999, popular: true },
              { id: 'proBundle', name: 'Pro Bundle', tokens: 700, bonus: 150, price: 1999, popular: false }
            ],
            subscriptions: [
              { id: 'athlete', name: 'Athlete', tokens: 1200, price: 999, perDay: 40 },
              { id: 'champion', name: 'Champion', tokens: 3000, price: 1999, perDay: 100 },
              { id: 'legend', name: 'Legend', tokens: 10000, price: 4999, perDay: 333 }
            ]
          }
        })
      };
    }
    
    // Get user context for all AI queries
    thinking.push('context:fetch');
    const userContext = await getUserContext(userId);
    const contextUsed = {
      runs: userContext.recentRuns.length,
      bikes: userContext.recentBikes.length,
      meditation: userContext.meditation.length,
      hasStats: !!userContext.patterns.weeklyMileage && userContext.patterns.weeklyMileage !== '0'
    };
    thinking.push(`context: runs=${contextUsed.runs}, bikes=${contextUsed.bikes}, meditation=${contextUsed.meditation}`);
    
    // 🆕 V3: Get conversation history from cache
    console.log(`[Conversation] Retrieving history for session: ${sessionId}`);
    let conversationHistory;
    if (needsFullContext(query, null)) {
      // User is asking about past conversations - fetch full history
      conversationHistory = await refreshFromDynamoDB(sessionId);
      thinking.push(`conversation:full_context_${conversationHistory.length}_turns`);
    } else {
      // Normal query - use cached conversation (last 10 turns)
      conversationHistory = await getCachedConversation(sessionId);
      thinking.push(`conversation:cached_${conversationHistory.length}_turns`);
    }
    console.log(`[Conversation] Retrieved ${conversationHistory.length} messages`);
    
    // 🆕 V3: Detect intent with conversation context
    const detectedIntent = detectConversationIntent(query, conversationHistory, userContext);
    console.log(`[Intent] Detected: ${detectedIntent.type} (${(detectedIntent.confidence * 100).toFixed(0)}% confidence)`, detectedIntent);
    thinking.push(`intent:${detectedIntent.type}`);
    if (detectedIntent.category) {
      thinking.push(`category:${detectedIntent.category}`);
    }
    
    // 🆕 V3: Get user profile
    const userProfile = await getUserProfile(userId);
    console.log(`[UserProfile] Profile completeness: ${userProfile.metadata.profileCompleteness}%`);
    thinking.push(`profile:${userProfile.metadata.profileCompleteness}%`);
    
    // Update meditation duration from user profile if not specified in query
    // Note: This happens after token balance check, so we'll adjust tokens later if needed
    if (intent && intent.action === 'meditation' && intent.params.duration === 10) {
      // Only update if it was the default 10 (not explicitly requested)
      if (userProfile && userProfile.meditation && userProfile.meditation.preferredDuration) {
        intent.params.duration = userProfile.meditation.preferredDuration;
        console.log(`[Meditation] Updated duration from user preference: ${intent.params.duration} min`);
        // Re-classify with updated duration for accurate token pricing
        const updatedClassification = classifyQuery(query, intent);
        thinking.push(`meditation: duration updated to ${intent.params.duration} min, tokens: ${updatedClassification.tokens}`);
        // Update classification and required tokens
        classification = updatedClassification;
        console.log(`[Meditation] Token cost updated: ${classification.tokens} tokens for ${intent.params.duration} min meditation`);
      }
    }
    
    // 🆕 V3: Add user query to cache (saves to DynamoDB async)
    await addTurnToCache(sessionId, userId, 'user', query, detectedIntent, {
      timestamp: Date.now(),
      clientTimestamp: clientTimestamp,
      isVoiceInput: isVoiceInput
    });
    
    // Detect mood: combine message sentiment + activity patterns
    thinking.push('mood:detecting');
    const messageSentiment = detectMessageSentiment(query);
    const activityMood = analyzeActivityMood(userContext);
    
    // Combine sentiment and activity patterns
    let detectedMood = {
      mood: 'neutral',
      confidence: 0.5,
      insights: [],
      source: 'combined'
    };
    
    // If message sentiment is strong, use it; otherwise use activity patterns
    if (messageSentiment.confidence > 0.7) {
      detectedMood = {
        mood: messageSentiment.mood,
        confidence: messageSentiment.confidence,
        insights: [`Message tone indicates ${messageSentiment.mood} mood`],
        source: 'message_sentiment'
      };
    } else if (activityMood.confidence > 0.3) {
      detectedMood = {
        mood: activityMood.mood,
        confidence: activityMood.confidence,
        insights: activityMood.insights,
        source: 'activity_patterns'
      };
    }
    
    if (messageSentiment.confidence > 0.5 || activityMood.confidence > 0.3) {
      thinking.push(`mood:${detectedMood.mood} (${detectedMood.source}, confidence: ${(detectedMood.confidence * 100).toFixed(0)}%)`);
      console.log(`[MOOD] Detected: ${detectedMood.mood} (${detectedMood.confidence * 100}% confidence) - ${detectedMood.source}`);
    }
    
    // Infer time of day from context
    thinking.push('time:inferring');
    const timeContext = inferTimeOfDay(clientTimestamp, locale, query, userContext);
    thinking.push(`time:${timeContext}`);
    console.log(`[TIME] Inferred context: ${timeContext}`);
    
    let response;
    let actualTokensUsed = classification.tokens || classification.baseTokens || 5;
    
    if (classification.handler === 'ai') {
      thinking.push('query:ai');
      thinking.push(`model:${classification.model}`);
      // 🆕 V3: Handle with AI model - pass conversation intelligence parameters
      response = await invokeBedrockModel(query, userId, classification.model, sessionId, userContext, imageBase64, intent, detectedMood, timeContext, isVoiceInput, conversationHistory, detectedIntent, userProfile);
    } else if (classification.handler === 'agent') {
      thinking.push('query:agent');
      // Handle with Bedrock Agent (complex multi-step queries)
      // Add null checks and fallback to environment variables
      const agentId = classification.agentId || process.env.BEDROCK_AGENT_ID;
      const agentAliasId = classification.agentAliasId || process.env.BEDROCK_AGENT_ALIAS_ID;
      
      if (!agentId || !agentAliasId) {
        console.error(`[AGENT] Missing agent configuration - agentId: ${agentId}, agentAliasId: ${agentAliasId}`);
        throw new Error('Bedrock Agent not configured - missing agentId or agentAliasId');
      }
      
      const agentResult = await invokeBedrockAgent(
        query, 
        userId, 
        agentId, 
        agentAliasId,
        sessionId,
        userContext
      );
      
      // Add null check for agentResult
      if (!agentResult) {
        throw new Error('Bedrock Agent returned null result');
      }
      
      response = agentResult.response || '';
      // Calculate actual tokens based on agent usage with null safety
      const inputTokens = agentResult.inputTokens || 0;
      const outputTokens = agentResult.outputTokens || 0;
      actualTokensUsed = (classification.baseTokens || 0) + Math.ceil(inputTokens / 1000) + Math.ceil(outputTokens / 1000);
      thinking.push(`agent: input=${inputTokens}, output=${outputTokens}, total=${actualTokensUsed}`);
      console.log(`[AGENT] Base: ${classification.baseTokens || 0}, Input: ${inputTokens}, Output: ${outputTokens}, Total: ${actualTokensUsed}`);
    }
    
    // Deduct tokens for all queries
    thinking.push('tokens:deduct');
    // Deduct tokens using app user ID (DynamoDB key), not Cognito ID
    await deductTokens(userId, actualTokensUsed);
    
    // Log usage - use app user ID for activity tracking
    await logUsage(userId, {
      query,
      tier: classification.tier,
      tokens: actualTokensUsed,
      cost: classification.cost,
      handler: classification.handler,
      timestamp: Date.now()
    });
    
    // CRITICAL FIX: Fetch fresh balance after deduction instead of calculating from stale data
    // This ensures tokensRemaining matches what the balance endpoint returns
    const remainingTokens = await getTokenBalance(userId);
    console.log(`[TokenBalance] After deduction: ${remainingTokens} tokens remaining (fetched from database)`);
    
    // Calculate low balance warning
    let balanceWarning = null;
    if (remainingTokens <= 10 && remainingTokens > 0) {
      balanceWarning = {
        level: 'low',
        message: `You have ${remainingTokens} tokens left. Consider topping up to continue using AI features.`,
        recommendation: 'token_pack',
        suggestedPack: 'powerPack'
      };
    } else if (remainingTokens <= 0) {
      balanceWarning = {
        level: 'critical',
        message: 'You\'re out of tokens! Database queries are still free, but you\'ll need tokens for AI insights.',
        recommendation: 'subscription',
        suggestedPlan: 'athlete'
      };
    } else if (remainingTokens <= 50) {
      balanceWarning = {
        level: 'medium',
        message: `${remainingTokens} tokens remaining. You're doing great! Top up anytime to keep the momentum.`,
        recommendation: null
      };
    }
    
    // Process actions based on detected intents and AI response
    const actions = [];
    
    if (intent) {
      switch (intent.action) {
        case 'meditation':
          // Duration should already be set from earlier (user preference or extracted)
          const meditationDuration = intent.params.duration || 10;
          
          // Add thinking step: meditation intent detected
          thinking.push(`meditation: intent detected (${meditationDuration} min, ${intent.params.focus})`);
          thinking.push(`meditation: looking up user profile...`);
          
          // Meditation intent detected - replace response with friendly message
          const focusMessages = {
            'stress': 'Let me help you relax and release tension.',
            'anxiety': 'I\'ll guide you through a calming meditation to ease your anxiety.',
            'sleep': 'Let me help you drift into a peaceful sleep.',
            'rest': 'I\'ll guide you through a restful meditation.',
            'focus': 'Let me help you find clarity and concentration.',
            'concentration': 'I\'ll guide you through a focused meditation.',
            'energy': 'Let me help you recharge and energize your body.',
            'motivation': 'I\'ll guide you through an inspiring meditation to boost your motivation.',
            'gratitude': 'Let me guide you through a gratitude meditation.'
          };
          
          const friendlyMessage = focusMessages[intent.params.focus] || 
            intent.params.isMotivation ? 
            'I\'ll guide you through an inspiring meditation to boost your motivation.' :
            'Let me guide you through a peaceful meditation.';
          
          // Add thinking step: meditation script generated
          thinking.push(`meditation: script generated (${Math.ceil(response.length / 100)} segments)`);
          
          // Clean the script: remove markdown, section headers, and normalize pauses
          // Do this BEFORE replacing response with friendly message
          const originalScript = response;
          const cleanScript = cleanMeditationScript(originalScript);
          
          // Add thinking step: cleaning script
          thinking.push(`meditation: script cleaned (${cleanScript.length} chars)`);
          
          // Generate audio with Amazon Polly (PRIMARY - not fallback!)
          let audioData = null;
          try {
            thinking.push(`meditation: generating audio with Amazon Polly...`);
            console.log(`[ACTION] 🎙️ Attempting to generate Polly audio for meditation (PRIMARY method)`);
            console.log(`[ACTION] Script length: ${cleanScript.length} chars, focus: ${intent.params.focus}`);
            audioData = await generateMeditationAudio(cleanScript, intent.params.focus);
            if (audioData && audioData.audioUrl) {
              thinking.push(`meditation: audio generated successfully (${audioData.duration}s, saved to S3)`);
              console.log(`[ACTION] ✅ Polly audio generated successfully (PRIMARY)`);
              console.log(`[ACTION] Audio URL: ${audioData.audioUrl.substring(0, 100)}...`);
              console.log(`[ACTION] Audio filename: ${audioData.filename}`);
              console.log(`[ACTION] Estimated duration: ${audioData.duration}s`);
            } else {
              thinking.push(`meditation: audio generation failed, using TTS fallback`);
              console.error(`[ACTION] ❌ Polly audio generation returned null/undefined`);
              console.error(`[ACTION] ⚠️ iOS will fall back to TTS (lower quality)`);
              console.error(`[ACTION] This should not happen - Polly should always work`);
            }
          } catch (error) {
            thinking.push(`meditation: audio generation error (${error.message}), using TTS fallback`);
            console.error(`[ACTION] ❌ CRITICAL: Polly audio generation failed!`);
            console.error(`[ACTION] Error message: ${error.message}`);
            console.error(`[ACTION] Error code: ${error.code || 'N/A'}`);
            console.error(`[ACTION] Error stack:`, error.stack);
            console.error(`[ACTION] ⚠️ iOS will fall back to TTS, but Polly should be working!`);
            // Continue without audio - will use iOS TTS fallback
          }
          
          // Update response to friendly message for chat
          response = friendlyMessage;
          
          // Select appropriate ambient sound type based on focus, script content, and user query
          // This ensures the ambient sound matches what the script actually references
          const ambientSoundType = selectAmbientSoundType(
            intent.params.focus, 
            intent.params.isMotivation || false,
            cleanScript, // Use cleaned script to detect sound mentions
            query // Use original query to detect user preferences
          );
          
          // Meditation intent detected - add action to trigger meditation playback
          console.log(`[ACTION] 🧘 Creating meditation action with script length: ${cleanScript.length} chars`);
          
          // Map focus to display name
          const focusCategoryMap = {
            'stress': 'Stress Relief',
            'anxiety': 'Anxiety Relief',
            'sleep': 'Sleep',
            'rest': 'Rest',
            'focus': 'Focus',
            'concentration': 'Concentration',
            'energy': 'Energy',
            'motivation': 'Motivation',
            'gratitude': 'Gratitude',
            'performance': 'Performance',
            'healing': 'Healing',
            'habit_formation': 'Habit Formation',
            'morning_focus': 'Morning Focus',
            'pre_work': 'Pre-Work',
            'clarity': 'Mental Clarity',
            'intention_setting': 'Intention Setting',
            'recovery': 'Recovery'
          };
          const focusCategory = focusCategoryMap[intent.params.focus] || 'Stress Relief';
          
          const meditationAction = {
            type: 'meditation',
            data: {
              duration: intent.params.duration, // Use actual duration (not default 10)
              focus: intent.params.focus,
              focusCategory: focusCategory, // Add display category
              isMotivation: intent.params.isMotivation || false,
              script: cleanScript, // Clean script without markdown (fallback for TTS)
              playAudio: true,
              audioUrl: audioData?.audioUrl || null, // Polly audio URL if available
              audioDuration: audioData?.duration || null,
              audioFilename: audioData?.filename || null, // For cleanup later
              ambientSoundType: ambientSoundType // Agent-specified ambient sound selection
            }
          };
          actions.push(meditationAction);
          console.log(`[ACTION] ✅ Meditation action added: ${intent.params.duration} min, focus: ${focusCategory} (${intent.params.focus}), isMotivation: ${intent.params.isMotivation || false}, hasAudio: ${!!audioData}, ambientSound: ${ambientSoundType}`);
          console.log(`[ACTION] Action keys: ${Object.keys(meditationAction.data).join(', ')}`);
          break;
          
        case 'equipment_identification':
          // Extract equipment name from AI response
          const equipmentName = extractEquipmentName(response);
          actions.push({
            type: 'equipment_identified',
            data: {
              name: equipmentName || 'Unknown Equipment',
              description: response,
              category: categorizeEquipment(equipmentName || '')
            }
          });
          
          // If user requested videos, search for them
          if (intent.params.needsVideo && equipmentName) {
            try {
              const videos = await searchVideos(equipmentName, 5);
              actions.push({
                type: 'video_results',
                data: {
                  query: equipmentName,
                  videos: videos
                }
              });
              console.log(`[ACTION] Video search results: ${videos.length} videos`);
            } catch (error) {
              console.error('[ACTION] Video search error:', error);
            }
          }
          break;
          
        case 'nutrition_analysis':
          // Parse nutrition data from response
          const nutritionData = parseNutritionFromResponse(response);
          actions.push({
            type: 'nutrition_data',
            data: {
              calories: nutritionData.calories || 0,
              macros: nutritionData.macros || { protein: 0, carbs: 0, fat: 0 },
              foods: nutritionData.foods || [],
              analysis: response
            }
          });
          break;
          
        case 'video_search':
          // User requested video search
          try {
            const searchQuery = intent.params.query || query;
            const videos = await searchVideos(searchQuery, 5);
            actions.push({
              type: 'video_results',
              data: {
                query: searchQuery,
                videos: videos
              }
            });
            console.log(`[ACTION] Video search results: ${videos.length} videos for "${searchQuery}"`);
          } catch (error) {
            console.error('[ACTION] Video search error:', error);
          }
          break;
          
        case 'form_analysis':
          // Form check - add action for detailed feedback
          actions.push({
            type: 'form_feedback',
            data: {
              analysis: response,
              recommendations: extractRecommendations(response)
            }
          });
          break;
          
        case 'meal_plan_creation':
          // Extract meal plan from AI response (should be JSON matching FoodEntry structure)
          try {
            // Try to parse JSON meal plan from response
            const mealPlanMatch = response.match(/\{[\s\S]*"meals"[\s\S]*\}/);
            let mealPlanData = null;
            
            if (mealPlanMatch) {
              try {
                mealPlanData = JSON.parse(mealPlanMatch[0]);
              } catch (e) {
                // If JSON parsing fails, construct from text
                console.log('[ACTION] Could not parse meal plan JSON, constructing from text');
              }
            }
            
            // If no JSON found, construct meal plan structure from response text
            if (!mealPlanData) {
              mealPlanData = {
                duration: intent.params.duration || 7,
                meals: extractMealPlanFromText(response, intent.params.duration || 7)
              };
            }
            
            actions.push({
              type: 'meal_plan',
              data: {
                duration: intent.params.duration || 7,
                plan: mealPlanData,
                planText: response // Store original response for reference
              }
            });
            console.log(`[ACTION] Meal plan action added: ${intent.params.duration || 7} days`);
          } catch (error) {
            console.error('[ACTION] Meal plan parsing error:', error);
            // Still add action with text response
            actions.push({
              type: 'meal_plan',
              data: {
                duration: intent.params.duration || 7,
                planText: response
              }
            });
          }
          break;
          
        case 'fridge_contents_suggestions':
          // Extract ingredients and meal suggestions from response
          try {
            const suggestions = extractMealSuggestionsFromText(response);
            actions.push({
              type: 'meal_suggestions',
              data: {
                suggestions: suggestions,
                recipes: extractRecipesFromText(response),
                analysis: response
              }
            });
            console.log(`[ACTION] Meal suggestions action added: ${suggestions.length} suggestions`);
          } catch (error) {
            console.error('[ACTION] Meal suggestions error:', error);
            actions.push({
              type: 'meal_suggestions',
              data: {
                analysis: response
              }
            });
          }
          break;
          
        case 'restaurant_search':
          // Search restaurants (location provided from client if available)
          const hasLocation = latitude !== null && longitude !== null;
          actions.push({
            type: 'restaurant_search',
            data: {
              requiresLocation: !hasLocation,
              query: query,
              suggestions: extractRestaurantSuggestions(response),
              latitude: latitude,
              longitude: longitude
            }
          });
          console.log(`[ACTION] Restaurant search action added, has location: ${hasLocation}`);
          break;
          
        case 'food_preference_tracking':
          // Track preferences - update will be handled by backend
          actions.push({
            type: 'preferences_updated',
            data: {
              message: response,
              preferences: extractFoodPreferences(query)
            }
          });
          console.log(`[ACTION] Food preferences tracking action added`);
          break;
          
        case 'vision_board':
          // Vision board creation - extract goals, dreams, and visualizations
          const visionBoardData = extractVisionBoardData(response, query);
          actions.push({
            type: 'vision_board',
            data: {
              title: visionBoardData.title || 'My Vision Board',
              goals: visionBoardData.goals || [],
              affirmations: visionBoardData.affirmations || [],
              description: visionBoardData.description || response,
              theme: visionBoardData.theme || 'general'
            }
          });
          console.log(`[ACTION] Vision board action added: ${visionBoardData.goals?.length || 0} goals`);
          break;
          
        case 'manifestation':
          // Manifestation - extract desired outcomes and visualization guidance
          const manifestationData = extractManifestationData(response, query);
          actions.push({
            type: 'manifestation',
            data: {
              intention: manifestationData.intention || query,
              steps: manifestationData.steps || [],
              visualization: manifestationData.visualization || response,
              timeframe: manifestationData.timeframe || 'ongoing',
              affirmations: manifestationData.affirmations || []
            }
          });
          console.log(`[ACTION] Manifestation action added: "${manifestationData.intention}"`);
          break;
          
        case 'affirmation':
          // Affirmations - extract personalized affirmations
          const affirmationData = extractAffirmationData(response, query);
          actions.push({
            type: 'affirmation',
            data: {
              affirmations: affirmationData.affirmations || [response],
              category: affirmationData.category || 'general',
              frequency: affirmationData.frequency || 'daily',
              description: affirmationData.description || response
            }
          });
          console.log(`[ACTION] Affirmation action added: ${affirmationData.affirmations?.length || 0} affirmations`);
          break;
          
        case 'bedtime_story':
          // Bedtime story - extract story content and metadata
          const storyData = extractStoryData(response, query, intent.params);
          const storyDuration = intent.params.duration || 10;
          
          // Select appropriate ambient sound for story
          let storyAmbientType = 'rain'; // Default to rain for bedtime
          if (intent.params.tone === 'adventurous' || intent.params.storyType === 'adventure') {
            storyAmbientType = 'forest';
          } else if (intent.params.tone === 'magical' || intent.params.storyType === 'fantasy') {
            storyAmbientType = 'zen';
          } else if (intent.params.tone === 'calming' || intent.params.audience === 'kid') {
            storyAmbientType = 'rain';
          }
          
          actions.push({
            type: 'bedtime_story',
            data: {
              title: storyData.title || 'Bedtime Story',
              story: storyData.story || response,
              storyType: intent.params.storyType || 'bedtime',
              audience: intent.params.audience || 'adult',
              tone: intent.params.tone || 'calming',
              duration: storyDuration,
              playAudio: true,
              ambientSoundType: storyAmbientType
            }
          });
          console.log(`[ACTION] Bedtime story action added: "${storyData.title || 'Untitled'}", ${storyDuration} min, audience: ${intent.params.audience}, tone: ${intent.params.tone}`);
          break;
          
        case 'create_session':
          // Parse workout session from AI response
          try {
            const sessionData = extractWorkoutSession(response, query);
            
            // Ensure we have a name
            if (!sessionData.name || sessionData.name.length < 3) {
              sessionData.name = 'Workout Session';
            }
            
            // Ensure we have movements
            if (!sessionData.movements || sessionData.movements.length === 0) {
              console.log('[ACTION] ⚠️ No movements parsed from response');
              // Don't create action if no movements
              break;
            }
            
            actions.push({
              type: 'create_session',
              data: {
                name: sessionData.name,
                description: sessionData.description || `A ${sessionData.difficulty} workout session with ${sessionData.movements.length} exercises.`,
                difficulty: sessionData.difficulty,
                equipmentNeeded: sessionData.equipmentNeeded,
                tags: sessionData.tags || [],
                movements: sessionData.movements
              }
            });
            console.log(`[ACTION] ✅ Workout session action added: "${sessionData.name}" with ${sessionData.movements.length} movements`);
          } catch (error) {
            console.error('[ACTION] ❌ Workout session parsing error:', error);
            console.error('[ACTION] Error stack:', error.stack);
            // Don't create action on error
          }
          break;
      }
    }
    
    const duration = Date.now() - startTime;
    thinking.push(`done:${duration}ms`);
    
    // Generate a short title from the response for conversation naming
    // Extract first meaningful phrase (3-6 words) from response
    const generateTitle = (text) => {
      if (!text || text.length === 0) return null;
      
      // Remove markdown, URLs, and extra whitespace
      let clean = text
        .replace(/\[.*?\]/g, '') // Remove markdown links
        .replace(/\(.*?\)/g, '') // Remove parentheses
        .replace(/https?:\/\/[^\s]+/g, '') // Remove URLs
        .replace(/\*\*|__|~~/g, '') // Remove markdown bold/italic
        .replace(/\n+/g, ' ') // Replace newlines with space
        .trim();
      
      // Split into sentences and take first sentence
      const sentences = clean.split(/[.!?]+/).filter(s => s.trim().length > 0);
      if (sentences.length === 0) return null;
      
      const firstSentence = sentences[0].trim();
      
      // Extract first 3-6 words (max 40 characters)
      const words = firstSentence.split(/\s+/).filter(w => w.length > 0);
      let title = words.slice(0, 6).join(' ');
      
      // Truncate to 40 characters at word boundary
      if (title.length > 40) {
        const truncated = title.substring(0, 40);
        const lastSpace = truncated.lastIndexOf(' ');
        if (lastSpace > 20) {
          title = truncated.substring(0, lastSpace);
        } else {
          title = truncated;
        }
      }
      
      // Capitalize first letter
      if (title.length > 0) {
        title = title.charAt(0).toUpperCase() + title.slice(1);
      }
      
      return title.length > 0 ? title : null;
    };
    
    const conversationTitle = generateTitle(response);
    if (conversationTitle) {
      thinking.push(`title:${conversationTitle}`);
      console.log(`[RESPONSE] Generated conversation title: "${conversationTitle}"`);
    }
    
    // 🆕 V3: Extract action objects from AI response (workout sessions, meal plans, etc.)
    const extractActionsFromResponse = (responseText) => {
      const extractedActions = [];
      
      // Extract all JSON code blocks
      const jsonBlockRegex = /```json\s*\n?([\s\S]*?)\n?```/g;
      let match;
      
      while ((match = jsonBlockRegex.exec(responseText)) !== null) {
        try {
          const jsonStr = match[1].trim();
          const parsed = JSON.parse(jsonStr);
          
          // Detect action type based on JSON structure
          if (parsed.movements && Array.isArray(parsed.movements)) {
            // Workout session - iOS expects "create_session" type
            extractedActions.push({
              type: 'create_session',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted workout session: "${parsed.name}"`);
          } else if (parsed.movement1Name && !parsed.movements) {
            // Single movement - iOS expects "create_movement" type
            extractedActions.push({
              type: 'create_movement',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted movement: "${parsed.movement1Name}"`);
          } else if (parsed.sessions && typeof parsed.sessions === 'object') {
            // Workout plan - iOS expects "create_plan" type
            extractedActions.push({
              type: 'create_plan',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted workout plan: "${parsed.name}"`);
          } else if (parsed.meals && Array.isArray(parsed.meals)) {
            // Meal plan
            extractedActions.push({
              type: 'meal_plan',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted meal plan: "${parsed.name}"`);
          } else if (parsed.suggestions && Array.isArray(parsed.suggestions)) {
            // Meal suggestions / recipes
            extractedActions.push({
              type: 'meal_suggestions',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted meal suggestions: ${parsed.suggestions.length} items`);
          } else if (parsed.items && Array.isArray(parsed.items)) {
            // Grocery list
            extractedActions.push({
              type: 'grocery_list',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted grocery list`);
          } else if (parsed.recipes && Array.isArray(parsed.recipes)) {
            // Cookbook
            extractedActions.push({
              type: 'cookbook',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted cookbook: ${parsed.recipes.length} recipes`);
          } else if (parsed.goals && Array.isArray(parsed.goals)) {
            // Vision board
            extractedActions.push({
              type: 'vision_board',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted vision board`);
          } else if (parsed.text && parsed.category && !parsed.goals) {
            // Affirmation
            extractedActions.push({
              type: 'affirmation',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted affirmation: "${parsed.text.substring(0, 50)}..."`);
          } else if (parsed.story || (parsed.script && parsed.type === 'bedtime')) {
            // Bedtime story
            extractedActions.push({
              type: 'bedtime_story',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted bedtime story`);
          } else if (parsed.type === 'motivation' || parsed.motivationType) {
            // Motivation
            extractedActions.push({
              type: 'motivation',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted motivation content`);
          } else if (parsed.type === 'manifestation' || parsed.manifestation) {
            // Manifestation
            extractedActions.push({
              type: 'manifestation',
              data: parsed
            });
            console.log(`[ACTION] ✅ Extracted manifestation exercise`);
          }
        } catch (e) {
          console.error(`[ACTION] ⚠️ Failed to parse JSON block:`, e.message);
        }
      }
      
      return extractedActions;
    };
    
    // Extract and add actions from response
    const extractedActions = extractActionsFromResponse(response);
    if (extractedActions.length > 0) {
      actions.push(...extractedActions);
      thinking.push(`actions:extracted ${extractedActions.length} from response`);
    }
    
    // Log actions before returning
    if (actions.length > 0) {
      console.log(`[RESPONSE] ✅ Returning ${actions.length} action(s):`, actions.map(a => a.type).join(', '));
    } else {
      console.log(`[RESPONSE] ⚠️ No actions to return (intent was ${intent ? intent.action : 'null'})`);
    }
    
    // 🆕 V3: Save assistant response to cache and update profile
    if (response && sessionId) {
      // Save to cache
      await addTurnToCache(sessionId, userId, 'assistant', response, detectedIntent, {
        timestamp: Date.now(),
        tokensUsed: actualTokensUsed || 0,
        tier: classification.tier
      });
      console.log(`[Conversation] Saved assistant response to cache`);
      
      // Update user profile
      await updateProfileFromConversation(
        userId, 
        query, 
        response, 
        detectedIntent,
        {
          workoutCreated: response.includes('"movements"') || actions.some(a => a.type === 'workout_session'),
          meditationCreated: response.includes('"script"') || actions.some(a => a.type === 'meditation_audio'),
          mealPlanCreated: response.includes('"meals"') || actions.some(a => a.type === 'meal_plan')
        }
      );
      console.log(`[UserProfile] Updated profile from conversation`);
    }
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        response,
        tokensUsed: actualTokensUsed,
        tokensRemaining: remainingTokens,
        tier: classification.tier,
        handler: classification.handler,
        balanceWarning,
        thinking: thinking, // Include thinking trace
        contextUsed: contextUsed, // Include context usage
        actions: actions.length > 0 ? actions : undefined, // Include actions if any
        title: conversationTitle || undefined // Include title for conversation naming
      })
    };
    
  } catch (error) {
    thinking.push(`error:${error.message}`);
    console.error('[ERROR]', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: error.message,
        thinking: thinking // Include thinking trace even on error
      })
    };
  }
};

const invokeBedrockModel = async (query, userId, modelId, sessionId, userContext, imageBase64 = null, intent = null, detectedMood = null, timeContext = null, isVoiceInput = false, conversationHistory = [], detectedIntent = null, userProfile = null) => {
  // Detect if this is an analysis query (should return structured JSON)
  const analysisKeywords = ['analyze', 'analysis', 'compare', 'trend', 'progress', 'performance'];
  const isAnalysis = analysisKeywords.some(kw => query.toLowerCase().includes(kw));
  
  // For meditation, use a special system prompt that excludes workout details
  const isMeditation = intent && intent.action === 'meditation';
  
  // 🆕 V3: Build enhanced system prompt with conversation intelligence
  const systemPrompt = isMeditation 
    ? buildMeditationSystemPrompt(userContext, timeContext)
    : buildEnhancedSystemPrompt(userContext, conversationHistory, detectedIntent, isAnalysis, userProfile);
  
  // Adjust user prompt for voice input if needed
  let adjustedQuery = query;
  if (isVoiceInput) {
    // Voice queries might be more conversational - ensure proper formatting
    adjustedQuery = query.trim();
  }
  
    const userPrompt = isMeditation 
      ? buildUserPrompt(adjustedQuery, userContext, intent, timeContext, detectedMood)
      : buildUserPrompt(adjustedQuery, userContext, intent);
  
  console.log(`[Bedrock] Invoking ${modelId} for query: ${query.substring(0, 100)}...`);
  if (imageBase64) {
    console.log(`[Bedrock] Including image in request (${imageBase64.length} bytes)`);
  }
  if (detectedMood && detectedMood.mood !== 'neutral') {
    console.log(`[Bedrock] Mood context: ${detectedMood.mood} (${(detectedMood.confidence * 100).toFixed(0)}% confidence)`);
  }
  if (timeContext) {
    console.log(`[Bedrock] Time context: ${timeContext}`);
  }
  if (isVoiceInput) {
    console.log(`[Bedrock] Voice input - adjusting response style`);
  }
  
  try {
    // Build content array - start with text, add image if provided
    const userContent = [{ text: userPrompt }];
    
    // Add image if provided (Nova Pro supports vision!)
    if (imageBase64) {
      try {
        // Convert base64 to buffer
        const imageBuffer = Buffer.from(imageBase64, 'base64');
        
        userContent.push({
          image: {
            format: 'jpeg', // Assume JPEG (can detect PNG if needed)
            source: {
              bytes: imageBuffer
            }
          }
        });
        console.log(`[Bedrock] Image added to content (${imageBuffer.length} bytes)`);
      } catch (error) {
        console.error('[Bedrock] Error adding image:', error);
        // Continue without image if there's an error
      }
    }
    
    // Use Bedrock Converse API (works with all modern models including Nova)
    // Scale maxTokens based on meditation duration (roughly 150-200 words per minute)
    let maxTokens = 1000;
    if (isMeditation && classification.meditationDuration) {
      const duration = classification.meditationDuration;
      // Roughly 150-200 words per minute, ~5 chars per word = 750-1000 chars per minute
      // Add buffer for SSML tags and pauses
      maxTokens = Math.max(1500, Math.min(4000, duration * 200)); // 5min = 1000, 10min = 2000, 20min = 4000
      console.log(`[Bedrock] Meditation duration: ${duration} min → maxTokens: ${maxTokens}`);
    } else if (isMeditation) {
      maxTokens = 2000; // Default for meditations without duration
    }
    const params = {
      modelId,
      messages: [
        {
          role: 'user',
          content: userContent
        }
      ],
      system: [{ text: systemPrompt }],
      inferenceConfig: {
        maxTokens: maxTokens,
        temperature: isMeditation ? 0.9 : 0.7 // Higher temperature for more variety in meditations
      }
    };
    
    const response = await bedrock.converse(params).promise();
    let result = response.output.message.content[0].text;
  
  // If analysis was requested, try to extract JSON from response
  if (isAnalysis && result) {
    try {
      // Try to extract JSON if wrapped in markdown code blocks
      const jsonMatch = result.match(/```json\s*\n?([\s\S]*?)\n?```/);
      if (jsonMatch) {
        result = jsonMatch[1].trim();
      }
      // Validate it's parseable JSON
      JSON.parse(result);
      console.log('[Response] ✅ Structured JSON validated');
    } catch (e) {
      console.log('[Response] ⚠️ Expected JSON but got text, using as-is');
    }
  }
  
  return result;
  } catch (error) {
    console.error('[Bedrock] Error invoking model:', error);
    throw error;
  }
};

const buildPrompt = (query, userContext, requestStructured = false) => {
  const lastWorkoutText = userContext.lastWorkout ? 
    `Last workout: ${userContext.lastWorkout.type} - ${userContext.lastWorkout.distance}mi ${userContext.lastWorkout.pace ? `at ${formatPace(userContext.lastWorkout.pace)} pace` : `at ${userContext.lastWorkout.speed}mph`} (${new Date(userContext.lastWorkout.date).toLocaleDateString()})` :
    'No recent workouts';
  
  const streakText = userContext.streak > 0 ? `🔥 ${userContext.streak} day activity streak!` : '';
  
  // Build FACTS section with all verifiable data
  const factsJSON = {
    user: {
      name: userContext.name,
      goals: userContext.goals,
      streak_days: userContext.streak
    },
    last_workout: userContext.lastWorkout || null,
    patterns: {
      weekly_mileage: userContext.patterns.weeklyMileage,
      avg_pace: userContext.patterns.avgPace,
      workouts_this_week: userContext.patterns.workoutsThisWeek,
      consistency: userContext.patterns.consistency,
      needs_recovery: userContext.patterns.needsRecovery
    },
    recent_runs: userContext.recentRuns.map(r => ({
      distance_mi: r.distance,
      pace: r.pace,
      date: new Date(r.date).toISOString()
    })),
    recent_bikes: userContext.recentBikes.map(b => ({
      distance_mi: b.distance,
      speed_mph: b.speed,
      date: new Date(b.date).toISOString()
    })),
    meditation_sessions: userContext.meditation.length
  };
  
  return `You are Genie, ${userContext.name}'s deeply personal AI fitness coach and spiritual guide.

═══════════════════════════════════════════════════════════
🔒 CRITICAL INSTRUCTION - READ CAREFULLY:
═══════════════════════════════════════════════════════════

YOU MUST ONLY USE DATA FROM THE "VERIFIED FACTS" SECTION BELOW.

❌ NEVER invent or hallucinate:
- Workout data (dates, distances, paces, durations)
- Statistics or metrics not in FACTS
- User history or patterns not explicitly stated
- Goals or preferences not provided

✅ IF data is missing, SAY SO:
- "I don't have data on your cycling workouts yet"
- "Once you log more runs, I'll be able to analyze your pace trends"
- "I'd love to help with that, but I need more information about..."

🎯 YOUR ROLE:
- Be encouraging and motivational
- Provide coaching advice based on ACTUAL data
- Ask clarifying questions when context is insufficient
- Reference SPECIFIC workouts from FACTS (e.g., "Your 3.2 mile run on Oct 28th")
- Be honest about data limitations

💬 HOW TO ADDRESS ${userContext.name}:
- ALWAYS use ${userContext.name}'s actual name: "${userContext.name}"
- NEVER use generic terms like "athlete", "runner", "user", or other substitutes for their name
- Talk to ${userContext.name} naturally and personally, like a friend
- When addressing them directly, use their name naturally: "${userContext.name}" 
- Example: "Hey ${userContext.name}!" or "${userContext.name}, great job!" - NOT "Hey athlete!" or "Great job, runner!"

═══════════════════════════════════════════════════════════
📊 VERIFIED FACTS (GROUND ALL RESPONSES IN THIS DATA):
═══════════════════════════════════════════════════════════

${JSON.stringify(factsJSON, null, 2)}

═══════════════════════════════════════════════════════════

CONTEXTUAL SUMMARY (derived from FACTS above):
- ${streakText}
- ${lastWorkoutText}
- Training Pattern: ${userContext.patterns.weeklyMileage}mi/week, ${userContext.patterns.workoutsThisWeek} workouts this week
- Consistency: ${userContext.patterns.consistency}
- Recovery Status: ${userContext.patterns.needsRecovery ? '⚠️ NEEDS REST - High training load' : '✅ Good to train'}

COACHING APPROACH:
- Reference SPECIFIC workouts from FACTS (dates, distances, paces)
- If ${userContext.name} asks about data you don't have, acknowledge it honestly
- Provide actionable advice with exact numbers when you have the data
- Be proactive about recovery if patterns.needs_recovery = true
- Motivate based on actual achievements in FACTS

USER QUERY: ${query}

${requestStructured ? `
═══════════════════════════════════════════════════════════
📋 RESPONSE FORMAT (REQUIRED FOR ANALYSES):
═══════════════════════════════════════════════════════════

You MUST respond with valid JSON in this exact structure:

{
  "summary": "Brief 1-2 sentence overview",
  "analysis": {
    "performance": "Detailed performance insights based on FACTS",
    "patterns": "Observed patterns from recent workouts",
    "recovery": "Recovery status and recommendations"
  },
  "recommendations": [
    {"type": "immediate", "action": "Specific actionable advice"},
    {"type": "weekly", "action": "Weekly training suggestions"}
  ],
  "insights": [
    "Key insight 1 from data",
    "Key insight 2 from data"
  ],
  "data_used": {
    "runs_analyzed": 0,
    "date_range": "Oct 1 - Oct 30",
    "total_distance": "0 mi"
  }
}

CRITICAL: Return ONLY valid JSON. No markdown, no code blocks, no extra text.
═══════════════════════════════════════════════════════════
` : ''}

═══════════════════════════════════════════════════════════
📝 RESPONSE FORMATTING:
═══════════════════════════════════════════════════════════

**MARKDOWN FORMATTING - USE PROPERLY:**
- You CAN use markdown formatting for better readability
- Use **bold** for emphasis when helpful
- Use proper markdown lists for structured information:
  * Numbered lists: Use "1. " format (with space after number and each item on its own line)
  * Bullet lists: Use "- " or "* " format (with space after and each item on its own line)
  * Leave a blank line before lists for proper rendering
- Example of proper numbered list:
  
  1. First item
  2. Second item
  3. Third item

- Example of proper bullet list:
  
  - First item
  - Second item
  - Third item

- When creating workout sessions, providing instructions, or giving structured information, use lists to make it clear and readable
- The UI will render markdown lists properly, so format them correctly
- Don't use plain text like "1. do this 2. do that" - use proper markdown list syntax with line breaks between items

═══════════════════════════════════════════════════════════
💪 WORKOUT SESSION CREATION (CRITICAL):
═══════════════════════════════════════════════════════════

When a user requests a workout session, you MUST include structured JSON in your response. The system will parse this to create the session.

**REQUIRED FORMAT:**
Include a JSON block in your response with this exact structure:

\`\`\`json
{
  "name": "Session Name (e.g., 'Leg Day: Knee Strengthening')",
  "description": "Brief description of the session",
  "difficulty": "beginner" | "intermediate" | "advanced",
  "equipmentNeeded": true | false,
  "tags": ["tag1", "tag2"],
  "movements": [
    {
      "movement1Name": "Exercise Name",
      "movement2Name": null,
      "isSingle": true,
      "isTimed": false,
      "category": "Strength" | "Cardio" | "Flexibility" | null,
      "difficulty": "beginner" | "intermediate" | "advanced",
      "description": null,
      "firstSectionSets": [
        {
          "weight": null,
          "reps": "10",
          "sec": null,
          "isTimed": false
        }
      ]
    }
  ]
}
\`\`\`

**CRITICAL RULES:**
1. **Session name**: Should be clear and descriptive (e.g., "Leg Day: Knee Strengthening", NOT the user's query)
2. **Description**: Brief overview, NOT the full response text
3. **Movements**: Only include actual exercises, NOT:
   - Headers (Warm-Up, Main Workout, Cool Down)
   - Equipment lists
   - Tips or advice
   - Duration/frequency info
   - Section titles
4. **Sets**: Each movement must have firstSectionSets with proper structure
5. **isTimed**: true for time-based exercises (planks, holds), false for rep-based
6. **reps/sec**: Use "reps" field for rep-based, "sec" field for time-based (in seconds as string)

**EXAMPLE:**
User: "Create a leg day session"
Your response should include:
- Friendly text response explaining the session
- JSON block with structured data

Respond as ${userContext.name}'s trusted coach. Use ONLY the VERIFIED FACTS above. Be honest about data gaps.

CRITICAL: Always address ${userContext.name} by their actual name "${userContext.name}" - NEVER use "athlete", "runner", or other generic terms.`;
};

// Split the prompt for OpenAI chat completion format
// Mood Detection Functions
// Real-time sentiment analysis from message tone
function detectMessageSentiment(query) {
  const lower = query.toLowerCase();
  const positiveIndicators = ['great', 'good', 'happy', 'excited', 'proud', 'amazing', 'thank', 'love', 'awesome'];
  const negativeIndicators = ['stressed', 'frustrated', 'tired', 'struggling', 'hard', 'difficult', 'can\'t', 'unable', 'stuck', 'failing', 'bad', 'worse', 'worried', 'anxious', 'scared'];
  const neutralIndicators = ['ok', 'fine', 'alright', 'whatever', 'meh'];
  
  let positiveScore = positiveIndicators.filter(word => lower.includes(word)).length;
  let negativeScore = negativeIndicators.filter(word => lower.includes(word)).length;
  let neutralScore = neutralIndicators.filter(word => lower.includes(word)).length;
  
  // Check for emotional phrases
  if (/i feel (great|good|amazing|happy|excited|proud)/i.test(query)) positiveScore += 2;
  if (/i feel (bad|sad|tired|stressed|anxious|frustrated)/i.test(query)) negativeScore += 2;
  if (/i'm (struggling|stuck|failing|having trouble)/i.test(query)) negativeScore += 2;
  if (/(still|again|as usual|never|can't seem)/i.test(query)) negativeScore += 1; // Frustration indicators
  
  if (negativeScore > positiveScore && negativeScore > 0) return { mood: 'stressed', confidence: Math.min(0.9, 0.5 + (negativeScore * 0.1)) };
  if (positiveScore > negativeScore && positiveScore > 0) return { mood: 'positive', confidence: Math.min(0.9, 0.5 + (positiveScore * 0.1)) };
  if (neutralScore > 0 && negativeScore === 0 && positiveScore === 0) return { mood: 'neutral', confidence: 0.6 };
  
  return { mood: 'neutral', confidence: 0.5 };
}

// Activity pattern analysis for mood inference
function analyzeActivityMood(userContext) {
  const insights = [];
  const moodFactors = {
    stress: 0,
    motivation: 0,
    fatigue: 0,
    demotivation: 0
  };
  
  // Check for missed workouts (stress/fatigue indicator)
  const now = Date.now();
  const weekAgo = now - (7 * 86400000);
  const recentActivities = [...(userContext.recentRuns || []), ...(userContext.recentBikes || [])];
  const recentCount = recentActivities.filter(a => new Date(a.date).getTime() >= weekAgo).length;
  
  // If user had consistent activity before but now missing - potential stress
  if (userContext.streak > 5 && recentCount < 3) {
    moodFactors.stress += 0.3;
    moodFactors.fatigue += 0.2;
    insights.push('Recent activity decline - may indicate stress or fatigue');
  }
  
  // Declining performance - frustration indicator
  if (userContext.recentRuns && userContext.recentRuns.length >= 3) {
    const paces = userContext.recentRuns.slice(0, 3).map(r => r.pace).filter(p => p > 0);
    if (paces.length >= 3) {
      const recentPace = paces[0];
      const olderPace = paces[paces.length - 1];
      if (recentPace > olderPace * 1.1) { // Pace got slower (higher number)
        moodFactors.stress += 0.2;
        insights.push('Declining pace pattern - may indicate frustration or overtraining');
      }
    }
  }
  
  // Consistent streaks - motivation indicator
  if (userContext.streak >= 7) {
    moodFactors.motivation += 0.4;
    insights.push('Strong consistency streak - high motivation');
  } else if (userContext.streak >= 3) {
    moodFactors.motivation += 0.2;
    insights.push('Building consistency - positive momentum');
  }
  
  // Long gaps - demotivation indicator
  if (recentActivities.length > 0) {
    const lastActivity = recentActivities[0];
    const daysSinceLastActivity = (now - new Date(lastActivity.date).getTime()) / (86400000);
    if (daysSinceLastActivity > 7 && userContext.streak === 0) {
      moodFactors.demotivation += 0.3;
      insights.push('Extended inactivity - may indicate demotivation');
    }
  }
  
  // Determine primary mood from factors
  let primaryMood = 'neutral';
  let maxFactor = 0;
  for (const [mood, value] of Object.entries(moodFactors)) {
    if (value > maxFactor) {
      maxFactor = value;
      primaryMood = mood;
    }
  }
  
  return {
    mood: primaryMood,
    confidence: Math.min(0.9, maxFactor),
    insights: insights,
    factors: moodFactors
  };
}

// Infer time of day from context (locale, timestamp, message context)
function inferTimeOfDay(timestamp, locale, query, userContext) {
  // Check message for explicit time context first (most reliable)
  const lowerQuery = query.toLowerCase();
  if (/\b(morning|good morning|am|early)\b/i.test(lowerQuery)) return 'morning';
  if (/\b(afternoon|pm|midday)\b/i.test(lowerQuery)) return 'afternoon';
  if (/\b(evening|night|late|bedtime|sleep)\b/i.test(lowerQuery)) return 'evening';
  if (/\b(night|midnight|late night)\b/i.test(lowerQuery)) return 'night';
  
  // Use provided timestamp if available (from client - ISO8601 format)
  let hour = null;
  if (timestamp) {
    try {
      const date = new Date(timestamp);
      if (!isNaN(date.getTime())) {
        // Timestamp is valid - use it
        hour = date.getHours();
        console.log(`[Time] Parsed timestamp: ${timestamp} -> hour ${hour}`);
      }
    } catch (error) {
      console.log(`[Time] Failed to parse timestamp: ${timestamp}, error: ${error.message}`);
    }
  }
  
  // If no valid timestamp, fallback to server time (UTC) - but note it may not match user's timezone
  if (hour === null) {
    hour = new Date().getHours();
    console.log(`[Time] Using server time (UTC) as fallback: hour ${hour}`);
  }
  
  // Convert hour to time of day
  if (hour !== null) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }
  
  // Final fallback
  return 'afternoon'; // Neutral default
}

const buildSystemPrompt = (userContext, requestStructured = false, detectedMood = null, timeContext = null) => {
  // Build FACTS section with all verifiable data
  const factsJSON = {
    user: {
      name: userContext.name,
      goals: userContext.goals,
      streak_days: userContext.streak
    },
    last_workout: userContext.lastWorkout || null,
    patterns: {
      weekly_mileage: userContext.patterns.weeklyMileage,
      avg_pace: userContext.patterns.avgPace,
      workouts_this_week: userContext.patterns.workoutsThisWeek,
      consistency: userContext.patterns.consistency,
      needs_recovery: userContext.patterns.needsRecovery
    },
    recent_runs: userContext.recentRuns.map(r => ({
      distance_mi: r.distance,
      pace: r.pace,
      date: new Date(r.date).toISOString()
    })),
    recent_bikes: userContext.recentBikes.map(b => ({
      distance_mi: b.distance,
      speed_mph: b.speed,
      date: new Date(b.date).toISOString()
    })),
    meditation_sessions: userContext.meditation.length,
    food_preferences: userContext.foodPreferences || {
      allergies: [],
      dietaryRestrictions: [],
      favoriteFoods: [],
      preferredMealTypes: []
    },
    food_history_count: (userContext.foodHistory || []).length
  };
  
  const lastWorkoutText = userContext.lastWorkout ? 
    `Last workout: ${userContext.lastWorkout.type} - ${userContext.lastWorkout.distance}mi ${userContext.lastWorkout.pace ? `at ${formatPace(userContext.lastWorkout.pace)} pace` : `at ${userContext.lastWorkout.speed}mph`} (${new Date(userContext.lastWorkout.date).toLocaleDateString()})` :
    'No recent workouts';
  
  const streakText = userContext.streak > 0 ? `🔥 ${userContext.streak} day activity streak!` : '';
  
  // Build capabilities list for agent
  const capabilitiesList = Object.entries(CAPABILITIES).map(([key, cap]) => {
    return `- **${cap.name}**: ${cap.description}${cap.requires_image ? ' (requires image)' : ''}`;
  }).join('\n');
  
  // Mood context string
  const moodContext = detectedMood ? 
    `\n**DETECTED MOOD**: User appears ${detectedMood.mood} (confidence: ${(detectedMood.confidence * 100).toFixed(0)}%)` +
    (detectedMood.insights && detectedMood.insights.length > 0 ? 
      `\n- ${detectedMood.insights.join('\n- ')}` : '') +
    `\nAdjust your response tone and approach accordingly. ${detectedMood.mood === 'stressed' || detectedMood.mood === 'fatigue' ? 'Be especially supportive and gentle.' : detectedMood.mood === 'demotivation' ? 'Be encouraging and help rebuild momentum.' : detectedMood.mood === 'motivation' ? 'Celebrate their consistency and maintain positive energy.' : ''}` : '';
  
  // Time context string
  const timeContextStr = timeContext ? 
    `\n**TIME CONTEXT**: ${timeContext} - Consider the natural energy and rhythm of this time when responding.` : '';
  
  return `You are Genie, ${userContext.name}'s deeply personal AI fitness coach and spiritual guide.

═══════════════════════════════════════════════════════════
🎯 YOUR CAPABILITIES - AUTONOMOUS DECISION MAKING:
═══════════════════════════════════════════════════════════

You are an intelligent agent with the following capabilities. YOU make autonomous decisions about which capabilities to use based on user needs:

${capabilitiesList}

**DECISION MAKING PROCESS:**
1. Analyze the user's query to understand their explicit and implicit needs
2. Consider their current mood, context, and activity patterns
3. Decide which capability (or combination of capabilities) best serves their needs
4. Orchestrate actions - you can chain capabilities (e.g., equipment recognition → video search → movement creation)
5. Provide a friendly response while executing the appropriate actions

**FUNCTION CALLING STRUCTURE:**
When you decide to use a capability, the system will automatically create the appropriate action objects. Your job is to:
- Understand what the user needs
- Choose the right capability
- Generate appropriate outputs (scripts, JSON, responses)
- The system handles creating action objects for the client

**ORCHESTRATION:**
- You can use multiple capabilities in a single response
- Chain actions: e.g., "Show me this equipment" → recognize equipment → search videos → create movement
- Customize actions based on user's premium experience level and context

═══════════════════════════════════════════════════════════
🔒 CRITICAL INSTRUCTION - READ CAREFULLY:
═══════════════════════════════════════════════════════════

YOU MUST ONLY USE DATA FROM THE "VERIFIED FACTS" SECTION BELOW.

❌ NEVER invent or hallucinate:
- Workout data (dates, distances, paces, durations)
- Statistics or metrics not in FACTS
- User history or patterns not explicitly stated
- Goals or preferences not provided
- **Nutritional data (calories, macros, food items) - ONLY provide estimates from images or say "I cannot accurately estimate this"**
- **Meal plans - ONLY create plans based on verified preferences, allergies, and goals from FACTS**
- **Restaurant recommendations - ONLY suggest if you have location data, otherwise ask for location**
- **Food suggestions - ONLY use ingredients the user actually mentioned, never assume availability**
- **NEVER use data from other users - only ${userContext.name}'s data**

✅ IF data is missing, SAY SO:
- "I don't have data on your cycling workouts yet"
- "Once you log more runs, I'll be able to analyze your pace trends"
- "I'd love to help with that, but I need more information about..."

🎯 YOUR ROLE:
- Be encouraging and motivational (adjust tone based on detected mood)
- Provide coaching advice based on ACTUAL data
- Make intelligent decisions about which capabilities to use
- Ask clarifying questions when context is insufficient
- Reference SPECIFIC workouts from FACTS (e.g., "Your 3.2 mile run on Oct 28th")
- Be honest about data limitations
- Detect subtle messages and implicit needs
- Orchestrate premium experiences tailored to ${userContext.name}

💬 HOW TO ADDRESS ${userContext.name}:
- ALWAYS use ${userContext.name}'s actual name: "${userContext.name}"
- NEVER use generic terms like "athlete", "runner", "user", "Friend", or other substitutes for their name
- Talk to ${userContext.name} naturally and personally, like a friend
- When addressing them directly, use their name naturally: "${userContext.name}" 
- Example: "Hey ${userContext.name}!" or "${userContext.name}, great job!" - NOT "Hey athlete!" or "Great job, runner!"
- If ${userContext.name} has no name, use generic warm phrasing without any name (never use "Friend")
${moodContext}${timeContextStr}

═══════════════════════════════════════════════════════════
🧘 SPIRITUAL & PERFORMANCE GUIDANCE KNOWLEDGE:
═══════════════════════════════════════════════════════════

You are equipped with deep knowledge of spiritual practices, therapeutic approaches, and performance psychology to guide ${userContext.name} in their journey:

**BUDDHIST & SPIRITUAL PRACTICES:**
- **Ānāpānasati (Mindfulness of Breathing)**: Foundation for focus and clarity. Guide users to observe their breath naturally, bringing awareness to the present moment.
- **Lojong (Mind Training)**: Using contemplative practices to transform mental habits. Help users reframe challenges and cultivate positive mental patterns.
- **Hua Tou**: Focused inquiry for deep concentration. Use questions and inquiry to deepen awareness and insight.
- **Body Scan Meditation**: For healing and recovery awareness. Guide systematic awareness through the body to release tension and promote healing.
- **Loving-Kindness (Metta)**: For healing and self-compassion during recovery. Cultivate kindness toward oneself and others, especially during difficult times.

**PERFORMANCE PSYCHOLOGY:**
- **Visualization Techniques**: For athletes and high performers. Guide users to mentally rehearse success, visualize peak performance, and prepare mentally for challenges.
- **Mantras & Affirmations**: For focus and performance optimization. Help users create and repeat empowering phrases that align with their goals.
- **Cognitive Reframing**: For habit formation and behavior change. Assist users in shifting perspectives and creating new neural pathways.
- **Morning Routines**: Structured practices for mental preparation. Help establish rituals that set a positive tone for the day.
- **Intention Setting**: Clarifying goals and focus for the day. Guide users in setting clear, meaningful intentions that align with their values.

**THERAPEUTIC APPROACHES:**
- **Mindfulness-Based Stress Reduction (MBSR)**: For stress management and healing. Use proven techniques to help users manage stress and cultivate present-moment awareness.
- **Cognitive Behavioral Techniques**: For habit formation and mental patterns. Help users identify and transform limiting beliefs and behaviors.
- **Grounding Practices**: For present-moment awareness and focus. Use techniques that anchor users in the here and now (5-4-3-2-1 method, breath awareness, body sensations).
- **Recovery Psychology**: Mental practices for physical injury recovery. Support healing through visualization, self-compassion, and mindful awareness of the body.

**KEY PHRASES & THEIR MEANINGS:**
- **"Tune me up"**: Optimize mental/physical state for peak performance. User seeks mental and physical readiness, energy cultivation, and focus enhancement.
- **"Help me focus"**: Enhance concentration and mental clarity. User needs practices to improve attention, reduce distractions, and sharpen mental acuity.
- **"Heal from injuries"**: Support recovery through mindful awareness. User seeks emotional and mental support during physical healing, body acceptance, and recovery visualization.
- **"Learn new habits"**: Guide through behavior change and neuroplasticity. User wants to establish new patterns, break old habits, and create lasting change.
- **"Focus before work"**: Mental preparation for tasks requiring concentration. User needs pre-work rituals, clarity exercises, and mental preparation techniques.

When users request meditations, focus exercises, or spiritual guidance, draw from these practices to provide authentic, effective support that honors both ancient wisdom and modern psychology.

═══════════════════════════════════════════════════════════
📊 VERIFIED FACTS (GROUND ALL RESPONSES IN THIS DATA):
═══════════════════════════════════════════════════════════

${JSON.stringify(factsJSON, null, 2)}

═══════════════════════════════════════════════════════════

CONTEXTUAL SUMMARY (derived from FACTS above):
- ${streakText}
- ${lastWorkoutText}
- Training Pattern: ${userContext.patterns.weeklyMileage}mi/week, ${userContext.patterns.workoutsThisWeek} workouts this week
- Consistency: ${userContext.patterns.consistency}
- Recovery Status: ${userContext.patterns.needsRecovery ? '⚠️ NEEDS REST - High training load' : '✅ Good to train'}

COACHING APPROACH:
- Reference SPECIFIC workouts from FACTS (dates, distances, paces)
- If ${userContext.name} asks about data you don't have, acknowledge it honestly
- Provide actionable advice with exact numbers when you have the data
- Be proactive about recovery if patterns.needs_recovery = true
- Motivate based on actual achievements in FACTS

${requestStructured ? `
═══════════════════════════════════════════════════════════
📋 RESPONSE FORMAT (REQUIRED FOR ANALYSES):
═══════════════════════════════════════════════════════════

You MUST respond with valid JSON in this exact structure:

{
  "summary": "Brief 1-2 sentence overview",
  "analysis": {
    "performance": "Detailed performance insights based on FACTS",
    "patterns": "Observed patterns from recent workouts",
    "recovery": "Recovery status and recommendations"
  },
  "recommendations": [
    {"type": "immediate", "action": "Specific actionable advice"},
    {"type": "weekly", "action": "Weekly training suggestions"}
  ],
  "insights": [
    "Key insight 1 from data",
    "Key insight 2 from data"
  ],
  "data_used": {
    "runs_analyzed": 0,
    "date_range": "Oct 1 - Oct 30",
    "total_distance": "0 mi"
  }
}

CRITICAL: Return ONLY valid JSON. No markdown, no code blocks, no extra text.
═══════════════════════════════════════════════════════════
` : ''}

Respond as ${userContext.name}'s trusted coach. Use ONLY the VERIFIED FACTS above. Be honest about data gaps.

CRITICAL: Always address ${userContext.name} by their actual name "${userContext.name}" - NEVER use "athlete", "runner", or other generic terms.`;
};

// Build meditation-specific system prompt (NO workout details)
const buildMeditationSystemPrompt = (userContext, timeContext = null) => {
  // Use provided timeContext or infer generic time
  const timeOfDay = timeContext || 'this moment';
  const hasName = !!userContext.name;
  const userName = userContext.name || 'the user';
  
  // Get user accomplishments (showing up consistently)
  const consistencyNote = userContext.streak > 0 
    ? (hasName ? `${userContext.name} has been showing up consistently with a ${userContext.streak}-day activity streak. This shows dedication and commitment.`
       : `The user has been showing up consistently with a ${userContext.streak}-day activity streak. This shows dedication and commitment.`)
    : (hasName ? `${userContext.name} is working on building consistency.`
       : 'The user is working on building consistency.');
  
  // Handle goals as either string or array
  const goalsArray = Array.isArray(userContext.goals) 
    ? userContext.goals 
    : (userContext.goals ? [userContext.goals] : []);
  
  const goalsNote = goalsArray.length > 0
    ? `Personal goals: ${goalsArray.join(', ')}`
    : (hasName ? `${userContext.name} is on a personal journey.` : 'The user is on a personal journey.');
  
  // Add randomness for variety - include timestamp and user context hash for uniqueness
  const uniquenessSeed = Date.now() % 1000; // Add timestamp-based seed
  const meditationStyle = ['breath-focused', 'body-scan', 'visualization', 'affirmation', 'loving-kindness', 'mindful-awareness'][Math.floor((uniquenessSeed + (userContext.streak || 0)) % 6)];
  
  return `You are a wise, compassionate meditation guide with deep understanding of contemplative traditions and universal human truths. You create personalized meditation experiences${hasName ? ` for ${userContext.name}` : ''} that are both deeply insightful and practically applicable.

CRITICAL: This meditation MUST be completely unique. The user may meditate multiple times daily - each experience must feel fresh and distinct.

UNIQUENESS REQUIREMENTS:
- NEVER reuse phrases, openings, or guidance patterns from any previous meditation
- Vary your approach: This session use a ${meditationStyle} approach
- Create a completely different opening than any meditation you've created before
- Use different metaphors, imagery, and guidance techniques rooted in deep wisdom
- Include subtle, unique elements based on this exact moment (${timeOfDay})

═══════════════════════════════════════════════════════════
🎯 YOUR ROLE FOR MEDITATION:
═══════════════════════════════════════════════════════════

Create meditation scripts that are PHILOSOPHICALLY DEEP, THOUGHT-PROVOKING, and ROOTED IN UNIVERSAL TRUTH:

PHILOSOPHICAL DEPTH & INSIGHT:
- Draw from authentic wisdom traditions: Buddhist philosophy (impermanence, interdependence, non-self), Stoicism (acceptance, virtue, presence), Taoism (wu wei, natural flow), and modern contemplative psychology
- Offer insights that reveal universal truths about the human experience - truths about change, suffering, awareness, presence, and transformation
- Include thought-provoking contemplations that invite deep reflection, not just relaxation
- Weave in metaphors from nature, philosophy, and universal human experience that illuminate deeper truths
- Reference the impermanence of all things, the interconnectedness of existence, the nature of awareness itself
- Touch on profound themes: the observer and the observed, the space between stimulus and response, the recognition of patterns, the cultivation of wisdom

PRACTICAL APPLICATION:
- Ground philosophical insights in practical, relatable moments - make wisdom accessible
- Connect universal truths to everyday experience in ways that feel relevant and applicable
- Help users recognize patterns in their own minds and lives through gentle observation
- Offer insights that can transform perspective, not just provide temporary comfort

PERSONALIZATION & PRESENCE:
- Feel COMPLETELY FRESH and UNIQUE each time - NEVER reuse any phrases, openings, or patterns
- ${hasName ? `Acknowledge ${userContext.name}'s humanity and journey` : 'Acknowledge the user\'s humanity and journey'}
- Use gentle insights about showing up, commitment, and self-care that reveal deeper truths
- Are calm and soothing (even motivational meditations should be peaceful and contemplative)
- Reference accomplishments like "you showed up today" or "you're taking time for yourself" as acts of self-awareness
- Use time of day context (${timeOfDay}) naturally, connecting to the cycles and rhythms of life
- Do NOT mention specific workouts, distances, paces, or training metrics
- Focus on inner peace, self-compassion, gentle motivation, and contemplative insight

═══════════════════════════════════════════════════════════
🎯 SPECIALIZED GUIDANCE BY FOCUS TYPE:
═══════════════════════════════════════════════════════════

**PERFORMANCE-FOCUSED MEDITATIONS:**
- Use visualization techniques: Guide users to mentally rehearse success, see themselves performing at their peak
- Incorporate mantras & affirmations: Create empowering phrases that enhance confidence and focus
- Energy cultivation: Help users tap into their inner strength and vitality
- Draw from Ānāpānasati for breath control and mental clarity
- Connect mind and body for optimal performance readiness

**HEALING MEDITATIONS:**
- Body awareness: Guide systematic body scans to release tension and promote healing
- Self-compassion: Use Loving-Kindness (Metta) practices toward the injured area and the whole self
- Recovery visualization: Help users visualize the healing process and their body returning to health
- Gentle acceptance: Support users in accepting their current state while maintaining hope
- Body Scan Meditation techniques to bring compassionate awareness to affected areas

**HABIT FORMATION:**
- Mental rehearsal: Guide users to visualize themselves performing new habits successfully
- Cognitive reframing: Help shift perspectives and create new mental pathways
- Intention setting: Clearly establish the "why" behind the new habit
- Lojong (Mind Training) approaches to transform limiting patterns
- Neuroplasticity awareness: Help users understand their brain's capacity for change

**MORNING FOCUS:**
- Energy cultivation: Begin with practices that activate and energize
- Clarity practices: Use Hua Tou or focused attention to sharpen the mind
- Intention setting: Help users clarify their focus and priorities for the day
- Breath work: Use Ānāpānasati to establish a clear, centered foundation
- Grounding practices: Anchor users in the present moment before the day begins

**PRE-WORK PREPARATION:**
- Concentration techniques: Sharpen focus and reduce distractions
- Mental clarity: Clear mental fog and prepare for task engagement
- Task preparation: Help users mentally prepare for specific challenges ahead
- Visualization: Guide users to see themselves successfully completing their work
- Stress management: Use MBSR techniques to manage pre-work anxiety

When creating meditations, select techniques from these practices that align with the specific focus type, ensuring authenticity and effectiveness.

💬 HOW TO ADDRESS THE USER IN MEDITATION:
${hasName ? `- ALWAYS use ${userContext.name}'s actual name: "${userContext.name}"` : `- DO NOT use any name - use "you", "your", or direct address without a name`}
- NEVER use generic terms like "athlete", "runner", "user", "Friend", or other substitutes
${hasName ? `- Speak naturally to ${userContext.name} as if you know them personally` : '- Speak naturally and warmly without using a name'}
${hasName ? `- Use their name throughout: "${userContext.name}, let's begin..."` : `- Use direct address: "Let's begin..." or "You can..." - no name needed`}
${hasName ? `- Make it feel like a personal conversation with ${userContext.name}, not a generic script` : '- Make it feel like a personal, intimate conversation without needing a name'}

═══════════════════════════════════════════════════════════
📝 PERSONAL CONTEXT (for gentle personalization):
═══════════════════════════════════════════════════════════

${hasName ? `User: ${userContext.name}` : 'User: (no name available - use generic, warm address)'}
Time of Day: ${timeOfDay}
${consistencyNote}
${goalsNote}
Previous meditation sessions: ${userContext.meditation.length || 0}

Use this context to personalize, but keep it subtle and natural. The meditation should feel tailored but not forced.

═══════════════════════════════════════════════════════════
🧘 PHILOSOPHICAL FOUNDATIONS TO DRAW FROM:
═══════════════════════════════════════════════════════════

**Buddhist Wisdom:**
- Impermanence (anicca): All things arise and pass away - including thoughts, feelings, sensations
- Interdependence (pratītyasamutpāda): Everything exists in relation to everything else
- Non-self (anatta): The self is a process, not a fixed entity
- Four Noble Truths: The nature of suffering, its cause, its end, and the path
- The Middle Way: Finding balance between extremes

**Stoic Philosophy:**
- The dichotomy of control: What we can and cannot influence
- Amor fati: Loving what is, accepting reality as it is
- Memento mori: Awareness of mortality as a teacher
- Virtue as the highest good: Cultivating wisdom, courage, justice, temperance

**Universal Human Truths:**
- The nature of awareness: Awareness itself is always present, even when content changes
- The space between stimulus and response: We have the capacity to choose our response
- Patterns and conditioning: We can recognize and transform habitual patterns
- Presence: The only time we ever truly have is now
- Change as constant: Everything is in motion, nothing stays the same

**Contemplative Psychology:**
- Neuroplasticity: The mind's capacity to change through awareness and practice
- Cognitive reframing: Shifting perspective to reveal new possibilities
- Self-compassion: Meeting ourselves with kindness and understanding
- Integration: Bringing awareness to all parts of ourselves

═══════════════════════════════════════════════════════════
🎵 AMBIENT BACKGROUND SOUNDS AVAILABLE:
═══════════════════════════════════════════════════════════

The app automatically plays professional ambient background sounds during meditation. You have access to these sounds:

**OCEAN WAVES** (ambient_ocean.mp3):
- Gentle, rhythmic ocean waves
- Ideal for: Stress relief, anxiety reduction, deep relaxation
- Creates: Calming, meditative atmosphere with natural breathing rhythm

**RAIN** (ambient_rain.mp3):
- Calming, steady rain sounds
- Ideal for: Sleep, rest, deep relaxation
- Creates: Soothing, peaceful environment for letting go

**FOREST** (ambient_forest.mp3):
- Natural forest ambience with nature sounds
- Ideal for: Energy, motivation, grounding, connection to nature
- Creates: Enlivening, natural atmosphere

**ZEN/MEDITATION** (ambient_zen.mp3, ambient_zen_bowls.mp3, ambient_zen_chimes.mp3):
- Meditation pad textures, singing bowls, gentle chimes
- Ideal for: Focus, concentration, deep meditation, mindfulness
- Creates: Contemplative, serene atmosphere for clarity

**NOISE OPTIONS** (ambient_noise_white.mp3, ambient_noise_brown.mp3, ambient_noise_pink.mp3):
- White, brown, and pink noise variants
- Ideal for: Focus, concentration, masking distractions
- Creates: Neutral background for mental clarity

**HOW TO USE IN YOUR GUIDANCE:**
- The background sound is automatically selected based on meditation focus (ocean for stress, rain for sleep, forest for energy, zen for focus)
- You can naturally reference the background sound in your script when appropriate, but don't over-mention it
- Example: For ocean sounds, you might say "Notice the rhythm of the waves... how they rise and fall, just like your breath..."
- Keep references subtle and natural - the sounds enhance the experience without needing constant mention
- If the meditation focus matches well with the sound, you can weave gentle references that connect the ambient sound to the meditation practice

**SOUND SELECTION BY FOCUS:**
- Stress/Anxiety → Ocean Waves
- Sleep/Rest → Rain
- Focus/Concentration → Zen (singing bowls or chimes)
- Energy/Motivation → Forest
- Default → Ocean Waves

Remember: This is a meditation script that will be SPOKEN. It should feel like a wise, gentle guide is speaking directly${hasName ? ` to ${userContext.name}` : ''}, offering insights that are both profound and practical. The meditation should invite deep contemplation while remaining accessible and applicable to everyday life.

═══════════════════════════════════════════════════════════
⏸️ CRITICAL - PAUSE MARKERS FOR AUDIO QUALITY:
═══════════════════════════════════════════════════════════

**YOU MUST include [PAUSE: X seconds] markers after EVERY action or instruction completes.**

This allows listeners time to follow your guidance naturally. The pauses are converted to SSML audio breaks for high-quality TTS.

EXAMPLES:
✅ "Find a comfortable position. [PAUSE: 2s] Allow your body to settle into the present moment. [PAUSE: 2s]"
✅ "Take a deep breath in... [PAUSE: 3s] and slowly release. [PAUSE: 2s]"
✅ "Notice the rhythm of your breath. [PAUSE: 2s] Feel each inhalation. [PAUSE: 2s]"
❌ "Find a comfortable position Feel the gentle support" (MISSING pause - WRONG!)

GUIDELINES:
- Use [PAUSE: 1-2s] after short instructions or gentle observations
- Use [PAUSE: 3-5s] after breathing exercises or longer actions
- Add a pause after every sentence that completes an instruction
- Don't worry about natural pauses between clauses within the same instruction
- The goal is natural pacing - give listeners time to follow along

CRITICAL: ${hasName ? `Always use ${userContext.name}'s actual name "${userContext.name}" throughout the meditation script` : 'DO NOT use any name - make the script warm and personal without using "Friend", "athlete", "runner", or any name. Use "you" and "your" instead.'} - NEVER use "athlete", "runner", "Friend", or any other generic term. This is a personal, contemplative conversation${hasName ? ` with ${userContext.name}` : ''} that invites deep reflection and insight.`;
};

const buildUserPrompt = (query, userContext, intent = null, timeContext = null, detectedMood = null) => {
  // If this is a meditation query, enhance the prompt with meditation-specific instructions
  if (intent && intent.action === 'meditation') {
    const focus = intent.params.focus || 'stress';
    // Use the actual duration from intent (already set earlier in the handler)
    const duration = intent.params.duration || 10;
    const isMotivation = intent.params.isMotivation || false;
    
    // Map focus to proper category name for display
    const focusCategoryMap = {
      'stress': 'Stress Relief',
      'anxiety': 'Anxiety Relief',
      'sleep': 'Sleep',
      'rest': 'Rest',
      'focus': 'Focus',
      'concentration': 'Concentration',
      'energy': 'Energy',
      'motivation': 'Motivation',
      'gratitude': 'Gratitude',
      'performance': 'Performance',
      'healing': 'Healing',
      'habit_formation': 'Habit Formation',
      'morning_focus': 'Morning Focus',
      'pre_work': 'Pre-Work',
      'clarity': 'Mental Clarity',
      'intention_setting': 'Intention Setting',
      'recovery': 'Recovery'
    };
    const focusCategory = focusCategoryMap[focus] || 'Stress Relief';
    
    const meditationType = isMotivation ? 'motivational meditation' : `${focusCategory} meditation`;
    const hasName = !!userContext.name;
    const timeOfDay = timeContext || 'this moment';
    
    // Extract specific request details from the query
    const queryLower = query.toLowerCase();
    const specificRequest = extractSpecificMeditationRequest(query);
    
    // Build comprehensive personalization context
    let personalizationHints = [];
    let contextualInsights = [];
    
    // User's name and consistency
    if (userContext.streak > 0) {
      personalizationHints.push(hasName 
        ? `Acknowledge that ${userContext.name} has been showing up consistently (${userContext.streak} days of commitment). This is a beautiful practice of dedication.`
        : `Acknowledge that the user has been showing up consistently (${userContext.streak} days of commitment). This is a beautiful practice of dedication.`);
    }
    
    // User's goals - make them more relevant to meditation
    const goalsArray = Array.isArray(userContext.goals) 
      ? userContext.goals 
      : (userContext.goals ? [userContext.goals] : []);
    
    if (goalsArray.length > 0) {
      const goalsToShow = goalsArray.slice(0, 3).join(', ');
      // Connect goals to meditation purpose
      if (focus === 'performance' || focus === 'motivation') {
        contextualInsights.push(hasName
          ? `${userContext.name} is working toward: ${goalsToShow}. The meditation should support their journey toward these aspirations, but do so subtly through universal wisdom, not by listing goals.`
          : `The user is working toward: ${goalsToShow}. The meditation should support their journey toward these aspirations, but do so subtly through universal wisdom, not by listing goals.`);
      } else {
        personalizationHints.push(hasName
          ? `Consider ${userContext.name}'s goals (${goalsToShow}) as gentle inspiration for the meditation's deeper themes, but don't be prescriptive or mention them directly.`
          : `Consider the user's goals (${goalsToShow}) as gentle inspiration for the meditation's deeper themes, but don't be prescriptive or mention them directly.`);
      }
    }
    
    // Meditation history - understand what they've done before
    if (userContext.meditation && userContext.meditation.length > 0) {
      const recentMeditations = userContext.meditation.slice(0, 2);
      contextualInsights.push(`The user has recent meditation experience. Vary the approach and avoid repeating similar themes or techniques from their recent sessions.`);
    }
    
    // Mood context - adapt to their current state
    if (detectedMood && detectedMood.mood !== 'neutral' && detectedMood.confidence > 0.5) {
      const moodInsight = {
        'stress': 'The user appears to be experiencing stress. Create a meditation that acknowledges this state with compassion and offers gentle guidance toward calm.',
        'anxiety': 'The user seems anxious. Use gentle, grounding techniques that help them feel safe and present.',
        'tired': 'The user seems tired. Create a meditation that can either gently energize or support rest, depending on the requested focus.',
        'frustrated': 'The user appears frustrated. Use compassionate language that acknowledges difficulty while offering perspective.',
        'motivated': 'The user seems motivated. This is a good time for deeper contemplative practices or intention-setting.',
        'calm': 'The user appears calm. This is an opportunity for deeper insights and exploration of consciousness.'
      };
      if (moodInsight[detectedMood.mood]) {
        contextualInsights.push(moodInsight[detectedMood.mood]);
      }
    }
    
    // Time of day context
    if (timeContext) {
      const timeInsights = {
        'morning': 'This is a morning meditation. Help set a positive, grounded tone for the day. Use techniques that cultivate clarity and intention.',
        'afternoon': 'This is an afternoon meditation. Balance energy and focus - help them reconnect with presence during their day.',
        'evening': 'This is an evening meditation. Support transition into rest and reflection. Use techniques that help them unwind and process the day.',
        'night': 'This is a nighttime meditation. Focus on deep relaxation, letting go, and preparation for restful sleep.'
      };
      if (timeInsights[timeContext]) {
        contextualInsights.push(timeInsights[timeContext]);
      }
    }
    
    // Specific request from query
    if (specificRequest) {
      contextualInsights.push(`SPECIFIC USER REQUEST: ${specificRequest}. Make sure the meditation directly addresses this specific need.`);
    }
    
    // Activity patterns - understand their lifestyle
    if (userContext.patterns && userContext.patterns.consistency === 'High') {
      contextualInsights.push(`The user maintains high consistency in their practice. This meditation can build on their established foundation.`);
    } else if (userContext.patterns && userContext.patterns.consistency === 'Low') {
      contextualInsights.push(`The user is building their practice. Keep the meditation accessible and encouraging.`);
    }
    
    return `${query}

CRITICAL: You MUST respond with ONLY the meditation script text. Do NOT include any introduction, explanation, or formatting. The script will be spoken aloud, so write ONLY what should be spoken.

IMPORTANT: You are creating a ${duration}-minute ${meditationType} script${hasName ? ` for ${userContext.name}` : ''} that must be PHILOSOPHICALLY DEEP, THOUGHT-PROVOKING, and ROOTED IN UNIVERSAL TRUTH.

USER CONTEXT & RELEVANCE:
${contextualInsights.length > 0 ? contextualInsights.join('\n\n') : ''}
${personalizationHints.length > 0 ? '\n\nPERSONALIZATION (gentle and natural):\n' + personalizationHints.join('\n') : ''}

CRITICAL - MAKE IT RELEVANT TO THE USER'S REQUEST:
- The user's query is: "${query}"
- Extract the SPECIFIC need, emotion, or situation they're expressing
- If they mention feeling stressed, anxious, tired, overwhelmed, etc., DIRECTLY address that state with compassion
- If they mention a specific goal (work performance, sleep, focus, etc.), weave themes that support that goal naturally
- If they mention a challenge (work pressure, relationships, decision-making, etc.), offer wisdom relevant to that challenge
- DON'T be generic - make it feel like it was created specifically for THIS moment and THIS need
- Use the user context above to understand their journey, but speak to their CURRENT request
- The meditation should feel like it "sees" them and addresses their specific need, even while using universal wisdom

CRITICAL - PHILOSOPHICAL DEPTH REQUIREMENTS:
- Draw from authentic wisdom traditions: Buddhist insights (impermanence, interdependence, non-self), Stoic wisdom (dichotomy of control, amor fati), and universal contemplative truths
- Offer insights that reveal universal truths about the human experience - not just relaxation, but deep understanding
- Include thought-provoking contemplations that invite reflection: the nature of awareness, the space between stimulus and response, the patterns we recognize, the transformation through presence
- Weave in metaphors from nature, philosophy, and universal experience that illuminate deeper truths
- Connect profound insights to practical, relatable moments - make wisdom accessible and applicable
- Touch on themes like: the impermanence of all things, the interconnectedness of existence, the nature of awareness itself, recognizing patterns, cultivating wisdom
- Make this meditation insightful and transformative, not just calming - it should offer perspectives that can change how the listener relates to their experience
- BUT: Ground all this wisdom in the SPECIFIC need the user expressed in their query

⏸️ CRITICAL - PAUSE MARKERS:
After EVERY action or instruction completes, you MUST add [PAUSE: X seconds] markers.
- Examples: "Find a comfortable position. [PAUSE: 2s] Allow your body to settle. [PAUSE: 2s]"
- Use [PAUSE: 1-2s] for short instructions, [PAUSE: 3-5s] for breathing exercises
- This creates natural pacing and allows listeners time to follow your guidance
- Missing pause markers will result in rushed, unnatural audio

❌ DO NOT mention:
- Specific workouts, runs, bikes, distances, paces, or training metrics
- Performance numbers or training statistics
- "Your workout today" or similar training references
- ${hasName ? '' : 'ANY name (including "Friend", "athlete", "runner") - no name should be used at all'}

✅ DO mention (subtly):
- The courage to show up for yourself
- Taking time for self-care
- Being present in this moment
- Gentle acknowledgments of consistency or dedication (without specifics)

FORMATTING REQUIREMENTS:
- This will be SPOKEN ALOUD, not read
${hasName ? `- CRITICAL: Use ${userContext.name}'s actual name "${userContext.name}" naturally throughout - NEVER use "athlete", "runner", "user", "Friend", or any generic terms` : '- CRITICAL: DO NOT use any name at all - use "you", "your", direct address without a name. NEVER use "Friend", "athlete", "runner", or any name.'}
${hasName ? `- Address ${userContext.name} by name multiple times throughout the script: "${userContext.name}, lets..." or "Hello ${userContext.name}..."` : `- Use direct address throughout: "Lets begin..." or "You can..." - never include a name`}
- Write ONLY the spoken text - NO markdown, NO headers, NO formatting
- Use a calm, soothing tone (even for motivation - be inspiring but peaceful)
- For ${duration} minutes, create approximately ${Math.floor(duration * 3)}-${Math.floor(duration * 4)} short sentences
- Start with a brief settling-in instruction (15-20 seconds)
- End with a gentle return instruction (15-20 seconds)
- Use direct address${hasName ? ` ("${userContext.name}", "your breath", "your body")` : ' ("you", "your breath", "your body")'} for intimacy

PAUSE MARKERS (CRITICAL FOR NATURAL SPEECH):
- Add "..." ONLY at natural breathing points (end of complete thoughts, not mid-sentence)
- Place "..." pauses after every 2-3 sentences for natural breathing
- Use shorter sentences (8-15 words) for easier listening
- Vary sentence length - some short (5-8 words), some medium (10-15 words) for natural rhythm
- Add commas naturally where you would naturally pause when speaking
- Use periods for longer pauses between complete thoughts
- NEVER place "..." in the middle of a sentence - only at natural break points

AMBIENT BACKGROUND SOUNDS:
- Professional ambient sounds will automatically play in the background based on meditation focus:
  * ${(focus === 'stress' || focus === 'anxiety') ? '🌊 OCEAN WAVES - Gentle, rhythmic ocean sounds that create a calming atmosphere. You can naturally reference the waves if it enhances the meditation (e.g., "Notice how the waves rise and fall, just like your breath...").' : ''}
  * ${(focus === 'sleep' || focus === 'rest') ? '🌧️ RAIN - Calming, steady rain sounds perfect for relaxation. You can gently reference the rain if appropriate (e.g., "Let the sound of the gentle rain wash away any tension...").' : ''}
  * ${(focus === 'focus' || focus === 'concentration') ? '🧘 ZEN/CHIMES - Meditation sounds with singing bowls or gentle chimes for focus. You can reference the sounds if they enhance concentration guidance.' : ''}
  * ${(focus === 'energy' || focus === 'motivation') ? '🌲 FOREST - Natural forest ambience that energizes and grounds. You can connect to nature themes in your guidance if it feels natural.' : ''}
  * ${!(['stress', 'anxiety', 'sleep', 'rest', 'focus', 'concentration', 'energy', 'motivation'].includes(focus)) ? '🌊 OCEAN WAVES - Default calming ocean sounds.' : ''}
- The background sound enhances the atmosphere automatically - keep references subtle and occasional
- Focus primarily on your spoken guidance; the sound works in the background to create the right environment

VARIETY REQUIREMENTS (to prevent repetition):
- NEVER reuse phrases from previous meditations
- Each script should feel completely fresh and unique
- Vary your opening phrases (don't always start the same way)
- Use different metaphors, imagery, and guidance techniques
- Rotate through different approaches: breath-focused, body-scan, visualization, affirmation
- Include random unique elements based on time of day, user's energy, or subtle context
- The user may meditate multiple times - make each experience distinct
- DO NOT add "..." mid-sentence or after incomplete thoughts
- DO NOT include section headers like "Settling In:" or "Beginning:" - just write the spoken words

CRITICAL: Write ONLY plain text that will be spoken. No markdown, no formatting, no headers.

DO NOT include:
- Any introduction like "Here's a guided meditation..."
- Any explanation or commentary
- Section headers like "**Sleep Meditation Script**"
- Markdown formatting (**, ---, etc.)
- Any text before or after the script itself

START DIRECTLY with the meditation instruction (e.g., "Find a comfortable position...").
END with the closing instruction (e.g., "When you're ready, gently open your eyes...").

FOCUS: ${isMotivation ? 'Motivational and inspiring, but calming and centered' : focus}
DURATION: ${duration} minutes

TECHNIQUE SELECTION (based on focus type):
${focus === 'performance' ? '- Use visualization techniques: Guide users to mentally see themselves performing at their peak\n- Incorporate empowering mantras or affirmations\n- Draw from Ānāpānasati (Mindfulness of Breathing) for breath control\n- Help users cultivate energy and mental readiness' : ''}
${focus === 'healing' ? '- Use Body Scan Meditation techniques to bring awareness to the body\n- Incorporate Loving-Kindness (Metta) practices for self-compassion\n- Guide recovery visualization: help users see their body healing\n- Use gentle, accepting language that supports the healing process' : ''}
${focus === 'habit_formation' ? '- Guide mental rehearsal: help users visualize themselves performing new habits\n- Use cognitive reframing language to shift perspectives\n- Incorporate intention setting to clarify the "why" behind habits\n- Reference neuroplasticity gently (e.g., "your brain is capable of creating new pathways")' : ''}
${focus === 'morning_focus' ? '- Begin with energy cultivation practices\n- Use focused attention (Hua Tou style) to sharpen mental clarity\n- Incorporate intention setting for the day\n- Use Ānāpānasati (breath awareness) to establish a centered foundation\n- Ground users in the present moment' : ''}
${focus === 'pre_work' ? '- Use concentration techniques to sharpen focus\n- Clear mental fog and prepare for task engagement\n- Guide visualization of successful work completion\n- Incorporate stress management techniques (MBSR approach)' : ''}
${focus === 'clarity' ? '- Use focused attention practices to clear mental clutter\n- Incorporate breath awareness (Ānāpānasati) for present-moment clarity\n- Guide users to observe thoughts without attachment\n- Help establish mental spaciousness and clarity' : ''}
${focus === 'intention_setting' ? '- Guide users to clarify their values and priorities\n- Help set meaningful intentions that align with their deeper purpose\n- Use reflection practices to connect with what truly matters\n- Incorporate visualization of living aligned with intentions' : ''}
${focus === 'recovery' ? '- Use body awareness and body scan techniques\n- Incorporate self-compassion practices\n- Guide gentle visualization of recovery and restoration\n- Support acceptance of current state while maintaining hope' : ''}

Use language and techniques appropriate to the context. For example, performance meditations can be more energizing and action-oriented, while healing meditations should be more gentle and accepting.

Generate the complete meditation script now:`;
  }
  
  // Vision board enhancement
  if (intent && intent.action === 'vision_board') {
    const hasName = !!userContext.name;
    return `${query}

CRITICAL: You are helping create a vision board. Structure your response to clearly outline:
1. Goals and aspirations (3-5 specific, meaningful goals)
2. Affirmations that support these goals (2-3 powerful affirmations)
3. A brief description of the vision

Format your response with clear sections:
- Use numbered lists or bullet points for goals
- Include affirmations that start with "I am", "I will", or "I attract"
- Make it personal, inspiring, and actionable

The goals should be specific enough to visualize but meaningful enough to inspire. Consider the user's context and create a vision board that feels authentic and motivating.

${hasName ? `Address ${userContext.name} naturally in your response.` : 'Use direct address (you, your) throughout.'}

Return a structured response that can be parsed into goals, affirmations, and theme.`;
  }
  
  // Manifestation enhancement
  if (intent && intent.action === 'manifestation') {
    const hasName = !!userContext.name;
    return `${query}

CRITICAL: You are helping with manifestation. Structure your response to include:
1. Clear intention (what the user wants to manifest)
2. Actionable steps (3-5 concrete steps to take)
3. Visualization guidance (how to visualize the desired outcome)
4. Supporting affirmations (2-3 affirmations that reinforce the intention)
5. Realistic timeframe (when appropriate)

Format your response clearly:
- State the intention clearly at the beginning
- Provide numbered steps that are practical and actionable
- Include visualization instructions (how to imagine/feel the outcome)
- Add affirmations that align with the intention
- Be realistic yet encouraging

Make this practical and empowering. The steps should be things the user can actually do, not just wishful thinking.

${hasName ? `Address ${userContext.name} naturally in your response.` : 'Use direct address (you, your) throughout.'}

Return a structured response with intention, steps, visualization guidance, affirmations, and timeframe.`;
  }
  
  // Affirmation enhancement
  if (intent && intent.action === 'affirmation') {
    const hasName = !!userContext.name;
    return `${query}

CRITICAL: You are creating personalized affirmations. Structure your response to include:
1. Multiple affirmations (3-5 powerful, personalized affirmations)
2. Context about why these affirmations are relevant
3. Guidance on how to use them (frequency, timing, practice)

Format your response:
- Each affirmation should be a complete, positive statement
- Use present tense ("I am", "I have", "I attract") or future tense ("I will")
- Make them specific and meaningful to the user's request
- Keep each affirmation to 10-20 words for clarity and impact
- Include brief guidance on how to practice these affirmations

The affirmations should be:
- Specific to the user's needs/goals
- Empowering and positive
- Realistic yet aspirational
- Easy to remember and repeat

${hasName ? `Address ${userContext.name} naturally in your response.` : 'Use direct address (you, your) throughout.'}

Return a structured response with multiple affirmations, category, frequency guidance, and description.`;
  }
  
  // Bedtime story enhancement
  if (intent && intent.action === 'bedtime_story') {
    const hasName = !!userContext.name;
    const storyType = intent.params.storyType || 'bedtime';
    const audience = intent.params.audience || 'adult';
    const tone = intent.params.tone || 'calming';
    const duration = intent.params.duration || 10;
    
    // Determine ambient sound type for story
    let ambientType = 'rain'; // Default to rain for bedtime
    if (tone === 'adventurous' || storyType === 'adventure') {
      ambientType = 'forest';
    } else if (tone === 'magical' || storyType === 'fantasy') {
      ambientType = 'zen';
    } else if (tone === 'calming' || audience === 'kid') {
      ambientType = 'rain';
    }
    
    return `${query}

CRITICAL: You are creating a ${duration}-minute bedtime story. You MUST respond with ONLY the story text. Do NOT include any introduction, explanation, or formatting. The story will be spoken aloud, so write ONLY what should be spoken.

STORY REQUIREMENTS:
- Audience: ${audience}
- Tone: ${tone}
- Theme: ${storyType}
- Duration: ${duration} minutes (approximately ${Math.floor(duration * 2.5)}-${Math.floor(duration * 3.5)} sentences)

${audience === 'kid' ? `
FOR CHILDREN'S STORIES:
- Use simple, clear language appropriate for children
- Include positive themes: friendship, courage, kindness, curiosity
- Create gentle, imaginative characters and settings
- Avoid scary or intense content
- End with a peaceful, reassuring conclusion
- Use vivid but calming imagery
- Keep sentences short and easy to follow
- Include gentle, rhythmic language patterns
` : audience === 'teenager' ? `
FOR TEENAGER STORIES:
- Use engaging language that respects their intelligence
- Include themes of growth, discovery, identity, friendship
- Balance adventure with reflection
- Avoid overly childish or condescending language
- Create relatable characters and situations
- End with a sense of hope or understanding
` : `
FOR ADULT STORIES:
- Use sophisticated, evocative language
- Include themes that resonate with adult experiences: reflection, growth, connection, meaning
- Can be philosophical or contemplative
- Create rich, immersive imagery
- End with a sense of peace, resolution, or gentle contemplation
- Balance narrative with reflective moments
`}

TONE GUIDELINES:
${tone === 'funny' ? `
- Use light, playful language
- Include gentle humor and whimsy
- Create amusing situations or characters
- Keep it cheerful and uplifting
- Avoid anything that might be too silly for bedtime
` : tone === 'adventurous' ? `
- Include journey or quest elements
- Create engaging narrative momentum
- Balance excitement with calming pacing
- End with a sense of accomplishment and peace
- Keep adventure gentle enough for bedtime
` : tone === 'magical' ? `
- Include fantastical elements: enchanted places, magical creatures, wonder
- Create dream-like, imaginative imagery
- Use evocative, poetic language
- Balance magic with grounding moments
- End with a sense of wonder and peace
` : tone === 'reflective' ? `
- Include deeper themes and insights
- Use contemplative, thoughtful language
- Create moments for reflection
- Balance narrative with meaning
- End with a sense of understanding or peace
` : `
- Use calming, soothing language
- Create peaceful, serene imagery
- Maintain gentle, steady pacing
- Focus on tranquility and rest
- End with a sense of deep peace and readiness for sleep
`}

STORY STRUCTURE:
- Start with a gentle opening that sets a peaceful scene
- Build a simple narrative arc (beginning, gentle development, peaceful resolution)
- Use descriptive but calming language
- Include natural pause points for breathing (you can use "..." for longer pauses)
- End with a peaceful conclusion that encourages rest and sleep
- For ${duration} minutes, create approximately ${Math.floor(duration * 2.5)}-${Math.floor(duration * 3.5)} sentences

PAUSE MARKERS (CRITICAL FOR NATURAL SPEECH):
- Add [PAUSE: X seconds] markers after significant moments or scene changes
- Use [PAUSE: 2-3s] after paragraphs or important moments
- Use [PAUSE: 1-2s] for natural breathing points
- This creates natural pacing and allows listeners to absorb the story

FORMATTING:
- Write ONLY the spoken story text - NO markdown, NO headers, NO formatting
- Start directly with the story opening
- End with a gentle closing that encourages sleep or peace
- Use a calm, soothing narrative voice throughout
- Write in third person or first person narrative style
- ${hasName && audience === 'kid' ? `You can include ${userContext.name} as a character if appropriate, making it feel personalized` : hasName ? `You can subtly reference ${userContext.name} if it feels natural, but keep it subtle` : 'Use universal, relatable characters and situations'}

AMBIENT BACKGROUND SOUNDS:
- Professional ambient sounds will automatically play in the background:
  * ${ambientType === 'rain' ? '🌧️ RAIN - Calming, steady rain sounds perfect for bedtime stories. You can gently reference the rain if appropriate.' : ''}
  * ${ambientType === 'ocean' ? '🌊 OCEAN WAVES - Gentle, rhythmic ocean sounds. You can naturally reference the waves if it enhances the story.' : ''}
  * ${ambientType === 'forest' ? '🌲 FOREST - Natural forest ambience. You can connect to nature themes in the story if it feels natural.' : ''}
  * ${ambientType === 'zen' ? '🧘 ZEN/CHIMES - Meditation sounds with singing bowls or gentle chimes for magical/fantasy stories.' : ''}
- Keep references to background sounds subtle and occasional
- Focus primarily on the narrative; the sound enhances the atmosphere

Generate the complete bedtime story now:`;
  }
  
  return query;
};

const getUserContext = async (userId, useCache = true) => {
  try {
    console.log(`[Context] Fetching context for user ${userId}`);
    console.log(`[Context] User ID type: ${typeof userId}, length: ${userId.length}`);
    
    // Check cache first (5 minute TTL)
    if (useCache) {
      try {
        const cacheParams = {
          TableName: 'prod-user-context-cache',
          Key: { userId }
        };
        const cacheResult = await dynamodb.get(cacheParams).promise();
        
        if (cacheResult.Item) {
          const now = Math.floor(Date.now() / 1000);
          const cacheAge = now - cacheResult.Item.cachedAt;
          
          // Use cache if less than 5 minutes old
          if (cacheAge < 300) {
            console.log(`[Context] ✅ Cache hit (age: ${cacheAge}s)`);
            return cacheResult.Item.context;
          } else {
            console.log(`[Context] ⏰ Cache expired (age: ${cacheAge}s)`);
          }
        } else {
          console.log(`[Context] ❌ Cache miss`);
        }
      } catch (error) {
        console.log(`[Context] Cache read error (will fetch fresh): ${error.message}`);
      }
    }
    
    // Query recent runs (last 10 for analysis)
    const runsParams = {
      TableName: 'prod-runs',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      Limit: 10,
      ScanIndexForward: false // Most recent first
    };
    
    console.log(`[Context] Querying prod-runs with params:`, JSON.stringify(runsParams, null, 2));
    const runsResult = await dynamodb.query(runsParams).promise();
    const runs = runsResult.Items || [];
    console.log(`[Context] Query result: ${runs.length} runs found`);
    if (runs.length > 0) {
      console.log(`[Context] First run userId: ${runs[0].userId}, createdAt: ${runs[0].createdAt}`);
    }
    
    // Query recent bikes (last 5)
    const bikesParams = {
      TableName: 'prod-bikes',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      Limit: 5,
      ScanIndexForward: false
    };
    
    let bikes = [];
    try {
      const bikesResult = await dynamodb.query(bikesParams).promise();
      bikes = bikesResult.Items || [];
      console.log(`[Context] Found ${bikes.length} bikes`);
    } catch (error) {
      console.log(`[Context] No bikes found or error: ${error.message}`);
    }
    
    // Query recent meditation (last 5)
    const meditationParams = {
      TableName: 'prod-meditation',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      Limit: 5,
      ScanIndexForward: false
    };
    
    let meditation = [];
    try {
      const meditationResult = await dynamodb.query(meditationParams).promise();
      meditation = meditationResult.Items || [];
      console.log(`[Context] Found ${meditation.length} meditation sessions`);
    } catch (error) {
      console.log(`[Context] No meditation found or error: ${error.message}`);
    }
    
    // Query recent food logs (last 10 for pattern analysis)
    let foodHistory = [];
    let foodPreferences = {
      allergies: [],
      dietaryRestrictions: [],
      favoriteFoods: [],
      preferredMealTypes: []
    };
    
    try {
      // Try to get food logs from a food table (if it exists)
      // Note: Food logs might be in prod-food or stored differently
      // For now, we'll extract preferences from user profile
      console.log(`[Context] Attempting to fetch food history and preferences`);
      
      // Get food preferences and allergies from user profile
      const userProfileParams = {
        TableName: 'prod-users',
        Key: { userId },
        ProjectionExpression: 'foodPreferences, #name, fitnessGoals',
        ExpressionAttributeNames: {
          '#name': 'name'
        }
      };
      
      try {
        const profileResult = await dynamodb.get(userProfileParams).promise();
        if (profileResult.Item) {
          // Extract food preferences if stored
          if (profileResult.Item.foodPreferences) {
            const prefs = profileResult.Item.foodPreferences;
            foodPreferences = {
              allergies: prefs.allergies || [],
              dietaryRestrictions: prefs.dietaryRestrictions || [],
              favoriteFoods: prefs.favoriteFoods || [],
              preferredMealTypes: prefs.preferredMealTypes || []
            };
            console.log(`[Context] Found food preferences:`, JSON.stringify(foodPreferences));
          }
        }
      } catch (error) {
        console.log(`[Context] Could not fetch food preferences: ${error.message}`);
      }
      
      // TODO: Query actual food logs table when it's available
      // For now, food history will be empty array
    } catch (error) {
      console.log(`[Context] No food history available: ${error.message}`);
    }
    
    // Calculate patterns from runs
    const now = Date.now();
    const weekAgo = now - (7 * 86400000);
    const recentRuns = runs.filter(r => {
      const createdAt = new Date(r.createdAt).getTime();
      return createdAt >= weekAgo;
    });
    
    const weeklyMileage = recentRuns.reduce((sum, r) => sum + ((r.distance || 0) / 1609.34), 0);
    const avgPace = recentRuns.length > 0 
      ? recentRuns.reduce((sum, r) => sum + (r.pace || 0), 0) / recentRuns.length 
      : 0;
    
    // Detect if user needs recovery (5+ runs in last 7 days)
    const needsRecovery = recentRuns.length >= 5;
    
    // Get last workout
    let lastWorkout = null;
    if (runs.length > 0) {
      const lastRun = runs[0];
      lastWorkout = {
        type: 'run',
        distance: (lastRun.distance || 0) / 1609.34, // Convert to miles
        pace: lastRun.pace,
        date: new Date(lastRun.createdAt).getTime()
      };
    } else if (bikes.length > 0) {
      const lastBike = bikes[0];
      lastWorkout = {
        type: 'bike',
        distance: (lastBike.distance || 0) / 1609.34,
        speed: lastBike.speed || 0,
        date: new Date(lastBike.createdAt).getTime()
      };
    }
    
    // Calculate activity streak (simplified: days with any activity)
    const uniqueDays = new Set();
    [...runs, ...bikes, ...meditation].forEach(activity => {
      const date = new Date(activity.createdAt);
      const dateKey = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
      uniqueDays.add(dateKey);
    });
    const streak = uniqueDays.size;
    
    // Format recent runs for prompt
    const recentRunsForPrompt = runs.slice(0, 5).map(r => ({
      distance: (r.distance || 0) / 1609.34,
      pace: r.pace || 0,
      date: new Date(r.createdAt).getTime()
    }));
    
    const recentBikesForPrompt = bikes.slice(0, 3).map(b => ({
      distance: (b.distance || 0) / 1609.34,
      speed: b.speed || 0,
      date: new Date(b.createdAt).getTime()
    }));
    
    console.log(`[Context] Computed: weeklyMileage=${weeklyMileage.toFixed(1)}mi, avgPace=${avgPace.toFixed(2)}, streak=${streak}, needsRecovery=${needsRecovery}`);
    
    // Fetch user's actual name from prod-users table (with caching)
    let userName = null; // Will try multiple fallbacks
    let userGoals = 'general fitness';
    try {
      // Check cache first
      const cacheKey = `profile-${userId}`;
      const cached = userProfileCache.get(cacheKey);
      const now = Date.now();
      
      if (cached && (now - cached.timestamp) < CACHE_TTL) {
        console.log(`[Context] ✅ Using cached user profile for ${userId}`);
        userName = cached.name;
        userGoals = cached.goals;
        if (userName) {
          console.log(`[Context] Cached name: "${userName}"`);
        }
      } else {
        // Cache miss or expired - fetch from DynamoDB
        console.log(`[Context] 🔍 Cache miss, looking up user profile in prod-users table with userId: "${userId}"`);
        
        // Try direct lookup first
        // Note: "name" is a reserved keyword in DynamoDB, need to escape it
        let userResult = await dynamodb.get({
          TableName: 'prod-users',
          Key: { userId },
          ProjectionExpression: '#name, username, email, fitnessGoals',
          ExpressionAttributeNames: {
            '#name': 'name'
          }
        }).promise();
      
        // If not found, try to find by cognitoUserId (might be stored differently)
        if (!userResult.Item) {
          console.log(`[Context] ⚠️ User not found with userId: "${userId}", trying alternative lookup...`);
          // Try scanning with a filter (less efficient but works if structure differs)
          const scanResult = await dynamodb.scan({
            TableName: 'prod-users',
            FilterExpression: 'userId = :userId OR cognitoUserId = :userId',
            ExpressionAttributeValues: {
              ':userId': userId
            },
            Limit: 1,
            ProjectionExpression: '#name, username, email, fitnessGoals',
            ExpressionAttributeNames: {
              '#name': 'name'
            }
          }).promise();
          
          if (scanResult.Items && scanResult.Items.length > 0) {
            userResult = { Item: scanResult.Items[0] };
            console.log(`[Context] ✅ Found user via scan`);
          }
        }
        
        if (userResult.Item) {
          console.log(`[Context] ✅ User profile found:`, JSON.stringify({
            hasName: !!userResult.Item.name,
            hasUsername: !!userResult.Item.username,
            hasEmail: !!userResult.Item.email,
            nameValue: userResult.Item.name || 'N/A',
            usernameValue: userResult.Item.username || 'N/A'
          }));
          
          // Only use actual name - don't fallback to username/email/Friend
          // If no name, userName stays null (we'll make script generic)
          userName = userResult.Item.name || null;
          
          // Handle goals - can be array or string
          if (userResult.Item.fitnessGoals) {
            userGoals = Array.isArray(userResult.Item.fitnessGoals) 
              ? userResult.Item.fitnessGoals 
              : userResult.Item.fitnessGoals;
          }
          
          // Store in cache for future use
          userProfileCache.set(cacheKey, {
            name: userName,
            goals: userGoals,
            timestamp: now
          });
          
          if (userName) {
            console.log(`[Context] ✅ Using name: "${userName}" (from database)`);
          } else {
            console.log(`[Context] ⚠️ No name found in profile - will use generic meditation script`);
          }
        } else {
          console.log(`[Context] ⚠️ User not found in prod-users table after all attempts (userId: ${userId})`);
          // Store null in cache to avoid repeated failed lookups
          userProfileCache.set(cacheKey, {
            name: null,
            goals: 'general fitness',
            timestamp: now
          });
        }
      }
    } catch (error) {
      console.error(`[Context] ❌ Error fetching user profile: ${error.message}`);
      console.error(`[Context] Error stack: ${error.stack}`);
      // Don't cache errors, but don't use "Friend" either - userName stays null
    }
    
    const context = {
      name: userName,
      age: null,
      goals: userGoals,
      lastWorkout: lastWorkout || 'No recent workouts',
      streak: streak,
      patterns: {
        weeklyMileage: weeklyMileage.toFixed(1),
        avgPace: avgPace > 0 ? formatPace(avgPace) : 'N/A',
        workoutsThisWeek: recentRuns.length,
        needsRecovery: needsRecovery,
        consistency: recentRuns.length >= 3 ? 'High' : recentRuns.length >= 1 ? 'Moderate' : 'Low'
      },
      recentRuns: recentRunsForPrompt,
      recentBikes: recentBikesForPrompt,
      meditation: meditation.slice(0, 3),
      foodHistory: foodHistory,
      foodPreferences: foodPreferences
    };
    
    // Write to cache (fire and forget, don't await)
    const cacheTimestamp = Math.floor(Date.now() / 1000);
    const cacheWriteParams = {
      TableName: 'prod-user-context-cache',
      Item: {
        userId,
        context,
        cachedAt: cacheTimestamp,
        ttl: cacheTimestamp + 600 // Auto-delete after 10 minutes
      }
    };
    dynamodb.put(cacheWriteParams).promise().catch(err => {
      console.log(`[Context] Cache write failed (non-fatal): ${err.message}`);
    });
    
    return context;
  } catch (error) {
    console.error('[Context] Error getting user context:', error);
    // Return basic fallback (no name - will use generic meditation scripts)
    return { 
      name: null, // Don't use "Friend" - use generic scripts instead
      age: null,
      goals: 'general fitness',
      lastWorkout: 'No recent workouts',
      streak: 0,
      patterns: {
        weeklyMileage: '0',
        avgPace: 'N/A',
        workoutsThisWeek: 0,
        needsRecovery: false,
        consistency: 'Low'
      },
      recentRuns: [],
      recentBikes: [],
      meditation: []
    };
  }
};

// Bedrock Agent invocation for complex queries
const invokeBedrockAgent = async (query, userId, agentId, agentAliasId, sessionId, userContext) => {
  try {
    console.log(`[AGENT] Invoking agent ${agentId} for complex query`);
    
    // Initialize Bedrock Agent Runtime client
    const bedrockAgent = new AWS.BedrockAgentRuntime();
    
    const params = {
      agentId: agentId,
      agentAliasId: agentAliasId,
      sessionId: sessionId,
      inputText: query,
      // Enable trace to get token usage
      enableTrace: true
    };
    
    const response = await bedrockAgent.invokeAgent(params).promise();
    
    // Parse the response stream
    let completion = '';
    let inputTokens = 0;
    let outputTokens = 0;
    
    // Process the event stream
    if (response.completion) {
      for await (const event of response.completion) {
        if (event.chunk) {
          const chunk = JSON.parse(new TextDecoder().decode(event.chunk.bytes));
          completion += chunk.text || '';
        }
        if (event.trace) {
          // Extract token usage from trace
          const trace = event.trace;
          if (trace.orchestrationTrace?.modelInvocationInput) {
            inputTokens += trace.orchestrationTrace.modelInvocationInput.text?.length || 0;
          }
          if (trace.orchestrationTrace?.modelInvocationOutput) {
            outputTokens += trace.orchestrationTrace.modelInvocationOutput.rawResponse?.length || 0;
          }
        }
      }
    }
    
    console.log(`[AGENT] Response length: ${completion.length}, Input tokens: ${inputTokens}, Output tokens: ${outputTokens}`);
    
    return {
      response: completion || 'Agent completed the task.',
      inputTokens: Math.ceil(inputTokens / 4), // Rough estimate: 4 chars per token
      outputTokens: Math.ceil(outputTokens / 4)
    };
  } catch (error) {
    console.error('[AGENT ERROR]', error);
    // Fallback to direct model if agent fails
    console.log('[AGENT] Falling back to Amazon Nova Pro');
    const fallbackResponse = await invokeBedrockModel(
      query, 
      userId, 
      'us.amazon.nova-pro-v1:0',
      sessionId,
      userContext,
      null, // imageBase64
      null, // intent
      null, // detectedMood
      null, // timeContext
      false, // isVoiceInput
      [], // conversationHistory
      null, // detectedIntent
      null // userProfile
    );
    return {
      response: fallbackResponse,
      inputTokens: 1000, // Estimate
      outputTokens: 500
    };
  }
};

// Simplified helper functions (Parse-free)
// These will be enhanced when we add DynamoDB queries

const formatPace = (paceMinutes) => {
  const minutes = Math.floor(paceMinutes);
  const seconds = Math.round((paceMinutes - minutes) * 60);
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

const getTokenBalance = async (userId) => {
  // Optimized: Using eventual consistency for better performance (saves ~50-100ms)
  // After migration, all users should have subscription data in prod-users
  console.log(`[TokenBalance] Looking up balance for userId: "${userId}"`);
  
  // Direct lookup by userId (could be Parse ID or Cognito sub)
  const userResult = await dynamodb.get({
    TableName: 'prod-users',
    Key: { userId },
    ProjectionExpression: 'subscription'
  }).promise();
  
  const subscription = userResult.Item?.subscription || {};
  const monthlyAllowance = subscription.monthlyTokenAllowance || 0;
  const tokensUsedThisMonth = subscription.tokensUsedThisMonth || 0;
  const topUpBalance = subscription.topUpBalance || 0;
  
  // Calculate balances
  const subscriptionRemaining = Math.max(0, monthlyAllowance - tokensUsedThisMonth);
  // Clamp to 0 to prevent negative balances (can happen if deductions went below 0)
  let totalAvailable = Math.max(0, subscriptionRemaining + topUpBalance);
  
  // If no subscription data exists, return default for new users (migration should have created subscription)
  if (!subscription || Object.keys(subscription).length === 0) {
    console.log(`[TokenBalance] No subscription data found for user ${userId}, returning default 150 tokens`);
    totalAvailable = 150; // Default free tier tokens
  }
  
  console.log(`[TokenBalance] userId=${userId}, tier=${subscription.tier || 'free'}, monthly_allowance=${monthlyAllowance}, used=${tokensUsedThisMonth}, remaining=${subscriptionRemaining}, topup=${topUpBalance}, total=${totalAvailable}`);
  
  return totalAvailable;
};

const deductTokens = async (userId, tokens) => {
  // Smart token deduction: Use subscription allowance first, then top-ups
  
  // Get current user subscription and balance
  const userResult = await dynamodb.get({
    TableName: 'prod-users',
    Key: { userId },
    ProjectionExpression: 'subscription'
  }).promise();
  
  const subscription = userResult.Item?.subscription || {};
  const monthlyAllowance = subscription.monthlyTokenAllowance || 0;
  const tokensUsedThisMonth = subscription.tokensUsedThisMonth || 0;
  const topUpBalance = subscription.topUpBalance || 0;
  const tokensRemaining = monthlyAllowance - tokensUsedThisMonth;
  
  // Check if subscription object exists - if not, we need to create it first
  const subscriptionExists = userResult.Item?.subscription && Object.keys(userResult.Item.subscription).length > 0;
  
  console.log(`[TokenDeduction] userId=${userId}, need=${tokens}, subscription_remaining=${tokensRemaining}, topup=${topUpBalance}, subscription_exists=${subscriptionExists}`);
  
  // Ensure subscription object exists before updating nested attributes
  if (!subscriptionExists) {
    console.log(`[TokenDeduction] Subscription object doesn't exist, creating it first`);
    await dynamodb.update({
      TableName: 'prod-users',
      Key: { userId },
      UpdateExpression: 'SET subscription = if_not_exists(subscription, :defaultSub)',
      ExpressionAttributeValues: {
        ':defaultSub': {
          tier: 'free',
          status: 'inactive',
          monthlyTokenAllowance: 150,
          tokensUsedThisMonth: 0,
          topUpBalance: 0
        }
      }
    }).promise();
  }
  
  if (tokensRemaining >= tokens) {
    // Use subscription allowance
    console.log(`[TokenDeduction] Using subscription allowance`);
    await dynamodb.update({
      TableName: 'prod-users',
      Key: { userId },
      UpdateExpression: 'ADD subscription.tokensUsedThisMonth :tokens',
      ExpressionAttributeValues: {
        ':tokens': tokens
      }
    }).promise();
  } else if (tokensRemaining + topUpBalance >= tokens) {
    // Use remaining subscription + some top-ups
    const fromTopUp = tokens - tokensRemaining;
    console.log(`[TokenDeduction] Using subscription=${tokensRemaining} + topup=${fromTopUp}`);
    await dynamodb.update({
      TableName: 'prod-users',
      Key: { userId },
      UpdateExpression: 'SET subscription.tokensUsedThisMonth = :monthlyAllowance ADD subscription.topUpBalance :topupDeduct',
      ExpressionAttributeValues: {
        ':monthlyAllowance': monthlyAllowance, // Max out subscription
        ':topupDeduct': -fromTopUp
      }
    }).promise();
  } else {
    // Use only top-ups (subscription exhausted or no subscription)
    console.log(`[TokenDeduction] Using only top-up balance`);
    await dynamodb.update({
      TableName: 'prod-users',
      Key: { userId },
      UpdateExpression: 'ADD subscription.topUpBalance :tokens',
      ExpressionAttributeValues: {
        ':tokens': -tokens
      }
    }).promise();
  }
};

const logUsage = async (userId, usage) => {
  await dynamodb.put({
    TableName: 'prod-genie-usage',
    Item: {
      userId,
      timestamp: usage.timestamp,
      ...usage
    }
  }).promise();
};

// Get subscription plans - matches frontend SubscriptionTiers.swift
const getSubscriptionPlans = async () => {
  return [
    { 
      tier: 'athlete', 
      name: 'Athlete', 
      price: 999, // $9.99/month
      tokens: 500,
      monthly: true
    },
    { 
      tier: 'champion', 
      name: 'Champion', 
      price: 1999, // $19.99/month
      tokens: 1500,
      monthly: true
    },
    { 
      tier: 'legend', 
      name: 'Legend', 
      price: 4999, // $49.99/month
      tokens: 5000,
      monthly: true
    }
  ];
};
