//
//  EditorViewModel.swift
//
//  概要:
//  このファイルはエディタ画面の主要なビューモデルを定義しています。
//  プロジェクトの状態管理、要素の追加/選択/編集/削除などの編集操作、
//  要素の移動/リサイズ/回転などの操作処理、操作履歴の管理（イベントソーシングによるアンドゥ/リドゥ）、
//  プロジェクトの保存/読み込み、画像エクスポート機能など、
//  エディタの中核となる機能を提供します。ユーザー操作とモデルの間の橋渡し役を担います。
//

import Foundation
import Combine
import UIKit
import Photos

/// エディタモード
enum EditorMode {
    case select      // 要素の選択・移動
    case shapeCreate // 図形作成
    case imageImport // 画像インポート
    case delete      // 削除
}

/// エディタビューモデル - エディタ画面の状態とロジックを管理
@MainActor
class EditorViewModel: ObservableObject, ImageEditCommitting, ElementTransformApplying {
    /// メモリ警告監視トークンのライフサイクル管理
    private final class MemoryWarningObserver {
        typealias Handler = @MainActor @Sendable () -> Void
        private var token: NSObjectProtocol?

        init(handler: @escaping Handler) {
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        }

        deinit {
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    // MARK: - プロパティ
    
    /// 現在のプロジェクト
    @Published private(set) var project: LogoProject
    
    /// 選択中の要素
    @Published private(set) var selectedElement: LogoElement?
    
    /// エディタモード
    @Published var editorMode: EditorMode = .select
    
    /// テキスト編集中かどうか
    @Published private(set) var isEditingText: Bool = false
    
    /// 編集中のテキスト要素
    @Published private(set) var editingTextElement: TextElement?
    
    /// 操作履歴の管理
    private lazy var history = EditorHistory(project: project)

    /// 確定操作のイベント生成を機能別に委譲する。各 UseCase は親を非所有で参照する。
    private(set) lazy var textEdits = TextEditUseCase(target: self)
    private(set) lazy var shapeEdits = ShapeEditUseCase(target: self)
    private(set) lazy var imageEdits = ImageEditUseCase(target: self)

    /// AI の表示状態と要求の寿命を所有する。推論依存は初期化時の注入を引き継ぐ。
    private(set) lazy var aiTools = AIToolsViewModel(
        edits: imageEdits,
        backgroundRemovalUseCase: backgroundRemovalUseCase,
        imageUpscaleUseCase: imageUpscaleUseCase,
        selection: $selectedElement.eraseToAnyPublisher(),
        changes: objectWillChange.eraseToAnyPublisher()
    )
    /// キャンバスのジェスチャーの開始値と未確定の変形を持つ。`ElementViewModel.transform` と同じものを共有する。
    private(set) lazy var transform = ElementTransformViewModel(
        editor: self, selection: $selectedElement.eraseToAnyPublisher()
    )
    private var transformObservation: AnyCancellable?
    /// ここから開く画面へ渡す外部処理。画面ごとに作るものは、開くたびに呼ぶ関数として持つ。
    let dependencies: EditorDependencies
    private let backgroundRemovalUseCase: any BackgroundRemovalProcessing
    private let imageUpscaleUseCase: ImageUpscaleUseCase
    private var aiToolsObservation: AnyCancellable?

    private let imageSaveViewModel: ImageSaveViewModel
    private var imageSaveObservation: AnyCancellable?
    private let imageImporter: any ImageImporting
    private let viewportSizeProvider: @MainActor () -> CGSize
    private let imageRoleUseCase = ImageRoleUseCase()
    private let imageElementMetadataRevertUseCase: ImageElementMetadataRevertUseCase
    
    /// 次に作成する図形のタイプ
    var nextShapeType: ShapeType = .rectangle
    
    /// プロジェクトが変更されたかどうか
    @Published private(set) var isProjectModified = false

    /// 画像保存処理の実行中フラグ（保存中は編集入力をロック）
    var isSavingImage: Bool { imageSaveViewModel.isSaving }

    /// 直近の写真ライブラリ保存失敗理由
    var lastPhotoLibrarySaveFailure: PhotoLibrarySaveFailure? { imageSaveViewModel.lastFailure }

    /// 画像一覧レールの表示フラグ
    @Published var isImageListRailVisible = false

    /// メモリ警告監視
    private var memoryWarningObserver: MemoryWarningObserver?

    // MARK: - イニシャライザ
    
    /// 新しいプロジェクトでエディタを初期化
    /// - Parameters:
    ///   - dependencies: 保存・インポート・AI の外部処理。実装は Composition Root が組み立てる
    init(
        project: LogoProject = LogoProject(),
        dependencies: EditorDependencies,
        viewportSizeProvider: @escaping @MainActor () -> CGSize = { UIScreen.main.bounds.size }
    ) {
        self.project = project
        self.dependencies = dependencies
        // AI ツールと共有する背景除去は、従来どおりエディタの初期化時に1つ作る。
        self.backgroundRemovalUseCase = dependencies.makeBackgroundRemover()
        self.imageUpscaleUseCase = dependencies.imageUpscaleUseCase
        self.imageImporter = dependencies.imageImporter
        self.imageElementMetadataRevertUseCase = ImageElementMetadataRevertUseCase(store: dependencies.metadataStore)
        self.viewportSizeProvider = viewportSizeProvider
        imageSaveViewModel = ImageSaveViewModel(saver: dependencies.photoLibrarySaver)
        
        // 履歴管理の初期化
        history = EditorHistory(project: project)

        // 既存の画面は親を購読するため、保存状態を複製せず変更通知だけを転送する。
        imageSaveObservation = imageSaveViewModel.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        // 遷移を扱う EditorView へ子の通知を転送し、表示状態そのものは複製しない。
        aiToolsObservation = aiTools.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        transformObservation = transform.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        memoryWarningObserver = MemoryWarningObserver { [weak self] in
            self?.handleMemoryWarning()
        }
    }

    // MARK: - ライフサイクル補助

    /// メモリ警告を受けた際にキャッシュを解放する
    private func handleMemoryWarning() {
        ImageCacheReleaseUseCase.releaseCaches(in: project.elements, defaultService: dependencies.previewService)
    }
    
    // MARK: - プロジェクト操作

    /// 外部からプロジェクト変更フラグを立てる
    func markProjectModified() {
        isProjectModified = true
    }
    
    /// プロジェクト名を更新
    func updateProjectName(_ name: String) {
        // プロジェクト名に変更があれば更新
        if project.name != name {
            let event = ProjectNameChangedEvent(
                oldName: project.name,
                newName: name
            )
            
            history.recordAndApply(event)
            isProjectModified = true
        }
    }
    
    /// プロジェクトのキャンバスサイズを更新
    func updateCanvasSize(_ size: CGSize) {
        // キャンバスサイズに変更があれば更新
        if project.canvasSize != size {
            let event = CanvasSizeChangedEvent(
                oldSize: project.canvasSize,
                newSize: size
            )
            
            history.recordAndApply(event)
            isProjectModified = true
        }
    }
    
    // MARK: - 要素操作
    
    /// 要素を追加
    func addElement(_ element: LogoElement) {
        
        // 自動Z-Index設定
        setAutoZIndex(for: element)
        
        let event = ElementAddedEvent(element: element)
        history.recordAndApply(event)
        
        
        selectedElement = element
        isProjectModified = true
    }
    
    /// 要素の自動Z-Index設定
    private func setAutoZIndex(for element: LogoElement) {
        let elementPriority = ElementPriority.defaultPriority(for: element.type)
        let nextZIndex = elementPriority.nextAvailableZIndex(existingElements: project.elements)
        element.zIndex = nextZIndex
        
    }
    
    /// テキスト要素を追加
    func addTextElement(text: String = "Text", position: CGPoint) {
        let textElement = TextElement(text: text)
        textElement.position = position
        addElement(textElement)
    }
    
    /// 図形要素を追加
    func addShapeElement(type: ShapeType, position: CGPoint) {
        let shapeElement = ShapeElement(shapeType: type)
        shapeElement.position = position
        addElement(shapeElement)
    }
    
    /// 選択中の要素を削除
    func deleteSelectedElement() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のインデックスを取得
        guard let index = project.elements.firstIndex(where: { $0.id == selectedElement.id }) else { return }

        // 削除後に確定すると、プロジェクトにない要素の履歴になる。Undo で削除・変形の順に戻せるよう、先に確定する。
        transform.interruptManipulation()

        // 削除イベントを作成して実行
        let event = ElementRemovedEvent(element: selectedElement, index: index)
        history.recordAndApply(event)
        
        self.selectedElement = nil
        isProjectModified = true
    }
    
