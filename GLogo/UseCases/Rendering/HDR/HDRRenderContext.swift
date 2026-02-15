//
//  HDRRenderContext.swift
//  GLogo
//
//  概要:
//  Display P3色空間ベースのRenderContextを拡張で提供する。
//  HDRパイプライン全体で共有し、広色域の色管理を統一する。

import CoreImage
import CoreGraphics

extension RenderContext {
    /// Display P3色空間で動作するHDR用レンダリングコンテキスト
    static let hdr: RenderContext = {
        let cs = CGColorSpace(name: CGColorSpace.displayP3)!
        let options: [CIContextOption: Any] = [
            .workingColorSpace: cs,
            .outputColorSpace: cs,
            .useSoftwareRenderer: false
        ]
        return RenderContext(colorSpace: cs, ciContext: CIContext(options: options))
    }()
}
