# Lambda Function Fix: Token Balance Mismatch

## Problem
The query handler calculates `tokensRemaining` incorrectly by using the pre-deduction balance:
```javascript
const remainingTokens = tokenBalance - actualTokensUsed;
```

This causes a mismatch because:
1. `tokenBalance` is fetched BEFORE tokens are deducted
2. `deductTokens()` updates the database
3. `remainingTokens` is calculated from stale data
4. The balance endpoint reads the updated database value, showing a different balance

## Solution
After deducting tokens, fetch the fresh balance from the database instead of calculating it.

## File to Modify
AWS Lambda: `genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU`

## Code Change

### Current Code (around line 2370):
```javascript
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

const remainingTokens = tokenBalance - actualTokensUsed;
```

### Fixed Code:
```javascript
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
```

## Additional Fix: User ID Consistency

The balance function checks `X-User-Id` header first, but the query handler doesn't. For consistency, update the query handler's `getUserId` function to also check `X-User-Id` header:

### Current getUserId in query handler (around line 2200):
```javascript
function getUserId(event) {
  // Try to get from JWT authorizer first (when auth is enabled)
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
```

### Updated getUserId (optional, for consistency):
```javascript
function getUserId(event) {
  // Priority 1: Check X-User-Id header (iOS app sends Parse user ID here)
  // Note: This should map to Cognito sub for token operations
  if (event.headers?.['X-User-Id'] || event.headers?.['x-user-id']) {
    const parseUserId = event.headers['X-User-Id'] || event.headers['x-user-id'];
    console.log(`[getUserId] X-User-Id header found: ${parseUserId}`);
    // If X-User-Id is provided, we still need to use Cognito sub for token operations
    // The balance function uses X-User-Id directly, but query handler uses Cognito sub
    // For now, continue using Cognito sub for consistency with token storage
  }
  
  // Priority 2: Try to get from JWT authorizer (when auth is enabled)
  if (event.requestContext?.authorizer?.jwt?.claims) {
    const claims = event.requestContext.authorizer.jwt.claims;
    console.log(`[Auth] Using Cognito sub: ${claims.sub}`);
    return claims.sub;
  }
  
  // Priority 3: Decode JWT from Authorization header manually (when auth is disabled)
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
```

**Note**: The user ID consistency fix is optional. The main fix is the `remainingTokens` calculation change.

## Testing
1. Make a query that uses tokens
2. Check the `tokensRemaining` value in the query response
3. Immediately call the balance endpoint
4. Both should return the same value

## Deployment

### Option 1: Automated Deployment Script
Run the provided script to automatically download, fix, and deploy:
```bash
./deploy_lambda_fix.sh
```

### Option 2: Manual Deployment
1. Download the Lambda function code from AWS
2. Apply the fix manually (replace line ~2645)
3. Zip and upload the updated code
4. Test with a real user account
5. Verify both endpoints return matching balances

## Status
- ✅ iOS App: Fixed (trusts balance endpoint)
- ⏳ Lambda Function: **Needs deployment** (use script above or manual deployment)

