ARWORD · 0.14.4 竖屏小星球

当前合并试玩（2026-11-05，基于 0.14.4，未作为新版本发布）
Windows 交付目标为 outputs/character-preview/Windows/ARWORD.exe，同一程序包含本轮人物、两轮动物改动及运行开销优化。
人物只保留大肥鱼，已去掉白模人的显示和切换；旧人物选择不影响学习记录。原骨骼仅在内部驱动动作，加载人物前不会露出白色身体。私人模型仍不加入公开包；已有缓存可继续使用，缺少人物的设备会显示安装说明。
动作增加起搬、抱稳、较沉的短步、途中重新抱紧、放下卸力和分阶段起身；休息有看向、揉脸、伸展和打盹。表情随用力、专注、放松、困倦变化。大肥鱼的握持高度、工具摆动路线与揉脸动作按其实际比例调整，不修改模型原件。走路、起身和乘船仍不消耗赚到的工作时间。

电脑上直接看
本版 Windows 构建目标为 outputs/0.14.4/Windows/ARWORD.exe。双击运行原生试玩，需 Windows 10/11 x64 及支持 Vulkan 的显卡。
鼠标左键拖动星球，滚轮缩放，点建筑或悬浮进度条打开工地学习卡；点卡片外收起。卡片滑出并淡出，镜头小幅后退约 12%，不突然跳远。词卡收起时，星球与宇宙之间显示本机时间。
本版只有正常应用入口，不再生成“直接看美术”启动器，也不显示预览说明、预设星球名或“继续照料”按钮。电脑正常存档保存在 Windows 本机，不自动同步手机。
开发特权默认开启。卡片双箭头可跳过当前练习，设置里可完成当前工地或全部建设，再前往火箭岛、矿洞、铸币坊或山顶观察。开发推进单独记录。
道路只保留少数建筑与加工点附近的短路，不再连遍所有六边形地块。小人按实际移动距离迈步，区分走路、轻跑和搬运；干活时腰、膝、肩肘共同参与蓄力、下击和回弹。低洼浅湾、草坡、高原和山地继续使用实际高度。

独立 Android 应用使用 io.github.changxichengxian.arword 包名，Godot 4.5.1 实时三维渲染，支持 Android 7.0 以上及 Vulkan。此次在安卓上独立安装，学习存档从新应用开始。

