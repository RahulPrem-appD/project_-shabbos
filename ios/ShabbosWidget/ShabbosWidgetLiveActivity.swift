//
//  ShabbosWidgetLiveActivity.swift
//  ShabbosWidget
//
//  Created by Rahul on 21/12/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShabbosWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ShabbosWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShabbosWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ShabbosWidgetAttributes {
    fileprivate static var preview: ShabbosWidgetAttributes {
        ShabbosWidgetAttributes(name: "World")
    }
}

extension ShabbosWidgetAttributes.ContentState {
    fileprivate static var smiley: ShabbosWidgetAttributes.ContentState {
        ShabbosWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ShabbosWidgetAttributes.ContentState {
         ShabbosWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ShabbosWidgetAttributes.preview) {
   ShabbosWidgetLiveActivity()
} contentStates: {
    ShabbosWidgetAttributes.ContentState.smiley
    ShabbosWidgetAttributes.ContentState.starEyes
}
