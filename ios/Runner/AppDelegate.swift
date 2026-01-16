import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for flutter_local_notifications
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    
    // Request notification permissions for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    // Debug: Check if sound files are in bundle
    self.verifySoundFilesInBundle()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Verify sound files are accessible in bundle
  func verifySoundFilesInBundle() {
    let soundFiles = [
      "RavShalomShofarDefaultlouder.caf",
      "RYomTovShabbatShalomSong.caf",
      "YomTov-Default.caf",
      "Ata Bechartanu-YomTov.caf",
      "Ata Bechartanu2-YomTov.caf",
      "HoduLaHashem-YomTov.caf"
    ]
    
    print("ShabbosApp: Verifying sound files in bundle...")
    var foundCount = 0
    
    for soundFile in soundFiles {
      // Check in bundle root
      if let path = Bundle.main.path(forResource: soundFile.replacingOccurrences(of: ".caf", with: ""), ofType: "caf") {
        print("ShabbosApp: ✓ Found \(soundFile) at: \(path)")
        foundCount += 1
      } else {
        // Check in Sounds folder
        if let soundsPath = Bundle.main.path(forResource: "Sounds", ofType: nil),
           FileManager.default.fileExists(atPath: "\(soundsPath)/\(soundFile)") {
          print("ShabbosApp: ✓ Found \(soundFile) in Sounds folder")
          foundCount += 1
        } else {
          print("ShabbosApp: ✗ NOT FOUND: \(soundFile)")
          print("ShabbosApp:   Bundle path: \(Bundle.main.bundlePath)")
        }
      }
    }
    
    print("ShabbosApp: Found \(foundCount)/\(soundFiles.count) sound files in bundle")
    if foundCount == 0 {
      print("ShabbosApp: ⚠️ WARNING: No sound files found in bundle!")
      print("ShabbosApp:   Ensure .caf files are added to Xcode project")
      print("ShabbosApp:   Check: Build Phases → Copy Bundle Resources")
    }
  }
  
  // Handle notification when app is in foreground
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("ShabbosApp: Notification received in foreground")
    print("ShabbosApp: Notification ID: \(notification.request.identifier)")
    
    // Note: UNNotificationSound doesn't expose the filename directly
    // iOS will play the sound automatically if it's configured in the notification
    // We can try to extract it from the userInfo if needed, but for scheduled notifications,
    // iOS handles the sound playback automatically when the notification fires
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
  
  // Handle notification tap or when notification fires in background
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("ShabbosApp: Notification response received")
    print("ShabbosApp: Notification ID: \(response.notification.request.identifier)")
    
    // Note: For scheduled notifications, iOS automatically plays the sound when they fire
    // This method is called when the user taps the notification
    // The sound has already been played by iOS when the notification appeared
    
    completionHandler()
  }
  
  // Note: iOS automatically plays notification sounds when scheduled notifications fire
  // We don't need to manually play sounds here - iOS handles it natively
  // The sound files just need to be:
  // 1. In .caf, .wav, or .aiff format (NOT .mp3)
  // 2. Added to the Xcode project bundle
  // 3. Referenced correctly in the notification details
}