这一段怎么玩
新词卡同屏显示释义、「记好了」和「学会」。点「学会」后会穿插两次抽查，均独立答对便标为已学会，并移出日常词题。答错或看提示会重新累计。
个人版可在设置中切换「英语朗读」。可爱版取自星落落_oi 授权训练的社区声库，由 Esmerubphire 发布。使用其合成参考音频 cute_N01，通过 OpenVoice V2 为原英语录音转换音色。每句听力保留完整录音的节奏。各安装包默认原声。大肥鱼声包按需从个人私有 GitHub 仓库下载并校验导入，覆盖更新会保留。
从飞船旁的三块小陆地开始。上半屏拖动看四周，点建筑或物体上方的进度条，选择这一段要做的事。只有选中的地方有白色虚线圈，缓慢旋转并呼吸明暗；没有固定的三个建筑按钮，也没有操纵杆。
主岛从三块地开始。球背的火箭岛也占三块地。四条巨大的触手分别从深海伸出，抓住岩岸与火箭。潮汐工地与岛之间隔着一片开阔水域。17 段扩地共 150 个建设小步，完工 57 块地形、5 个球面分区。船坞开放跨海路线，远岛金矿和主岛铸币坊分别负责原料与加工。
三主体及九项附属工程共 144 步，连同扩地总计 294 步。火箭通行费为 36 枚金币。每批矿石可铸 2 枚金币，每袋最多交 6 枚。完成任一整本词书的首轮独立辨认后可解锁火箭。世界终点与词汇的长期记忆记录分别保存。
每个工地独立记录进度。六次工作包含三次词义回忆、一次阅读、一次听力、一次句子组织。当前工程从已建成的来源采集材料，经过对应加工点，再运往目标；原料、成品与运输可在世界里看到，没有领木头页面或背包兑换。跨陆地行程通过船坞航线乘船，仍在这一颗星球上。
沿岸树林提供木料；石岸切石场处理石材；锯木坊把木料制成木板；南边草地采收果粮；砖窑烧制砖块；晶湾磨镜台把晶体加工成镜片；向风小丘取水。芦苇浅湾将芦苇织成帆布，高原锻造台将铁矿制成铁件，云杉观星台使用镜片并开放星云观察。
船坞接收木板、帆布、铁件和砖块，打开群岛航线；椰风群岛提供硬木，潮光玻璃坊将海玻璃加工成镜片；黑沙熔岩台加工耐水石管，潮汐引水站接续取水与供水。木屋、风车、花园按各自工程接收相应材料。路线和用途预先设计，尚未提供自由配方或开放式经营；待机和机械空转不会自动增加生产记录。
选择词书后，按尚未独立辨认的词数和剩余建设小步分配练习量；每六次练习的阅读、听力和组句节奏保持不变。开局前三小步最多各两次练习，此后用十五小步逐渐过渡到词书对应的量，最多 48 次/小步。物体上方的总进度及当前小步进度每次变化。分配会保存，换书或未来增加世界容量时重算；不清掉已完成的建筑或小数进度。这里只是节奏估算，不保证完成建设时全词书均已掌握。
每次正确词义回忆增加 12 秒工作；阅读、听力、组句各增加 9 秒，最多积到 36 秒。换下一题不会打断这段工作。步行、起身和坐船不扣工作时间，仅站定干活时扣除。人物走向采集点、搬运、敲打建设；工作时间结束后收起工具，坐下、躺着、伸懒腰或轻晃脚。开发跳过同样触发当前工序的工作动作。额外动作和休息均不追加资源、建设或学习记录，工作时间只在本次运行中播放，不积累离线收益。没有角色或工具数值升级。
新地形使用累计记录解锁：完成南边草地且木料采集累计 8 次，可接芦苇浅湾；完成石岸且石料采集累计 10 次，可接石脊高原；完成高原、小丘、晶湾且阅读加听力累计 12 次，可接云杉观星台。达到前置条件后先显示灰色预告和累计进度，点它可看所需条件。达标后可以选择扩建，不会直接送出全部土地。原有累计记录继续有效。
开发跳过词卡会计入场景采集；跳过阅读或听力会写入独立的开发推进计数，并参与对应地形的开放条件。这些操作不改变词汇记忆强度、不增加学习统计里的阅读/听力/组句完成数，也不清除尚未独立完成的提示记录。
看不懂时可以看释义、译文或听力原文，再继续。提示记录保留，不扣体力、不倒计时。答错和使用提示后的练习，不标成独立掌握。

操作

收起词卡后，近处的镜头逐渐降到地表上方 35°。五处泊位随各自的岸边地块出现，渡船起航加速，弯道连续转向，靠岸前减速。新词先看词义，再隔开其他词独立回忆三次。进入黑洞近观后，暖白吸积盘斜穿视野，细光环与前景的气体薄雾分开呈现。拖动可绕行，缩放可在盘面特写和完整轮廓之间切换。
单指拖动星球，地表跟着手指走。双指贴住地表后，一起挪动可以拖移，转动可以倾转星球，张开拉近、合拢拉远。三个动作可以同时进行，抬起一指后可接着单指拖动。指南针回到当前工地。点建筑或悬浮进度条打开学习卡，点卡片外收起。进度跟随物体，转到背面或被卡片挡住时隐藏，白色旋转环只标记当前目标。
云朝向球心并随球转动，船头沿航向。工作角色按建筑轮廓绕行，采集和建设有全身动作。选中环贴合地形，新增地块和新物体带短促回弹。
点单词即发音；阅读中的词可点开释义并自动发音。空心星星未收藏，实心星星已收藏。没有额外的“音”按钮和音标。
顶部书脊图标选择词书，展开的书本可浏览全库短文。耳机在词卡上切换听音辨义，在阅读或听力任务中重播。齿轮里调整词汇起点、自动读词、音效、轻音乐和开发特权，也可查看收藏。
阅读可选短版或展开版；长文仅在阅读区域内滚动。听力可重播、慢放或看原文。句子词块保持固定位置，选过的变灰。

