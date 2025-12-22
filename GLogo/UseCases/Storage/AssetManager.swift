//
//  AssetManager.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはアプリで使用するアセット（画像、フォント、テンプレートなど）の管理を担当します。
//  アセットの保存、読み込み、キャッシュ、削除などの機能を提供し、
//  ユーザーがプロジェクトで使用するカスタムアセットの管理を容易にします。
//

import UIKit

/// アセット管理ユーティリティ
class AssetManager {
    /// シングルトンインスタンス
    static let shared = AssetManager()
    
    /// アセットタイプ
    enum AssetType: String {
        case image = "Images"
        case font = "Fonts"
        case template = "Templates"
        case texture = "Textures"
        case background = "Backgrounds"
    }
    
    /// 画像キャッシュ
    private let imageCache = NSCache<NSString, UIImage>()
    
    /// プリロードされた画像キャッシュ
    private var preloadedImages: [String: UIImage] = [:]
    
    /// 初期化
    private init() {
        // 必要なディレクトリの作成
        createDirectoriesIfNeeded()
        
        // メモリ警告時のキャッシュクリア設定
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - ディレクトリ管理
    
    /// 必要なディレクトリを作成
    private func createDirectoriesIfNeeded() {
        for type in AssetType.allCases {
            do {
                let directoryURL = directoryURL(for: type)
                if !FileManager.default.fileExists(atPath: directoryURL.path) {
                    try FileManager.default.createDirectory(
                        at: directoryURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
            } catch {
                print("Failed to create directory for \(type.rawValue): \(error)")
            }
        }
    }
    
    /// アセットタイプに対応するディレクトリURLを取得
    private func directoryURL(for type: AssetType) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(type.rawValue)
    }
    
    // MARK: - 画像アセット管理
    
    /// 画像アセットを保存
    func saveImage(_ image: UIImage, name: String, type: AssetType = .image, alsoSaveProxy: Bool = true) -> Bool {
        guard let data = image.pngData() else { return false }
        
        let fileURL = directoryURL(for: type).appendingPathComponent("\(name).png")
        
        do {
            try data.write(to: fileURL)
            
            // 高解像度の場合はプロキシも保存（長辺を約1920pxに縮小）
            if alsoSaveProxy {
                let mp = (image.size.width * image.size.height) / 1_000_000.0
                if mp > 18.0, let proxy = resizeImage(image, targetLongSide: 1920) {
                    let proxyURL = directoryURL(for: type).appendingPathComponent("\(name)_proxy.png")
                    if let proxyData = proxy.pngData() {
                        try? proxyData.write(to: proxyURL)
                    }
                }
            }
            
            // キャッシュに追加
            cacheImage(image, for: name, type: type)
            
            return true
        } catch {
            print("Failed to save image \(name): \(error)")
            return false
        }
    }
    
    /// 画像アセットを読み込み
    func loadImage(named name: String, type: AssetType = .image) -> UIImage? {
        // キャッシュをチェック
        if let cachedImage = getCachedImage(for: name, type: type) {
            return cachedImage
        }
        
        // ファイルから読み込み
        let fileURL = directoryURL(for: type).appendingPathComponent("\(name).png")
        
        if let image = UIImage(contentsOfFile: fileURL.path) {
            // キャッシュに追加
            cacheImage(image, for: name, type: type)
            return image
        }
        
        // アプリバンドルから読み込み（デフォルトアセット）
        if let bundleImage = UIImage(named: name) {
            cacheImage(bundleImage, for: name, type: type)
            return bundleImage
        }
        
        return nil
    }

    /// プロキシ画像を読み込み（存在しない場合はnil）
    func loadProxyImage(named name: String, type: AssetType = .image) -> UIImage? {
        let proxyURL = directoryURL(for: type).appendingPathComponent("\(name)_proxy.png")
        if let image = UIImage(contentsOfFile: proxyURL.path) {
            return image
        }
        return nil
    }

    /// リサイズヘルパー
    private func resizeImage(_ image: UIImage, targetLongSide: CGFloat) -> UIImage? {
        let longSide = max(image.size.width, image.size.height)
        guard longSide > targetLongSide else { return image }
        let scale = targetLongSide / longSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
    
    /// 画像アセットを削除
    func deleteImage(named name: String, type: AssetType = .image) -> Bool {
        let fileURL = directoryURL(for: type).appendingPathComponent("\(name).png")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                
                // キャッシュから削除
                removeCachedImage(for: name, type: type)
                
                return true
            }
            return false
        } catch {
            print("Failed to delete image \(name): \(error)")
            return false
        }
    }
    
    /// 指定タイプのすべての画像アセット名を取得
    func getAllImageNames(type: AssetType = .image) -> [String] {
        let directoryURL = self.directoryURL(for: type)
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
            
            return fileURLs
                .filter { $0.pathExtension.lowercased() == "png" }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            print("Failed to get image names for \(type.rawValue): \(error)")
            return []
        }
    }
    
