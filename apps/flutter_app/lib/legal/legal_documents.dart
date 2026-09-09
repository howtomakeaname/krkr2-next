import '../config/app_info.dart';

/// In-app legal copy. Keep this aligned with the repo LICENSE and the
/// code paths that actually run (prefs, first-open, VNDB scrape).
///
/// `{appName}`, `{copyrightHolder}`, `{copyrightYear}`, and `{appVersion}`
/// come from [AppInfo]. Upstream project names
/// such as reAAAq's KrKr2 Next stay as historical references.
class LegalDocuments {
  const LegalDocuments(this.languageCode);

  final String languageCode;

  static const updatedOn = '2026-09-09';

  String get openSource =>
      _fill(_pick(_openSourceZh, _openSourceEn, _openSourceJa));

  String get privacy => _fill(_pick(_privacyZh, _privacyEn, _privacyJa));

  String get disclaimer => _fill(_pick(_disclaimerZh, _disclaimerEn, _disclaimerJa));

  String _fill(String text) => text
      .replaceAll('{appName}', AppInfo.nameForLanguage(languageCode))
      .replaceAll(
        '{copyrightHolder}',
        AppInfo.copyrightHolderForLanguage(languageCode),
      )
      .replaceAll('{copyrightYear}', '${AppInfo.copyrightYear}')
      .replaceAll('{appVersion}', AppInfo.version);

  String _pick(String zh, String en, String ja) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('zh')) return zh;
    if (code.startsWith('ja')) return ja;
    return en;
  }
}

