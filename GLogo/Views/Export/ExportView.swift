//
//  ExportView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴプロジェクトのエクスポート設定と実行のためのSwiftUIビューです。
//  エクスポート形式（PNG/JPEG）、サイズ設定、透明背景オプション、JPEG品質などの
//  設定を行うためのUIコントロールを提供します。また、エクスポートのプレビュー表示や
//  エクスポート実行、共有機能へのアクセスも提供します。
//  ExportViewModelと連携して、エクスポート処理を管理します。
//
//
//import SwiftUI
//
///// エクスポートビュー
//struct ExportView: View {
//    /// 表示制御用の状態
//    @Environment(\.presentationMode) var presentationMode
//    
//    /// エクスポートビューモデル
//    @StateObject private var viewModel: ExportViewModel
//    
//    /// アクティビティシートの表示フラグ
//    @State private var isShowingActivitySheet = false
//    
//    /// エラーアラートの表示フラグ
//    @State private var isShowingErrorAlert = false
//    
//    /// エラーメッセージ
//    @State private var errorMessage = ""
//    
//    /// 初期化
//    init(viewModel: EditorViewModel) {
//        _viewModel = StateObject(wrappedValue: ExportViewModel(editorViewModel: viewModel))
//    }
//    
//    var body: some View {
//        NavigationView {
//            ScrollView {
//                VStack(spacing: 20) {
//                    // プレビューセクション
//                    previewSection
//                    
//                    // 設定セクション
//                    ExportOptionsView(viewModel: viewModel)
//                    
//                    // ボタンセクション
//                    buttonSection
//                }
//                .padding()
//            }
//            .navigationTitle("エクスポート")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                // 閉じるボタン
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("キャンセル") {
//                        presentationMode.wrappedValue.dismiss()
//                    }
//                }
//            }
//            .sheet(isPresented: $isShowingActivitySheet) {
//                // エクスポートされた画像を共有するためのアクティビティビュー
//                if let exportedImage = viewModel.exportedImage {
//                    ActivityViewController(activityItems: [exportedImage])
//                }
//            }
//            .alert(isPresented: $isShowingErrorAlert) {
//                Alert(
//                    title: Text("エラー"),
//                    message: Text(errorMessage),
//                    dismissButton: .default(Text("OK"))
//                )
//            }
//            .onAppear {
//                // 初回表示時に設定をリセット
//                viewModel.resetSettings()
//            }
//        }
//    }
//    
//    // MARK: - プレビューセクション
//    
//    private var previewSection: some View {
//        VStack(spacing: 16) {
//            Text("プレビュー")
//                .font(.headline)
//                .frame(maxWidth: .infinity, alignment: .leading)
//            
//            // エクスポートが完了している場合はエクスポート画像を表示
//            if viewModel.isExportComplete, let exportedImage = viewModel.exportedImage {
//                // プレビュー画像
//                Image(uiImage: exportedImage)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(maxHeight: 200)
//                    .background(
//                        // 透明背景のチェッカーパターン（PNG形式で透明背景選択時のみ）
//                        Group {
//                            if viewModel.exportFormat == .png && viewModel.transparentBackground {
//                                CheckerboardPattern()
//                            } else {
//                                Color.clear
//                            }
//                        }
//                    )
//                    .cornerRadius(4)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 4)
//                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//                    )
//            } else {
//                // エクスポートされていない場合はプレースホルダー
//                Rectangle()
//                    .fill(Color.gray.opacity(0.1))
//                    .frame(height: 200)
//                    .overlay(
//                        Text("エクスポートボタンを押して\nプレビューを生成")
//                            .multilineTextAlignment(.center)
//                            .foregroundColor(.gray)
//                    )
//                    .cornerRadius(4)
//            }
//        }
//    }
//    
//    // MARK: - ボタンセクション
//    
//    private var buttonSection: some View {
//        HStack(spacing: 16) {
//            // エクスポートボタン
//            Button(action: performExport) {
//                HStack {
//                    Image(systemName: "square.and.arrow.down")
//                    Text(viewModel.isExportComplete ? "再エクスポート" : "エクスポート")
//                }
//                .frame(maxWidth: .infinity)
//            }
//            .buttonStyle(FilledButtonStyle(color: .blue))
//            .disabled(viewModel.isExporting)
//            
//            // 共有ボタン（エクスポート完了時のみ有効）
//            Button(action: shareExport) {
//                HStack {
//                    Image(systemName: "square.and.arrow.up")
//                    Text("共有")
//                }
//                .frame(maxWidth: .infinity)
//            }
//            .buttonStyle(FilledButtonStyle(color: .green))
//            .disabled(!viewModel.isExportComplete || viewModel.isExporting)
//        }
//        .padding(.top, 10)
//    }
//    
//    // MARK: - アクション
//    
//    /// エクスポートを実行
//    private func performExport() {
//        viewModel.performExport()
//    }
//    
//    /// エクスポート結果を共有
//    private func shareExport() {
//        viewModel.shareExportedImage { success in
//            if success {
//                isShowingActivitySheet = true
//            } else {
//                errorMessage = "エクスポートファイルの共有準備に失敗しました。"
//                isShowingErrorAlert = true
//            }
//        }
//    }
//}
//
///// カスタムボタンスタイル
//struct FilledButtonStyle: ButtonStyle {
//    let color: Color
//    
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .padding(.vertical, 12)
//            .foregroundColor(.white)
//            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
//            .cornerRadius(8)
//    }
//}
//
///// チェッカーボードパターン（透明背景の表示用）
//struct CheckerboardPattern: View {
//    let size: CGFloat = 10
//    
//    var body: some View {
//        Canvas { context, size in
//            // パターンのタイル数
//            let columns = Int(size.width / self.size) + 1
//            let rows = Int(size.height / self.size) + 1
//            
//            for row in 0..<rows {
//                for column in 0..<columns {
//                    let rect = CGRect(
//                        x: CGFloat(column) * self.size,
//                        y: CGFloat(row) * self.size,
//                        width: self.size,
//                        height: self.size
//                    )
//                    
//                    // 市松模様のパターン
//                    if (row + column) % 2 == 0 {
//                        context.fill(Path(rect), with: .color(.white))
//                    } else {
//                        context.fill(Path(rect), with: .color(.gray.opacity(0.2)))
//                    }
//                }
//            }
//        }
//    }
//}
//
///// UIActivityViewControllerラッパー
//struct ActivityViewController: UIViewControllerRepresentable {
//    let activityItems: [Any]
//    let applicationActivities: [UIActivity]? = nil
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let controller = UIActivityViewController(
//            activityItems: activityItems,
//            applicationActivities: applicationActivities
//        )
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
//
///// プレビュー
//struct ExportView_Previews: PreviewProvider {
//    static var previews: some View {
//        ExportView(viewModel: EditorViewModel())
//    }
//}
