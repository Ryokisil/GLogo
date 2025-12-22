//
//  RenderContext.swift
//  GLogo
//
//  概要:
//  共有するCIContextと色空間をまとめたレンダリング用コンテキスト。
//  パイプラインから再利用し、色管理とパフォーマンスを統一する。

import CoreImage
import CoreGraphics

/// レンダリング時に共有したいリソースや色空間をまとめる。
struct RenderContext {
    let colorSpace: CGColorSpace
    let ciContext: CIContext

    static let shared: RenderContext = {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let options: [CIContextOption: Any] = [
            .workingColorSpace: cs,
            .outputColorSpace: cs,
            .useSoftwareRenderer: false
        ]
        return RenderContext(colorSpace: cs, ciContext: CIContext(options: options))
    }()
}