    // 特定の要素を直接選択
    func selectElement(_ element: LogoElement?) {
        selectedElement = element
    }
    
    /// 選択を解除
    func clearSelection() {
        selectedElement = nil
    }
    
    /// テキスト編集を開始
    func startTextEditing(for textElement: TextElement) {
        // 現在の編集を終了（もしあれば）
        endTextEditing()

        editingTextElement = textElement
        isEditingText = true
        selectedElement = textElement

    }

    /// 選択中の要素がテキストならテキスト編集を開始する。View 側の型ダウンキャストを排除するための入口
    /// - Parameters: なし
    /// - Returns: なし
    func startTextEditingForSelectedElement() {
        guard let textElement = selectedElement as? TextElement else { return }
        startTextEditing(for: textElement)
    }

    /// 選択中の要素が画像かどうか。View 側で `as? ImageElement` を書かずに判定するための入口
    var isImageElementSelected: Bool {
        selectedElement is ImageElement
    }

    /// 選択中の画像要素を型付きで返す。View 側のダウンキャストを排除するための入口
    var selectedImageElement: ImageElement? {
        selectedElement as? ImageElement
    }
    
    /// テキスト編集を終了
    func endTextEditing() {
        if isEditingText {
            isEditingText = false
            editingTextElement = nil
        }
    }
    
