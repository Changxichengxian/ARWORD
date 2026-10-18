词境前线 0.1.0
原生 Android、完全离线的个人英语游戏原型

直接使用

安装随附的“词境前线-0.1.0.apk”。声明支持 Android 8.0 及以上；本次实际运行环境是 Android 16.1 模拟器，没有在你的手机上实测。无需账户、浏览器、网络或付费服务。音频和词典已经装在安装包里。

首次打开可以做 16 道词义抽样，也可以先试一场。抽样只安排起始难度，不会推算一个虚假的总词汇量。阅读、听力、词义、组句随后分别调整。

玩法

每场最多八回合。读或听情报，结合对手习惯和双方体力选择突击、固守、迂回，再掌握出手时机。阅读时没有倒计时。对手在你选择前已决定本回合动作；它们是明确标注的本地程序。

固守克制突击，迂回克制固守，突击克制迂回。突击消耗两点体力，迂回消耗一点，固守恢复两点。可以选择“稳定出手”，不必一直盯着时机条。战斗压力与英语难度分开调节。

完成战斗可获得建设材料，失败也有收获。四座建筑各建一次，营地完成后保留成果，不增加新的等级上限。菜圃按完成的战斗次数生长，离线不会枯萎。工坊提供两种不同用途的配装；木桥通向观察你惯用打法的灰鸦。

四次“河谷来客”随建设出现。英文说明来意，两种交换都成立，你按当前需要选择材料或行粮。它们没有过期时间，回看不会重复发奖励，也不会算作英语答对。

学习内容

内置 160 个精编词汇与例句、36 段战斗阅读、24 段听力、24 道组句，共 244 道练习。另有 12 封来信，每封短长两版，以及 4 次来访的短长两版。
内置 216 段英文合成录音，共约 29 分钟，可原速或 0.8 倍播放。听力内容和录音均不依赖手机的语音引擎。
离线词典含 29,494 个词条/词形，与精编课程规模分开计算。原始释义来自 ECDICT，许可证位于 app/src/main/assets/ECDICT-LICENSE.txt。

英文可以点词查义。提示、字幕、小测中自报的猜测不计为独立理解。“跨日熟悉”要求至少三次相隔约一天的独立提取，并保持复习进展。它是对本应用已遇到词的观察，不是标准化词汇量测试。词汇档案会显示这些依据。

“这段太难，换短一点”立即缩短当前材料，保持本回合对手动作和战斗压力。连续需要帮助会降低相应技能的工作难度；也可以在设置里手动指定，关闭自动调整。

来信室支持粘贴自己的英文短文，每篇最多 15,000 字符、最多 30 篇。自选文章可点词查义，不自动生成翻译、录音或测验。组句只检查预设词块与有限的合理变体，不能评估开放写作。

数据

所有进度留在设备内。应用不申请网络、联系人、麦克风或广泛存储权限。导出和导入通过 Android 系统文件选择器进行，用户选择保存位置；若选择第三方云盘位置，后续传输由该文件服务处理。
在“设置”导出 JSON 存档。导入会先显示摘要，导入后可以撤销最近一次导入。重新打开可继续未结束的交锋或练习。
卸载应用会移除私有进度，请先导出。没有账户云同步，也没有自动云备份。单独的签名备份用于将来构建同一应用的更新，与游戏存档无关。

源码结构

app/src/main/java/com/wordfrontier/app/Game.java
  纯 Java 规则、对手决策、建设、进度和间隔复习。
app/src/main/java/com/wordfrontier/app/Content.java
  本地内容选择、存档内容校验、SQLite 词典。
app/src/main/java/com/wordfrontier/app/MainActivity.java
  原生 Android 控件、声音、存档文件选择器和页面。
app/src/main/java/com/wordfrontier/app/SceneView.java
  原生 Canvas 营地、战场与时机动画。
app/src/androidTest/java/com/wordfrontier/app/NativeTestRunner.java
  在 Android 上执行的界面、媒体和完整流程检查。
tests/CoreTest.java
  纯规则测试与固定种子对战模拟。
tools/
  内容、声音生成与内容核查工具。
docs/
  研究依据、设计推导、内容维护和验证记录。

重新构建

测试使用 Windows PowerShell、JDK 21、Android SDK 36 / Build Tools 34.0.0、Gradle 8.9、Android Gradle Plugin 8.6.1。Java 源码级别为 17，JDK 17 或 21 可用于此工具链；本机只实际验证了 JDK 21。项目 targetSdk 为 35，minSdk 为 26。采用本机已有构建插件，其对 compileSdk 36 的版本提示在 gradle.properties 中显式关闭；本项目实际使用 SDK 36 完成构建和模拟器检查。

先设置 JAVA_HOME 为 JDK 目录，ANDROID_SDK_ROOT 为 Android SDK 目录。在源码根目录执行：
  .\build.ps1
输出：app/build/outputs/apk/debug/app-debug.apk

第一次构建可能需要网络下载 Gradle 和构建插件。依赖已经缓存时可用：
  .\build.ps1 -Offline

正常构建直接使用已随源码打包的内容、词典和录音，不需要运行生成工具，不需要 Python、FFmpeg 或 Windows 语音服务。

如需生成与交付版本相同签名的个人更新，把单独的私密签名备份解压到源码根目录，再执行：
  .\build.ps1 -Release
输出：app/build/outputs/apk/release/app-release.apk

源码包不含签名密钥、密码、本机路径、构建缓存。个人签名备份需自己保管，不要发到公开代码仓库。它使后续 APK 能覆盖更新这份应用；如果丢失密钥，仍可重建源码，但不能直接覆盖原签名版本。
随源码提供的 Gradle 启动脚本和 Wrapper 构建入口保留原版权头；其许可和声明在 gradle/wrapper/GRADLE-LICENSE.txt、GRADLE-NOTICE.txt。它们用于构建，不运行在手机应用里。

验证命令

  .\gradlew.bat assembleDebug assembleDebugAndroidTest lintDebug
  .\tools\test_core.ps1 -JsonLibrary C:\path\to\json-20180813.jar
  adb install -r app/build/outputs/apk/debug/app-debug.apk
  adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
  adb shell am instrument -w com.wordfrontier.app.test/com.wordfrontier.app.NativeTestRunner

规则测试使用 org.json:json，脚本优先查找本机 Gradle 缓存，也可显式指定。原生测试会重置该应用的测试进度，应在模拟器或专用测试安装上运行，不要对有个人存档的手机执行。

版本边界

这是可以安装试玩的第一版，尚未证明长期好玩或提升英语成绩。阅读暂停与回合制能降低同时操作和理解的负担，也可能削弱你喜欢的即时对抗感。本地对手不会提供“另一位真人在对面”的社会意义。固定内容读完后会重复，不把词典词条数量冒充课程容量。
现在最值得判断的是：情报有没有让你愿意读，反制有没有让你觉得是自己赢的，四座建筑完成时有没有留下满足感。后续改动应根据这三项体验选择，避免持续叠加系统。
