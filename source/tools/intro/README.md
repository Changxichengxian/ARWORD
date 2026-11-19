# 录制 ARWORD 介绍视频

在这台 Windows 电脑上，双击同目录的「录制介绍视频.cmd」。完成后打开项目里的 `outputs/应用介绍/ARWORD-介绍.mp4`。默认录成 720 × 1280、每秒 24 帧的竖屏视频。只有成片通过完整解码检查，工具才会替换上次的文件。

旁白和每个镜头停留多久，都在 `story.json`。改 `line` 就能换台词，`at` 是开口前留的秒数。台词变长时，镜头会自动延长。第一幕在岸边，近拍兔子时海鸥在画外，山顶观星台之后才出现黑洞。黑洞这一幕只放音乐。用 `--width 1080 --fps 30` 可以重录成更高分辨率，`--output` 可以另存一份。

工具直接拍摄 Godot 里的应用。词卡用小学词书里的 island（岛）演示认词与回忆，中间播放个人声包里这条词的英语发音。换示例词时，一起改词卡镜头的 `book` 和 `word`。扩地镜头把中间多次练习压缩到同一个机位。后期的海岸和观星台使用单独的演示进度。拍摄期间，游戏使用临时目录和隔离存档。

中文旁白默认由大肥鱼的可爱版模型直接念。它使用作者的 F6 权重、N01 参考音、配套提示文本与中文断句流程。英语单词播放应用个人声包里的对应录音。语音素材来自星落落_oi 授权训练的社区声库，由 Esmerubphire 发布。大肥鱼形象作者为木子恶魔。

想先听台词，可以在这个目录运行 `录制介绍视频.cmd --sample rabbit`。这会把兔子那句导出为独立的 WAV。要比较同一句的旧读法，加上 `--voice legacy`，就会先让 Windows 普通话朗读，再用 OpenVoice V2 换成大肥鱼的音色。两种试听分别保存。

换电脑时，准备 Godot 4.5.1、带字幕渲染功能的 FFmpeg、个人角色和英语声包，再用 Godot 导入 `source/`。中文直读需要作者的模型包和配套的 CosyVoice 运行环境。本机模型在 `work/intro-feiyu`，引擎源码在 `work/qa142/engine`，Python 使用 Ubuntu 子系统的 `~/.local/share/arword-feiyu/env/bin/python`。可用 `--voice-model` 和 `--voice-engine` 指向其他安装位置，或用 `--voice-python` 指定装好依赖的 Windows 解释器。[作者的模型与安装说明](https://huggingface.co/Esmerubphire/FeiyuVoice-CosyVoice3)
