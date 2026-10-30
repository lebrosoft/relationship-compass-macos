import SwiftUI
import PeoplebookKit

@main
struct PeoplebookApp: App {
    @State private var model = AppModel.make()

    var body: some Scene {
        WindowGroup("人脉簿") {
            ContentView()
                .environment(model)
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 700)
    }
}
