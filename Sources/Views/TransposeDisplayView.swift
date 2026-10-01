import SwiftUI

struct TransposeDisplayView: View {
    @EnvironmentObject private var controller: TransposeController

    var body: some View {
        let style: HierarchicalShapeStyle = controller.offset == 0 ? .secondary : .primary
        VStack(spacing: 0) {
            Text(controller.keyName)
                .font(.system(size: 96, weight: .bold))
                .lineLimit(1)
            Text(controller.offsetLabel)
                .font(.system(size: 36, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(style)
        .frame(minWidth: 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(controller.keyName)、\(controller.offsetLabel)")
    }
}
