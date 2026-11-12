import SwiftUI

/// Screen 4: past scans, kept on this device only.
struct HistoryScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var history: HistoryStore

    @State private var confirmClear = false

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ScrollView {
                    emptyState
                }
            } else {
                list
            }
        }
        .brandedScreen()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !history.entries.isEmpty {
                    Button(L("history.clear")) { confirmClear = true }
                        .font(AppFont.ui(16, .semibold, relativeTo: .body))
                }
            }
        }
        .alert(L("history.clear.confirm.title"), isPresented: $confirmClear) {
            Button(L("history.clear.confirm.action"), role: .destructive) { history.clear() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("history.clear.confirm.message"))
        }
    }

    // A List, so that rows can be swiped away.
    private var list: some View {
        List {
            Section {
                ForEach(history.entries) { entry in
                    Button {
                        model.reopen(entry)
                    } label: {
                        HistoryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: Theme.screenPadding, bottom: 4, trailing: Theme.screenPadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            history.remove(entry.id)
                        } label: {
                            Label(L("history.delete"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                CardLabel(text: L("history.title"))
                    .padding(.leading, 4)
                    .padding(.bottom, 4)
                    .listRowInsets(EdgeInsets(top: 12, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
            } footer: {
                Text(L("history.note"))
                    .font(AppFont.ui(13.5, .regular, relativeTo: .footnote))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Theme.muted)
                .accessibilityHidden(true)
            Text(L("history.empty.title"))
                .font(AppFont.ui(20, .heavy, relativeTo: .title3))
                .foregroundColor(Theme.ink)
            Text(L("history.empty.message"))
                .font(AppFont.ui(15.5, .regular, relativeTo: .body))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private var title: String {
        if let host = entry.host, !host.isEmpty {
            return host
        }
        let summary = QRClassifier.classify(stored: entry.payload, as: entry.type).summary
        return summary.isEmpty ? entry.type.title : summary
    }

    private var subtitle: String {
        let time = HistoryRow.relativeFormatter.localizedString(for: entry.date, relativeTo: Date())
        if entry.checkFailed {
            return L("history.failed") + " · " + time
        }
        return entry.type.title + " · " + time
    }

    private var dotColor: Color {
        if let verdict = entry.verdict {
            return Theme.color(for: verdict)
        }
        return Theme.line
    }

    private var verdictDescription: String {
        if let verdict = entry.verdict {
            return verdict.headline
        }
        if entry.checkFailed {
            return ""
        }
        return entry.type == .url ? L("history.unchecked") : ""
    }

    var body: some View {
        HStack(spacing: 12) {
            if entry.checkFailed {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.warn)
                    .frame(width: 26)
            } else if entry.type == .url {
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .frame(width: 26)
            } else {
                Image(systemName: entry.type.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(entry.type == .url ? AppFont.mono(15, .semibold) : AppFont.ui(16.5, .semibold, relativeTo: .body))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(AppFont.ui(13.5, .regular, relativeTo: .footnote))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([title, subtitle, verdictDescription].filter { !$0.isEmpty }.joined(separator: ", ")))
    }
}