const _openSourceZh = '''
第一条 目的与适用范围

本声明适用于软件「{appName}」（以下简称「本软件」）。本软件系用于运行 KiriKiri2 视觉小说，并包含本仓库另行接入之 Artemis 作品运行能力的自由软件。

本声明旨在：（一）披露本软件之许可条件；（二）对上游项目予以致谢；（三）列明本软件所使用之第三方开源组件及其许可协议。本声明为摘要，不替代各许可证之完整文本。完整条款以本仓库根目录 LICENSE、各上游 NOTICE 及源码文件头为准；如有不一致，以上游文本为准。

第二条 致谢

本软件之实现有赖于吉里吉里2（KiriKiri2）作者 W.Dee 及 Kirikiri Z 各贡献者所提供之引擎与脚本环境。本软件开发者在此致谢。

本 HarmonyOS / OpenHarmony 构建系基于 reAAAq 所发布之 KrKr2 Next 进行的二次开发；KrKr2 Next 又源自 2468785842 所发布之 krkr2 对 KiriKiri2 的重构。对于前述上游将引擎迁移至现代图形栈及跨平台界面所作之工作，一并致谢。

本条致谢不构成对前述主体之合作、授权、赞助或代言关系的陈述。

第三条 本软件之许可

本软件中由「{copyrightHolder}」享有著作权之部分，依照 GNU 通用公共许可证第 3 版或（由被许可人选择）其后任何版本（GPL-3.0-or-later）授权。仓库根目录 LICENSE 载明：Copyright (C) {copyrightYear} {copyrightHolder}。

在遵守 GPL-3.0-or-later 的前提下，被许可人得复制、修改并再分发本软件。本软件按「现状」（AS IS）提供。有关无担保及责任限制，适用 GPL 第 15 条、第 16 条，并适用「关于」页面所载免责声明。于「关于」页面提供本开源协议声明，亦为满足 GPL 关于适当法律声明（Appropriate Legal Notices）之要求。GPL-3.0 全文参见：https://www.gnu.org/licenses/gpl-3.0.html

第四条 第三方组件清单

以下列明本仓库直接依赖或 LICENSE 中载明之主要组件。各项包括名称、许可协议及用途说明。部分组件仅在特定平台或构建选项下予以链接，未必包含于用户所取得之特定二进制发行中。传递依赖未能尽列。

（一）引擎及上游项目

1. KiriKiri2 / Kirikiri Z（W.Dee 及贡献者）
许可协议：类 BSD 条款。再分发时应当保留著作权声明及免责声明；未经书面许可，不得将相关组织或贡献者之名称用于衍生作品之宣传。
用途：吉里吉里视觉小说引擎本体，提供 TJS 脚本、图层、音视频及 XP3 等资源格式。

2. krkr2（2468785842）
许可协议：从其仓库之规定；本项目 LICENSE 以 GPL-3.0-or-later 承接，并保留上游声明。
用途：将 KiriKiri2 自既有渲染栈迁移之开源重构，为本软件所依据之 KrKr2 Next 的直接上游。

3. KrKr2 Next（reAAAq）
许可协议：GPL-3.0-or-later
用途：以 Flutter 实现界面并接入现代图形接口的跨平台运行器。本 HarmonyOS 构建系在其基础上的二次开发。

4. Artemis 引擎相关源码
许可协议：GPL-3.0。其中 Lua 5.1.5 为 MIT 许可，stb_vorbis 为公有领域 / MIT 许可。
用途：运行以 .pfs 封包之 Artemis 作品。第三方说明见 cpp/artemis/upstream/THIRD_PARTY_NOTICES.md。

5. Lua 5.1.5
许可协议：MIT
用途：嵌入式脚本语言，经 Artemis 第三方目录引入。

6. stb_vorbis（Sean Barrett）
许可协议：公有领域 / MIT
用途：Ogg Vorbis 音频解码。

（二）图形、图像及字体

7. ANGLE
许可协议：BSD-3-Clause
用途：将 OpenGL ES 转译为 Metal、Vulkan 或 Direct3D。适用于桌面及部分移动构建。HarmonyOS 构建采用系统 EGL，不经由 ANGLE。

8. libjpeg-turbo / Independent JPEG Group
许可协议：IJG、BSD-3-Clause 及 zlib（组合适用）
用途：JPEG 编解码，供引擎读取图像。

9. libpng
许可协议：libpng License
用途：PNG 编解码。

10. libwebp
许可协议：BSD-3-Clause
用途：WebP 图像处理。

11. FreeType
许可协议：FreeType License（亦可选择 GPL）
用途：字体光栅化，供引擎绘制文字。

12. jxrlib / JPEG XR Device Porting Kit
许可协议：Microsoft 文档许可（BSD 风格）
用途：JPEG XR 图像处理。

13. OpenCV 4
许可协议：Apache-2.0
用途：计算机视觉库，经 vcpkg 引入，用于部分图像处理路径。

14. Highway
许可协议：Apache-2.0
用途：SIMD 辅助运算。

（三）音频及容器

15. libogg / libvorbis / Theora（Xiph.org）
许可协议：BSD-3-Clause
用途：Ogg 容器、Vorbis 音频及 Theora 视频。

16. OpenAL Soft
许可协议：LGPL-2.1
用途：跨平台音频输出。部分平台适用。

17. FFmpeg
许可协议：通常为 LGPL-2.1+；如构建启用 GPL 组件，则适用 GPL。
用途：音视频解复用与解码。具体许可以实际链接之构建选项为准。

18. Opus / opusfile
许可协议：BSD-3-Clause
用途：Opus 音频。部分平台适用。

19. Oboe
许可协议：Apache-2.0
用途：Android 低延迟音频，仅适用于 Android。

（四）压缩及归档

20. 7-Zip
许可协议：LGPL-2.1+；其中用于解压 RAR 之代码另受 unRAR 限制条款约束。
用途：文件管理中的解压功能（file_archive）及引擎侧归档处理。

21. libarchive
许可协议：BSD-2-Clause
用途：通用归档读写。

22. UnRAR
许可协议：unRAR license（允许使用源码，但禁止用于复现 RAR 压缩算法）。
用途：RAR 解压。源码可获得，但不构成 OSI 意义上的宽松开源许可。

23. minizip / zlib
许可协议：zlib
用途：zip 及通用压缩。

24. lz4
许可协议：BSD-2-Clause
用途：高速压缩。

25. zstd
许可协议：BSD 与 GPL-2 双许可
用途：Zstandard 压缩。

（五）文本、正则及其他原生组件

26. Oniguruma
许可协议：BSD-2-Clause
用途：正则表达式引擎，供 TJS / 脚本侧使用。

27. picojson
许可协议：BSD-2-Clause
用途：轻量 JSON 解析。

28. libxml2
许可协议：MIT
用途：XML 解析。

29. tinyxml2
许可协议：zlib
用途：轻量 XML 解析。

30. uchardet
许可协议：MPL-1.1 / GPL / LGPL（三许可，择一适用）
用途：文本编码探测。

31. MT19937（Matsumoto & Nishimura）
许可协议：BSD 风格
用途：梅森旋转伪随机数发生器。

32. Boost（含 iostreams、locale、spirit、phoenix 等）
许可协议：Boost Software License 1.0
用途：C++ 基础库，涵盖流、本地化及语法分析等。

33. Bullet Physics
许可协议：zlib
用途：物理引擎，随历史引擎依赖引入。

34. fmt / spdlog
许可协议：MIT
用途：格式化及日志。

35. SDL2
许可协议：zlib
用途：窗口与输入，适用于部分桌面平台。

36. Android Open Source Project 片段
许可协议：Apache-2.0
用途：LICENSE 中收录之 AOSP 代码。

37. libgdiplus
许可协议：MIT
用途：部分非 Windows 平台之 GDI+ 兼容层。

（六）界面及 Flutter 插件（pubspec 直接依赖）

38. Flutter / Dart SDK
许可协议：BSD-3-Clause
用途：跨平台用户界面及语言运行时。

39. shared_preferences、path_provider、url_launcher、image_picker、http、video_player、cupertino_icons 等 Flutter 团队插件
许可协议：BSD-3-Clause（以各软件包 LICENSE 为准）
用途：本地设置、路径、外部链接、图像选取、网络请求、视频预览及 Cupertino 图标。

40. file_picker
许可协议：MIT
用途：选取文件或目录，以导入游戏。HarmonyOS 构建采用同级检出之移植实现。

41. flutter_svg
许可协议：MIT
用途：SVG 渲染。

42. lucide_icons_flutter
许可协议：包装层为 MIT；Lucide 图标本身主要为 ISC
用途：界面线性图标。

43. liquid_glass_widgets
许可协议：MIT
用途：底部导航等液态玻璃视觉效果。

44. unorm_dart
许可协议：MIT
用途：Unicode 正规化。

45. intl / path
许可协议：BSD-3-Clause
用途：国际化及路径处理。

第五条 开发期依赖

Catch2（BSL-1.0）及 argparse（MIT）等组件主要用于测试或命令行工具，通常不纳入用户所安装之应用程序。

第六条 解释

本声明所列许可名称均为通行简称。具体权利义务以各许可证全文为准。本声明不授予超出各许可证范围之任何权利。
''';

