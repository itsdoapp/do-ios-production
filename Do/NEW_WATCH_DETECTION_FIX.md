# New Apple Watch Not Showing in Xcode - Fix Guide

## Quick Steps to Make Your Watch Appear in Xcode

### 1. **Verify Watch is Paired with iPhone**

First, ensure your watch is properly paired:
- On your **iPhone**, open the **Watch** app
- Check **"My Watch"** tab
- Your Apple Watch should appear at the top
- If not paired, follow the pairing process first

### 2. **Check Watch is Unlocked and On**

- Ensure your Apple Watch is **unlocked** (not showing lock screen)
- Ensure it's **powered on** and not in sleep mode
- Wake it up by raising your wrist or tapping the screen

### 3. **Check Xcode Device List**

1. **Open Xcode**
2. **Window → Devices and Simulators** (⇧⌘2)
3. In the left sidebar, look for:
   - Your **iPhone** (should be listed)
   - Your **Apple Watch** (should appear under or near your iPhone)

### 4. **If Watch Doesn't Appear in Xcode**

Try these steps in order:

#### Step A: Restart Devices
1. **Restart your iPhone**
2. **Restart your Apple Watch** (hold side button → Power Off)
3. **Restart Xcode**
4. Check Devices and Simulators again

#### Step B: Trust Computer on iPhone
1. Connect iPhone to Mac via USB
2. On iPhone, if prompted: **"Trust This Computer"**
3. Enter your iPhone passcode
4. This allows Xcode to see paired devices

#### Step C: Check Watch Connection
1. On iPhone: **Watch app → My Watch**
2. Ensure watch shows as **"Connected"** (not disconnected)
3. If disconnected, wait for it to reconnect
4. Both devices should be on same Wi-Fi or use Bluetooth

#### Step D: Enable Developer Mode (watchOS 9+)
If your watch is running watchOS 9 or later:

1. **On Apple Watch:**
   - Settings → Privacy & Security
   - Scroll to **Developer Mode**
   - Toggle **ON**
   - Watch will restart

2. **After restart:**
   - Confirm you want to enable Developer Mode
   - Watch will restart again

3. **Verify in Xcode:**
   - Devices and Simulators should now show your watch

### 5. **Check Xcode Preferences**

1. **Xcode → Settings → Platforms**
2. Ensure watchOS platform is downloaded/installed
3. If missing, click **"Get"** to download

### 6. **Verify Watch is Discoverable**

1. **On iPhone:**
   - Settings → Bluetooth
   - Ensure Bluetooth is ON
   - Your watch should appear in "My Devices"

2. **On Apple Watch:**
   - Settings → General → About
   - Note the watchOS version
   - Ensure it's watchOS 10.0+ (matches your deployment target)

### 7. **Force Xcode to Refresh Devices**

1. **Quit Xcode completely** (⌘Q)
2. **Disconnect iPhone from Mac** (if connected via USB)
3. **Reconnect iPhone** (if using USB)
4. **Open Xcode**
5. **Window → Devices and Simulators** (⇧⌘2)
6. Click the **refresh button** (circular arrow) if available
7. Or close and reopen the window

### 8. **Check for Trust Issues**

If you see "Untrusted Developer" or similar:

1. **On iPhone:**
   - Settings → General → VPN & Device Management
   - Look for your developer certificate
   - Tap **"Trust"** if needed

2. **On Apple Watch:**
   - Settings → General → Profiles & Device Management
   - Trust your developer profile if present

### 9. **Verify Watch Appears in Console**

1. **Xcode → Window → Devices and Simulators**
2. Select your **iPhone**
3. Check the console/logs for any watch-related errors
4. Look for messages about watch pairing or connection

### 10. **Alternative: Build Without Selecting Watch**

Even if watch doesn't appear in Xcode device list, you can still build:

1. **Select "Do" scheme** (iOS app)
2. **Choose your iPhone** as destination
3. **Build and Run** (⌘R)
4. The watch app should install automatically to your paired watch
5. Check Watch app on iPhone → My Watch → Do → Install

## Common Issues

### Issue: "Watch not paired"
**Solution:** Pair watch with iPhone first via Watch app

### Issue: "Watch locked"
**Solution:** Unlock your Apple Watch

### Issue: "Developer Mode not enabled"
**Solution:** Enable Developer Mode on watch (watchOS 9+)

### Issue: "Watch not on same network"
**Solution:** Ensure both devices on same Wi-Fi or use Bluetooth

### Issue: "Xcode can't see paired devices"
**Solution:** Trust computer on iPhone, restart Xcode

## Quick Checklist

- [ ] Watch is paired with iPhone (check Watch app)
- [ ] Watch is unlocked and powered on
- [ ] iPhone is unlocked
- [ ] Both devices on same Wi-Fi or Bluetooth connected
- [ ] Developer Mode enabled on watch (watchOS 9+)
- [ ] iPhone trusted computer on Mac
- [ ] Xcode restarted
- [ ] Check Devices and Simulators window (⇧⌘2)

## Still Not Working?

1. **Check watchOS version:**
   - On watch: Settings → General → About
   - Must be watchOS 10.0+ for your deployment target

2. **Try manual installation:**
   - Build iOS app normally
   - On iPhone: Watch app → My Watch → Do → Install

3. **Check Xcode console:**
   - Look for specific error messages
   - May indicate pairing or trust issues

4. **Reset watch pairing (last resort):**
   - Unpair watch from iPhone
   - Pair again
   - This will reset all connections

## Important Notes

- **You don't need to select the watch in Xcode** - just build from iPhone
- The watch app installs automatically when you build the iOS app
- If watch doesn't appear in Xcode but is paired, you can still build and install
- Developer Mode is only needed for watchOS 9+ and for debugging on watch

