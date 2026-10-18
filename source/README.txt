词境前线 3D · 0.3.0 可玩样段
2026-10-15

独立 Android 应用，包名 com.wordfrontier.frontier3d。Godot 4.5.1 实时三维渲染；没有浏览器或 WebView。与旧版 0.2 分开安装、分开存档。

这一版可以玩什么
一张河谷地图、一种六发武器、三种对手、一座可以修通的侧桥。模型、碰撞、遮挡和弹道在三维空间中运作。敌人会追击、侧移、寻找射击角度，也会在三连发后露出换弹空档。
英语包括 6 组长短战术情报、12 段情报配音、1,200 道词义题及单词发音、24 题自适应抽样、可点击查词、收藏与战后句子拼接。全部内容随包提供，不联网生成。

试玩
左侧摇杆移动；按住右侧圆盘自动瞄准可见敌人，拖动圆盘可以手动瞄准。边移动边开火。
闪避会短暂避开伤害；真正穿过敌弹会补回一发。抓住敌人黄色“换弹”提示进攻，可造成反制伤害。
弹夹打空后会自动换弹，也能点小“换弹”按钮提前换。木箱挡子弹但会被打坏；红桶会炸伤附近所有人。
胜利得到 10 木料，失败得到 3 木料。8 木料可修好侧桥，以后能从侧面接近据点。桥只需修一次。
右上暂停菜单可以选练手、标准、挑战。Aa 打开英语手册。战前可以选短篇/展开阅读、听情报/慢速、查词与译文；作战中不会自动弹题。
桌面编辑器调试可用 WASD、鼠标、空格闪避、R 换弹；主要验收对象为 Android 双指触控。

本地存档
frontier3d.json 保存桥梁、木料、词汇档位、收藏和练习记录，带一份 .bak 备份。退出后回营地，不续接正在进行的战斗。
24 题只用于粗调题目难度，不能据此准确宣称掌握几千个词。阅读字数是接触量，听力次数是播放开始次数，都不代表已经掌握。

源码位置
scripts/main.gd：战斗、英语流程和存档。
scripts/fighter.gd：角色动作、受击、对手行为。
scripts/world.gd：地图、三维场景、碰撞、导航及造桥。
scripts/hud.gd：触摸摇杆和界面。
assets/models：10 个 glTF 模型。art-source：对应 Blender 4.4.3 建模文件。
assets/*.json：冻结的题库、情报与查词数据。assets/audio：全部离线录音及音效。
assets/CREDITS.txt：引擎、字体、词典与语音来源；相应许可也在 assets 中。

重新构建 APK（Windows PowerShell）
准备 Godot 4.5.1 标准 Windows 编辑器，以及同版本 Android 导出模板 android_debug.apk、android_release.apk。模板放在同一个目录。
准备 Android SDK platform-tools/build-tools 及 Java。实际验证使用 Temurin 21、Android build-tools 36.1.0；APK 的 targetSdk 为 35，minSdk 为 24。
使用自己的签名密钥和本地配置文件；源码包不含任何签名密钥、密码或服务密钥。配置文件采用 storeFile、storePassword、keyAlias、keyPassword 四个字段，storeFile 可以相对该配置文件指定。
示例命令（把下面路径替换成你自己的路径）：
  .\build.ps1 -Godot C:\Tools\Godot\Godot_v4.5.1-stable_win64_console.exe -Templates C:\Tools\Godot\templates -AndroidSdk C:\Android\Sdk -JavaHome C:\Tools\jdk-21 -SigningProperties C:\Private\signing.properties -OutputDirectory C:\Build\frontier3d
脚本在临时隔离目录中导入、导出、对齐和签名，输出 APK、构建日志及输入文件 SHA-256 清单，不修改全局 Godot 编辑器设置。
运行要求：Android 7.0 或以上，设备支持 Vulkan。包含 arm64-v8a、armeabi-v7a、x86_64 三种架构。实际手机驱动、温度和帧率尚未验证；本次原生流程验证使用 Android API 36.1 模拟器。

验证命令（先完成编辑器导入）
  Godot_v4.5.1-stable_win64_console.exe --headless --editor --path . --import
  Godot_v4.5.1-stable_win64_console.exe --headless --path . --script tests/core.gd -- --qa
  Godot_v4.5.1-stable_win64_console.exe --headless --path . --script tests/encounters.gd -- --qa
  Godot_v4.5.1-stable_win64_console.exe --headless --path . --script tests/font.gd
测试使用隔离模式，不读取或修改正式存档。Android instrumentation 源码放在 tests/android，仅用于单独的测试 APK，不随游戏包导出。

资产再生成
日常构建直接使用随包提供的模型、字体、音频和 JSON，无需 Blender、语音模型或外部词典。
tools/make_models.py 和 render_icon.py 供 Blender 后台执行；make_font.py 使用 fonttools 将随包原字体转换为改名后的静态子集。
make_content.py 是迁移 0.2 内容的开发脚本，需要旧项目目录；随后必须运行 refine_vocabulary.py。词库已完成迁移及筛选，正常构建不要重复运行该步骤。
make_voice.py 是开发时的离线配音脚本，需要自行配置 Kokoro 模型、kokoro-onnx、soundfile 和 FFmpeg 路径；tools/audio-manifest.json 保存文本与音频对应关系。应用只分发合成录音，不带推理模型。

当前范围和限制
这是用于判断操作手感与学习介入是否合适的小样段，内容有限。建设只有一座桥，情报循环使用六组，词义题来自固定题库；还不是能持续生成新地图与新阅读的长期版本。
对手是本地 AI，不冒充真人，也没有暗中控制胜负的匹配系统。当前自动对战检查只能证明部分策略能赢、站立不动会输，不能证明难度平衡或好玩。
词义和干扰项经过规则筛选及抽查，没有完成全部人工语言学审校。语音为 Kokoro 合成，未经过真人听感评测。
构建、原生操作、数据完整性通过，也不能据此声称学习效果已经验证。