固定人物
个人版首次启动会校验大肥鱼原件并复制到 user://characters/。当前只保留大肥鱼，设置显示人物信息与作者署名；旧的默认人物选择会自动使用已安装的大肥鱼。大肥鱼的步幅、工具握点、尾部留空与闭眼打盹已适配；9 个表面的接触点索引预先计算。作者为木子恶魔。
已发布的 0.14.4 公开版仍包含当时的默认人物；当前源码已移除其显示，未重新发布安卓包。历史个人首装包的构建目标为 outputs/0.14.4/Android/ARWORD-0.14.4-setup.apk（安卓版本代码 27），公开稳定包为 outputs/0.14.4/Public/ARWORD-0.14.4.apk（版本代码 28）。请先打开个人版一次，让应用校验并保存大肥鱼。公开更新发布后，可从“设置 → 检查更新”升级并继续使用缓存人物。清除应用数据或卸载会删除该设备上的缓存模型与学习记录。作者原模型不进公开仓库、公开安装包或更新附件。

可以停下来看什么
宇宙保留大面积深黑。三处稀疏、低饱和的程序体积星云置于太阳系后方的不同距离，以三维噪声和沿视线取样形成云层、暗核和薄亮边，不使用摄影图片或生成的星云壁纸。每次启动使用新的随机种子，设置里的“换片星空”可以立即换一次；五项参数保持用户选择。太阳与四颗风格不同的行星在独立的透视三维空间中公转、自转，远景按实际窗口像素渲染以减少模糊。轨道和距离经过压缩；当前星体只供观察和轻触反馈，不能登陆、旅行或建设。
建成云杉观星台后，选择山顶工地，点望远镜图标可近看三处程序星云。触屏上可以边转动双指边张合，调整画面倾角和观察距离。电脑可拖动视角，用滚轮调整距离。
海里有五种不同轮廓的水生动物：原有小鱼、银鱼、珊瑚鱼、鳐鱼和海龟，按深浅分层游动。巨鲸重做为长身、宽扁头的蓝鲸，保留较大体量，尾部上下慢摆，会换气、喷水、跃出和下潜；点击观察只改变动作时序，不使巡游路线瞬移。海岸的重复蓝色扁块已去掉，改为断续泡沫与少量岩礁；海底稀疏布置珊瑚、海草和旧骨架。
火箭岛有更暗的岩岸、局部灯光和深水。近看能分辨触手的墨青背脊、暗紫腹面和大小渐变的吸盘，海怪的身体藏在水下。每次交金币时触手会动，交满后松开火箭，外海仍露出一截弧背。其他海区保留岩洞、珊瑚和遗迹。
设置中的“星空与星云”提供五项实时滑条：星云浓度、色彩强度、星云范围、星星密度和漂移速度。面板放在下方，上方天空不遮暗，拖动立即生效；松手、关闭或退出时保存，也可恢复默认。漂移调为零只停住星云，行星继续运行；调速不跳相位。
背景音乐为本项目原创的 Island Drift，80 秒器乐循环。播放单词或听力语音时自动压低，结束后逐渐恢复；轻音乐与操作音效可以分别关闭。