const _privacyZh = '''
第一条 目的与适用范围

本隐私声明适用于软件「{appName}」（以下简称「本软件」），用以说明本软件在现行实现下对信息的处理方式。本软件不提供用户账号体系，亦不向任何第三方出售用户个人信息。

第二条 定义

「本地存储」指保存在用户设备上、默认不向本软件开发者所控制之服务器传输的数据。「网络传输」指本软件经系统网络权限向设备以外主机发送或接收数据。

第三条 本地存储的信息

除用户自行复制、导出或通过操作系统备份外，下列信息默认仅保存在用户设备：

（一）游戏库条目、封面路径、显示名称，以及经用户主动操作取得的简介与关键词；
（二）设置项，包括语言、主题、帧率、横屏锁定及引擎相关选项等；
（三）供「统计」功能使用的游玩时长及会话记录；
（四）文件管理所涉之授权目录、最近删除清单及相关状态；
（五）是否已完成「首次打开」上报，以及为此在本地生成的匿名标识。

第四条 网络传输

HarmonyOS 发行包声明网络权限。现行实现下的网络传输限于：

（一）首次打开上报。本软件于启动时尝试向统计地址发送一次 HTTP POST 请求，路径为 /api/first_open。请求正文仅包含 id（于本地生成的匿名标识）及 v（当前固定为 {appVersion}）。本构建所配置之地址为本机回环地址：一般设备为 127.0.0.1:8080，Android 模拟器为 10.0.2.2:8080，并非面向公众的统计分析服务。在真实设备上，该服务通常并不存在；请求失败不影响本软件继续运行。现行界面未提供关闭该项上报的选项。

（二）元数据刮削。仅在用户主动使用「刮削信息」功能时，本软件将用户输入的检索词发送至 VNDB Kana API（https://api.vndb.org/kana），并可能进一步请求作品详情。用户选定封面后，本软件自 VNDB 返回的图像地址下载封面，请求中附带 Referer: https://vndb.org/。

第五条 本软件不处理的信息

本软件不提供注册或登录，不收集用户的电话号码、电子邮箱或真实姓名；不将游戏文件、存档、截图或「管理」目录中的内容上传至本软件开发者所控制的服务器（本构建亦不存在此类服务器）；不接入广告软件开发工具包，不进行跨应用广告追踪；不在「关于」页面收集或展示作者联系方式。

第六条 系统权限与文件范围

HarmonyOS 发行包声明网络权限及振动权限。游戏文件及「管理」功能仅在用户授权的目录范围内，或在 Download/<应用标识>/ 路径下，于本地进行读写。更换封面可能唤起系统相册或文件选择器。

第七条 第三方处理

用户向 VNDB 提交的检索，由 VNDB 依其自身条款处理。本软件无法决定该第三方是否记录访问日志。如日后将首次打开上报之地址变更为远程主机，按现行实现，报送内容仍仅包括匿名标识及版本号；届时应当相应修订本声明，不得继续表述为仅向本机回环地址发送。

第八条 修订

本声明依据 2026-09-09 之程序实现整理。实现变更的，本声明应当同步修订。
''';

const _disclaimerZh = '''
第一条 按现状提供

本软件按「现状」（AS IS）提供，不对适销性、特定用途适用性、不侵权或持续可用性作任何明示或默示保证。本条与仓库 LICENSE 所附 GPL-3.0 第 15 条、第 16 条一致。用户使用本软件的全部风险由用户自行承担，包括但不限于存档损坏、兼容性失败、数据丢失或设备异常。

第二条 责任限制

在适用法律允许的最大范围内，著作权人及贡献者不对因使用或无法使用本软件所产生的任何损害承担责任，即使其已被告知发生该等损害的可能性。

第三条 非官方性质与内容权利

本软件为视觉小说引擎之非官方运行环境，与 W.Dee、Kirikiri Z 项目、Artemis、各游戏制作委员会、发行商或应用分发平台之间不存在授权、合作、赞助或代言关系。

游戏脚本、立绘、语音、音乐、商标及其他内容之权利归各权利人所有。用户将作品导入本软件并运行的，系用户自身行为；用户应当确保其拥有合法复制件或相应许可。本软件之发行不附带任何游戏资源。贡献者对用户导入之内容不承担责任。

第四条 内容分级

部分作品可能含有成人内容或不适宜于公共场合播放的内容。本软件不提供年龄分级过滤，亦不在启动前对内容进行审查。用户应当自行判断使用场景是否适当。

第五条 开发状态

本软件仍处于开发阶段，可能发生崩溃、无响应，或与官方引擎、原版 krkr2 之行为不一致。本条不构成对特定版本质量或兼容性的承诺。

第六条 本地文件操作

「管理」功能所提供的复制、移动、重命名、解压、移至最近删除及永久删除，均为在用户设备上执行的本地文件操作。因用户操作失误或软件缺陷导致的数据丢失，风险由用户承担。「最近删除」不会被自动清空，但永久删除后不可恢复。

第七条 第三方信息

经刮削取得的元数据来源于 VNDB 等第三方，可能不准确、不完整或已过时，亦不构成对相关作品是否有权分发的判断。

第八条 名称与商标

KiriKiri、吉里吉里、KrKr2 及相关名称、商标归各权利人所有。本声明仅为本软件使用说明。本声明与 LICENSE 所载 GPL 文本不一致的，以 LICENSE 为准。
''';

