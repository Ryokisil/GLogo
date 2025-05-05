//
//  UIComponents.swift
//  GameLogoMaker
//
//  概要:
//  再利用可能なUIコンポーネント
//

import SwiftUI

struct AspectRatioButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(8)
        }
    }
}

struct CheckerboardPattern: View {
    var body: some View {
        // チェッカーボードパターンの実装
        GeometryReader { geometry in
            Path { path in
                let cellSize: CGFloat = 10
                for y in stride(from: 0, to: geometry.size.height, by: cellSize) {
                    for x in stride(from: 0, to: geometry.size.width, by: cellSize) {
                        if (Int(x / cellSize) + Int(y / cellSize)) % 2 == 0 {
                            path.addRect(CGRect(x: x, y: y, width: cellSize, height: cellSize))
                        }
                    }
                }
            }
            .fill(Color.gray.opacity(0.3))
        }
    }
}
