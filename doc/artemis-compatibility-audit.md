# Artemis 兼容引擎与 Android 二进制对照

## 后续修补状态（2026-09-05）

修补按功能分成独立提交，下面的“已实现”只覆盖列出的语义；完整原版兼容仍有缺口。

| 能力 | 本轮结果 | 尚未覆盖 |
| --- | --- | --- |
| 表情差分 | `0f7f0cb` 在同层换图时更新自然宽高和裁剪 UV，保留位置、锚点和父级变换。天梨 `a0054`（200×152）→ `a0051`（280×176）→ `a0002`（208×176）已在宿主及 Mate80 验证对齐 | 此场景为 PNG 差分，不经过 E-mote；E-mote 自身仍未实现 |
| 视频 | PFS 与包旁散装文件均可读；FFmpeg 解码、PCM 输出、全屏及指定图层播放、循环、等待、取消键、播完恢复场景已经接通。Mate80 已播放原 `movie/logo.mp4` 和 84 秒剧情视频 | 第三段长视频、OGV/透明视频、所有原版视频标签组合尚未验证 |
| 逐字 / ruby | 每字入场时序、批量字形绘制、首次点击补全文字、再次点击推进；消息层独立页；ruby 标签与 UTF-8 范围，读音和底文一起换行；`prohibit/hung` 基本禁则和悬挂标点 | 混合字体 / 嵌套样式、竖排、复杂 ruby 分配、完整断行与字形塑形、文字清除和隐藏动画 |
| 动画 | `tweenset` 同属性连续片段、loop、yoyo、无限循环和取消；锚点旋转、左右/上下翻转及旋转动画；绘制、点击、拖拽共用父级变换 | 完整 shader、图层效果中间缓冲及更多原版组合 |
| 按键 / 自动阅读 | override 各输入状态位和恢复、逐帧边沿、帧回调后的输入派发；自动阅读等文字和指定语音结束，再计算阅读间隔；点击/stop 停止自动阅读 | 完整快进 / 已读策略、更多 key role、脚本状态 get/set |
| 原版存档快照 | 已识别原包存档 `BOWS` 头、版本 1003、压缩长度和 zlib 负载，用于后续格式对照 | **尚未实现**原版快照导入或同格式写出；当前变量银行持久化和 Lua-source Pluto 子集不能替代原版存档 |

### 合并 main 后的图层变换修补

- `2f2b4c0` 合并 `origin/main` 的 `171ba79`（新首页、统计页及玻璃组件）。没有合并冲突，原有六项本机文件修改/删除经哈希检查保持不变。
- `d595b4f`（3 文件）：`rotate`、`reversex/reversey` 以及 `zoom`，采用 `T(position) T(anchor) R S(reverse×scale) T(-anchor)` 的父子矩阵组合。原 Android 库 `CDisplayObject::ApplyPropertyToMatrix`（`0x4d6dc8`）提供旋转角度、缩放、翻转及锚点顺序的对照。图片和字形四角均通过同一变换绘制；点击使用逆矩阵，避免旋转矩形包围盒中的空白也触发按钮。
- `d899ffc`（2 文件）：旋转角度接入 tween 参数读写，支持连续片段的隐式起点、往返及已有的循环机制。
- `9fad736`（4 文件）：拖拽位移先还原到父级坐标，再限制到 `dragarea`；同步写回横纵坐标。零缩放时忽略不可逆的拖拽位移。
- 合并后 Flutter **48 项测试通过**；GLES/视频配置 **4/4** 回归通过，无 GLES/无 FFmpeg 配置 **2/2** 通过；SDK 20 `engine_api` 与签名 Release HAP 构建成功。`flutter analyze` 返回 14 条 info、无 error/warning；七个被提示的文件与合并前逐字节一致，未在本轮改动。
- 宿主真实游戏到达天梨课堂剧情，额外施加 15° 旋转及水平翻转后，身体与表情保持对齐；这是受控变换验证，未声称该角度来自原剧情。无商业图片加入测试或提交。
- Mate80 上 `movie/dcpyzcv3t.mp4`（23359303 字节，约 84.93 秒）显示连续剧情画面，播完回到天梨课堂正文；音轨提交 4078592 帧，与宿主完整解码一致，`underflows=0`。本轮未录制扬声器声音，不能以此声称已量化声画同步精度。
- 新包已覆盖安装 Mate80；新首页和玻璃导航可显示，启动视频、标题及剧情可进入。新签名 HAP SHA-256：`3d88d2a46cd8221924a6dd9a2044744d0f569732ac49566f02e2bf22c36d5b78`；包内原生库 SHA-256：`b971019c1294b90b43985ea0e31df8b3705eba2bf2bd122914fb2b17eb234dc1`；build ID：`92451ab1dbfb47650f72b972baf3896971e286d5`。移除 `.comment` 后与 staged 库逐字节一致。

