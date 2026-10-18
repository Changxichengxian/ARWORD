词屿 · 0.4.0 竖屏小星球样段

独立 Android 应用，包名 com.wordfrontier.planet。Godot 4.5.1 实时三维渲染；离线运行，无浏览器或 WebView。与 0.2、0.3 分开安装与存档。需要 Android 7.0 以上及 Vulkan 支持。

这一段怎么玩
选出词义就直接采集眼前的树木或矿石。材料沿弧线飞进建筑，没有领奖、仓库兑换或战斗结算。连续采集六次会清出一小块资源地。木屋、风车、花园分别需要 8、12、16 次采集，有基础、框架、主体和完工变化。木屋完成后小船出现，风车完成后叶片转动。完工后保留世界，可以继续复习，没有无限建筑等级。
想不起来可以直接看释义和例句，再遮住释义回忆。看过提示的词更早复习，不计作独立掌握。不会扣体力，也没有倒计时。
右上“听”切换听音辨义；词卡“音”重播，“藏”收藏。右上“信”包含三封短来信，可听、慢放、查词、看译文，读懂安排并组织句子后会移动木屋、风车或接通灌溉。灌溉动画在花园和风车建成后出现。拖动上半屏可转星球，“看看星球”可收起词卡。

内容与学习范围
96 个精选词，四档粗略难度，覆盖基础到较难的通用词。每词有音标、释义、例句、译文与离线发音；另有三封 35–44 词的来信和句子组织练习。默认从第二档开始，连续独立答对四次上调，连续两次需要提示下调，也可在右上“···”手动改起点。这不是总词汇量测试，四选一也不能证明自由回忆能力。
提示后约两分钟进入复习；独立回忆间隔随记录延长到数小时和数天。即时重复不会增加记忆强度。全词库见完后仍可提前练习；当前没有在线内容生成，这是一段有限内容的玩法样段。
录音使用 Kokoro af_heart 合成，非真人配音。慢速播放保留大致音高。

存档
user://island4.json，临时文件写完后替换，另留 .bak。保留建筑、词汇记录、收藏、难度和来信安排。卸载或清除本应用数据会删除存档，不影响旧版应用。

源码与美术
scripts/main.gd：流程、音频、存档、阅读与句子组织。
scripts/learning.gd：复习、难度、三个建设阶段。
scripts/grove.gd：三维场景、采集、搬运、建筑动画。
scripts/hud.gd：原生游戏界面。
assets/vocabulary.json、lessons.json：人工整理的教学正文，可直接编辑；修改语音文字后需重生成相应录音。
art-source：11 个原创 Blender 源文件。assets/models：对应 GLB 运行资源；它们属于项目美术源资产，保存在 Git。
tools/make_art.py、render_icon.py：Blender 4.4.3 后台运行，生成模型和图标。
tools/make_font.py：Python fonttools，生成静态字体子集。文字改动后运行。
tools/make_dictionary.py：传入 ECDICT CSV 路径，重新提取本地查词内容，保留人工补充音标。
tools/make_voice.py：参数 --models 指向 Kokoro ONNX 模型目录，--ffmpeg 指向 FFmpeg；依赖 kokoro-onnx、onnxruntime、numpy、soundfile。模型不随源码保存，已生成的 99 段语音可直接用于构建。
第三方许可见 assets/CREDITS.txt 及其所列文件。

构建
用 Godot 4.5.1、对应 Android 导出模板、Android SDK、JDK 21。PowerShell 调用 build.ps1，传入 -Godot、-Templates、-AndroidSdk、-JavaHome、-SigningProperties、-OutputDirectory。SigningProperties 使用个人私密文件，包含 storeFile、storePassword、keyAlias、keyPassword，勿提交 Git。
脚本在独立临时目录导入和导出，不修改全局 Godot 设置；对齐、签名、验证后清理本次中间目录。生成 APK、SHA256SUMS.txt、source-inputs-sha256.json 和 build.log。最后一个清单记录打包输入，便于核对交付来源。

检查
Godot --headless --editor --path . --import
Godot --headless --path . --script tests/core.gd -- --qa
--qa 仅用于隔离测试存档，不会在常规应用启动时启用。
tests/android 是单独的 Android 触控检查程序，不包含在游戏 APK 中；fixture 是明确的预置测试进度。截图和流程通过不等于实体手机操作顺畅、愿意复玩或学习有效。

版本保存
工作源码统一在 source/，根目录 Git 标签 v0.1.0、v0.2.0、v0.3.0、v0.4.0 保存各代源码。旧版可用 git archive 导出到单独目录，不要直接覆盖正在修改的 source。APK、测试包、缓存和签名资料不进入 Git。新版本通过检查后删除旧编译产物，只留当前可安装包供试玩。

