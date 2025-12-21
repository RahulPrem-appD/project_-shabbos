# iOS Live Activity Setup Guide

To enable the countdown timer on iOS Lock Screen and Dynamic Island, you need to add a Widget Extension in Xcode.

## Steps to Set Up

### 1. Open the iOS project in Xcode
```bash
cd ios
open Runner.xcworkspace
```

### 2. Add Widget Extension Target
1. In Xcode, go to **File > New > Target**
2. Search for and select **Widget Extension**
3. Click **Next**
4. Configure the target:
   - **Product Name**: `ShabbosWidget`
   - **Team**: Select your development team
   - **Bundle Identifier**: `com.shabbos.shabbosApp.ShabbosWidget`
   - **Include Live Activity**: ✅ Check this box
   - **Include Configuration App Intent**: ❌ Uncheck this
5. Click **Finish**
6. When asked to activate the scheme, click **Activate**

### 3. Configure App Group
1. Select the **Runner** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Add a new App Group: `group.com.shabbos.shabbosApp`
6. Repeat steps 1-5 for the **ShabbosWidget** target

### 4. Update Widget Extension Code
Replace the content of `ShabbosWidget/ShabbosWidgetLiveActivity.swift` with the code from `ShabbosWidgetExtension/ShabbosWidgetExtension.swift` in this folder.

### 5. Set Minimum iOS Version
1. Select the **ShabbosWidget** target
2. Go to **General**
3. Set **Minimum Deployments** to **iOS 16.2** or higher

### 6. Update Info.plist in Widget Extension
Make sure the Widget Extension's Info.plist includes:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 7. Clean and Build
1. Clean the build: **Product > Clean Build Folder** (Cmd+Shift+K)
2. Build the project: **Product > Build** (Cmd+B)

## How the Countdown Works

1. When the first alarm (pre-notification) fires, the app starts a Live Activity
2. The Live Activity shows:
   - **Lock Screen**: Countdown timer to candle lighting time
   - **Dynamic Island** (iPhone 14 Pro+): Compact countdown display
3. The countdown updates in real-time
4. When candle lighting time arrives, the Live Activity ends

## Troubleshooting

- **Live Activity not showing**: Make sure Live Activities are enabled in Settings > Face ID & Passcode > Allow Access When Locked > Live Activities
- **App Group error**: Ensure both Runner and ShabbosWidget have the same App Group configured
- **Build error**: Clean build folder and try again

## Note

Live Activities require iOS 16.2+. On older iOS versions, the app will still show regular notifications but without the live countdown feature.