const _openSourceEn = '''
Article 1 Purpose and Scope

This statement applies to the software “{appName}” (the “Software”). The Software is free software for running KiriKiri2 visual novels and, in this repository, Artemis titles.

This statement: (a) sets out the licence terms of the Software; (b) records acknowledgements of upstream projects; and (c) identifies principal third-party open-source components and their licences. It is a summary and does not replace the full text of any licence. The governing texts are the root LICENSE file, upstream NOTICE files, and source headers. In the event of inconsistency, the upstream text prevails.

Article 2 Acknowledgements

The Software depends on the engine and scripting environment created by W.Dee, author of KiriKiri2 (吉里吉里2), and by the contributors to Kirikiri Z. The developers of the Software hereby acknowledge that work.

This HarmonyOS / OpenHarmony build is a derivative of KrKr2 Next as published by reAAAq. KrKr2 Next is in turn derived from the krkr2 rewrite of KiriKiri2 published by 2468785842. The work of those upstream projects in moving the engine onto a modern graphics stack and a cross-platform interface is likewise acknowledged.

Nothing in this Article shall be construed as a statement of partnership, licence, sponsorship, or endorsement by the persons or projects named above.

Article 3 Licence of the Software

Those parts of the Software in which copyright is held by “{copyrightHolder}” are licensed under the GNU General Public License, version 3, or (at the licensee’s option) any later version (GPL-3.0-or-later). The root LICENSE file states: Copyright (C) {copyrightYear} {copyrightHolder}.

Subject to GPL-3.0-or-later, the licensee may copy, modify, and redistribute the Software. The Software is provided “AS IS”. The disclaimer of warranty and limitation of liability in GPL sections 15 and 16 apply, together with the disclaimer available from About. Making this statement available from About also satisfies the GPL requirement for Appropriate Legal Notices. The full text of GPL-3.0 is available at: https://www.gnu.org/licenses/gpl-3.0.html

Article 4 Third-Party Components

The following are principal components that this repository depends on directly or that are named in LICENSE. Each entry states the name, licence, and purpose. Some components are linked only on particular platforms or under particular build options and may be absent from a given binary. Transitive dependencies are not exhaustively listed.

(1) Engines and upstream projects

1. KiriKiri2 / Kirikiri Z (W.Dee and contributors)
Licence: BSD-style terms. Redistribution shall retain the copyright notice and disclaimer. The names of the relevant organisations or contributors shall not be used to promote derived works without prior written permission.
Purpose: The visual-novel engine, including TJS, layers, audio/video, and XP3 and related formats.

2. krkr2 (2468785842)
Licence: as specified in that repository; this project’s LICENSE continues under GPL-3.0-or-later and preserves upstream notices.
Purpose: An open rewrite migrating KiriKiri2 from its prior rendering stack; the immediate upstream of KrKr2 Next.

3. KrKr2 Next (reAAAq)
Licence: GPL-3.0-or-later
Purpose: A cross-platform runtime with a Flutter interface and modern graphics. This HarmonyOS build is derived from it.

4. Artemis-related source
Licence: GPL-3.0. Lua 5.1.5 is MIT; stb_vorbis is public domain / MIT.
Purpose: Execution of Artemis titles packed as .pfs. See cpp/artemis/upstream/THIRD_PARTY_NOTICES.md.

5. Lua 5.1.5
Licence: MIT
Purpose: Embedded scripting language, introduced via the Artemis third-party tree.

6. stb_vorbis (Sean Barrett)
Licence: public domain / MIT
Purpose: Ogg Vorbis audio decoding.

(2) Graphics, images, and fonts

7. ANGLE
Licence: BSD-3-Clause
Purpose: Translation of OpenGL ES to Metal, Vulkan, or Direct3D. Used on desktop and certain mobile builds. The HarmonyOS build uses system EGL and does not use ANGLE.

8. libjpeg-turbo / Independent JPEG Group
Licence: IJG, BSD-3-Clause, and zlib (in combination)
Purpose: JPEG codec for engine image loading.

9. libpng
Licence: libpng License
Purpose: PNG codec.

10. libwebp
Licence: BSD-3-Clause
Purpose: WebP image processing.

11. FreeType
Licence: FreeType License (GPL optional)
Purpose: Font rasterisation for engine text.

12. jxrlib / JPEG XR Device Porting Kit
Licence: Microsoft documentation licence (BSD-style)
Purpose: JPEG XR image processing.

13. OpenCV 4
Licence: Apache-2.0
Purpose: Computer-vision library, introduced via vcpkg, used on certain image-processing paths.

14. Highway
Licence: Apache-2.0
Purpose: SIMD helpers.

(3) Audio and containers

15. libogg / libvorbis / Theora (Xiph.org)
Licence: BSD-3-Clause
Purpose: Ogg container, Vorbis audio, and Theora video.

16. OpenAL Soft
Licence: LGPL-2.1
Purpose: Cross-platform audio output on certain platforms.

17. FFmpeg
Licence: typically LGPL-2.1+; GPL if GPL components are enabled in the build.
Purpose: Demultiplexing and decoding. The licence applicable to a given binary follows the options actually linked.

18. Opus / opusfile
Licence: BSD-3-Clause
Purpose: Opus audio on certain platforms.

19. Oboe
Licence: Apache-2.0
Purpose: Low-latency audio on Android only.

(4) Compression and archives

20. 7-Zip
Licence: LGPL-2.1+; code used to extract RAR is additionally subject to the unRAR restriction.
Purpose: Extraction in the file manager (file_archive) and engine-side archives.

21. libarchive
Licence: BSD-2-Clause
Purpose: Generic archive input and output.

22. UnRAR
Licence: unRAR license (source may be used; reproduction of the RAR compression algorithm is prohibited).
Purpose: RAR extraction. Source is available, but the licence is not a permissive OSI open-source licence.

23. minizip / zlib
Licence: zlib
Purpose: Zip and general-purpose compression.

24. lz4
Licence: BSD-2-Clause
Purpose: High-speed compression.

25. zstd
Licence: dual BSD / GPL-2
Purpose: Zstandard compression.

(5) Text, regular expressions, and other native components

26. Oniguruma
Licence: BSD-2-Clause
Purpose: Regular-expression engine on the TJS / script side.

27. picojson
Licence: BSD-2-Clause
Purpose: Lightweight JSON parsing.

28. libxml2
Licence: MIT
Purpose: XML parsing.

29. tinyxml2
Licence: zlib
Purpose: Lightweight XML parsing.

30. uchardet
Licence: MPL-1.1 / GPL / LGPL (tri-licence)
Purpose: Text-encoding detection.

31. MT19937 (Matsumoto & Nishimura)
Licence: BSD-style
Purpose: Mersenne Twister pseudorandom number generator.

32. Boost (including iostreams, locale, spirit, phoenix, and similar)
Licence: Boost Software License 1.0
Purpose: C++ infrastructure, including streams, locale, and parsing.

33. Bullet Physics
Licence: zlib
Purpose: Physics engine, inherited with historical engine dependencies.

34. fmt / spdlog
Licence: MIT
Purpose: Formatting and logging.

35. SDL2
Licence: zlib
Purpose: Windowing and input on certain desktop platforms.

36. Android Open Source Project excerpts
Licence: Apache-2.0
Purpose: AOSP code recorded in LICENSE.

37. libgdiplus
Licence: MIT
Purpose: GDI+ compatibility on certain non-Windows platforms.

(6) User interface and Flutter plugins (direct pubspec dependencies)

38. Flutter / Dart SDK
Licence: BSD-3-Clause
Purpose: Cross-platform user interface and language runtime.

39. shared_preferences, path_provider, url_launcher, image_picker, http, video_player, cupertino_icons, and similar Flutter team plugins
Licence: BSD-3-Clause (subject to each package LICENSE)
Purpose: Local settings, paths, external links, image selection, HTTP, video preview, and Cupertino icons.

40. file_picker
Licence: MIT
Purpose: Selection of files or directories for importing games. The HarmonyOS build uses a port checked out as a sibling tree.

41. flutter_svg
Licence: MIT
Purpose: SVG rendering.

42. lucide_icons_flutter
Licence: MIT for the wrapper; Lucide icons themselves are principally ISC
Purpose: Line icons in the user interface.

43. liquid_glass_widgets
Licence: MIT
Purpose: Liquid-glass visual treatment of the tab bar and similar controls.

44. unorm_dart
Licence: MIT
Purpose: Unicode normalisation.

45. intl / path
Licence: BSD-3-Clause
Purpose: Internationalisation and path handling.

Article 5 Development-Only Dependencies

Components such as Catch2 (BSL-1.0) and argparse (MIT) are used primarily for tests or command-line tools and are not ordinarily included in the application installed by the user.

Article 6 Construction

Licence names in this statement are conventional short titles. Rights and obligations are governed by the full licence texts. This statement grants no rights beyond those licences.
''';

