//
//  EditorBottomToolStrip.swift
//  GLogo
//
//  概要:
//  エディタ画面下部に表示する横スクロール式のツールストリップを提供します。
//  既存の編集ロジックとは分離し、UIレイヤーとして選択状態の表示とタップ通知を担当します。
//

import SwiftUI

enum EditorBottomTool: String, CaseIterable, Identifiable {
    case select
    case adjust
    case magicStudio
    case filters
    case effects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select:
            return "Text"
        case .adjust:
            return "Adjust"
        case .magicStudio:
            return "AI Tools"
        case .filters:
            return "Filters"
        case .effects:
            return "Effects"
        }
    }

    var systemImageName: String {
        switch self {
        case .select:
            return "textformat"
        case .adjust:
            return "slider.horizontal.3"
        case .magicStudio:
            return "sparkles"
        case .filters:
            return "camera.filters"
        case .effects:
            return "fx"
        }
    }
}

struct EditorBottomToolStrip: View {
    @Binding var selectedTool: EditorBottomTool
    let onSelectTool: (EditorBottomTool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EditorBottomTool.allCases) { tool in
                        toolButton(tool)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .background(
            Color(UIColor.secondarySystemBackground)
        )
    }

    private func toolButton(_ tool: EditorBottomTool) -> some View {
        let isSelected = tool == selectedTool

        return Button {
            selectedTool = tool
            onSelectTool(tool)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tool.systemImageName)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 18)
                Text(tool.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .frame(height: 13)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
