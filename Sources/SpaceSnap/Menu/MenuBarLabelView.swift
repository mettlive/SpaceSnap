import SwiftUI

struct MenuBarLabelView: View {
    let model: AppModel

    var body: some View {
        if model.settings.showsSpaceNumberInMenuBar,
           let spaces = model.activeSpaces,
           spaces.currentSpace.kind == .desktop,
           let number = spaces.currentDesktopNumber {
            Text("\(number)")
        } else {
            Image(systemName: "rectangle.on.rectangle")
        }
    }
}