    /// 選択中の要素をコピー
    func duplicateSelectedElement() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のコピーを作成
        let copy = selectedElement.copy()
        
        // コピーした要素を少しずらして配置
        copy.move(by: CGPoint(x: 20, y: 20))
        
        // 要素を追加
        let event = ElementAddedEvent(element: copy)
        history.recordAndApply(event)
        
        self.selectedElement = copy
        isProjectModified = true
    }
    
    /// 選択中の要素を更新
    func updateSelectedElement(_ element: LogoElement) {
        guard let index = project.elements.firstIndex(where: { $0.id == element.id }) else { return }
        
        // ここではイベントを使用しない
        project.elements[index] = element
        
        // 選択要素を更新
        selectedElement = element
        isProjectModified = true
    }

    /// 編集イベントを適用し、選択要素と変更フラグを更新
    /// - Parameters:
    ///   - event: 適用する編集イベント
    ///   - elementId: 対象要素のID
    /// - Returns: なし
    func applyEventAndRefreshSelection(_ event: EditorEvent, elementId: UUID) {
        history.recordAndApply(event)

        if selectedElement?.id == elementId {
            if let updatedElement = project.elements.first(where: { $0.id == elementId }) {
                selectedElement = updatedElement
            }
        }

        isProjectModified = true
    }
    
    /// テキスト要素のプロパティを更新
    func updateTextElement(_ textElement: TextElement) {
        updateSelectedElement(textElement)
    }
    
    /// 画像要素のプロパティを更新
    func updateImageElement(_ imageElement: ImageElement) {
        updateSelectedElement(imageElement)
    }

