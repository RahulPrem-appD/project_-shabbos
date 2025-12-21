import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity Attributes
// These attributes match the data sent from Flutter via live_activities package
@available(iOS 16.2, *)
struct ShabbosActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Maps to the data dictionary sent from Flutter
        var candleLightingTime: Int  // milliseconds since epoch
        var eventName: String
        var isYomTov: Bool
        var eventType: String
        
        // Computed property to get Date from milliseconds
        var candleLightingDate: Date {
            return Date(timeIntervalSince1970: TimeInterval(candleLightingTime) / 1000.0)
        }
    }
    
    // Static attributes (don't change during the activity)
    var activityId: String
}

// MARK: - Live Activity Widget
@available(iOS 16.2, *)
struct ShabbosLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShabbosActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(context.state.isYomTov ? "Yom Tov" : "Shabbos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.candleLightingDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.eventName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text(context.state.candleLightingDate, style: .timer)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        Text("until candle lighting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(context.state.candleLightingDate, style: .timer)
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundColor(.orange)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let state: ShabbosActivityAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Icon and event info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text(state.isYomTov ? "Yom Tov" : "Shabbos")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(state.eventName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right: Countdown timer
            VStack(alignment: .trailing, spacing: 4) {
                Text(state.candleLightingDate, style: .timer)
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.orange)
                
                HStack(spacing: 4) {
                    Text("🕯️")
                    Text(state.candleLightingDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget Bundle
@main
struct ShabbosWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ShabbosLiveActivity()
        }
    }
}

