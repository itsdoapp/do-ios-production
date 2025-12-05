# Backend Fix Instructions

The AWS Lambda function `genie-agent-prod-QueryHandlerFunction-2YLHH30v5fgU` was failing because it was missing several required modules (`conversationCache`, `intentDetector`, etc.) in the deployment package.

We have fixed this directly on AWS by inlining robust implementations of these modules into `index.js`.

## ⚠️ Critical Next Step

To prevent this fix from being overwritten by future deployments, you must update your backend source repository.

### 1. Locate Backend Repo
Find the repository containing the source code for the `QueryHandlerFunction`.

### 2. Update `index.js`
Replace the `index.js` in your backend repo with the fixed version saved at:
`backend_fix/index.js`

### 3. Verify Dependencies
Ensure your backend build process includes all necessary files. The issue was likely caused by a build script that only zipped `index.js` and ignored other local modules.

### 4. What Changed in `index.js`?
- **Inlined Modules**: Replaced `require('./module')` with actual code for:
  - `buildUserProfile` (fetches from DynamoDB `prod-users`)
  - `refreshFromDynamoDB` (fetches from `prod-genie-messages`)
  - `detectConversationIntent` (basic keyword detection)
- **Fixed Bugs**:
  - Removed duplicate function declarations.
  - Fixed DynamoDB query key (`conversationId` vs `sessionId`).
  - Added default `metadata` to user profiles.
  - Added missing `getUserProfile` and `updateProfileFromConversation` aliases.

## iOS App Changes (Already Committed)
The iOS app has been updated to:
1. Send `X-User-Id` header with all queries (ensures consistent balance lookup).
2. Use optimistic updates for instant UI feedback.
3. Fix the token purchase sheet showing 0 balance.