const _privacyEn = '''
Article 1 Purpose and Scope

This privacy statement applies to the software “{appName}” (the “Software”) and describes how information is processed under the current implementation. The Software does not provide user accounts and does not sell personal information to any third party.

Article 2 Definitions

“Local storage” means data retained on the user’s device and not, by default, transmitted to a server controlled by the developers of the Software. “Network transmission” means the sending or receiving of data by the Software to or from a host other than the device, using system network permission.

Article 3 Information Held in Local Storage

Except where the user copies or exports data, or the operating system creates a backup, the following is retained on the device by default:

(a) library entries, cover paths, display names, and descriptions and keywords obtained through the user’s express action;
(b) settings, including language, theme, frame rate, landscape lock, and engine-related options;
(c) play duration and session records used by the Statistics function;
(d) authorised directories, the recently-deleted list, and related state for file management; and
(e) whether a first-open report has been completed, and the anonymous identifier generated locally for that purpose.

Article 4 Network Transmission

The HarmonyOS package declares network permission. Under the current implementation, network transmission is limited to the following:

(a) First-open report. On launch, the Software attempts one HTTP POST to /api/first_open. The body contains only id (an anonymous identifier generated locally) and v (currently fixed as {appVersion}). The host configured in this build is a loopback address: 127.0.0.1:8080 on ordinary devices, or 10.0.2.2:8080 on the Android emulator. It is not a public analytics service. On a physical device that service is ordinarily absent; a failed request does not prevent the Software from continuing. The current interface does not provide a control to disable this report.

(b) Metadata scraping. Only when the user expressly uses “Scrape info” does the Software send the user’s search text to the VNDB Kana API (https://api.vndb.org/kana), and it may then request further details. After the user selects a cover, the Software downloads the image from the URL returned by VNDB, with Referer: https://vndb.org/.

Article 5 Information Not Processed

The Software does not provide registration or sign-in and does not collect telephone numbers, email addresses, or legal names. It does not upload game files, save data, screenshots, or contents of the Manage directory to a server controlled by the developers (and this build has no such server). It does not incorporate an advertising SDK and does not conduct cross-application advertising tracking. It does not collect or display author contact details on the About page.

Article 6 System Permissions and File Scope

The HarmonyOS package declares network and vibrate permissions. Game files and the Manage function are read and written locally only within a directory authorised by the user, or under Download/<application identifier>/. Changing a cover may invoke the system photo library or file picker.

Article 7 Third-Party Processing

Searches submitted to VNDB are processed by VNDB under its own terms. The Software cannot determine whether that third party records access logs. If the first-open endpoint is later changed to a remote host, the payload under the current implementation remains limited to the anonymous identifier and version; this statement shall then be revised and shall not continue to describe the destination as loopback only.

Article 8 Revision

This statement is prepared by reference to the implementation dated 2026-09-09. If the implementation changes, this statement shall be revised accordingly.
''';