内容与学习范围
六本参考词书：小学 1,030、初中 1,603、高中 2,724、四级 3,154、六级 3,307、专八 3,929，跨书共用 10,696 个词头。按精确词头隔两级剔除：高中减小学、四级减初中、六级减高中原表、专八减四级原表；小学和初中不剔除，不合并派生词或不同词形。原来 96 个精选词的例句、发音和记录继续保留，同词在不同词书共享学习记录与收藏。默认选高中，可直接换书。
小学是本项目选编的基础参考表；初中到六级来自 ECDICT 的考试标签，专八指 OpenEtymology 的英语专业八级参考表。这些分类不代表核定的官方完整大纲。数据来源、修改、精确剔除和许可见 assets/wordbooks/SOURCE_NOTES.txt。短选项按规则从词典产生，并修订一批常见偏义；自动检查和抽查不等于全库人工教学审定。
全库 34 组短读、展开阅读、听力及组句，含 22 组工作手记和 12 组非建造题材。每个工地都可取到全库。阅读窗可前后换篇，答题按难度、近期学习和复习记录调度。查词词典覆盖 876 个词形。
默认从第二档开始，连续独立答对四次上调，连续两次需要提示下调，也可手动改起点。这不是总词汇量测试，四选一不能证明自由回忆能力。
提示后的词约两分钟进入复习；首次独立回忆也约两分钟再见，之后逐步延长到十分钟、数小时和数天。即时重复不增加记忆强度。阅读、听力、组句分别记录完成和是否看过提示，不据此虚增词汇掌握量。
六本词书共用 10,696 段单词录音。学习流程另有 978 项语音，其中 102 段短读、展开阅读与听力指令均以整句或整段合成。Kokoro af_heart 为美式英语合成声音。
这仍然是有限内容的样段，没有在线生成、无限词库、跨星球旅行或自由建造。扩地路线与建筑位置由地图预先安排，玩家选择当前可用工地；学习与施工仍有抽象对应。人物动作不增加学习奖励或建设收益。构建、截图和流程检查不能证明好玩、实体手机流畅或学习有效。

存档
user://island4.json，临时文件写完后替换，另留 .bak。保留原有建筑、词汇、收藏、难度和安排；0.6 使用可选 frontier 字段保存扩地区域、当前工地和独立工作轮次；已有词汇、收藏、三处建筑和工作轮次保留。旧建筑所需的支撑陆地直接出现，不拆旧建筑、不重做旧学习记录。旧版已建成的主体不重做，不清空旧词汇。卸载或清除应用数据会删除存档。
0.9 增加可选的 music、dev_skip、dev_steps、dev_context 字段。旧存档缺少这些字段时使用默认值；开发跳过采用正常存档，不是退出就清空的体验模式。--qa 和内部预置场景仍使用隔离记录，仅供自动检查。
space_settings 保存星空五项参数；缺项使用默认值，非法数值恢复默认或限制到滑条范围，不改变学习和施工记录。
0.10 增加可选 book_id、study_plan、pending_help 和 frontier.effort。新字段缺失时使用默认值；换书仍保留之前词汇记录和待完成的提示标记，重新选回可继续复习。天空随机种子不写入存档，用户滑条参数继续保存。
0.11 新增五个扩地区域，以及 frontier.production、frontier.deliveries 生产和运送记录。旧存档缺项时补默认值，已有土地、建筑和学习记录保留；世界容量变化后重算后续练习安排。观星与开发巡游不追加学习成绩。
人物资源与选择存在 user://characters/，使用已核验的固定模型哈希，和独立的 choice.cfg。公开更新读取设备已有的固定角色缓存。

