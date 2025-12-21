//
//  ShabbosWidgetBundle.swift
//  ShabbosWidget
//
//  Created by Rahul on 21/12/25.
//

import WidgetKit
import SwiftUI

@main
struct ShabbosWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShabbosWidget()
        ShabbosWidgetControl()
        ShabbosWidgetLiveActivity()
    }
}