const _disclaimerEn = '''
Article 1 Provision “As Is”

The Software is provided “AS IS”, without any express or implied warranty of merchantability, fitness for a particular purpose, non-infringement, or continued availability. This Article is consistent with GPL-3.0 sections 15 and 16 in LICENSE. The user assumes all risk of use, including without limitation damaged save data, failed compatibility, loss of data, or device malfunction.

Article 2 Limitation of Liability

To the maximum extent permitted by applicable law, the copyright holders and contributors shall not be liable for any damages arising from the use of, or inability to use, the Software, even if they have been advised of the possibility of such damages.

Article 3 Unofficial Character and Content Rights

The Software is an unofficial runtime for visual-novel engines. It is not licensed, partnered, sponsored, or endorsed by W.Dee, the Kirikiri Z project, Artemis, any game production committee, any publisher, or any application distribution platform.

Rights in scripts, artwork, voice, music, trade marks, and other content belong to their respective owners. Importing a work into the Software and running it is the user’s own act; the user shall ensure that the user holds a lawful copy or an appropriate licence. The Software is distributed without game assets. Contributors accept no responsibility for content imported by the user.

Article 4 Content Classification

Some works may contain adult material or material unsuitable for public exhibition. The Software does not apply age classification filters and does not review content before launch. The user shall determine whether the circumstances of use are appropriate.

Article 5 Development Status

The Software remains under development and may crash, become unresponsive, or differ in behaviour from the official engine or original krkr2. This Article is not a representation as to the quality or compatibility of any particular version.

Article 6 Local File Operations

Copy, move, rename, extract, move to Recently Deleted, and permanently delete, as offered by Manage, are local file operations on the user’s device. The risk of data loss from user error or software defect is borne by the user. Recently Deleted is not emptied automatically; permanent deletion cannot be reversed.

Article 7 Third-Party Information

Metadata obtained by scraping originates from VNDB and similar third parties. It may be inaccurate, incomplete, or out of date, and it does not constitute a determination as to whether a work may lawfully be distributed.

Article 8 Names and Trade Marks

KiriKiri, 吉里吉里, KrKr2, and related names and marks belong to their respective owners. This statement is a description of the Software. If it conflicts with the GPL text in LICENSE, LICENSE prevails.
''';

