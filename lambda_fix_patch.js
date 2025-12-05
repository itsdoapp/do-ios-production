// PATCH for genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU
// Fix: Replace line ~2645 to fetch fresh balance after deduction

// OLD CODE (around line 2645):
/*
    const remainingTokens = tokenBalance - actualTokensUsed;
*/

// NEW CODE:
// CRITICAL FIX: Fetch fresh balance after deduction instead of calculating from stale data
// This ensures tokensRemaining matches what the balance endpoint returns
const remainingTokens = await getTokenBalance(userId);
console.log(`[TokenBalance] After deduction: ${remainingTokens} tokens remaining (fetched from database)`);


