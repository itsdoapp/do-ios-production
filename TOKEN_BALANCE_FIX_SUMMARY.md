# Token Balance Mismatch - Fix Summary

## Problem Identified

The token balance API endpoint and the query endpoint were returning different values because:

1. **Query Handler Bug**: Calculates `tokensRemaining` from pre-deduction balance
   - Fetches balance BEFORE deducting tokens
   - Deducts tokens (updates database)
   - Calculates `remainingTokens = tokenBalance - actualTokensUsed` using OLD balance
   - Returns stale value that doesn't match database

2. **Balance Endpoint**: Correctly reads from database after tokens are deducted
   - Shows accurate balance

3. **iOS App Workaround**: Had backwards logic preferring query endpoint balance
   - This was masking the real issue

## Root Causes

1. **Race Condition**: Query handler calculates remaining tokens from stale data instead of fetching fresh balance after deduction
2. **User ID Handling**: Both endpoints handle user IDs correctly with fallback logic, but query handler doesn't check `X-User-Id` header (not critical since it uses Cognito sub which is correct)

## Fixes Applied

### ✅ 1. iOS App Fix (Completed)
**File**: `Do/Core/Services/Genie/GenieAPIService.swift`

**Changes**:
- Removed workaround that preferred query endpoint balance over balance endpoint
- Now trusts balance endpoint as authoritative source
- Updated cache logic to use balance endpoint value

**Lines Changed**: 515-544

### ✅ 2. Lambda Function Fix (Documented)
**File**: `LAMBDA_FIX_TOKEN_BALANCE.md`

**Required Change**:
- After `deductTokens()`, fetch fresh balance: `const remainingTokens = await getTokenBalance(userId);`
- This ensures `tokensRemaining` matches what balance endpoint returns

**Lambda Function**: `genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU`
**Approximate Line**: ~2370

### ✅ 3. User ID Consistency (Verified)
- **Query Handler**: Uses Cognito sub directly (from JWT) - correct for token operations
- **Balance Handler**: Checks `X-User-Id` header first, then Cognito sub, with fallback scan by `cognitoUserId`
- Both endpoints correctly handle user lookup with appropriate fallbacks
- No changes needed (both work correctly)

### ✅ 4. Database Structure (Verified)
**Table**: `prod-users`
**Key**: `userId` (HASH)
**Token Storage**: 
- `subscription.tokensUsedThisMonth` - Monthly subscription usage
- `subscription.topUpBalance` - Purchased top-up tokens
- `subscription.monthlyTokenAllowance` - Monthly allowance from subscription
- `subscription.tier` - Subscription tier

**Balance Calculation**:
```javascript
const subscriptionRemaining = Math.max(0, monthlyAllowance - tokensUsedThisMonth);
const totalAvailable = Math.max(0, subscriptionRemaining + topUpBalance);
```

This is correct and matches what both endpoints should return.

## Testing Plan

1. **Before Fix**:
   - Make a query that uses tokens
   - Query response `tokensRemaining` ≠ Balance endpoint `balance`
   
2. **After Fix**:
   - Make a query that uses tokens
   - Query response `tokensRemaining` = Balance endpoint `balance`
   - Both should match exactly

3. **Edge Cases to Test**:
   - User with subscription only
   - User with top-up tokens only
   - User with both subscription and top-ups
   - User with exhausted subscription (using top-ups)
   - Concurrent queries (race conditions)

## Deployment Steps

1. ✅ **iOS App**: Fixed in codebase (GenieAPIService.swift lines 515-531)
2. ⏳ **Lambda Function**: **REQUIRES DEPLOYMENT**
   - **Option A**: Run automated script: `./deploy_lambda_fix.sh`
   - **Option B**: Manual deployment (see `LAMBDA_FIX_TOKEN_BALANCE.md`)
   - Function: `genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU`
   - Change: Replace line ~2645 to fetch fresh balance after deduction
   - Test with real user account after deployment

## Files Modified

1. `Do/Core/Services/Genie/GenieAPIService.swift` - iOS app fix
2. `LAMBDA_FIX_TOKEN_BALANCE.md` - Lambda fix instructions (new file)

## Expected Outcome

After deploying the Lambda fix:
- Query endpoint `tokensRemaining` will match balance endpoint `balance`
- iOS app will display consistent balance values
- No more discrepancies between endpoints