const _openSourceJa = '''
第1条 目的及び適用範囲

本声明は、ソフトウェア「{appName}」（以下「本ソフトウェア」）に適用する。本ソフトウェアは、KiriKiri2 のビジュアルノベルを実行するための自由ソフトウェアであり、本リポジトリにおいては Artemis 作品の実行機能を含む。

本声明は、（一）本ソフトウェアの許諾条件を明らかにし、（二）上流プロジェクトへの謝意を記録し、（三）利用する主要な第三者オープンソース構成要素及びそのライセンスを掲げることを目的とする。本声明は要約であり、各ライセンスの全文に代わるものではない。全文はリポジトリ根の LICENSE、上流の NOTICE 及びソース先頭の表示による。抵触があるときは上流の文言を優先する。

第2条 謝辞

本ソフトウェアの実現は、吉里吉里2（KiriKiri2）の作者 W.Dee 及び Kirikiri Z の貢献者が提供したエンジン及びスクリプト環境に依拠する。本ソフトウェアの開発者は、ここに謝意を表する。

この HarmonyOS / OpenHarmony 構築は、reAAAq が公表した KrKr2 Next を基礎とする二次開発である。KrKr2 Next は、2468785842 が公表した krkr2 による KiriKiri2 の再構成に由来する。エンジンを現代的なグラフィックス及び横断的な利用者界面へ移行した上流の作業に対し、併せて謝意を表する。

本条の謝辞は、上記の主体との提携、許諾、後援又は推奨の関係を述べるものではない。

第3条 本ソフトウェアのライセンス

「{copyrightHolder}」が著作権を有する部分は、GNU 一般公衆ライセンス第3版又は（被許諾者の選択により）それ以降の版（GPL-3.0-or-later）により許諾する。リポジトリ根の LICENSE には Copyright (C) {copyrightYear} {copyrightHolder} とある。

GPL-3.0-or-later に従うことを条件として、被許諾者は本ソフトウェアを複製し、改変し、再配布することができる。本ソフトウェアは「現状有姿」（AS IS）で提供する。無保証及び責任制限については、GPL 第15条及び第16条並びに「バージョン情報」に掲げる免責声明による。「バージョン情報」において本声明を掲げることは、GPL が求める適切な法的表示（Appropriate Legal Notices）の充足にも当たる。GPL-3.0 の全文は https://www.gnu.org/licenses/gpl-3.0.html を参照。

第4条 第三者構成要素

以下は、本リポジトリが直接依存し、又は LICENSE に掲げられる主要な構成要素である。各項目は名称、ライセンス及び用途を示す。一部は特定のプラットフォーム又は構築オプションでのみリンクされ、利用者が取得した特定のバイナリに含まれないことがある。間接依存は網羅しない。

（1）エンジン及び上流

1. KiriKiri2 / Kirikiri Z（W.Dee 及び貢献者）
ライセンス：BSD 系。再配布に当たっては著作権表示及び免責を保持しなければならない。書面による許可なく、関係団体又は貢献者の名称を派生製品の宣伝に用いてはならない。
用途：ビジュアルノベルエンジン本体。TJS、レイヤ、音声映像、XP3 等。

2. krkr2（2468785842）
ライセンス：当該リポジトリの定めによる。本プロジェクトの LICENSE は GPL-3.0-or-later で承接し、上流の表示を保持する。
用途：従前のレンダリング機構から KiriKiri2 を移行した再構成。KrKr2 Next の直接の上流。

3. KrKr2 Next（reAAAq）
ライセンス：GPL-3.0-or-later
用途：Flutter による界面と現代的なグラフィックスを備えた横断ランタイム。本 HarmonyOS 構築はその二次開発である。

4. Artemis 関連ソース
ライセンス：GPL-3.0。Lua 5.1.5 は MIT、stb_vorbis はパブリックドメイン / MIT。
用途：.pfs で梱包された Artemis 作品の実行。cpp/artemis/upstream/THIRD_PARTY_NOTICES.md を参照。

5. Lua 5.1.5
ライセンス：MIT
用途：埋め込みスクリプト言語。Artemis の第三者ディレクトリ経由。

6. stb_vorbis（Sean Barrett）
ライセンス：パブリックドメイン / MIT
用途：Ogg Vorbis 音声の復号。

（2）グラフィックス、画像及びフォント

7. ANGLE
ライセンス：BSD-3-Clause
用途：OpenGL ES の Metal、Vulkan 又は Direct3D への変換。デスクトップ及び一部のモバイル構築で用いる。HarmonyOS 構築はシステムの EGL を用い、ANGLE を経由しない。

8. libjpeg-turbo / Independent JPEG Group
ライセンス：IJG、BSD-3-Clause 及び zlib（併用）
用途：JPEG。エンジンの画像読込み。

9. libpng
ライセンス：libpng License
用途：PNG。

10. libwebp
ライセンス：BSD-3-Clause
用途：WebP。

11. FreeType
ライセンス：FreeType License（GPL も選択可）
用途：フォントのラスタライズ。

12. jxrlib / JPEG XR Device Porting Kit
ライセンス：Microsoft の文書ライセンス（BSD 系）
用途：JPEG XR。

13. OpenCV 4
ライセンス：Apache-2.0
用途：コンピュータビジョン。vcpkg 経由。一部の画像処理経路。

14. Highway
ライセンス：Apache-2.0
用途：SIMD 補助。

（3）音声及びコンテナ

15. libogg / libvorbis / Theora（Xiph.org）
ライセンス：BSD-3-Clause
用途：Ogg、Vorbis、Theora。

16. OpenAL Soft
ライセンス：LGPL-2.1
用途：一部プラットフォームの音声出力。

17. FFmpeg
ライセンス：通常は LGPL-2.1+。構築で GPL 構成要素を有効にした場合は GPL。
用途：分離及び復号。適用ライセンスは実際にリンクした構築による。

18. Opus / opusfile
ライセンス：BSD-3-Clause
用途：一部プラットフォームの Opus。

19. Oboe
ライセンス：Apache-2.0
用途：Android のみの低遅延音声。

（4）圧縮及びアーカイブ

20. 7-Zip
ライセンス：LGPL-2.1+。RAR 展開に用いるコードは unRAR の制限にも服する。
用途：ファイル管理における展開（file_archive）及びエンジン側アーカイブ。

21. libarchive
ライセンス：BSD-2-Clause
用途：汎用アーカイブの入出力。

22. UnRAR
ライセンス：unRAR license（ソースの利用は可。RAR 圧縮算法の再現は禁止）。
用途：RAR 展開。ソースは得られるが、寛容な OSI オープンソースライセンスではない。

23. minizip / zlib
ライセンス：zlib
用途：zip 及び汎用圧縮。

24. lz4
ライセンス：BSD-2-Clause
用途：高速圧縮。

25. zstd
ライセンス：BSD / GPL-2 のデュアル
用途：Zstandard。

（5）テキスト、正規表現その他のネイティブ構成要素

26. Oniguruma
ライセンス：BSD-2-Clause
用途：TJS / スクリプト側の正規表現。

27. picojson
ライセンス：BSD-2-Clause
用途：軽量 JSON 解析。

28. libxml2
ライセンス：MIT
用途：XML 解析。

29. tinyxml2
ライセンス：zlib
用途：軽量 XML 解析。

30. uchardet
ライセンス：MPL-1.1 / GPL / LGPL（三許可、択一）
用途：文字コードの推定。

31. MT19937（Matsumoto & Nishimura）
ライセンス：BSD 系
用途：メルセンヌ・ツイスタ。

32. Boost（iostreams、locale、spirit、phoenix 等を含む）
ライセンス：Boost Software License 1.0
用途：C++ 基盤。ストリーム、ロケール、構文解析等。

33. Bullet Physics
ライセンス：zlib
用途：物理演算。歴史的なエンジン依存として導入。

34. fmt / spdlog
ライセンス：MIT
用途：整形及びログ。

35. SDL2
ライセンス：zlib
用途：一部デスクトップの窓及び入力。

36. Android Open Source Project の断片
ライセンス：Apache-2.0
用途：LICENSE に掲げられる AOSP コード。

37. libgdiplus
ライセンス：MIT
用途：一部の非 Windows 向け GDI+ 互換。

（6）利用者界面及び Flutter プラグイン（pubspec の直接依存）

38. Flutter / Dart SDK
ライセンス：BSD-3-Clause
用途：横断的な利用者界面及び言語実行系。

39. shared_preferences、path_provider、url_launcher、image_picker、http、video_player、cupertino_icons 等の Flutter チームプラグイン
ライセンス：BSD-3-Clause（各パッケージの LICENSE による）
用途：設定、経路、外部リンク、画像選択、HTTP、動画プレビュー、Cupertino アイコン。

40. file_picker
ライセンス：MIT
用途：ゲーム取込みのためのファイル又はディレクトリ選択。HarmonyOS 構築は隣接チェックアウトの移植による。

41. flutter_svg
ライセンス：MIT
用途：SVG 描画。

42. lucide_icons_flutter
ライセンス：ラッパは MIT。Lucide 本体は主に ISC
用途：界面の線画アイコン。

43. liquid_glass_widgets
ライセンス：MIT
用途：タブバー等のリキッドガラス表現。

44. unorm_dart
ライセンス：MIT
用途：Unicode 正規化。

45. intl / path
ライセンス：BSD-3-Clause
用途：国際化及びパス処理。

第5条 開発専用の依存

Catch2（BSL-1.0）及び argparse（MIT）等は、主として試験又はコマンドライン用具に用い、利用者がインストールするアプリケーションには通常含まれない。

第6条 解釈

本声明に掲げるライセンス名は通称である。権利義務は各ライセンスの全文による。本声明は、それらの範囲を超える権利を付与しない。
''';