    // MARK: - キャッシュ管理
    
    /// 画像をキャッシュに追加
    private func cacheImage(_ image: UIImage, for name: String, type: AssetType) {
        let cacheKey = cacheKey(for: name, type: type)
        imageCache.setObject(image, forKey: cacheKey as NSString)
    }
    
    /// キャッシュから画像を取得
    private func getCachedImage(for name: String, type: AssetType) -> UIImage? {
        let cacheKey = cacheKey(for: name, type: type)
        
        // メモリキャッシュをチェック
        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // プリロードキャッシュをチェック
        return preloadedImages[cacheKey]
    }
    
    /// キャッシュから画像を削除
    private func removeCachedImage(for name: String, type: AssetType) {
        let cacheKey = cacheKey(for: name, type: type)
        imageCache.removeObject(forKey: cacheKey as NSString)
        preloadedImages.removeValue(forKey: cacheKey)
    }
    
    /// キャッシュキーを生成
    private func cacheKey(for name: String, type: AssetType) -> String {
        return "\(type.rawValue)_\(name)"
    }
    
    /// メモリキャッシュをクリア
    @objc func clearMemoryCache() {
        imageCache.removeAllObjects()
        preloadedImages.removeAll()
    }
    
    // MARK: - プリロード
    
    /// 指定タイプのすべての画像をプリロード
    func preloadImages(type: AssetType = .image, completion: ((Int) -> Void)? = nil) {
        let imageNames = getAllImageNames(type: type)
        
        for name in imageNames {
            let fileURL = directoryURL(for: type).appendingPathComponent("\(name).png")
            
            if let image = UIImage(contentsOfFile: fileURL.path) {
                let key = cacheKey(for: name, type: type)
                preloadedImages[key] = image
            }
        }
        
        completion?(preloadedImages.count)
    }
    
    // MARK: - アセットインポート
    
    /// 外部URLから画像をインポート
    func importImageFromURL(_ url: URL, name: String? = nil, type: AssetType = .image, completion: @escaping (Bool, String?) -> Void) {
        // URLSessionを使用してダウンロード
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
                return
            }
            
            // 画像データの検証
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
                return
            }
            
            // 名前の生成（指定がなければURLから）
            let assetName = name ?? url.deletingPathExtension().lastPathComponent
            
            // 重複を避けるためのユニーク名
            let uniqueName = self.generateUniqueName(baseName: assetName, type: type)
            
            // 画像の保存（高解像度ならプロキシも併せて保存）
            let success = self.saveImage(image, name: uniqueName, type: type, alsoSaveProxy: true)
            
            DispatchQueue.main.async {
                completion(success, success ? uniqueName : nil)
            }
        }.resume()
    }
    
    /// ユニークな名前を生成
    private func generateUniqueName(baseName: String, type: AssetType) -> String {
        let existingNames = Set(getAllImageNames(type: type))
        
        // 名前が既に存在しなければそのまま使用
        if !existingNames.contains(baseName) {
            return baseName
        }
        
        // 存在する場合は連番を付与
        var index = 1
        var uniqueName = "\(baseName)_\(index)"
        
        while existingNames.contains(uniqueName) {
            index += 1
            uniqueName = "\(baseName)_\(index)"
        }
        
        return uniqueName
    }
    
    // MARK: - サムネイル生成
    
    /// 画像のサムネイルを生成
    func generateThumbnail(for image: UIImage, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { _ in
            // アスペクト比を維持
            let aspectRatio = image.size.width / image.size.height
            
            var drawRect: CGRect
            
            if aspectRatio > 1 {
                // 横長画像
                let height = size.width / aspectRatio
                drawRect = CGRect(
                    x: 0,
                    y: (size.height - height) / 2,
                    width: size.width,
                    height: height
                )
            } else {
                // 縦長画像
                let width = size.height * aspectRatio
                drawRect = CGRect(
                    x: (size.width - width) / 2,
                    y: 0,
                    width: width,
                    height: size.height
                )
            }
            
            // 画像を描画
            image.draw(in: drawRect)
        }
    }
}

// MARK: - AssetType拡張

extension AssetManager.AssetType: CaseIterable {}
