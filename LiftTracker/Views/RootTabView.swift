import SwiftUI

struct RootTabView: View {
    @State private var tab = 0

    private let items: [(title: String, icon: String)] = [
        ("Workout", "figure.strengthtraining.traditional"),
        ("History", "calendar"),
        ("Progress", "chart.line.uptrend.xyaxis"),
        ("Settings", "gearshape"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page(WorkoutView(), 0)
                page(HistoryView(), 1)
                page(ProgressScreen(), 2)
                page(SettingsView(), 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(swipe)

            CustomTabBar(selection: $tab, items: items)
        }
        .tint(.red)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
    }

    /// All pages stay mounted; only the current one is visible and interactive.
    private func page<V: View>(_ view: V, _ index: Int) -> some View {
        view
            .opacity(tab == index ? 1 : 0)
            .zIndex(tab == index ? 1 : 0)
            .allowsHitTesting(tab == index)
    }

    /// Horizontal swipe (on non-scrolling areas) moves between pages.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { v in
                guard abs(v.translation.width) > 60, abs(v.translation.height) < 80 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    tab = v.translation.width < 0 ? min(items.count - 1, tab + 1)
                                                  : max(0, tab - 1)
                }
            }
    }
}

/// Bottom tab bar that mirrors the standard look but works with the swipeable page stack.
private struct CustomTabBar: View {
    @Binding var selection: Int
    let items: [(title: String, icon: String)]

    var body: some View {
        HStack {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    selection = i
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].icon).font(.system(size: 20))
                        Text(items[i].title).font(.caption2)
                    }
                    .foregroundStyle(selection == i ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[i].title)
                .accessibilityAddTraits(selection == i ? [.isSelected] : [])
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
    }
}