源码与美术
scripts/main.gd：流程、音频、存档、阅读与句子组织。
scripts/learning.gd：复习、难度、建筑进度。
scripts/wordbooks.gd：六本参考词书的读取与成员关系。
scripts/frontier.gd：有限地图、解锁条件、分工地进度和兼容读取。
scripts/grove.gd：三维场景、采集、搬运、建筑动画。
scripts/terrain.gd：共享的六边形地表高度、相连边界与各片陆地的球面分区映射。按球面弧长安排地块，避免铸币坊等远离分区中心的地块拉长。
scripts/worker.gd：有时限的工作与休息动作，不修改学习记录。
scripts/character_motion.gd：纯姿态计算，分别定义步态、挥工具、搬运和休息的节奏；不推进工作时间或修改进度。worker 负责状态衔接与连续步态，avatar 负责实际骨骼、表情与手部接触。
scripts/avatar.gd 和 scripts/fixed_cast.gd 负责固定人物的骨骼、材质、接触点以及独立角色缓存和选择。
scripts/water.gd、assets/water.gdshader、shore_foam.gdshader：海床深度、海水和岸边浪纹。
scripts/wildlife.gd：鸟蝶、五类水生动物、巨鲸、海底小景。
scripts/cosmos.gd、assets/cosmos_*.gdshader：透视太阳系与动态深空背景。
scripts/ambience.gd：背景音乐、语音时压低音乐和退出释放。
scripts/study_voice.gd：可选私人声包的校验、导入与录音读取。
scripts/hud.gd、icon_button.gd：原生游戏界面和图标。
assets/vocabulary.json、missions.json、frontier_missions.json：教学内容；改英文语音文字后需重新生成对应录音。
art-source 与 assets/models 中有 89 对可编辑模型源文件和 GLB。tools/make_voyage_art.py 生成火箭、金矿洞、铸币坊、金矿石和金币。tools/make_rocket_kraken.py 生成火箭岛巨型触手。可在 art-source/rocket_kraken.blend 中编辑四条触手的形态、吸盘和退海动作。
tools/make_art.py、render_icon.py：Blender 4.4.3 后台运行，生成模型和图标。
tools/make_life_art.py：生成鸟、蝴蝶、鱼和鲸的 Blender 源文件与运行模型。
tools/make_blue_whale.py：单独重建连续长身、宽扁头、细长胸鳍和水平分叉尾的蓝鲸，不重导其他动物；make_life_art.py 的鲸生成也使用它。
tools/make_deep_sea_art.py：生成新增水生动物、珊瑚、海草、骨架、实体洞窟与巨物。
tools/make_frontier_art.py、make_telescope.py：生成新生产设施、材料、地景与望远镜。
tools/make_music.py：原创器乐循环的音符、音色与合成过程；运行需要 numpy、soundfile 及 FFmpeg。
tools/make_missions.py：生成 12 组建筑手记。tools/make_frontier_missions.py：生成 10 组扩地与加工手记。
tools/make_dictionary.py：传入 ECDICT CSV 路径，提取词形和释义。
tools/make_wordbooks.py、make_wordbook_audio.py：由保留的源词头和选中词典记录重建六本词书、短释义与选项，按文字哈希生成或复用离线发音。tools/check_wordbooks.py 检查原表剔除、题目结构、来源许可和每条音频。
tools/make_builder.py：连续蒙皮人物及对应 Blender 源文件的独立生成脚本。
tools/make_audio_manifest.py：从当前词库、手记、词典生成语音清单。
tools/make_voice.py：--models 指向 Kokoro ONNX 模型目录，--ffmpeg 指向 FFmpeg；依赖 kokoro-onnx、onnxruntime、numpy、soundfile。按文字哈希增量生成，模型不随源码保存。
tools/make_font.py：Python fonttools，生成静态字体子集，文字改动后运行。
android-plugin 保存原生更新插件源代码，tools/make_apk_update.py 从已签名的公开包与同应用旧包生成 update.json、完整包和逐字节可还原的差异附件。
手机在设置中主动检查时，优先向 GitHub Releases 官方 API 获取最新版本信息，按附件读取清单与下载文件。网页发布路径作为备用。目标包完成核对后交给安卓系统安装器。
第三方许可见 assets/CREDITS.txt。