### 视频失败的两层根因

1. 公共引擎此前把 `$1==1` 一类表达式原样存入变量，游戏条件判断得到非数值而跳过视频。`a4cb7f6` / `5d6a8a3` 增加整数运算、比较、逻辑短路、位运算、字符串和变量引用解析，并在标签派发前求值。支持范围不等于原版完整表达式语法。
2. 视频读取接通后，Mate80 日志已显示 `movie/logo.mp4` 读取 **155570 字节**并打开 HEVC；失败点是 `sws_scale` 返回 0。FFmpeg 3.3.9 的 ARM64 NEON YUV/NV→RGBA 等无缩放包装函数确实写入了像素，却统一返回 0。`c2ef8aa` 将两个包装宏改为返回 `srcSliceH`，保留 NEON 加速。补丁放在 `vcpkg/ports/ffmpeg`，没有在 Flutter、游戏脚本或目录权限中绕过。

此前 hdc shell 看不到系统下载目录，只能说明 shell 的存储视图不同，不能据此判断应用不能读。应用原有授权可以读取 PFS 旁的 `movie`；无需用户复制视频到调试沙箱。

### 本轮验证

- 宿主四组测试 `runtime_regressions`、`audio_stream_regressions`、`video_decoder_regressions`、`compositor_regressions` 全部通过。新增覆盖表达式短路及二进制字符串、逐字/自动阅读、ruby、禁则/悬挂、视频帧/PCM/循环/取消、音轨短于视频后的结束处理。测试使用合成资源。
- 另在宿主编译相同 FFmpeg 3.3.9（Darwin 禁用汇编），原包三段 MP4 均完整解码：logo 151 帧、dcpyzcv3t 2548 帧、o4p6jwsag 2755 帧，分辨率均 1280×720，同时完整读出 PCM。这是宿主验证，不是三段均已在真机看完。
- HarmonyOS vcpkg 重新构建 FFmpeg Release/Debug，原生 `engine_api`、Release 签名 HAP 成功；覆盖安装保留应用数据。核对 HAP 中原生库与 staged 库，移除 `.comment` 后逐字节一致。
- Mate80 两次正常启动均打开原目录 `movie/logo.mp4`，画面 HEVC、声音 AAC。连续设备截图显示 Madosoft 标志动画；视频音轨提交 241860 帧，`underflows=0`，没有此前首帧转换失败，随后继续显示启动画面与标题。日志帧数不能代替扬声器听感或严格 A/V 同步测量。
- 视频阶段签名 HAP SHA-256：`858efbb400165aae98c4f6d50ea549282530265be49d598a66bd66ffd3b7e757`；包内 `libengine_api.so`：`9aa2e721d5ffca2e2e48d90abd01812184c83d0abefde26598c41040d61f5874`；build ID：`50dafa74d4abbd9a3d2fb2ffe3ae84edfd0f609e`。
- 日志、游戏截图和反汇编资料保存在未纳入版本管理的 `agent-artifacts/artemis-audit/`。公共引擎补丁在 vendor 源码；OHAudio 输出和生命周期留在鸿蒙后端。

禁则字符分类参考 [W3C JLReq 的行首、行尾禁则及悬挂标点](https://www.w3.org/TR/jlreq/#line_start_prohibition)，当前实现为横排基本子集，显式换行优先。

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

## 初轮验证记录（后续结果见上文）

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

初轮安装的签名 HAP SHA-256：`9dbfde223ae7056534531269afd3b2b36eb9fc1f442c5426b2f8e2958b3460e2`。包内 `libengine_api.so` SHA-256：`cb9d9a388dc5b73514061cc901c09500d3d1bc81834efb7d2802376c866a599a`；ELF build ID：`2369e1267f16afdbdd6881f401edfc94ef5f6d59`。

## 仍未完成的兼容能力

完整差异见文首表格。特别是原版存档：原包 `autosave.dat` 为 `BOWS` / 1003，解压后为 368256 字节的原生快照；兼容引擎目前只持久化变量银行，并且 `save file=...` 仍会落到系统变量保存路径，`load` 尚未恢复场景、Lua 状态及脚本游标。因此不能把存档按钮返回或槽位显示成功当作可读档的证据，也不能声称已有原版快照兼容。后续应先分离系统变量与槽位保存，再验证原版快照字段及完整恢复过程。

`libartemis.so` 与 `libartemis-compatible-v2.so` 含 E-mote 符号，其余几个被检查的版本未检出；兼容引擎没有相应实现。天梨此次脸部错位是已修复的 PNG 换图尺寸问题，不能由此推广为 E-mote 已可用。

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
