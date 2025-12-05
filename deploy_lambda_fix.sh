#!/bin/bash
# Script to deploy the token balance fix to the query handler Lambda function

set -e

LAMBDA_FUNCTION_NAME="genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU"
AWS_PROFILE="do-app-admin"
AWS_REGION="us-east-1"
TEMP_DIR="/tmp/lambda-fix-$$"

echo "🔧 Deploying token balance fix to Lambda function: $LAMBDA_FUNCTION_NAME"

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

# Apply the fix
if [ ! -f "index.js" ]; then
  echo "❌ index.js not found in Lambda package"
  exit 1
fi

echo "🔨 Applying fix..."
# Backup original
cp index.js index.js.backup

# Replace the line that calculates remainingTokens from stale data
# Find the line: const remainingTokens = tokenBalance - actualTokensUsed;
# Replace with: const remainingTokens = await getTokenBalance(userId);

sed -i.bak 's/const remainingTokens = tokenBalance - actualTokensUsed;/\/\/ CRITICAL FIX: Fetch fresh balance after deduction instead of calculating from stale data\
    \/\/ This ensures tokensRemaining matches what the balance endpoint returns\
    const remainingTokens = await getTokenBalance(userId);\
    console.log(`[TokenBalance] After deduction: ${remainingTokens} tokens remaining (fetched from database)`);/' index.js

# Verify the fix was applied
if grep -q "await getTokenBalance(userId)" index.js; then
  echo "✅ Fix applied successfully"
else
  echo "❌ Fix not applied correctly. Restoring backup..."
  mv index.js.backup index.js
  exit 1
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
echo "📋 Next steps:"
echo "1. Test the fix by making a query and checking tokensRemaining matches balance endpoint"
echo "2. Monitor CloudWatch logs for the new log message: '[TokenBalance] After deduction: X tokens remaining'"
echo ""
echo "🧹 Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

echo "✅ Done!"


