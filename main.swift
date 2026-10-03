import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

@main
struct PictureGoApp: App {
    @StateObject private var model = ConverterModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 650)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}

// MARK: - Data

enum SidebarPage: String, CaseIterable, Identifiable {
    case professional = "专业图片格式转化"
    case common = "常见图片格式转化"
    case about = "关于我们"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .professional: return "slider.horizontal.3"
        case .common: return "photo.on.rectangle.angled"
        case .about: return "info.circle"
        }
    }
}

enum FormatCategory {
    case common
    case professional
}

struct ImageFormat: Identifiable {
    let id: String
    let name: String
    let fileExtension: String
    let category: FormatCategory
    let typeIdentifier: String
    let note: String

    var utType: UTType {
        UTType(typeIdentifier) ?? .data
    }
}

enum FormatCatalog {
    static let all: [ImageFormat] = [
        ImageFormat(id: "public.jpeg", name: "JPEG", fileExtension: "jpg", category: .common, typeIdentifier: "public.jpeg", note: "适合照片与网页"),
        ImageFormat(id: "public.png", name: "PNG", fileExtension: "png", category: .common, typeIdentifier: "public.png", note: "无损，支持透明"),
        ImageFormat(id: "public.heic", name: "HEIC", fileExtension: "heic", category: .common, typeIdentifier: "public.heic", note: "高压缩率照片"),
        ImageFormat(id: "public.heif", name: "HEIF", fileExtension: "heif", category: .common, typeIdentifier: "public.heif", note: "现代高效图像"),
        ImageFormat(id: "public.tiff", name: "TIFF", fileExtension: "tiff", category: .common, typeIdentifier: "public.tiff", note: "高质量印刷"),
        ImageFormat(id: "com.compuserve.gif", name: "GIF", fileExtension: "gif", category: .common, typeIdentifier: "com.compuserve.gif", note: "动图与简单动画"),
        ImageFormat(id: "com.microsoft.bmp", name: "BMP", fileExtension: "bmp", category: .common, typeIdentifier: "com.microsoft.bmp", note: "Windows 位图"),
        ImageFormat(id: "org.webmproject.webp", name: "WebP", fileExtension: "webp", category: .common, typeIdentifier: "org.webmproject.webp", note: "网页优先"),
        ImageFormat(id: "public.avif", name: "AVIF", fileExtension: "avif", category: .professional, typeIdentifier: "public.avif", note: "新一代网页图像"),
        ImageFormat(id: "com.apple.icns", name: "ICNS", fileExtension: "icns", category: .professional, typeIdentifier: "com.apple.icns", note: "macOS 图标资源"),
        ImageFormat(id: "com.microsoft.ico", name: "ICO", fileExtension: "ico", category: .professional, typeIdentifier: "com.microsoft.ico", note: "Windows 图标资源"),
        ImageFormat(id: "org.jpeg-xl", name: "JPEG XL", fileExtension: "jxl", category: .professional, typeIdentifier: "org.jpeg-xl", note: "高保真新格式"),
        ImageFormat(id: "com.adobe.photoshop-image", name: "PSD", fileExtension: "psd", category: .professional, typeIdentifier: "com.adobe.photoshop-image", note: "Photoshop 文档"),
        ImageFormat(id: "com.adobe.illustrator.ai", name: "AI", fileExtension: "ai", category: .professional, typeIdentifier: "com.adobe.illustrator.ai", note: "Illustrator 文档"),
        ImageFormat(id: "com.adobe.pdf", name: "PDF", fileExtension: "pdf", category: .professional, typeIdentifier: "com.adobe.pdf", note: "适合分享与印刷")
    ]

    static func formats(for page: SidebarPage) -> [ImageFormat] {
        switch page {
        case .professional:
            return all.filter { $0.category == .professional }
        case .common:
            return all.filter { $0.category == .common }
        case .about:
            return []
        }
    }
}

struct ConversionItem: Identifiable {
    let id = UUID()
    let url: URL
    var state: ItemState = .waiting

    enum ItemState {
        case waiting
        case converting
        case done(URL)
        case failed(String)
    }
}