第二轮动物试玩（2026-11-05）：Windows 入口为 outputs/wildlife-expanded/Windows/ARWORD.exe。新增兔子、海豚、海马、河豚和鱿鱼，运行模型与 Blender 源文件增加到 89 对。兔子在草地短跳、嗅闻、理毛与停坐，开局 1 只，扩地最多 2 只；避让建筑、装饰、海岸和人物。海豚上浮换气后再下潜，海马小鳍悬游，河豚轻触后逐渐鼓起，鱿鱼收缩身体和分段摆腕。鱼群交替游动、放慢与停留，鸟蝶增加转头和姿态变化。
龟甲改成沿椭圆轮廓排列的错落多边形，取消横平竖直的内部格子。岩台有三只错开行动的螃蟹，沿岩壁爬到真实海床觅食，再返回岩台；扩地后只使用安全路线，周围受阻的个体留台活动。海豹会腹部挪动、伸展、侧躺晒背和抬头回应。按用户要求取消“去看看”及“巡游与海底”入口和整页跳转面板，观察动物使用正常的星球拖动、缩放和轻触；内部镜头检查只供开发验证。
新增制作入口 tools/make_rabbit.py、tools/make_ocean_guests.py；兔子地面行为位于 scripts/land_wildlife.gd。所有动物行为均不写学习、材料或建设记录。安卓继续使用同一套原生源码，本轮交付 Windows 试玩，不重新发布安装包。

第一轮动物外观与动作修订（2026-11-05）：海鸥使用白头、灰色分段翼和黑色翼尖，拍翼与滑翔平滑交替；海龟前长后短的鳍从甲壳下连接，前鳍划水、后鳍转向，间歇滑行。鳐鱼内外翼分段摆动；三类鱼使用竖直尾鳍与独立胸鳍；蝴蝶前后翅略有延迟。螃蟹有八条可动步足，海豹双前鳍、虎鲸胸鳍和水母触须补充小幅动作。轻触鸟蝶后的上升与加速逐渐发生。相关 Blender 源文件保留在 art-source/；第一轮试玩保留在 outputs/wildlife-preview/Windows/ARWORD.exe。
内部动物核对：Godot --headless --path . --script tests/wildlife_motion.gd -- --qa；原生姿态图：Godot --path . --script tests/wildlife_visual.gd -- --qa --visual-out=<截图目录>。两项使用隔离场景，不改本人学习记录。

运行开销与维护边界（2026-11-05）
terrain 在创建时预计算固定 57 块地形的中心、共享角点高度，以及五个球面分区的坐标变换。扩地只改变已出现的土地，不改这些几何定义；若以后支持编辑地图，改完后必须重建 Terrain，不能直接改 cells 或 charts 后沿用旧缓存。任意位置的地面高度仍按实际位置计算，不无限缓存浮点坐标。
wildlife 共用固定的八个外围采样方向，每次检查只构造一次切平面。水生动物仍检查中心和周围共九个位置，不减少避陆采样、动物数量或更新频率。worker 在一帧骨骼更新内复用同一个逆变换，下一帧重新计算。
hud 的工地标签每帧跟随镜头，但只在文字、主题或子控件尺寸变化时重新计算布局；先算完遮挡和屏幕边界，再统一设置可见性。新增影响尺寸的内容要触发最小尺寸更新或调用 sync_goal，避免把布局计算放回每帧循环。
learning 每次仍读取最新学习记录，用一次扫描选择最早复习项，保留新词随机选择；不缓存会随答题变化的候选结果。优先级完全相同的候选选列表中第一项，旧排序对同优先级没有稳定顺序保证。
study_voice 只缓存最近使用的可选声包录音，最多 32 条、合计 8 MiB 编码后的 MP3 数据；这是缓存数据上限，不是整个音频系统的内存上限。超过上限的单条仍可播放但不进入缓存。重新 prepare 时清空缓存并关闭旧压缩包，避免导入新声包后沿用旧录音。默认原声继续由 Godot 资源系统读取。
性能检查使用隔离存档和无画面模式，分别检查正常场景更新、选词和录音读取。耗时只代表本机 CPU 工作，不能换算为手机或显卡渲染帧率。本轮对照记录和 Windows 试玩在 outputs/performance-preview/；临时测试资料在 work/performance/。

