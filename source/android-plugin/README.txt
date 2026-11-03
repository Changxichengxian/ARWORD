ARWORD 安卓应用更新

设置 → 检查更新会读取 Changxichengxian/ARWORD 的 GitHub Release。检查与下载均由玩家主动发起。安装包版本号比手机当前版本高时才提供更新。

清单名为 update.json。完整包和所有差异包放在同一 vX.Y.Z 版本的 Release 附件里。安卓根据当前已安装 APK 的 SHA-256 选择最小的可用差异包，界面显示所需下载量。如果没有匹配的底包，会显示完整包大小，再由玩家点下载。

差异包由新的 ZIP 成员数据、旧压缩成员的复制位置以及签名块等元数据组成。手机在应用私有缓存中读取自身 base.apk 并重建新的 APK，校验下载长度、SHA-256、包名、版本号、签名证书，之后交给系统安装器。新包需要用户确认。系统要求授权该来源时，会打开对应系统页面。通信使用 HTTPS 和 GitHub 发布域名限制。应用申请 INTERNET 和 REQUEST_INSTALL_PACKAGES。

source/build.ps1 默认制作个人首装包。传入 -PublicRelease 后，构建脚本在单独的暂存目录排除受限人物文件。两种构建使用不同的 OutputDirectory。-UpdateRepository 接受 owner/repo，默认 Changxichengxian/ARWORD。不要把 GitHub 密钥写入客户端。

每次源码更新同时提高 export_presets.cfg 的 version/code、version/name 和 project.godot 的 config/version。以 v0.13.0 为例，在空目录生成准备发布的附件：

python source/tools/make_apk_update.py --apk NEW-PUBLIC.apk --base OLD-PERSONAL.apk --base OLD-PUBLIC.apk --version 0.13.0 --code 13 --output RELEASE

生成工具会用 Android SDK 的 aapt2 核对公开包的包名和版本，拒绝包含 VRM 的目标包，验证每份差异包能逐字节恢复目标包。上传 RELEASE 目录生成的附件。旧底包仅用于本机制作补丁，可在校验后按项目约定删除。若要支持多个历史版本，在清理前为它们生成对应补丁。首次带有更新功能的个人包需手动覆盖安装一次。
