LocalAvatarPicker — Android 原生文档选择

运行接口
Engine.get_singleton("LocalAvatarPicker").pick_avatar()
信号：avatar_picked(path)、avatar_pick_failed(message)、avatar_pick_cancelled()。
成功路径为应用私有缓存中的 selected.vrm；主应用应复制到自己的待验证文件，再进行格式、骨架和资源检查，成功后替换当前角色。取消或读取失败不会改动主应用已选角色。

仅使用 ACTION_OPEN_DOCUMENT 和 ContentResolver.openInputStream 读取用户选中的 content URI，不推测共享存储路径、不要求全盘读取、不联网、不保留文档访问权。单文件上限 64 MiB，读取与磁盘复制在后台线程完成。最多保留一个完成的缓存文件及一个正在复制的临时文件；不删除用户原文件。

构建
prepare.ps1 将官方 Godot 4.5.1 android_source.zip 解到本轮独立 staging 的 android/build，Java 代码直接进入官方 app 模块的 src，Manifest 通过 Godot v2 插件条目注册。引擎运行库使用模板附带的 Godot AAR；无需外来插件。源码中不保存 AAR、class、dex、Gradle 缓存或 APK。
source/build.ps1 自动调用准备脚本并使用 Gradle 导出，最终签名与以前相同。Java 和 Manifest 只包含选择器功能，不含角色模型。
