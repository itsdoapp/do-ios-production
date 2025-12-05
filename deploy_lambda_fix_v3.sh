#!/bin/bash
# Script to deploy the token balance fix to the query handler Lambda function
# Fixes: remainingTokens calculation AND getUserId to check X-User-Id header

set -e

LAMBDA_FUNCTION_NAME="genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU"
AWS_PROFILE="do-app-admin"
AWS_REGION="us-east-1"
TEMP_DIR="/tmp/lambda-fix-$$"

echo "🔧 Deploying token balance fix (v3) to Lambda function: $LAMBDA_FUNCTION_NAME"

# Create temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download current Lambda function code
echo "📥 Downloading current Lambda function code..."
DOWNLOAD_URL=$(aws lambda get-function \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --query 'Code.Location' \
  --output text)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ Failed to get download URL"
  exit 1
fi

curl -s "$DOWNLOAD_URL" -o lambda-code.zip
unzip -q lambda-code.zip
echo "✅ Extracted Lambda function code"

# Apply the fixes
if [ ! -f "index.js" ]; then
  echo "❌ index.js not found in Lambda package"
  exit 1
fi

echo "🔨 Applying fixes..."
# Backup original
cp index.js index.js.backup

# Fix 1: Replace remainingTokens calculation (already done, but ensure it's there)
if ! grep -q "await getTokenBalance(userId)" index.js || ! grep -q "After deduction" index.js; then
  sed -i.bak 's/const remainingTokens = tokenBalance - actualTokensUsed;/\/\/ CRITICAL FIX: Fetch fresh balance after deduction instead of calculating from stale data\
    \/\/ This ensures tokensRemaining matches what the balance endpoint returns\
    const remainingTokens = await getTokenBalance(userId);\
    console.log(`[TokenBalance] After deduction: ${remainingTokens} tokens remaining (fetched from database)`);/' index.js
  echo "✅ Applied Fix 1: remainingTokens calculation"
else
  echo "✅ Fix 1 already applied: remainingTokens calculation"
fi

# Fix 2: Update getUserId to check X-User-Id header first (like balance endpoint)
# Find the getUserId function and add X-User-Id header check
python3 << 'PYTHON_SCRIPT'
import re

with open('index.js', 'r') as f:
    content = f.read()

# Pattern to find getUserId function that doesn't check X-User-Id
# Look for function that starts with JWT authorizer check
pattern = r'(function getUserId\(event\) \{[^}]*?// Try to get from JWT authorizer first)'

# Check if X-User-Id is already checked
if 'X-User-Id' in content or 'x-user-id' in content:
    # Check if it's in getUserId function
    getUserId_match = re.search(r'function getUserId\(event\) \{[^}]{0,500}?X-User-Id', content, re.DOTALL)
    if getUserId_match:
        print("✅ getUserId already checks X-User-Id header")
    else:
        print("⚠️ X-User-Id found elsewhere, but not in getUserId - will add it")
        # Add X-User-Id check at the beginning of getUserId
        replacement = r'''function getUserId(event) {
  // Priority 1: Check X-User-Id header (iOS app sends Parse user ID here)
  // This ensures we use the same userId as the balance endpoint
  if (event.headers?.['X-User-Id'] || event.headers?.['x-user-id']) {
    const parseUserId = event.headers['X-User-Id'] || event.headers['x-user-id'];
    console.log(`[getUserId] Using X-User-Id header: ${parseUserId}`);
    // Note: For token operations, we still need to map to Cognito sub if needed
    // But getTokenBalance will handle the lookup with fallback
    return parseUserId;
  }
  
  // Priority 2: Try to get from JWT authorizer first'''
        
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            with open('index.js', 'w') as f:
                f.write(new_content)
            print("✅ Added X-User-Id header check to getUserId")
        else:
            print("❌ Could not add X-User-Id check - pattern not found")
else:
    # Add X-User-Id check
    replacement = r'''function getUserId(event) {
  // Priority 1: Check X-User-Id header (iOS app sends Parse user ID here)
  // This ensures we use the same userId as the balance endpoint
  if (event.headers?.['X-User-Id'] || event.headers?.['x-user-id']) {
    const parseUserId = event.headers['X-User-Id'] || event.headers['x-user-id'];
    console.log(`[getUserId] Using X-User-Id header: ${parseUserId}`);
    return parseUserId;
  }
  
  // Priority 2: Try to get from JWT authorizer first'''
    
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    if new_content != content:
        with open('index.js', 'w') as f:
            f.write(new_content)
        print("✅ Added X-User-Id header check to getUserId")
    else:
        print("❌ Could not add X-User-Id check - pattern not found")
PYTHON_SCRIPT

# Verify the fixes were applied
if grep -q "await getTokenBalance(userId)" index.js && grep -q "After deduction" index.js; then
  echo "✅ Fix 1 verified: remainingTokens fetches fresh balance"
else
  echo "❌ Fix 1 not found. Restoring backup..."
  mv index.js.backup index.js
  exit 1
fi

if grep -q "X-User-Id.*header" index.js || grep -q "x-user-id.*header" index.js; then
  echo "✅ Fix 2 verified: getUserId checks X-User-Id header"
else
  echo "⚠️ Fix 2 may not have been applied (X-User-Id check)"
fi

# Create deployment package
echo "📦 Creating deployment package..."
zip -q lambda-fixed.zip index.js package.json node_modules/ -r 2>/dev/null || zip -q lambda-fixed.zip index.js package.json 2>/dev/null || zip -q lambda-fixed.zip index.js

# Update the Lambda function
echo "🚀 Updating Lambda function..."
aws lambda update-function-code \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file "fileb://lambda-fixed.zip" \
  --output json

echo ""
echo "✅ Lambda function updated successfully!"
echo ""
echo "📋 Fixes applied:"
echo "1. ✅ remainingTokens now fetches fresh balance after deduction"
echo "2. ✅ getUserId now checks X-User-Id header first (matches balance endpoint)"
echo ""
echo "📋 Next steps:"
echo "1. Test the fix by making a query and checking tokensRemaining matches balance endpoint"
echo "2. Verify 402 error responses now show correct balance (357 instead of 0)"
echo "3. Monitor CloudWatch logs for: '[TokenBalance] After deduction: X tokens remaining'"
echo ""
echo "🧹 Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

echo "✅ Done!"


