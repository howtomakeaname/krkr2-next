# Artemis 兼容引擎与 Android 二进制对照

审计日期：2026-09-05。目标平台：HarmonyOS SDK 20 / arm64。

## 对照范围与证据

- 原库与 Android 接入：[Tyranor-Next](https://github.com/Weiss-UltimateSavior/Tyranor-Next)，检出提交 `2f28e0c`，目录 `engine/src/main/nativeplugins/artemis/arm64-v8a`。
- 兼容引擎：[artemis-compat](https://github.com/Weiss-UltimateSavior/artemis-compat)，本项目 vendor 固定提交 `d23ca4d6df0abd5d305da683971b55a1ae6bd2c0`，附加修补见 `cpp/artemis/upstream/UPSTREAM.md`。
- 方法：ELF 动态依赖、导出符号、字符串和 ARM64 函数定点反汇编，再与实际游戏 Lua 调用及兼容引擎实现对照。没有恢复完整原版 C++ 源码；符号存在本身也不能证明某游戏在该版本中的实际行为。
- 实际游戏包：用户提供的“常轨脱离Creative凸（官中）”及 patch 链。游戏资源和提取脚本仅用于本地验证，不纳入回归测试或源码。

| Android 库 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `libartemis-compatible-v2.so` | 9304328 | `75ffde0ad3a8c58fd82a3f797131686eb66ed7468a7db6452be7932718c44b35` |
| `libartemis-compatible.so` | 7506728 | `48e72b81092d30144af4a8362eb47f04c71d2e5f03539a9c5b39030d4f72b8ee` |
| `libartemis-v4.so` | 8136736 | `9839e6fee3287ac7ad16149b49732b87b51276c3dff2a0633bdf7d2247807012` |
| `libartemis-v5.so` | 8201376 | `55d8deb7623b968ce6d9cb290e33a1199bc978fe72583fc9403d180afaf4b315` |
| `libartemis.so` | 9292144 | `cb2b58d8080b29529b27a8453f602646ab5f13ae5d4acc59b673c27c27e2d9cc` |

这些库均使用 `artemis::` 符号，未发现兼容项目的 `artc::` 符号。因此文件名里的 `compatible` 不能当作“当前 artemis-compat 编译产物”的证据。它们依赖 Android 的 `libandroid`、`liblog`、OpenSL ES 等接口；Tyranor 经动态加载和 `ANativeActivity_onCreate` 驱动它们。不能仅把 `.so` 改名或替换链接库就当作鸿蒙原生引擎使用。

## 已确认的差异与修补

| 问题 | 证据 / 原行为 | 修改位置 |
| --- | --- | --- |
| 启动白屏、转场后还要多点一次 | 游戏 `wt()` 发出 `{wait,input=1}`，转场后可能连续发出两次。旧实现把 `input` 当成新的无限点击等待；它应只决定现有等待是否可被输入打断 | 公共引擎 `script/lua_engine.cpp` |
| BGM 只反复播放前奏 | 原 `CVorbis::Load` 在 `0x54ad8c` 一带比较文件 stem 的 `_a`，随后拼接 `_b.`；`CVorbis::Read` 在 `0x54b7b8` 接续第二源。游戏大量采用这类音频 | 公共引擎 `audio/vorbis_stream.*`，两平台后端消费该流 |
| 换曲、停 SE、音量设置不正确 | 原库存在 `CommandSxfade/Sfade/Sestop/Sefade/Span/Sepan` 和有时间参数的 `CSoundManager`；游戏实际调用这些标签。旧兼容实现没有完整执行这些标签，且 BGM 按文件名建声道、无 id 的 sstop 停止全部声音 | 公共引擎 `audio/audio_channels.*`、Lua 标签派发 |
| BGM 切换时同步展开整首音频 | 原库有 `CSoundMixer::Mix`、`CSoundTrack::Read`。旧实现把整首 Ogg 解成 PCM，再开始输出 | 公共引擎分块 Vorbis 解码；保留压缩字节，在音频回调中读取 PCM |
| 淡出末端闪一下 | alpha 的 `v > 1 ? v/255 : v` 把脚本值 1 当成完全不透明 | 公共合成器统一采用 0–255 alpha，允许零缩放与镜像缩放 |
| 转场来源依赖窗口缓冲 | 旧 `CaptureFrame` 在上一帧 swap 后拷贝默认帧缓冲，无法保证读到已呈现的场景 | 公共合成器保存场景 FBO，从保留场景捕获转场；保留目标 viewport/framebuffer |
| 点击禁用按钮仍触发、Lua 回调长期积累栈数据 | `setEventFilter` 原来是空实现；带点号函数查找残留父表 | 公共 Lua 引擎注册过滤器，过滤点击和 onpush；共用栈平衡的函数查找 |
| 回调跳转后跳过新脚本首条指令 | 原循环持有旧 `AsbLine&`，Lua 可以在执行中替换脚本，循环仍推进新的游标 | 公共 `AsbRunner::ExecuteLine` 使用指令副本与流程版本；宿主调用同一执行函数 |
| 菜单事件推进正文、开始游戏跳转被吞 | 旧兼容层直接复用正文游标；显式 return 后继续跳转又被全局 returning 标记拦截。实际游戏设置页往返可复现 | 公共执行器保存事件返回帧与原等待，提供脚本栈；移除无条件跳转拦截 |
| 选择项文字偏左、描边缺失、换行失效 | 游戏 font 标签指定 `align/outline/outlinecolor`，旧光栅化忽略这些属性，`rt` 也无操作 | 公共合成器按 em 排版、使用 typographic metrics、对齐/描边/换行，并按当前文本层加载字体；行距计入 ruby 预留行，文本区域位置与图层变换分开，空文本清除纹理 |
| 语音尾部可能被提前释放 | OHAudio 回调填完最后一块不等于扬声器播完最后一块 | 仅鸿蒙后端按呈现 timestamp 判断尾部播放完成；恢复暂停时保留已排队尾音 |
| 语音结束时渲染线程等待系统音频释放 | DevEco 官方《推荐使用 OHAudio 开发音频播放功能》说明 Stop 等待缓存，普遍超过 50 ms；旧后端从引擎线程同步 Stop/Release | 仅鸿蒙后端立即静音并移交回收线程，销毁引擎时等待所有回调与资源释放 |
| ARM Mac 交叉构建误执行 OHOS ELF、GNU config.sub 拒绝 ohos | legacy Meson helper 只看 CPU family 与平台白名单；GNU 主机名解析不识别 linux-ohos | 仅鸿蒙 triplet 显式提供 cross file，并用 Linux/musl configure 别名；公共 Meson 构建适配在 SDK 参数提取后抑制未使用的 driver 参数，修正基础类型/NEON 误探测；GLib 选择与 `__linux__` 一致的源文件集合。实际 clang target/sysroot 保持 OHOS |

声像取值按原库 `CSoundTrack::SetPan` 对照限制为 -1000…1000；使用 constant-power 左右增益。音量限制为 0…1000。交叉淡化保留两条物理轨，编号 SE/语音与 BGM 分离，后端只负责输出。

## 验证记录

- 桌面 ARM64 + ANGLE GLES：`runtime_regressions`、`audio_stream_regressions`、`compositor_regressions` 通过。测试仅使用合成脚本、正弦波和自制矩形字体。
- 已覆盖：交叉淡化中点与结束、独立停止、替换失败保留旧曲、淡化重新定向、声像；`_a → _b` 样本连续、循环重复、loop=0 顺序播放两段、缺少 `_b` 回退；强制等待与可跳过等待、无条件等待立即结束、过滤按钮、Lua 栈平衡与重入跳转；转场不读被清空的默认缓冲、alpha=1、零缩放；文字居中、描边与显式换行、ruby 预留行、字体区域与图层位移组合、空文本清理；菜单事件跳转/调用返回后恢复原游标和等待。
- 生命周期回归：菜单事件挂起正文的定时等待时，切到后台再恢复会同时平移活跃等待和事件返回帧中的等待期限，后台停留不会耗尽正文等待时间。
- SDK 20：Artemis core 与原生回归测试可交叉编译。真机拒绝通过 hdc shell 执行未签名独立 ELF，不能将这些测试记为真机通过。
- 构建探测：重编后的 GLib/FriBidi/Cairo 正确识别 `int=4`，Cairo 指针、`long`、`size_t` 均为 8；Pixman 的 `NEON A64 Intrinsic Support` 为 `YES`，对应依赖已成功编译。
- Android：音频后端使用 AOSP 官方 OpenSL ES 头文件通过语法检查；没有 Android 设备运行结果。
- 桌面真实游戏：启动画面自动结束、标题菜单、灰色“继续游戏”被拦截、开始游戏、路线选择、剧情分支和正文、设置页可到达；设置打开/关闭后，正文保持原句及原生游标 48，之后普通点击才推进下一句。宿主音频是静音 stub，因此桌面游戏验证不代表系统音频输出验证。
- 完整 SDK 20 构建：vcpkg 依赖重建、`engine_api` 编译链接、OHOS Flutter Release HAP 打包及签名全部成功；使用 `hdc install -r` 覆盖安装到 HUAWEI Mate 80，保留原有应用数据与游戏包。
- 真机真实游戏：启动流程无需额外点击即可到达标题；灰色“继续游戏”点击后仍停留标题；开始游戏、路线选择、剧情与选项均可进入。设置页打开后按 Home，后台停留约 10 秒，再恢复并返回，仍显示原来的“直接邀请天梨 / 静观其变”两项选择及同一句正文。
- 真机音频：采集范围内 29 个已回收 renderer 的 `underflows` 均为 0；标题语音完整提交 152245 帧，短音效和多条角色语音也有播放/回收记录。`bgm06_a → bgm06_b`、`bgm28_a → bgm28_b` 配对均成功。点击跳过会主动终止语音，因此部分回收帧数短于源长度是跳过行为；这些数据不能代替扬声器实际听感评价。
- 真机日志采集范围内未发现 `ERROR / failed / Exception / UNIMPLEMENTED` 记录；这不代表所有标签都已实现。截图、会话日志和构建 manifest 留在本地 `agent-artifacts/artemis-audit`，不将商业游戏资源纳入源码。

本次安装的签名 HAP SHA-256：`9dbfde223ae7056534531269afd3b2b36eb9fc1f442c5426b2f8e2958b3460e2`。包内 `libengine_api.so` SHA-256：`cb9d9a388dc5b73514061cc901c09500d3d1bc81834efb7d2802376c866a599a`；ELF build ID：`2369e1267f16afdbdd6881f401edfc94ef5f6d59`。

## 仍未实现的原库能力

本次修补不是原版引擎的完整替代。仍需独立实现并逐项验证：视频播放（当前兼容路径会跳过）、逐字显示和完整 ruby/复杂排版、更多图层 shader/动画语义、完整按键 override/自动阅读语义、原生存档/读档快照兼容等。`libartemis.so` 与 `libartemis-compatible-v2.so` 含 E-mote 符号，其余几个被检查的版本未检出；兼容引擎没有相应实现。不能由“能进标题或剧情”推断这些功能已正常。

## 复现

宿主基础回归：

```sh
cmake -S cpp/artemis/tests -B /tmp/artemis-tests -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/artemis-tests
ctest --test-dir /tmp/artemis-tests --output-on-failure
```

GLES 回归另加 `-DARTC_TEST_GLES=ON`，桌面需要提供 ANGLE、EGL/GLES registry 的 CMake prefix/include。OHOS 使用 SDK 20 toolchain 时直接链接系统 EGL/GLES；`ARTC_TEST_DATA_DIR` 可以指定设备上的合成资源目录。正式真机游戏验证应通过签名 HAP，不能用 shell ELF 执行失败替代测试结论。

完整鸿蒙原生库构建（在仓库根目录，先将 `OHOS_NATIVE_SDK` 设置为 SDK 20 的 `native` 目录）：

```sh
export VCPKG_ROOT="$PWD/.devtools/vcpkg"
cmake -S . -B /tmp/krkr-artemis-native-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DOHOS_STL=c++_shared \
  -DOHOS_ARCH=arm64-v8a -DOHOS_PLATFORM=OHOS \
  -DVCPKG_TARGET_TRIPLET=arm64-ohos \
  -DVCPKG_INSTALL_OPTIONS=--allow-unsupported \
  -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$OHOS_NATIVE_SDK/build/cmake/ohos.toolchain.cmake"
cmake --build /tmp/krkr-artemis-native-build --target engine_api -j6
```

将生成的 `bridge/engine_api/libengine_api.so` strip 后放入 `apps/flutter_app/ohos/entry/libs/arm64-v8a`，同时使用相同 SDK 的 `libc++_shared.so` 和 `libomp.so`。然后使用 OHOS Flutter 分支运行 `flutter build hap --release`；必须确认命令成功，并核对签名 HAP 中原生库的 build ID、加载段及哈希，不能只检查旧 HAP 文件是否存在。Hvigor 会移除 `.comment`：本次对 staged 库执行 `llvm-objcopy --remove-section=.comment` 后，与 HAP 内库逐字节一致。