构建
Windows：Python 调用 build_desktop.py --godot <Godot控制台exe> --templates <4.5.1 templates.tpz> --output <交付目录>。使用独立编辑器配置和临时目录，导出内嵌资源的单个 EXE 与来源哈希，不再生成公共美术预览启动器。无需签名资料。交付程序不含测试代码、Blender 工程或浏览器。
Android：依赖 Godot 4.5.1 及对应 Android 导出模板、Android SDK、JDK 21。Templates 目录还须有同版官方 android_source.zip；这是构建依赖，不是旧安装包，也不提交 Git。PowerShell 7 调用 build.ps1，传入 -Godot、-Templates、-AndroidSdk、-JavaHome、-SigningProperties、-OutputDirectory。签名配置属于私密文件，勿提交 Git。
build.ps1 调用 android-plugin/prepare.ps1 注入更新插件并通过 Gradle 导出。公开构建使用 -PublicRelease，个人构建从被 Git 忽略的 assets/characters/deepseek.vrm 读取固定模型。更新仓库默认为 Changxichengxian/ARWORD。
脚本在独立临时目录导入和导出，不修改全局 Godot 设置；对齐、签名、验证后清理本次中间目录。生成 APK、SHA256SUMS.txt、source-inputs-sha256.json、android-build-dependencies.json 和 build.log。输入清单覆盖 Java 插件源码；依赖清单记录源模板哈希与 Manifest 注册名，配合 prepare.ps1 核对模板来源、修改和最终 APK 的注册/权限声明。
海面与海床、鱼群共享测深数据。水面用硬件深度测试和透明混合，浅水能看见海床，波纹保留动态高光。手机单独限制三维场景的像素数，学习界面保持屏幕原始分辨率。

检查
Godot --headless --editor --path . --import
Godot --headless --path . --script tests/core.gd -- --qa
Godot --headless --path . --script tests/two_finger.gd -- --qa
Godot --headless --path . --script tests/rest_terrain.gd -- --qa
Godot --path . --script tests/rest_support.gd -- --qa
Godot --headless --path . --script tests/world_progress.gd -- --qa
Godot --headless --path . --script tests/archipelago.gd -- --qa
Godot --headless --path . --script tests/development.gd -- --qa
Godot --headless --path . --script tests/wordbooks.gd -- --qa
Godot --path . --script tests/wordbook_ui.gd -- --qa --visual-out=<截图目录>
Godot --path . --script tests/spatial_actor.gd -- --qa --visual-out=<截图目录>
Godot --path . --script tests/cosmos_art.gd -- --qa --visual-out=<截图目录>
Godot --headless --path . --script tests/space_settings.gd -- --qa
Godot --headless --path . --script tests/worker_motion.gd -- --qa
Godot --headless --audio-driver Dummy --path . --script tests/character_actions.gd -- --qa --qa-with-cast --qa-avatar-scope=actions
Godot --headless --audio-driver Dummy --path . --script tests/avatar_expression.gd -- --qa --qa-with-cast --qa-avatar-scope=expressions
Godot --path . --script tests/character_visual.gd -- --qa --qa-with-cast --qa-avatar-scope=visual --character=deepseek --visual-out=<独立截图目录>
Godot --headless --path . --script tests/water_surface.gd -- --qa
Godot --headless --audio-driver Dummy --path . --script tests/runtime_resources.gd -- --qa
Godot --headless --audio-driver Dummy --path . --script tests/hud_runtime.gd -- --qa
Godot --headless --audio-driver Dummy --path . --script tests/terrain_performance.gd -- --qa --baseline-terrain=<优化前terrain.gd绝对路径>
Godot --headless --path . --script tests/cosmos.gd -- --qa
Godot --headless --path . --script tests/cosmos_observatory.gd -- --qa
Godot --path . --script tests/observatory_ui.gd -- --qa --visual-out=<截图目录>
Godot --headless --path . --script tools/check_life.gd
Godot --headless --path . --script tools/check_aquatic.gd
Godot --path . --script tests/deep_sea.gd -- --qa --visual-out=<截图目录>
python tools/check_assets.py
python tools/check_wordbooks.py
python tools/check_music.py
Godot --headless --path . --script tests/desktop_preview.gd -- --art-preview
Godot --path . --script tests/pacing_visual.gd -- --art-preview --visual-out=<截图目录>
Godot --path . --script tests/cosmos_settings.gd -- --qa --visual-out=<截图目录>
Godot --path . --script tests/card_visual.gd -- --qa --visual-out=<截图目录>
Godot --headless --path . --script tests/avatar_storage.gd -- --qa
Godot --path . --script tests/avatar_ui.gd -- --qa --qa-with-cast --visual-out=<独立截图目录>
--qa 隔离测试存档；常规应用不会启用。--art-preview 仅保留为内部预置场景检查参数，同样隔离存档；不设公共入口或标题水印。tests/android 是独立的 Android 触控检查程序，不包含在游戏 APK 中。预置的完工场景不代表用户完成相应学习。
固定角色检查使用独立的 user://qa-characters/。带 --qa-with-cast 和独立 --qa-avatar-scope=<名称> 检查唯一大肥鱼、旧选择兼容与缺少模型的流程。
具体检查结果见 验证记录.txt。构建、流程检查和截图不能证明实体手机流畅、愿意复玩或学习有效。

