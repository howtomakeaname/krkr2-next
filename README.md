<p align="center">
  <h1 align="center">KrKr2 Next</h1>
  <p align="center">基于 Flutter 重构的下一代 KiriKiri2 跨平台模拟器</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-In%20Development-orange" alt="Status">
  <img src="https://img.shields.io/badge/engine-KiriKiri2-blue" alt="Engine">
  <img src="https://img.shields.io/badge/framework-Flutter-02569B" alt="Flutter">
  <img src="https://img.shields.io/badge/graphics-ANGLE-red" alt="ANGLE">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License">
</p>

---

**语言 / Language**: 中文 | [English](README_EN.md)

> 🙏 本仓库（HarmonyOS 适配版）基于 [reAAAq/KrKr2-Next](https://github.com/reAAAq/KrKr2-Next) 二次开发而来，在其基础上新增了 HarmonyOS/OpenHarmony（原生鸿蒙）支持，感谢原作者的贡献。上游项目又是基于 [krkr2](https://github.com/2468785842/krkr2) 重构的，一并致谢。

## 简介

**KrKr2 Next** 是 [KiriKiri2 (吉里吉里2)](https://zh.wikipedia.org/wiki/%E5%90%89%E9%87%8C%E5%90%89%E9%87%8C2) 视觉小说引擎的现代化跨平台运行环境。它完全兼容原版游戏脚本，使用现代图形接口进行硬件加速渲染，并在渲染性能和脚本执行效率上做了大量优化。基于 Flutter 构建统一的跨平台界面，支持 macOS · iOS · Windows · Linux · Android · HarmonyOS/OpenHarmony 六大平台。

下图为当前在 macOS 上通过 Metal 后端运行的实际效果：

<p align="center">
  <img src="doc/1.png" alt="macOS Metal 后端运行截图" width="800">
</p>

## 架构

<p align="center">
  <img src="doc/architecture.png" alt="技术架构图" width="700">
</p>

**渲染管线**：引擎通过 ANGLE 的 EGL Pbuffer Surface 进行离屏渲染（OpenGL ES 2.0），渲染结果通过平台原生纹理共享机制（macOS → IOSurface、Windows → D3D11 Texture、Linux → DMA-BUF）零拷贝传递给 Flutter Texture Widget 显示。


## 开发进度

> ⚠️ 本项目处于活跃开发阶段，尚未发布稳定版本。macOS 平台进度领先。

| 模块 | 状态 | 说明 |
|------|------|------|
| C++ 引擎核心编译 | ✅ 完成 | KiriKiri2 核心引擎全平台可编译 |
| ANGLE 渲染层迁移 | ✅ 基本完成 | 替代原 Cocos2d-x + GLFW 渲染管线，使用 EGL/GLES 离屏渲染 |
| engine_api 桥接层 | ✅ 完成 | 导出 `engine_create` / `engine_tick` / `engine_destroy` 等 C API |
| Flutter Plugin | ✅ 基本完成 | Platform Channel 通信、Texture 纹理桥接 |
| Texture 零拷贝渲染 | ✅ 基本完成 | 通过平台原生纹理共享机制零拷贝传递引擎渲染帧到 Flutter |
| Flutter 调试 UI | ✅ 基本完成 | FPS 控制、引擎生命周期管理、渲染状态监控 |
| 输入事件转发 | ✅ 基本完成 | 鼠标 / 触控事件坐标映射转发到引擎 |
| 引擎性能优化 | 🔨 进行中 | SIMD 像素混合、GPU 合成管线、VM 解释器优化等 |
| 游戏兼容性优化 | 🔨 进行中 | 补全解析引擎、添加插件，阶段目标与 Z 大闭源版兼容性持平 |
| 原有 krkr2 模拟器功能移植 | 📋 规划中 | 将原有 krkr2 模拟器功能逐步移植到新架构 |

## 平台支持状态

| 平台 | 状态 | 图形后端 | 纹理共享机制 |
|------|------|----------|-------------|
| macOS | ✅ 基本完成 | Metal | IOSurface |
| iOS | 🔨 流程打通，正在优化和修复 OpenGL 渲染 | Metal | IOSurface |
| Windows | 📋 计划中 | Direct3D 11 | D3D11 Texture |
| Linux | 📋 计划中 | Vulkan / Desktop GL | DMA-BUF |
| Android | 🔨 流程跑通，优化中 | OpenGL ES / Vulkan | HardwareBuffer |
| HarmonyOS / OpenHarmony | 🔨 流程跑通（模拟器实测可玩），优化中 | 系统 EGL (GLES) / 软件合成 | OHNativeWindow / RawImage 读回 |

## HarmonyOS / OpenHarmony（原生鸿蒙）支持

本仓库在 upstream 基础上新增了原生鸿蒙（HarmonyOS / OpenHarmony，API 20 / SDK 5.x）支持：引擎 C++ 核心经 OHOS NDK（llvm + musl）交叉编译为 `libengine_api.so` 打入 HAP，由 Flutter OHOS 宿主加载；音频走系统 OHAudio；字体直接注册 `/system/fonts` 下的 NotoSansCJK 等系统字体。

### 环境准备

1. [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（含 OpenHarmony SDK，实测用 API 20）
2. Flutter OHOS fork：[flutter_flutter_ohos](https://gitcode.com/openharmony-sig/flutter_flutter)（实测 `oh-3.41.9-release` 分支），检出后将其 `bin` 加入 PATH
3. [ohos_flutter_packages](https://gitcode.com/openharmony-sig/flutter_packages) 检出到与本仓库**同级**的 `ohos_flutter_packages/` 目录（OHOS 专属的 `dependency_overrides` 存放在 `apps/flutter_app/pubspec_overrides.ohos.yaml`，构建脚本会自动拷贝为 `pubspec_overrides.yaml` 启用；其他平台不受影响，无需该目录）
4. vcpkg 依赖按仓库根 `vcpkg.json` 拉取，triplet 使用 `vcpkg/triplets/arm64-ohos.cmake`

### 构建与安装

```bash
./build/build_ohos.sh release     # 交叉编译引擎 + flutter build hap
hdc install -r apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

> ⚠️ 性能相关：请勿用 `debug` 产物评估性能——CMake Debug 为 `-O0`，Highway SIMD
> 混合内核退化为每 16 像素多次跨函数调用，整帧合成慢约两个数量级。release 为
> `-O2 -DNDEBUG` + Flutter AOT。

### 运行说明与已知限制

- 模拟器上建议在应用设置中切换 **renderer=software**（软件渲染 + RawImage 帧路径）；模拟器 GPU 对高频纹理上传不稳定，实机可尝试默认 GL 路径
- 游戏导入：系统文件选择器只返回 `docs://` URI（fopen 引擎无法消费），应用内提供沙箱目录扫描与 URL 网络导入（支持断点续传）；也可 `hdc file send` 直接送入应用沙箱
- Cubism Live2D 插件因无 OHOS 预编译 Core 暂未编入；layerex_draw（libgdiplus 依赖）同
- 引擎日志：hilog（tag `krkr2`）与应用沙箱内 `files/flutter/krkr2-engine.log` 双通道

## macOS 源码构建

```bash
./build/build_macos.sh debug      # 引擎 + Flutter app（需 Xcode）
```

Live2D Cubism SDK 因再分发许可**不入库**（`cpp/plugins/cubism/` 下的 `Core/lib/` 与 `Framework/` 已 gitignore），首次构建前需自行放置：

- `Core/`：官方 [CubismSdkForNative](https://cubism.live2d.com/sdk-native/en/) 压缩包（实测 5-r.5）中的 `Core` 目录——含各平台预编译 `libLive2DCubismCore.a` 与头文件；
- `Framework/`：使用 [KiriKiri-LauncherC](https://github.com/xiaocongyu66/KiriKiri-LauncherC) 仓库内的修补版 Framework（保留 krkrlive2d.cpp 所需的 `SetDrawableForceHidden` 等扩展 API）。

引擎无 UI 冒烟验证可不依赖 Xcode/Flutter：直接链接 `out/macos/debug/bridge/engine_api/libengine_api.dylib` 调用 engine_api C 接口（`engine_open_game_async` 支持 `.xp3` 归档或解包目录），设 `KRKR_HEADLESS=1` 可让引擎跳过系统弹窗、改为 stderr 输出。

## 引擎性能优化

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P0 | 像素混合 SIMD 化 ([Highway](https://github.com/google/highway)) | ✅ 完成 |
| P0 | 全 GPU 合成渲染管线 | 🔨 进行中 |
| P0 | TJS2 VM 解释器优化 (computed goto) | 📋 计划中 |
## 许可证

本项目基于 GNU General Public License v3.0 (GPL-3.0) 开源，详见 [LICENSE](./LICENSE)。
