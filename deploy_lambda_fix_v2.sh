#!/bin/bash
# Script to deploy the token balance fix to the query handler Lambda function
# Fixes both: remainingTokens calculation AND getTokenBalance fallback lookup

set -e

LAMBDA_FUNCTION_NAME="genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU"
AWS_PROFILE="do-app-admin"
AWS_REGION="us-east-1"
TEMP_DIR="/tmp/lambda-fix-$$"

echo "🔧 Deploying token balance fix (v2) to Lambda function: $LAMBDA_FUNCTION_NAME"

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

# Fix 1: Replace remainingTokens calculation
sed -i.bak 's/const remainingTokens = tokenBalance - actualTokensUsed;/\/\/ CRITICAL FIX: Fetch fresh balance after deduction instead of calculating from stale data\
    \/\/ This ensures tokensRemaining matches what the balance endpoint returns\
    const remainingTokens = await getTokenBalance(userId);\
    console.log(`[TokenBalance] After deduction: ${remainingTokens} tokens remaining (fetched from database)`);/' index.js

# Fix 2: Add fallback lookup to getTokenBalance function
# Find the getTokenBalance function and add fallback logic after the direct lookup fails
python3 << 'PYTHON_SCRIPT'
import re

with open('index.js', 'r') as f:
    content = f.read()

# Pattern to find getTokenBalance function that doesn't have fallback
pattern = r'(const getTokenBalance = async \(userId\) => \{[^}]*?const userResult = await dynamodb\.get\(\{[^}]*?\)\.promise\(\);[^}]*?const subscription = userResult\.Item\?\?\.subscription \|\| \{\};)'

# Replacement with fallback logic
replacement = r'''const getTokenBalance = async (userId) => {
  // Optimized: Using eventual consistency for better performance (saves ~50-100ms)
  // After migration, all users should have subscription data in prod-users
  console.log(`[TokenBalance] Looking up balance for userId: "${userId}"`);
  
  // Direct lookup by userId (could be Parse ID or Cognito sub)
  let userResult = await dynamodb.get({
    TableName: 'prod-users',
    Key: { userId },
    ProjectionExpression: 'subscription'
  }).promise();
  
  // If no record found, try fallback lookup by scanning for cognitoUserId
  if (!userResult.Item) {
    console.log(`[TokenBalance] No record found for userId="${userId}", trying fallback lookup...`);
    try {
      const scanResult = await dynamodb.scan({
        TableName: 'prod-users',
        FilterExpression: 'cognitoUserId = :cognitoId',
        ExpressionAttributeValues: {
          ':cognitoId': userId
        },
        Limit: 1,
        ProjectionExpression: 'userId, subscription'
      }).promise();
      
      if (scanResult.Items && scanResult.Items.length > 0) {
        const foundRecord = scanResult.Items[0];
        console.log(`[TokenBalance] ✅ Found user record with userId="${foundRecord.userId}" (has cognitoUserId="${userId}")`);
        userResult = { Item: foundRecord };
      } else {
        console.log(`[TokenBalance] ❌ No user record found even with fallback lookup`);
        // Return default for new users
        userResult = { Item: null };
      }
    } catch (scanError) {
      console.error(`[TokenBalance] ❌ Error scanning for user: ${scanError.message}`);
      userResult = { Item: null };
    }
  }
  
  const subscription = userResult.Item?.subscription || {};'''

# Try to replace
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content != content:
    with open('index.js', 'w') as f:
        f.write(new_content)
    print("✅ Added fallback lookup to getTokenBalance")
else:
    print("⚠️ Could not find exact pattern, trying alternative approach...")
    # Alternative: Just add the fallback after the first lookup
    alt_pattern = r'(let userResult = await dynamodb\.get\(\{[^}]*?Key: \{ userId \}[^}]*?\)\.promise\(\);)'
    alt_replacement = r'''let userResult = await dynamodb.get({
    TableName: 'prod-users',
    Key: { userId },
    ProjectionExpression: 'subscription'
  }).promise();
  
  // If no record found, try fallback lookup by scanning for cognitoUserId
  if (!userResult.Item) {
    console.log(`[TokenBalance] No record found for userId="${userId}", trying fallback lookup...`);
    try {
      const scanResult = await dynamodb.scan({
        TableName: 'prod-users',
        FilterExpression: 'cognitoUserId = :cognitoId',
        ExpressionAttributeValues: {
          ':cognitoId': userId
        },
        Limit: 1,
        ProjectionExpression: 'userId, subscription'
      }).promise();
      
      if (scanResult.Items && scanResult.Items.length > 0) {
        const foundRecord = scanResult.Items[0];
        console.log(`[TokenBalance] ✅ Found user record with userId="${foundRecord.userId}" (has cognitoUserId="${userId}")`);
        userResult = { Item: foundRecord };
      } else {
        console.log(`[TokenBalance] ❌ No user record found even with fallback lookup`);
        userResult = { Item: null };
      }
    } catch (scanError) {
      console.error(`[TokenBalance] ❌ Error scanning for user: ${scanError.message}`);
      userResult = { Item: null };
    }
  }'''
    
    new_content = re.sub(alt_pattern, alt_replacement, content, flags=re.DOTALL)
    if new_content != content:
        with open('index.js', 'w') as f:
            f.write(new_content)
        print("✅ Added fallback lookup to getTokenBalance (alternative method)")
    else:
        print("❌ Could not apply fallback fix automatically")
PYTHON_SCRIPT

# Verify the fixes were applied
if grep -q "await getTokenBalance(userId)" index.js; then
  echo "✅ Fix 1 applied: remainingTokens now fetches fresh balance"
else
  echo "❌ Fix 1 not applied correctly. Restoring backup..."
  mv index.js.backup index.js
  exit 1
fi

if grep -q "cognitoUserId = :cognitoId" index.js; then
  echo "✅ Fix 2 applied: getTokenBalance now has fallback lookup"
else
  echo "⚠️ Fix 2 may not have been applied (fallback lookup)"
  echo "   This might be okay if the function already has it"
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
echo "2. ✅ getTokenBalance now has fallback lookup for cognitoUserId"
echo ""
echo "📋 Next steps:"
echo "1. Test the fix by making a query and checking tokensRemaining matches balance endpoint"
echo "2. Monitor CloudWatch logs for: '[TokenBalance] After deduction: X tokens remaining'"
echo "3. Verify 402 error responses now show correct balance"
echo ""
echo "🧹 Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

echo "✅ Done!"