版本保存
唯一工作源码在 source/，根目录 Git 按版本打标签。公开包和增量文件发布到 GitHub Releases。个人包只在本机交付。下次更新时，先用真实旧签名包生成差异附件，再使用该旧包和附件还原新安装包，核对其大小、哈希与签名后的完整新包一致后清理旧包。


0.12.3
点工地会立即起身跑向可到达的落脚点，有船坞时可以跨岛。移动不发材料、不计学习。选中工地的白色虚线在一张与地表相切的平面上悬浮，只有切换地点或扩地才重算高度。火箭岛的一臂沿岛缘回抱，另一臂绕箭身向上盘旋。安卓水面用真实海床深度和透明混合，天空与星球分开控制绘制开销。

0.13.2
启用黑洞后可以直接点黑影进入近景，双指或滚轮缩放，左上角返回。tools/make_lens_transfer.py 用非旋转黑洞的近似计算两次薄盘交点，输出到 assets/cosmos/；手机在交点上采样流动的盘面。该效果借鉴电影团队的论文与构图，没有复现电影使用的旋转黑洞计算器。
开发特权可重做当前工地或回到开局。两项操作均需确认并保留英语学习记录。跨岛行程包含沿岸行走、过栈桥、乘船和离船步行，渡船停靠在最近一次抵达的泊位。火箭岛可下潜观察海沟。中心天体可选太阳或黑洞，望远镜内可近看三处程序星云。四首原创器乐轮播，设置中可切歌。

安卓读取当前窗口四边的安全范围。词书等顶部按钮、底部词卡、弹窗及观测返回键随系统栏、挖孔与手势区域调整位置。星空与星球继续铺满屏幕。

0.13.2 · 工地巡游可看虎鲸和潮间岩台。旧存档首次进入新版采用黑洞，手动选择太阳后记住选择。时钟水平居中。移动端光照单独指定软阴影过滤。

个人朗读包制作：source/tools/make_study_voice.py 接收包含 audio/ 和 wordbooks/audio/ 下 MP3 文件的 ZIP、作者发布的 cute_N01.wav、OpenVoice V2 源码与 converter 权重目录。输出放在 assets/characters/feiyu-cute-v1.arvoice，所有构建均将它排除。权重与私人录音在 Git 外。

0.14.4 顶栏保留词书和设置，阅读、收藏、练习偏好和学习统计收进词书。所有新装使用原声。私有声包首次在设置下载和导入，此后离线播放。
