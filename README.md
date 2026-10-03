# PictureGo

> 一款拥有毛玻璃界面、支持批量处理的原生 macOS 图片格式转换工具。

PictureGo 面向需要快速整理、转换和导出图片的创作者、设计师与开发者。它将常见图片格式与专业工作流集中在一个清晰的本地应用中：拖入图片，选择目标格式，调整质量，然后完成导出。

![PictureGo App Icon](https://imagetourls.com/zh/v?u=https%3A%2F%2Fcdn.imagetourls.com%2Fuploads%2FtyImg%2FM9GBSm0y.png)

## ✨ 特性

- 原生 macOS SwiftUI 应用，界面采用蓝紫渐变与毛玻璃视觉语言
- 侧边栏工作区：常见图片格式、专业图片格式、关于我们
- 支持文件选择与拖拽导入
- 支持批量图片转换
- 支持输出质量调节，适用于 JPEG、HEIC 等有损格式
- 转换结果保存到用户选择的本地文件夹
- 本地处理图片，不上传用户文件
- 集成 PictureGo 专属多尺寸 App 图标
- 附带一支快闪风格的产品介绍视频

## 🧩 支持格式

界面内置以下格式入口：

| 分类 | 格式 |
| --- | --- |
| 常见格式 | JPEG、PNG、HEIC、HEIF、TIFF、GIF、BMP、WebP |
| 专业格式 | AVIF、ICNS、ICO、JPEG XL、PSD、AI、PDF |

实际可读写能力由当前 macOS 的 ImageIO 编解码器决定。若系统没有对应编码器，PictureGo 会显示明确的失败提示，而不会静默生成无效文件。

## 🎬 产品介绍视频

[下载 PictureGo-intro.mp4](outputs/PictureGo-intro.mp4)

视频为 1920 × 1080、约 21.5 秒，包含原创电子氛围背景音乐和快速交叠转场，展示 PictureGo 的主要工作区与功能。

## 🛠️ 技术栈

- Swift 6
- SwiftUI
- AppKit
- ImageIO
- UniformTypeIdentifiers
- Core Graphics
- FFmpeg（仅用于生成产品介绍视频）

## 🚀 构建与运行

### 环境要求

- macOS 14.0 或更高版本
- Xcode Command Line Tools
- Swift 6 或兼容的 Apple Swift 工具链

### 编译 App

在项目根目录运行：

```bash
chmod +x build_app.sh
./build_app.sh
```

构建完成后，应用位于：

```text
outputs/PictureGo.app
```

也可以直接打开：

```bash
open outputs/PictureGo.app
```

构建脚本会完成以下工作：

1. 使用系统 `swiftc` 编译 SwiftUI 应用
2. 生成蓝紫渐变图片堆叠 App 图标
3. 生成多尺寸 `AppIcon.icns`
4. 写入应用 `Info.plist`
5. 进行本地 ad-hoc 签名
6. 输出可运行的 `PictureGo.app`

## 📁 项目结构

```text
.
├── Sources/PictureGo/main.swift       # SwiftUI 应用与转换逻辑
├── Resources/Info.plist               # App Bundle 配置
├── Resources/make_icon.swift           # App 图标生成器
├── build_app.sh                        # 编译与打包脚本
├── video/render_intro.py              # 产品介绍视频生成脚本
└── outputs/                            # 构建产物与宣传素材
```

## 📝 自定义界面文字

应用中的界面文本集中在 `Sources/PictureGo/main.swift`，例如：

- 侧边栏名称：`SidebarPage`
- 关于我们文案：`AboutView`
- 页面标题：`PageHeader`
- 拖拽区提示与按钮：`DropZone`、`ConverterView`

修改后重新运行 `./build_app.sh` 即可生成新的 App。

## ⚠️ 说明

PictureGo 目前使用 macOS ImageIO 进行图片编解码。不同 macOS 版本、硬件和系统组件可能对专业格式的导出能力有所差异；遇到不支持的格式时，应用会保留源文件并给出错误提示。

## 👤 关于作者

PictureGo 由 Suisungo 制作，AI 参与了部分设计与开发过程。

如发现问题或有功能建议，欢迎联系：

**19004762016@163.com**

感谢使用 PictureGo！

## 📄 License

当前项目尚未指定开源许可证。如果你准备公开发布仓库，建议根据项目用途补充合适的 License 文件。
