//
//  FiltersPanelView.swift
//  GLogo
//
//  概要:
//  フィルターパネルのモード選択シェル。
//  Standard(SDR) と HDR の切替UIを提供し、実体ビューは各モード専用ファイルへ委譲する。
//

import SwiftUI

private enum FilterPanelMode: String, CaseIterable, Identifiable {
    case standard
    case hdr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .hdr:
            return "HDR"
        }
    }
}

struct FiltersPanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void

    @State private var selectedMode: FilterPanelMode = .standard

    /// Expose adjustment fingerprint for tests and other callers.
    /// This forwards to the SDR implementation, which hashes manual adjustment values.
    static func adjustmentFingerprint(for img: ImageElement) -> Int {
        FiltersPanelSDRView.adjustmentFingerprint(for: img)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            modeSelector
            modeContent
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Button("Reset") {
                viewModel.resetFilterPresets()
            }
            .font(.subheadline.weight(.semibold))
            .disabled(viewModel.appliedFilterPresetId == nil)

            Spacer()

            Text("Filters")
                .font(.headline)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var modeSelector: some View {
        Picker("Filter Mode", selection: $selectedMode) {
            ForEach(FilterPanelMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .standard:
            FiltersPanelSDRView(viewModel: viewModel)
        case .hdr:
            FiltersPanelHDRView(viewModel: viewModel)
        }
    }
}