@MainActor
final class ConverterModel: ObservableObject {
    @Published var page: SidebarPage = .common
    @Published var items: [ConversionItem] = []
    @Published var selectedFormatID = "public.jpeg"
    @Published var quality: Double = 0.9
    @Published var isConverting = false
    @Published var statusMessage = "准备就绪"

    var selectedFormat: ImageFormat {
        FormatCatalog.all.first(where: { $0.id == selectedFormatID }) ?? FormatCatalog.all[0]
    }

    var completedCount: Int {
        items.filter {
            if case .done = $0.state { return true }
            return false
        }.count
    }

    func setPage(_ page: SidebarPage) {
        self.page = page
        if let first = FormatCatalog.formats(for: page).first {
            selectedFormatID = first.id
        }
    }

    func add(urls: [URL]) {
        let accepted = urls.filter { $0.isFileURL && isSupportedInput($0) }
        let existing = Set(items.map { $0.url.standardizedFileURL })
        let newItems = accepted.filter { !existing.contains($0.standardizedFileURL) }.map { ConversionItem(url: $0) }
        items.append(contentsOf: newItems)
        if !newItems.isEmpty {
            statusMessage = "已添加 \(newItems.count) 个文件"
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func remove(_ item: ConversionItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        items.removeAll()
        statusMessage = "准备就绪"
    }

    func convert() {
        guard !items.isEmpty else {
            statusMessage = "请先添加图片"
            return
        }
        guard let outputDirectory = chooseOutputDirectory() else { return }

        isConverting = true
        statusMessage = "正在转换…"
        let format = selectedFormat
        let currentItems = items

        for index in currentItems.indices {
            guard let currentIndex = items.firstIndex(where: { $0.id == currentItems[index].id }) else { continue }
            items[currentIndex].state = .converting
            do {
                let destination = try ImageConverter.convert(
                    source: currentItems[index].url,
                    destinationDirectory: outputDirectory,
                    format: format,
                    quality: quality
                )
                items[currentIndex].state = .done(destination)
            } catch {
                items[currentIndex].state = .failed(error.localizedDescription)
            }
        }

        isConverting = false
        statusMessage = "完成：\(completedCount)/\(items.count) 个文件"
    }

    private func chooseOutputDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择输出文件夹"
        panel.message = "PictureGo 会将转换后的图片保存到这里"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func isSupportedInput(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return true }
        return type.conforms(to: .image)
    }
}

enum ImageConverter {
    static func convert(source: URL, destinationDirectory: URL, format: ImageFormat, quality: Double) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw ConversionError.cannotRead
        }
        let baseName = source.deletingPathExtension().lastPathComponent
        var destinationURL = destinationDirectory.appendingPathComponent("\(baseName).\(format.fileExtension)")
        if destinationURL.standardizedFileURL == source.standardizedFileURL {
            destinationURL = destinationDirectory.appendingPathComponent("\(baseName)-converted.\(format.fileExtension)")
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            format.typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.unsupported(format.name)
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.1, min(1.0, quality))
        ]
        CGImageDestinationAddImageFromSource(destination, imageSource, 0, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failedToWrite
        }
        return destinationURL
    }

    enum ConversionError: LocalizedError {
        case cannotRead
        case unsupported(String)
        case failedToWrite

        var errorDescription: String? {
            switch self {
            case .cannotRead: return "无法读取此图片"
            case .unsupported(let format): return "系统暂不支持导出为 \(format)"
            case .failedToWrite: return "无法写入目标文件"
            }
        }
    }
}

// MARK: - Main layout

