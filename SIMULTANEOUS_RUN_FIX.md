# Fix for Simultaneous App Execution

I have aligned the project configuration with the reference `DoIOS` project to resolve the issue where running one app would kill the other.

## Key Findings & Fixes

1.  **Product Name Conflict Resolved**
    -   **Problem**: Both the iOS app and the Watch app were configured to output a product named `Do.app`. This caused a collision in the build directory and simulator installation.
    -   **Fix**: Renamed the Watch App's product reference to `Do Watch App.app` (matching the target name and reference project style). Updated all references in the project file.
    -   **Important Update**: Explicitly added `PRODUCT_NAME = "Do Watch App"` to the Watch App build settings to prevent Xcode from reverting the scheme configuration.

2.  **Watch App Installation Settings**
    -   **Problem**: `SKIP_INSTALL` was set to `YES` for the Watch App.
    -   **Fix**: Changed `SKIP_INSTALL` to `NO` to match the reference project. This ensures the watch app is properly staged for embedding.

3.  **Embedding Phase Restored**
    -   **Problem**: The "Embed Watch Content" build phase was set to run only during archiving (`runOnlyForDeploymentPostprocessing = 1`).
    -   **Fix**: Changed it back to `0` (run on all builds) to ensure the watch app is always embedded, which is the standard configuration for a companion app.

4.  **Target Dependencies Restored**
    -   **Problem**: The explicit dependency of the iOS app on the Watch app was missing.
    -   **Fix**: Re-added the `PBXTargetDependency` to the iOS target. This ensures Xcode builds the watch app before the iOS app.

5.  **Scheme Configuration Reset**
    -   **Problem**: Schemes were modified to avoid building dependencies.
    -   **Fix**: Restored `buildImplicitDependencies = "YES"` and added the Watch App back to the iOS scheme's build action. This allows Xcode to correctly manage the build graph.

## Verification

These changes ensure that:
-   The Watch App is built as `Do Watch App.app`.
-   The iOS App is built as `Do.app`.
-   The Watch App is embedded into the iOS App during the build.
-   Xcode treats them as related but distinct products, preventing the "kill on install" behavior caused by product name collisions.

**If Xcode prompts you about changes to the project file, please accept them or reload the project.** You should now be able to run the iOS app (Command-R) and the Watch app simultaneously in the simulator.