const _privacyJa = '''
第1条 目的及び適用範囲

本プライバシー声明は、ソフトウェア「{appName}」（以下「本ソフトウェア」）に適用し、現行実装における情報の取扱いを明らかにする。本ソフトウェアは利用者アカウントを設けず、利用者の個人情報を第三者に販売しない。

第2条 定義

「ローカル保存」とは、利用者の端末上に保持され、原則として本ソフトウェアの開発者が管理するサーバへ送信されないデータをいう。「ネットワーク送信」とは、システムのネットワーク権限を用いて、端末以外のホストとの間でデータを送受信することをいう。

第3条 ローカルに保存する情報

利用者が自ら複製若しくは書き出しを行い、又はオペレーティングシステムがバックアップを作成する場合を除き、次に掲げる情報は、原則として端末内にのみ保存する。

（一）ライブラリ項目、カバー経路、表示名、並びに利用者が明示的に取得した紹介文及びキーワード
（二）言語、テーマ、フレームレート、横画面固定及びエンジン関連を含む設定
（三）「統計」が用いるプレイ時間及びセッション記録
（四）ファイル管理に係る許可ディレクトリ、最近削除した項目及び関連状態
（五）初回起動の送信済みの有無、及びそのために端末内で生成した匿名識別子

第4条 ネットワーク送信

HarmonyOS 配布物はネットワーク権限を宣言する。現行実装におけるネットワーク送信は、次に限る。

（一）初回起動の報告。本ソフトウェアは起動時に /api/first_open へ HTTP POST を1回試みる。本文は id（端末内で生成した匿名識別子）及び v（現在は {appVersion} に固定）のみである。本構築の宛先はループバックである。通常の機器は 127.0.0.1:8080、Android エミュレータは 10.0.2.2:8080 であり、公衆向けの計測サービスではない。実機において当該サービスは通常存在せず、失敗しても本ソフトウェアの継続を妨げない。現行の界面に、この報告を停止する操作は設けていない。

（二）メタデータの取得。利用者が「情報を取得」を明示的に用いたときに限り、入力した検索語を VNDB Kana API（https://api.vndb.org/kana）へ送り、必要に応じて詳細を請求する。カバーを選択した後、VNDB が返した画像 URL からダウンロードし、Referer: https://vndb.org/ を付する。

第5条 取り扱わない情報

本ソフトウェアは登録及びログインを設けず、電話番号、電子メールアドレス又は本名を収集しない。ゲームファイル、セーブ、スクリーンショット又は「管理」内の内容を、開発者が管理するサーバへアップロードしない（本構築にそのようなサーバも存在しない）。広告用 SDK を組み込まず、アプリを横断する広告追跡を行わない。「バージョン情報」において作者の連絡先を収集し、又は表示しない。

第6条 システム権限及びファイルの範囲

HarmonyOS 配布物はネットワーク及び振動の権限を宣言する。ゲームファイル及び「管理」は、利用者が許可したディレクトリの範囲内、又は Download/<アプリ識別子>/ の下で、端末内において読み書きする。カバーの変更は、システムの写真又はファイル選択を呼び出すことがある。

第7条 第三者による取扱い

VNDB に提出した検索は、VNDB が自己の条件により取り扱う。当該第三者がアクセス記録を残すか否かは、本ソフトウェアにおいて知り得ない。初回起動の宛先を後に遠隔ホストへ変更する場合、現行実装では送信内容は匿名識別子及び版番号に限る。そのときは本声明を改め、ループバックのみである旨の記述を継続してはならない。

第8条 改訂

本声明は 2026-09-09 時点の実装に基づき作成している。実装が変わったときは、本声明を合わせて改訂する。
''';

const _disclaimerJa = '''
第1条 現状有姿での提供

本ソフトウェアは「現状有姿」（AS IS）で提供し、商品性、特定目的適合性、非侵害又は継続利用可能性について、明示又は黙示を問わず保証しない。本条は LICENSE に付する GPL-3.0 第15条及び第16条と一致する。セーブ破損、互換の失敗、データ消失又は機器の不調を含む利用上のリスクは、利用者が負担する。

第2条 責任の制限

適用法令が許す最大限の範囲において、著作権者及び貢献者は、本ソフトウェアの利用又は利用不能から生じた損害について責任を負わない。当該損害の可能性を知らされていたときも同様とする。

第3条 非公式性及び内容の権利

本ソフトウェアはビジュアルノベルエンジンの非公式な実行環境である。W.Dee、Kirikiri Z プロジェクト、Artemis、各製作委員会、発売元又はアプリ配信基盤との許諾、提携、後援又は推奨の関係はない。

スクリプト、原画、音声、音楽、商標その他の内容の権利は、それぞれの権利者に帰属する。作品を本ソフトウェアに取り込み実行する行為は利用者自身の行為であり、利用者は適法な複製物又は相当の許諾を有することを確保しなければならない。本ソフトウェアの配布にゲーム資源は付属しない。貢献者は、利用者が取り込んだ内容について責任を負わない。

第4条 内容区分

一部の作品には、成人向けの内容又は公の場での再生に適さない内容が含まれることがある。本ソフトウェアは年齢区分による濾過を行わず、起動前に内容を審査しない。利用者は、利用の場面が適当であるかを自ら判断しなければならない。

第5条 開発の状態

本ソフトウェアは開発の途上にあり、異常終了、応答停止、又は公式エンジン若しくは旧 krkr2 との挙動の相違が生じることがある。本条は、特定の版の品質又は互換性を約するものではない。

第6条 ローカルなファイル操作

「管理」が提供するコピー、移動、名称変更、展開、最近削除への移動及び完全削除は、いずれも利用者の端末上のローカルなファイル操作である。操作の誤り又はソフトウェアの不具合によるデータ消失のリスクは、利用者が負担する。最近削除は自動では空にならないが、完全削除の後は復元できない。

第7条 第三者情報

取得したメタデータは VNDB 等の第三者に由来し、不正確、不完全又は古いことがあり、当該作品を頒布してよいかの判断を構成しない。

第8条 名称及び商標

KiriKiri、吉里吉里、KrKr2 並びに関連する名称及び商標は、それぞれの権利者に帰属する。本声明は本ソフトウェアの説明である。LICENSE の GPL 本文と抵触するときは、LICENSE を優先する。
''';