    /// 選択中の画像要素を初期状態に戻し、Undo可能な履歴として記録
    /// - Parameters: なし
    /// - Returns: なし
    func revertSelectedImageToInitialState() {
        guard let imageElement = selectedElement as? ImageElement else {
            return
        }

        let event = ImageRevertedToInitialStateEvent(element: imageElement, metadataStore: dependencies.metadataStore)
        imageElement.endEditing()
        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 選択中の画像要素が初期状態へ戻せるかを返す
    /// - Parameters: なし
    /// - Returns: リバート可能な場合は true
    func canRevertSelectedImageToInitialState() -> Bool {
        guard let imageElement = selectedElement as? ImageElement else {
            return false
        }
        return imageElementMetadataRevertUseCase.canRevertToInitialState(imageElement)
    }

    /// 現在の編集対象の実体と履歴移動の世代を、加工開始・完了時に照合する。
    func imageEditToken(for element: ImageElement) -> ImageEditToken? {
        guard project.elements.contains(where: { $0 === element }) else { return nil }
        return ImageEditToken(element: ObjectIdentifier(element), imageRevision: element.editRevision,
                              historyRestorationRevision: history.restorationRevision)
    }

    /// 画像加工後の選択方針を維持し、変更フラグと表示を同期する。
    func applyImageEvents(_ events: [EditorEvent], elementId: UUID, selectsResult: Bool) {
        for event in events {
            history.recordAndApply(event)
        }
        // 古い描画の完了を待たず、加工後の画像を確定品質で表示する。
        project.element(for: elementId, as: ImageElement.self)?.endEditing()
        if selectsResult || selectedElement?.id == elementId {
            if let updatedElement = project.elements.first(where: { $0.id == elementId }) {
                selectedElement = updatedElement
            }
        }
        isProjectModified = true
        objectWillChange.send()
    }

    /// キャンバスのテキスト入力を機能別 UseCase へ渡す。
    func updateTextContent(_ textElement: TextElement, newText: String) {
        textEdits.updateTextContent(textElement, newText: newText)
    }

    /// 画像の役割を変更（ベース/オーバーレイの切り替え）
    func toggleImageRole(_ imageElement: ImageElement) {
        guard imageRoleUseCase.toggleRole(for: imageElement, in: &project) else { return }
        objectWillChange.send()
        isProjectModified = true
    }
    
    // MARK: - 編集履歴操作
    
    /// アンドゥ操作
    func undo() {
        // ボタンの無効化に加えて、キーボードショートカットや直接の呼び出しでも止めるため、`canUndo` で判定する。
        if canUndo {
            history.undo()
            // 履歴移動で描画要求が失効しても、選択中のプレビュー状態を残さない。
            (selectedElement as? ImageElement)?.endEditing()

            // 選択要素の状態を適切に更新
            if let selectedElement = selectedElement {

                // 現在選択中の要素がまだ存在するか確認
                if let updatedElement = project.elements.first(where: { $0.id == selectedElement.id }) {
                    self.selectedElement = updatedElement
                } else {
                    // 要素が削除された場合は選択を解除
                    self.selectedElement = nil
                }
            }

            isProjectModified = true
            objectWillChange.send()
        }
    }

    /// リドゥ操作
    func redo() {
        if canRedo {
            history.redo()
            (selectedElement as? ImageElement)?.endEditing()

            // リドゥ後、選択要素の状態を適切に更新
            if let selectedElement = selectedElement {
                // 現在選択中の要素がまだ存在するか確認
                if let updatedElement = project.elements.first(where: { $0.id == selectedElement.id }) {
                    self.selectedElement = updatedElement
                } else {
                    // 要素が削除された場合は選択を解除
                    self.selectedElement = nil
                }
            }

            isProjectModified = true
            objectWillChange.send()
        }
    }

    /// アンドゥが可能かどうか。ジェスチャーの変形が未確定のあいだは、履歴を動かすと開始値と食い違うため不可とする。
    var canUndo: Bool {
        return history.canUndo && !transform.hasPendingGestureTransform
    }

    /// リドゥが可能かどうか。未確定の変形があるあいだは不可とする（`canUndo` と同じ理由）。
    var canRedo: Bool {
        return history.canRedo && !transform.hasPendingGestureTransform
    }
    
    // MARK: - イベント適用

    /// イベントを適用して記録
    func applyEvent(_ event: EditorEvent) {
        history.recordAndApply(event)
        isProjectModified = true
    }

    // MARK: - 履歴情報
    
    /// 操作履歴の説明を取得
    func getHistoryDescriptions() -> [String] {
        return history.getHistoryDescriptions()
    }
    
    // MARK: - 写真ライブラリ保存
    //
    // フロー概要:
    //  - UI からは saveToPhotoLibrary を呼ぶだけで、要素構成に応じて通常 or 合成を自動判定。
    //  - saveCompositeToPhotoLibrary は互換用に合成保存を強制するエントリーポイント。
    //  - 写真ライブラリ保存本体のロジックは SaveImage 配下に分離済み。
    
    /// 写真アプリに画像を保存（通常の1枚保存）
    /// プロジェクトの編集内容をフィルター適用済み画像として写真ライブラリに保存する
    func saveToPhotoLibrary(completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void) {
        imageSaveViewModel.save(
            project: project,
            prepare: prepareForImageSave,
            completion: completion
        )
    }
    
    /// - 役割：ユーザーが「保存」ボタンを押した時の最初の受け口（エントリーポイント）
    /// - 処理：写真ライブラリの権限確認と合成保存フローの呼び出し
    func saveCompositeToPhotoLibrary(completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void) {
        imageSaveViewModel.saveComposite(
            project: project,
            prepare: prepareForImageSave,
            completion: completion
        )
    }

    /// 保存開始前に操作状態を整える。保存入力を取得する前に、未確定のジェスチャーの差分を履歴1件として確定する。
    /// 保存される内容は画面の値のままで変わらない。
    /// - Parameters: なし
    /// - Returns: なし
    private func prepareForImageSave() {
        transform.interruptManipulation()

        for element in project.elements {
            (element as? ImageElement)?.endEditing()
        }
    }
    
    // MARK: - インポート
    //
    // フロー概要:
    //  - UI から addImageElement / addCroppedImageElement を呼び出す（エントリーポイント）。
    //  - 画像ソースと条件を ImageImportCoordinator に渡して生成・初期配置を委譲。
    //  - 生成後は ViewModel で追加・選択・カメラセンタリングを実行する。
    
    /// 画像要素をデータから追加
    func addImageElement(imageData: Data, position: CGPoint, phAsset: PHAsset? = nil, assetIdentifier: String? = nil) {
        guard let result = importImageElement(
            source: .imageData(imageData),
            canvasSize: nil,
            assetIdentifier: assetIdentifier
        ) else {
            return
        }

        applyImportedImage(result.element)
    }
    
    /// 画像のクロップ後にImageElementを追加
    func addCroppedImageElement(image: UIImage, assetIdentifier: String? = nil) {
        guard let result = importImageElement(
            source: .uiImage(image),
            canvasSize: project.canvasSize,
            assetIdentifier: assetIdentifier
        ) else {
            return
        }

        applyImportedImage(result.element)
    }

    private func importImageElement(
        source: ImageImportSource,
        canvasSize: CGSize?,
        assetIdentifier: String?
    ) -> ImageImportResult? {
        imageImporter.importImage(
            source: source,
            project: project,
            viewportSize: viewportSizeProvider(),
            assetIdentifier: assetIdentifier,
            canvasSize: canvasSize
        )
    }

    private func applyImportedImage(_ element: ImageElement) {
        addElement(element)
        selectElement(element)

        // 画像が見えるようにカメラを移動
        centerViewOnElement(element)
    }
    
    // MARK: - インポートの表示制御
    
    /// 特定の要素にビューを中央揃え
    private func centerViewOnElement(_ element: LogoElement) {
        // このメソッドは、カメラビューがある場合に、そのビューを特定の要素の位置に移動させる
        // 実装はビューコントローラーのカメラビューの実装に依存
        // NotificationCenter経由で通知を送るか、デリゲートパターンを使用
        
        let centerPoint = CGPoint(
            x: element.position.x + element.size.width / 2,
            y: element.position.y + element.size.height / 2
        )
        
        // 通知を送信して、ビューコントローラーにカメラ移動を要求
        NotificationCenter.default.post(
            name: Notification.Name("CenterCameraOnPoint"),
            object: centerPoint
        )
    }
    
#if DEBUG
    // MARK: - UIテスト用 fixture

    /// UIテスト用の fixture 名を表す列挙型
    enum UITestFixture: String {
        /// 画像要素を追加・選択した状態
        case selectedImage
        /// 高画質化済み画像要素を追加・選択した状態
        case enhancedImage
        /// 画像要素を画面内に置いて選択した状態（キャンバス上のジェスチャーの UI テスト用）
        case onScreenImage
    }

    /// fixture 適用済みフラグ（重複投入防止）
    private var hasAppliedUITestFixture = false

    /// launch argument で指定された fixture を適用する（一度だけ）
    /// - Parameters:
    ///   - makeElementFactory: fixture の画像要素を作る Factory。適用するときだけ呼ぶ
    func applyUITestFixtureIfNeeded(makeElementFactory: () -> ImageElementFactory) {
        guard !hasAppliedUITestFixture else { return }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiTestFixture"),
              index + 1 < args.count,
              let fixture = UITestFixture(rawValue: args[index + 1]) else {
            return
        }
        hasAppliedUITestFixture = true
        switch fixture {
        case .selectedImage:
            applySelectedImageFixture(enhanced: false, elementFactory: makeElementFactory())
        case .enhancedImage:
            applySelectedImageFixture(enhanced: true, elementFactory: makeElementFactory())
        case .onScreenImage:
            applySelectedImageFixture(
                enhanced: false,
                elementFactory: makeElementFactory(),
                // ほかの fixture はキャンバス中央（画面外）に置く。UI テストのピンチは、選択枠の矩形（キャンバス全体）の
                // 中心で行われるため、画面内に置き、iPhone のキャンバスの中心を十分に含む大きさにする。
                frame: CGRect(x: 40, y: 100, width: 320, height: 440)
            )
        }
    }

    /// ダミー画像要素を追加・選択する fixture
    /// - Parameters:
    ///   - frame: 指定した場合は、キャンバス座標の位置とサイズで置く。省略時はキャンバス中央
    private func applySelectedImageFixture(enhanced: Bool, elementFactory: ImageElementFactory, frame: CGRect? = nil) {
        // 1x1 赤ピクセルの最小 PNG を生成（アセット不要）
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        guard let data = image.pngData() else { return }

        let imageElement = elementFactory.makeElement(imageData: data, canvasSize: project.canvasSize)
        imageElement.position = CGPoint(
            x: project.canvasSize.width / 2,
            y: project.canvasSize.height / 2
        )
        if let frame {
            imageElement.position = frame.origin
            imageElement.size = frame.size
        }
        if enhanced {
            imageElement.hasAppliedUpscale = true
        }
        addElement(imageElement)
        selectElement(imageElement)
    }
#endif

    // MARK: - 画像一覧レール

    /// 画像要素のみをzIndex降順（前面→背面）で返す
    var imageElements: [ImageElement] {
        project.elements
            .compactMap { $0 as? ImageElement }
            .sorted { $0.zIndex > $1.zIndex }
    }

    /// 画像一覧レールでのドラッグ並べ替え
    /// - Parameters:
    ///   - source: 移動元インデックス（降順リスト上）
    ///   - destination: 移動先インデックス（降順リスト上）
    func reorderImageElements(from source: IndexSet, to destination: Int) {
        var ordered = imageElements
        ordered.move(fromOffsets: source, toOffset: destination)
        applyImageElementOrder(ordered)
    }

    /// ドラッグ中の画像を指定ターゲット位置へ移動する
    /// - Parameters:
    ///   - draggedImageID: ドラッグ中の画像要素ID
    ///   - targetImageID: ドロップ先の画像要素ID
    /// - Returns: なし
    func reorderImageElement(draggedImageID: UUID, to targetImageID: UUID) {
        var ordered = imageElements
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == draggedImageID }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetImageID }),
              sourceIndex != targetIndex else {
            return
        }

        let destination = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        ordered.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
        applyImageElementOrder(ordered)
    }

    /// 並べ替え後の画像配列に既存zIndex帯を再割り当てし、履歴へ記録する
    /// - Parameters:
    ///   - orderedElements: 前面→背面順に並んだ画像要素配列
    /// - Returns: なし
    private func applyImageElementOrder(_ orderedElements: [ImageElement]) {
        let currentImageElements = imageElements
        let sortedZIndices = currentImageElements.map(\.zIndex).sorted(by: >)
        var changes: [(elementId: UUID, oldZIndex: Int, newZIndex: Int)] = []

        for (index, element) in orderedElements.enumerated() {
            let newZIndex = sortedZIndices[index]
            if element.zIndex != newZIndex {
                changes.append((elementId: element.id, oldZIndex: element.zIndex, newZIndex: newZIndex))
            }
        }

        guard !changes.isEmpty else { return }

        let event = ImageOrderChangedEvent(changes: changes)
        history.recordAndApply(event)
        isProjectModified = true
        objectWillChange.send()
    }
}