struct ContentView: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 290)
        } detail: {
            ZStack {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                switch model.page {
                case .about:
                    AboutView()
                case .professional, .common:
                    ConverterView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.blue)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PictureGo")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("专业图片转换")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 48)
                .padding(.bottom, 22)

                Text("工作区")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                List(selection: Binding(
                    get: { model.page },
                    set: { if let value = $0 { model.setPage(value) } }
                )) {
                    ForEach(SidebarPage.allCases) { page in
                        Label(page.rawValue, systemImage: page.icon)
                            .font(.system(size: 13))
                            .tag(page)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("本地引擎已就绪")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
    }
}

struct ConverterView: View {
    @EnvironmentObject private var model: ConverterModel
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: model.page.rawValue,
                    subtitle: model.page == .professional ? "面向设计师与开发者的专业格式工作流" : "快速、清晰地完成日常图片转换"
                )

                DropZone(isTargeted: $isDropTargeted) {
                    model.chooseFiles()
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                    for provider in providers {
                        provider.loadObject(ofClass: NSURL.self) { object, _ in
                            guard let url = object as? URL else { return }
                            DispatchQueue.main.async { model.add(urls: [url]) }
                        }
                    }
                    return true
                }

                if !model.items.isEmpty {
                    FileQueueView()
                }

                HStack(alignment: .top, spacing: 16) {
                    FormatPickerCard()
                    QualityCard()
                }

                HStack {
                    Label(model.statusMessage, systemImage: model.isConverting ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        model.convert()
                    } label: {
                        HStack(spacing: 8) {
                            if model.isConverting {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(model.isConverting ? "正在转换" : "开始转换")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.items.isEmpty || model.isConverting)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.custom("PingFang SC", size: 20).weight(.light))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

struct DropZone: View {
    @Binding var isTargeted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(isTargeted ? 0.22 : 0.12))
                        .frame(width: 58, height: 58)
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.blue)
                }
                Text(isTargeted ? "松开即可添加" : "拖入图片，或点击选择文件")
                    .font(.system(size: 15, weight: .medium))
                Text("支持批量添加 · 系统会自动识别常见图片格式")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isTargeted ? Color.blue : Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7, 7]))
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

struct FileQueueView: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("待处理文件")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(model.items.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                    Spacer()
                    Button("清空") { model.clearAll() }
                        .buttonStyle(.link)
                        .font(.system(size: 12))
                }

                ForEach(model.items) { item in
                    HStack(spacing: 10) {
                        Image(nsImage: NSImage(contentsOf: item.url) ?? NSImage(size: NSSize(width: 28, height: 28)))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.url.lastPathComponent)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(item.url.pathExtension.uppercased())
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ItemStateView(state: item.state)
                        Button {
                            model.remove(item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct ItemStateView: View {
    let state: ConversionItem.ItemState

    var body: some View {
        Group {
            switch state {
            case .waiting:
                Text("等待中").foregroundStyle(.secondary)
            case .converting:
                ProgressView().controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .font(.system(size: 11))
    }
}

struct FormatPickerCard: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("输出格式", systemImage: "doc.badge.gearshape")
                    .font(.system(size: 13, weight: .semibold))
                Picker("输出格式", selection: $model.selectedFormatID) {
                    ForEach(FormatCatalog.formats(for: model.page)) { format in
                        Text("\(format.name)  ·  .\(format.fileExtension)").tag(format.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Text(model.selectedFormat.note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct QualityCard: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("导出质量", systemImage: "dial.medium")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Int(model.quality * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                Slider(value: $model.quality, in: 0.1...1.0)
                Text("对 JPEG、HEIC 等有损格式生效")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "关于我们", subtitle: "认识 PictureGo 与它背后的创作者")

                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Image(systemName: "photo.stack.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 60, height: 60)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PictureGo")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                Text("一个图片转化应用")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Text("该软件参与 AI 制作。")
                            .font(.system(size: 14, weight: .medium))
                        Text("ChatGPT 5.6 Sol辅助制作")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text("我是 Suisungo，平时喜欢搞搞别的。\n目前软件几乎可以说是有*所有*图片格式了。\n有任何 bug 请反馈给 19004762016@163.com\n\n感谢你的使用！\n另外，该项目已开源，由SwiftUI构建，目前只支持苹果系统。")
                            .font(.system(size: 13))
                            .lineSpacing(6)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    AboutStat(value: "15+", label: "内置格式")
                    AboutStat(value: "100%", label: "本地处理")
                    AboutStat(value: "∞", label: "批量图片")
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
    }
}

struct AboutStat: View {
    let value: String
    let label: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(17)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}
