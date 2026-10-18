"""Original learning content + a licensed offline dictionary subset.
Run from project root. No network is required after ECDICT has been downloaded.
"""
from pathlib import Path
import argparse, csv, json, random, re, shutil, sqlite3
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'app/src/main/assets'
rng=random.Random(20261012)
questions=[]; stories=[]
WORDS=[
"""arrive|到达|The first visitors arrive before noon.
borrow|借入|May I borrow your map for a day?
carry|携带|We can carry the small boxes together.
choose|选择|Choose a dry place for the tent.
corner|角落|A small lamp stands in the corner.
decide|决定|We must decide which road to take.
empty|空的|The basket is empty after lunch.
enough|足够的|There is enough water for everyone.
follow|跟随|Follow the path beside the river.
fresh|新鲜的|She brings fresh bread every morning.
gather|聚集|The travelers gather near the fire.
gentle|轻柔的|A gentle wind moves through the grass.
improve|改善|Practice can improve your listening.
invite|邀请|We invite our neighbors to dinner.
journey|旅程|The journey takes three days.
leave|离开|We leave the village after breakfast.
notice|注意到|Did you notice the broken window?
offer|主动提供|They offer us a place to sleep.
prepare|准备|We prepare a hot meal for the team.
quiet|安静的|The street is quiet at night.
reach|到达|Can we reach the bridge before dark?
repair|修理|He can repair the old wooden chair.
return|返回|Please return before the rain starts.
share|分享|We share our food with the visitors.
simple|简单的|The plan is simple and easy to follow.
slowly|缓慢地|The boat moves slowly across the lake.
space|空间|There is space for one more tent.
stay|停留|You can stay here until tomorrow.
storm|暴风雨|The storm keeps everyone indoors.
strong|强壮的|A strong horse pulls the heavy cart.
surprise|惊喜|The birthday cake is a lovely surprise.
together|一起|We finish the work together.
useful|有用的|This little tool is very useful.
village|村庄|The village lies beside a wide river.
wait|等待|Please wait here for the next boat.
waste|浪费|Do not waste the clean water.
weather|天气|The weather changes quickly here.
wide|宽阔的|The road is wide enough for two carts.
wooden|木制的|They build a wooden table for the hall.
worry|担心|Do not worry about making a mistake.""",
"""avoid|避免|We avoid the narrow road during heavy rain.
balance|平衡|Try to keep a balance between work and rest.
benefit|益处|One benefit of walking is better sleep.
compare|比较|Compare the two maps before you choose.
complete|完成|We hope to complete the bridge this week.
consider|考虑|Please consider the risks before leaving.
defend|防守|Two guards stay behind to defend the gate.
delay|延迟|The rain may delay our trip by an hour.
depend|依赖|The village depends on the river for water.
discover|发现|We discover a small garden behind the house.
effort|努力|The team puts a lot of effort into the project.
escape|逃脱|The animals escape through a hole in the fence.
expect|预料|We expect the visitors to arrive this evening.
explain|解释|Can you explain why the path is closed?
familiar|熟悉的|Her voice sounds familiar to me.
gently|轻轻地|Place the glass gently on the table.
gradually|逐渐地|The empty field gradually becomes a garden.
harvest|收获|The farmers celebrate a good harvest.
instead|代替；反而|It is raining, so we will read indoors instead.
manage|设法完成|We manage to fix the roof before the storm.
material|材料|Wood is the main material used for the bridge.
meanwhile|与此同时|I will cook; meanwhile, you can set the table.
opponent|对手|Our opponent often attacks from the left.
patient|耐心的|Be patient while the young plants grow.
perhaps|也许|Perhaps the other road is safer.
protect|保护|The walls protect the garden from the wind.
purpose|目的|The purpose of this room is to store food.
reduce|减少|Better tools can reduce the time we need.
regular|有规律的|Regular practice is better than one long session.
remain|仍然处于；留下|Please remain inside until the storm ends.
replace|替换|We need to replace the broken wheel.
resource|资源|Clean water is a valuable resource.
route|路线|This route follows the coast for several miles.
shelter|庇护处|We find shelter in an old stone house.
signal|信号|A raised flag is the signal to move.
supply|补给品|The cart carries a supply of food and medicine.
trade|贸易|Trade brings new goods into the village.
trust|信任|I trust her because she keeps her promises.
unless|除非|We will leave now unless you need more time.
weakness|弱点|The wall has a weakness near the old gate.""",
"""accurate|准确的|We need an accurate map of the valley.
adapt|适应|The team must adapt to the changing weather.
advance|前进|The soldiers advance slowly through the mist.
alternative|替代选择|Walking is a good alternative to waiting for a cart.
approach|接近|As we approach the village, we hear music.
assume|假定|Do not assume that every quiet road is safe.
brief|简短的|He gives a brief account of the journey.
capacity|容量|The new tank has twice the capacity of the old one.
consequence|后果|Think about the consequence of leaving the gate open.
constant|持续的|The constant noise makes it difficult to rest.
contrast|对比|There is a clear contrast between the two plans.
convince|说服|We convince the driver to take a safer route.
decline|下降|The number of visitors begins to decline in winter.
efficient|高效的|This new stove is more efficient than the old one.
estimate|估计|Can you estimate how long the repairs will take?
evidence|证据|The broken branches are evidence that someone passed here.
expand|扩大|We plan to expand the garden next spring.
expose|使暴露|Removing the fence would expose the plants to strong winds.
flexible|灵活的|A flexible plan is useful when the weather changes.
frequent|频繁的|Frequent rain makes the path difficult to use.
hesitate|犹豫|She does not hesitate to help a stranger.
identify|识别|Can you identify the bird by its song?
maintain|维持|We need to maintain a steady supply of water.
nevertheless|尽管如此|The work is difficult; nevertheless, they continue.
obtain|获得|Travelers can obtain fresh water at the station.
opportunity|机会|The quiet afternoon is an opportunity to repair the roof.
predict|预测|It is difficult to predict the next storm.
priority|优先事项|Keeping everyone warm is our first priority.
recover|恢复|The plants recover after a few days of rain.
reluctant|不情愿的|He is reluctant to leave his comfortable home.
reliable|可靠的|We need a reliable source of news.
reveal|揭示|The letter may reveal the reason for her journey.
temporary|临时的|They put up a temporary shelter near the road.
threat|威胁|Flooding is the biggest threat to the village.
transfer|转移|We transfer the food to a dry room.
uncertain|不确定的|The date of their return is still uncertain.
valuable|有价值的|Her advice is especially valuable to new travelers.
whereas|然而；相比之下|The north road is short, whereas the south road is safe.
withdraw|撤退|The guards withdraw when they see the larger force.
withstand|承受|The new roof can withstand heavy snow.""",
"""ambiguous|含糊的|The message is ambiguous, so we ask for more detail.
anticipate|预期|We anticipate greater demand for water in summer.
apparent|明显的|There is no apparent damage to the bridge.
compensate|补偿|The extra supplies compensate for the late delivery.
compromise|折中方案|They reach a compromise that gives each group some space.
conceal|隐藏|Thick branches conceal the entrance to the path.
consistent|一致的|Her report is consistent with what the scouts saw.
constraint|限制条件|Limited time is the main constraint on our plan.
coordinate|协调|We coordinate the deliveries so that nothing is wasted.
credible|可信的|We need a credible explanation for the missing goods.
deliberate|有意的|The delay is deliberate, intended to avoid the storm.
disrupt|扰乱|A sudden flood could disrupt the supply route.
distinguish|区分|It is hard to distinguish a real warning from a rumor.
divert|使转向|We divert the water into a smaller channel.
elaborate|详尽的|The captain has an elaborate plan with several stages.
emerge|出现|A new problem begins to emerge during construction.
feasible|可行的|The smaller bridge is a feasible solution.
fluctuate|波动|Water levels fluctuate throughout the year.
imply|暗示|Dark clouds imply that a storm may be near.
incentive|激励因素|A safer road is an incentive for travelers to return.
inevitable|不可避免的|Some delays are inevitable in such bad weather.
inference|推断|Her conclusion is an inference based on several clues.
initiative|主动权|A quick response allows our team to take the initiative.
integrate|整合|We integrate the new garden into the existing village.
mutual|相互的|The agreement depends on mutual trust.
negotiate|协商|The two villages negotiate the cost of the bridge.
objective|客观的|Try to give an objective account of what happened.
persist|坚持|They persist despite several unsuccessful attempts.
plausible|合理可信的|The broken wheel is a plausible reason for the delay.
precise|精确的|We need precise measurements before cutting the wood.
preserve|保留；保护|The village hopes to preserve its old meeting hall.
reinforce|加固|Workers reinforce the wall with additional stone.
resilient|有恢复力的|These plants are resilient and recover after dry weather.
retain|保留|The rebuilt house retains its original front door.
scarce|稀缺的|Fresh vegetables are scarce during the cold months.
subsequent|随后的|The subsequent report provides more reliable details.
sustain|维持|A small garden cannot sustain the entire village.
trade-off|权衡取舍|There is a trade-off between speed and safety.
underlying|根本的|We must understand the underlying cause of the problem.
vulnerable|易受攻击的|Without a wall, the camp is vulnerable to attacks."""
]
word_rows=[]
for level,block in enumerate(WORDS):
    for line in block.splitlines():
        word,zh,sentence=line.split('|');word_rows.append((level,word,zh,sentence))
# Classify the sense actually used in the authored example. Avoid giving away
# a word's meaning merely because it is the only adjective among three verbs.
WORD_KINDS = {
    'noun': set('corner journey space storm surprise village weather balance benefit effort harvest material opponent purpose resource route shelter signal supply trade weakness alternative capacity consequence contrast evidence opportunity priority threat compromise constraint incentive inference initiative trade-off'.split()),
    'adjective': set('empty enough fresh gentle quiet simple strong useful wide wooden familiar patient regular accurate brief constant efficient flexible frequent reluctant reliable temporary uncertain valuable ambiguous apparent consistent credible deliberate elaborate feasible inevitable mutual objective plausible precise resilient scarce subsequent underlying vulnerable'.split()),
    'adverb': set('slowly together gently gradually perhaps'.split()),
    'connector': set('instead meanwhile unless nevertheless whereas'.split()),
}
word_kind = {word:kind for kind,words in WORD_KINDS.items() for word in words}
close_meanings = [set(group.split()) for group in (
    'arrive reach', 'maintain sustain', 'preserve retain',
    'credible plausible reliable', 'accurate precise',
    'anticipate expect predict', 'reveal expose', 'slowly gradually',
    'defend protect', 'wait stay remain', 'trade-off compromise',
)]
for words in WORD_KINDS.values():
    assert words <= {r[1] for r in word_rows}
for i,(level,word,zh,sentence) in enumerate(word_rows):
    kind=word_kind.get(word,'verb')
    ambiguous=set().union(*(group for group in close_meanings if word in group))
    candidates=[r for r in word_rows if r[1]!=word and r[2]!=zh and r[1] not in ambiguous and word_kind.get(r[1],'verb')==kind]
    # Prefer the same working band; neighboring bands fill sparse word types.
    candidates.sort(key=lambda r:abs(r[0]-level))
    radius=0
    while sum(abs(r[0]-level)<=radius for r in candidates)<3: radius+=1
    pool=list(dict.fromkeys(r[2] for r in candidates if abs(r[0]-level)<=radius))
    assert len(pool)>=3, word
    rng.shuffle(pool)
    distractors=[]
    meanings={r[1]:r[2] for r in word_rows}
    for candidate in pool:
        if any(candidate in {meanings[w] for w in group} and any(selected in {meanings[w] for w in group} for selected in distractors) for group in close_meanings):
            continue
        distractors.append(candidate)
        if len(distractors)==3:break
    assert len(distractors)==3, word
    options=[zh]+distractors;rng.shuffle(options)
    questions.append(dict(id=f'v{i:03}',skill=0,level=level,word=word,kind=kind,text=sentence,zh=zh,prompt=f'在这句话里，{word} 是什么意思？',options=options,correct=options.index(zh),audio=f'audio/v{i:03}.mp3',explain=f'{word}：{zh}。'))

# Each report is a self-contained original scene, not a copied test item.
READS=[
(0,0,'The red team is on the main road. They run toward our gate. No one stays behind the trees. They want to get here fast.','红队在主路上，正跑向营门，没有人在树林后停留。他们想迅速抵达。'),
(0,1,'The guards stop beside a stone wall. They put their shields in front of them. They do not follow our scout. They plan to wait here.','卫兵在石墙边停下，把盾牌放在身前，没有追赶侦察兵。他们打算在这里等待。'),
(0,2,'The front road is empty. We see two riders near the trees on our left. They are moving around the camp. Watch the side path.','正面道路空了。两名骑手出现在左侧树林附近，正绕着营地移动。留意侧路。'),
(0,0,'A horn sounds near the river. The other team leaves its safe place. All of them move straight toward us. Their leader wants a quick fight.','河边响起号角。对方离开安全位置，全部径直向我们移动，领队想速战速决。'),
(0,1,'It is quiet at the old gate. The other team has food and water there. They sit behind their shields. They are not coming out yet.','旧门处很安静。对方备有食物和水，待在盾后，暂时不打算出来。'),
(0,2,'Our scout finds fresh tracks beside the river. The tracks go around the wall, not through the gate. Someone wants to reach us from the side.','侦察兵发现河边有新足迹，足迹绕过城墙，没有穿过大门。有人想从侧面接近。'),
(0,0,'The captain points at our camp. Her team picks up its weapons and leaves the hill. They take the shortest road. They will meet us from the front.','队长指向营地。队员拿起武器离开山坡，走最短的路，要从正面与我们交战。'),
(0,1,'The bridge is narrow. The other team stays at the far end. They build a small wall from old boxes. They want us to come to them.','桥很窄。对方留在远端，用旧箱子垒起矮墙，等我们过去。'),
(0,2,'A bird flies up from the right-hand woods. Then we see a blue flag there. Most of the other team has left the main road. They are taking a side route.','右侧树林惊起飞鸟，随后出现一面蓝旗。对方大部离开主路，走了侧路。'),
(1,0,'The guards have been waiting all morning, but their captain is losing patience. He orders them to leave the wooden fence and take the direct route to our camp. They carry light equipment so that they can reach us quickly.','卫兵等了一上午，队长渐渐失去耐心。他命令大家离开木栅栏，沿直路赶来，轻装行动以求快速接近。'),
(1,1,'Our scout waves a flag from the hill, hoping to draw the other team forward. They notice it but remain behind the broken cart. Their leader checks the shields and tells everyone to protect the narrow entrance.','侦察兵挥旗试图引对手前进。对方看到了，却仍待在坏车后。领队检查盾牌，吩咐守住狭窄入口。'),
(1,2,'The main path looks quiet, although we can hear footsteps beyond the garden. A traveler reports that several guards borrowed a small boat. They plan to cross the stream and approach our camp from the west.','主路安静，但菜园外能听到脚步。旅人说几名卫兵借了小船，准备渡溪从西侧接近营地。'),
(1,0,'Rain is starting to fall, and the other team does not want a long battle. Their captain sends everyone down the middle of the valley. They leave their spare supplies on the hill and aim to break through before the weather gets worse.','雨开始落下，对方不愿久战。队长让全队走谷地中央，把备用补给留在山坡，力图在天气恶化前突破。'),
(1,1,'The workers have placed heavy logs across the road. Behind them, the opposing team is preparing a safe position. Instead of chasing our riders, they share water and wait. Their plan depends on making us attack first.','工人把重木横在路上，对方在后面准备安全阵地。他们不追骑手，分水等待，计划让我们先攻。'),
(1,2,'We expected the other team to use the bridge. Instead, they are following a narrow track behind the houses. The track reaches the back of our camp. Only one guard remains near the bridge to keep our attention there.','我们原以为对方会走桥，他们却沿房屋后的窄路走向营地后方，只留一名卫兵在桥边吸引注意。'),
(1,0,'A messenger tells us that the captain has changed her plan. She no longer wants to wait for extra supplies. Her team forms a line on the main road and moves directly toward our position. Speed is now her priority.','信使说队长改了计划，不再等补给。她的队伍在主路列队，径直赶来，现在速度优先。'),
(1,1,'The opposing team reaches a low wall before sunset. Their scout suggests following us, but the leader refuses. They repair a gap in the wall and prepare to spend the night there. The position is easy to defend.','对方日落前到达矮墙。侦察兵提议追赶，领队拒绝，修补墙缝准备过夜。这个位置易守。'),
(1,2,'The front gate is still watched, but most of the footsteps are moving away from it. Our scout sees the team turning into an orchard. They can use that route to appear beside our supply cart without crossing the open road.','正门仍有人盯着，大部分脚步却远离了它。侦察兵看见队伍拐入果园，可借此接近补给车侧面，避开开阔道路。'),
(2,0,'The opposing captain knows that our supplies will arrive by evening. If she waits, our position will become stronger. She therefore abandons the shelter of the ruined mill and orders a rapid advance along the open road. Her scouts stay close to the main group rather than searching for another route.','对方队长知道我们的补给傍晚到达，拖延会让我们更强。因此她放弃旧磨坊的掩护，下令沿开阔道路迅速前进，侦察兵紧跟主队，没有寻找别的路线。'),
(2,1,'Our riders have made several attempts to attract attention near the stream. The opposing commander refuses to follow them. He has limited supplies, but his stone position offers excellent protection. For the moment, he prefers to maintain that advantage and force us to cross the exposed ground ourselves.','我方骑手数次在溪边诱敌，对方指挥官拒绝追击。虽然补给有限，石质阵地提供了良好保护。他宁愿守住优势，让我们自行穿越暴露地带。'),
(2,2,'A small group is making considerable noise near the front gate. Meanwhile, our second scout reports movement behind the eastern ridge. The commander appears to be using the noisy group to hold our attention while the larger force takes a longer but less exposed route toward our right side.','小队在正门制造噪声，同时另一名侦察兵发现东侧山脊后的动静。指挥官似乎借小队吸引注意，让主力走更长但较隐蔽的路线接近右侧。'),
(2,0,'The weather forecast gives the other team only a brief opportunity to cross the valley. Their commander considers a sheltered route, then rejects it because it would take too long. The entire group leaves cover and advances toward our central position before the rain can turn the road into mud.','天气只给对方短暂的穿谷机会。指挥官因耗时太久放弃隐蔽路线，全队离开掩体，赶在雨把路变成泥潭前直进我方中央。'),
(2,1,'The defenders have enough food to remain where they are, and they know our team must eventually pass through the gate. Although several younger guards want to pursue us, the captain keeps them behind the reinforced barrier. She intends to let the difficult ground do part of the work.','守军粮食充足，也知道我们终将通过大门。尽管年轻卫兵想追击，队长仍将其留在加固屏障后，准备利用地形。'),
(2,2,'The bridge seems like the obvious approach, which is exactly why the opposing captain avoids it. She sends two guards there as a distraction, while the rest follow a shallow channel hidden by reeds. That channel joins the road just behind our position, where we have fewer supplies and less cover.','桥是明显的接近路线，因此对方反而避开它。两名卫兵在桥上佯动，其余沿芦苇遮住的浅渠行进，浅渠通向我方后侧，那里补给和掩护较少。'),
(2,0,'The opposing team has discovered that our central barrier is still under repair. Their captain decides that waiting would waste this advantage. Rather than dividing the group, she gathers everyone on the main track and commits to an immediate attack on the unfinished entrance.','对方发现我方中央屏障尚在修缮，队长认为不能错失机会。她不分兵，将全队集中在主路，立即进攻未完工入口。'),
(2,1,'Our scout reports that the other team has stopped beside the abandoned storehouse. They are reinforcing the doors and moving their supplies inside. A few riders appear ready to chase us, but the commander calls them back. His priority is to hold a reliable position rather than gain ground quickly.','对方停在旧仓库旁，加固门并搬入补给。几名骑手想追来，却被叫回。指挥官优先守住可靠阵地，不急于抢地。'),
(2,2,'The opposing commander has watched us strengthen the front entrance all morning. She knows that another direct attempt would be costly. After leaving a visible flag near the main road, she leads the greater part of her team through a dry riverbed toward the unguarded side of the camp.','对方指挥官看我们加固正门一上午，知道再次直攻代价很高。她在主路留一面显眼旗帜，带大部沿干河床接近无人把守的侧面。'),
(3,0,'The scouts initially interpreted the quiet road as evidence of a withdrawal. A subsequent report, however, mentions that the opposing commander has abandoned all reserve positions and concentrated her forces at the valley entrance. Given that her supplies are running low and our reinforcements are expected tomorrow, she appears willing to accept immediate losses in exchange for a decisive breakthrough at the center.','侦察兵起初把安静道路当成撤退证据，但后续报告说对方放弃预备阵地，将兵力集中在谷口。鉴于其补给不足、我方援军明日抵达，她似乎愿意承受眼前损失，以换取中央决定性突破。'),
(3,1,'Several banners have appeared beyond the wall, creating the impression that the defenders are preparing to advance. Yet no supply carts have left the courtyard, and workers continue to reinforce the entrance. The more plausible interpretation is that the movement is intended to discourage our approach while the commander preserves her defensive advantage. She has little incentive to abandon such a reliable position.','墙外旗帜让人以为守军准备前进，但补给车未出院落，工人还在加固入口。更合理的解释是，这些动作旨在阻止我们靠近，同时保住防御优势。她没有多少理由放弃可靠阵地。'),
(3,2,'The message describes a deliberate increase in activity at the main gate, but it also notes that most experienced riders are absent from that position. Tracks recently discovered behind the orchard suggest an alternative approach. Taken together, these details imply that the visible activity is a diversion, allowing the main force to exploit the less protected route along our flank.','正门活动有意增加，但老练骑手大多不在场。果园后的新足迹暗示另一条路线。综合来看，显眼活动用于诱导注意，让主力利用我方侧翼较少保护的通路。'),
(3,0,'The commander has rejected two proposals that would have preserved her forces: waiting for additional supplies and circling through the northern woods. Both options would delay the encounter, allowing our engineers to finish the central defenses. Her remaining decision is therefore consistent with a rapid frontal commitment, despite the risk of exposing the group on open ground.','指挥官拒绝了等补给和绕北林两种保全兵力的方案，因为两者都会拖延，让我方工兵完成中央防御。因此剩下的决策指向快速正面投入，尽管全队有暴露于开阔地的风险。'),
(3,1,'A captured schedule indicates that the opposing team has arranged regular food deliveries to its current position for the next three days. Although individual riders occasionally emerge to provoke a response, there is no evidence of preparations for a sustained advance. The logistics are more consistent with holding the existing barrier and encouraging us to exhaust ourselves against it.','一份日程显示，对方已为现阵地安排未来三天的固定送粮。虽有骑手出来挑衅，却无持续推进准备。后勤安排更符合守住现有屏障、诱使我方消耗力量的打算。'),
(3,2,'The opposing leader has repeatedly emphasized the importance of the central bridge in messages that could easily be intercepted. Meanwhile, supplies have quietly been transferred to the western bank, where a narrow trail reaches our rear. The discrepancy suggests that her public emphasis is meant to conceal the actual approach rather than reveal it. The less visible movement deserves greater attention.','对方反复在易被截获的信息中强调中央桥梁，同时补给却悄悄转向西岸，那里的窄路通往我方后方。这种不一致提示公开强调是在掩盖真实路线，应更注意不显眼的动向。'),
(3,0,'The latest report contradicts the assumption that the enemy will conserve its strength. Reserve units are joining the central formation, while equipment that would slow their movement has been left behind. Combined with the approaching storm, which will soon make the main road impassable, these preparations point toward an attempt to force a direct engagement within the remaining window.','最新报告与对方将保留实力的假设矛盾。预备队加入中央队形，拖慢速度的装备被丢下。风暴将使主路无法通行，这些准备指向在窗口关闭前强行正面接战。'),
(3,1,'Our repeated retreats have failed to draw the commander out of the old fort. Her refusal is not necessarily hesitation: the fort controls the only reliable source of water, and leaving it would surrender that advantage. The additional shields now being carried inside reinforce the inference that she intends to make us approach on her terms.','多次后退都未诱出旧堡指挥官。这未必是犹豫，因为堡垒控制唯一可靠水源，离开就会放弃优势。新增盾牌被搬入，进一步支持她要我们按其条件靠近的推断。'),
(3,2,'The front line remains conspicuous, yet its movements have become unusually repetitive. A second observer reports that the supply trail has shifted toward a concealed passage around the hill. This combination is consistent with a small force sustaining the appearance of a direct confrontation while the principal group moves to a position from which it can threaten our side.','正面队伍依然显眼，动作却异常重复。另一个观察者报告补给路线转向绕山的隐蔽通道。这符合小部队维持正面对峙表象、主力转向威胁我方侧面的情况。')
]
labels=['正面突击','原地固守','侧翼迂回']
for i,(level,signal,text,zh) in enumerate(READS):
    opts=labels.copy();rng.shuffle(opts)
    questions.append(dict(id=f'r{i:03}',skill=1,level=level,signal=signal,title='前线侦察记录',text=text,zh=zh,prompt='根据这份报告，侦察时对方主要在做什么？',options=opts,correct=opts.index(labels[signal]),explain=zh+'\n这是侦察时的动向；交锋前对手仍可能变招。'))

# Some checks ask about causes and details; recognizing three military keywords
# alone must not be enough to pass every reading task.
DETAILS={
3:('对方领队希望这场战斗怎样进行？',['快速打完','一直等到明天','完全避免交战']),
6:('队伍选择了哪条路？',['最短的路','河流另一岸的路','最隐蔽的长路']),
8:('蓝旗出现在哪里？',['右侧树林里','营地中央','旧桥下方']),
9:('队长为什么不再继续等候？',['他已经失去耐心','轻装装备还没有送到','他想等我方先主动出击']),
10:('我方侦察兵挥旗的目的是什么？',['引对方离开阵地前进','召回我方正在渡河的骑手','示意对方从侧路绕行']),
11:('几名卫兵借用了什么？',['一条小船','一辆马车','一套修桥工具']),
13:('对方为什么不追我方骑手？',['希望让我们先发起进攻','准备沿侧路主动出击','急着在天黑前渡河']),
15:('队长决定不再等待什么？',['额外补给','我方的投降消息','侧路侦察兵的返回']),
17:('果园路线能帮助对方做到什么？',['避开开阔道路，接近补给车侧面','从正门直接穿过开阔道路','让全队留在原地守桥']),
18:('对方为什么不愿等到傍晚？',['我方补给将到达，阵地会更强','他们的援军到时会先发起进攻','磨坊会在傍晚停止提供掩护']),
19:('指挥官看重现有位置的什么优势？',['石质阵地提供良好保护','原地有充足补给可长期使用','从这里能更快追上我方骑手']),
21:('更隐蔽的路线为什么被放弃？',['走那条路会花太长时间','那条路比中央路线更加暴露','指挥官希望等雨停以后再走']),
23:('留在桥边的两名卫兵主要有什么作用？',['吸引我方注意','保护正在桥上转移的主力','为浅水道寻找新的入口']),
25:('指挥官的优先事项是什么？',['守住可靠位置','尽快追上我方骑手','立即离开整个河谷']),
27:('哪些情况使对方愿意立即冒险？',['补给不足，而我方援军明日到达','我方补给不足，而对方援军明日到达','对方补给将到达，主力准备继续等待']),
28:('什么细节不支持“对方即将前进”的表象？',['补给车未离开，工人还在加固入口','墙外出现了旗帜','我方能看见部分守军']),
30:('等待和绕路两种方案有什么共同问题？',['都会给我方完成防御的时间','都会让对方立即暴露在开阔地上','都会让对方更快到达中央入口']),
31:('三天的固定送粮安排更支持哪种判断？',['对方打算留在当前阵地','对方正在完全撤离当前阵地','对方已准备立即持续向前推进']),
33:('对方为什么丢下部分装备？',['避免这些装备拖慢移动','把装备留给即将到来的我方援军','利用这些装备长期加固原阵地']),
35:('主力转移时，显眼的小部队在做什么？',['维持正面对峙的表象','带领主力沿正面路线突破','放弃正面对峙并全部转向侧面'])
}
for idx,(prompt,answers) in DETAILS.items():
    q=next(x for x in questions if x['id']==f'r{idx:03}')
    ordered=answers.copy();rng.shuffle(ordered);q['prompt']=prompt;q['options']=ordered;q['correct']=ordered.index(answers[0])

LISTENS=[
(0,0,'They are coming down the main road. Get ready at the gate.','他们正沿主路赶来，在门口做好准备。'),
(0,1,'They have stopped behind the wall. They are waiting for us.','他们停在墙后，正在等我们。'),
(0,2,'Look to your left. They are moving through the trees.','看左侧，他们正在树林里移动。'),
(0,0,'The whole team is running straight toward our camp.','全队正径直跑向营地。'),
(0,1,'Their shields are up. No one is leaving the old bridge.','他们举起了盾，没有人离开旧桥。'),
(0,2,'The main road is empty. They are taking the path on our right.','主路空了，他们正走我们右侧的小道。'),
(1,0,'The captain does not want to wait. She is bringing everyone down the center.','队长不想等了，正带全队沿中央前进。'),
(1,1,'They noticed our scout, but they did not follow him. They are staying behind the fence.','他们发现侦察兵却没有追，仍待在栅栏后。'),
(1,2,'Two guards are watching the bridge. The others are going around the hill to our left.','两名卫兵盯着桥，其余正绕山到我们的左侧。'),
(1,0,'They have left their supplies behind so they can move faster. Expect a direct attack.','他们丢下补给以便加速，预计会直接进攻。'),
(1,1,'The other team is repairing the barrier. It looks like they want us to attack first.','对方正在修屏障，看起来想让我们先攻。'),
(1,2,'Keep watching the side road. Their riders have crossed the river behind the garden.','继续留意侧路，他们的骑手已在菜园后渡河。'),
(2,0,'The commander has abandoned the safer route. She is concentrating the entire group at the center for a quick breakthrough.','指挥官放弃了更安全的路线，将全队集中在中央寻求快速突破。'),
(2,1,'Our attempt to draw them out has failed. They remain in cover and continue to reinforce their position.','诱敌失败了，他们留在掩体中，继续加固阵地。'),
(2,2,'The noise at the gate is a distraction. Most of their team is following the dry stream toward our right flank.','门口的噪声用来分散注意，主力正沿干溪向我方右翼行进。'),
(2,0,'They know our supplies will arrive tonight. Rather than give us time to prepare, they are advancing along the main road now.','他们知道补给今晚到达，不愿给我们准备时间，现在正沿主路前进。'),
(2,1,'Although their riders look ready to move, the commander has ordered them to hold the narrow entrance and wait.','骑手虽看似准备移动，指挥官却命令他们守住窄入口等待。'),
(2,2,'Only a small group remains in sight. Fresh tracks suggest the others have taken the longer route behind our camp.','视野中只剩小队，新足迹表明其余人走了营地后方的长路。'),
(3,0,'Despite earlier reports of a possible withdrawal, their reserve units are joining the central formation. A direct commitment now seems the most plausible interpretation.','虽先前有可能撤退的报告，预备队却正加入中央队形。现在正面投入是最合理的解释。'),
(3,1,'Their repeated movements outside the wall appear intended to provoke us. The supplies and reinforced doors suggest they plan to retain their defensive advantage.','墙外反复的动作像是挑衅，补给和加固的门表明他们打算保留防御优势。'),
(3,2,'Only a small force remains near the bridge. Meanwhile, equipment is being transferred along the concealed western trail, consistent with an attempt to reach our side.','只有少量兵力留在桥边，装备同时沿隐蔽西路转移，符合接近我方侧面的企图。'),
(3,0,'Their commander has rejected any further delay. Equipment that might slow the group has been discarded, and every unit is now approaching through the central valley.','指挥官拒绝继续拖延，拖慢速度的装备已丢弃，全部队伍正从中央谷地接近。'),
(3,1,'The apparent hesitation may be deliberate. Their current position controls the water supply, so abandoning it would sacrifice their most reliable advantage.','表面上的犹豫可能是有意的，现阵地控制水源，放弃它就会失去最可靠的优势。'),
(3,2,'The emphasis on the main bridge conflicts with the latest supply movements. Those movements indicate that the principal force is circling toward our less protected flank.','对主桥的强调与最新补给动向矛盾，后者表明主力正绕向我方保护较少的侧翼。')
]
for i,(level,signal,text,zh) in enumerate(LISTENS):
    opts=labels.copy();rng.shuffle(opts)
    questions.append(dict(id=f'l{i:03}',skill=2,level=level,signal=signal,title='斥候来讯',text=text,zh=zh,prompt='先听消息：对方的主要动向是什么？',options=opts,correct=opts.index(labels[signal]),audio=f'audio/l{i:03}.mp3',explain=zh))

ORDERS=[
(0,0,'They are coming toward the gate.','他们正向大门而来。'),(0,1,'They are waiting behind the wall.','他们正在墙后等待。'),(0,2,'They are moving around our camp.','他们正在绕着营地移动。'),
(0,0,'The riders are taking the main road.','骑手正走主路。'),(0,1,'The guards will stay at the bridge.','卫兵将留在桥边。'),(0,2,'Their team is turning to the left.','他们的队伍正转向左侧。'),
(1,0,'They plan to attack before the rain starts.','他们计划在下雨前进攻。'),(1,1,'Their captain wants them to defend the gate.','他们的队长想让他们守住大门。'),(1,2,'They are using the trees to hide their approach.','他们正利用树木隐蔽接近。'),
(1,0,'They have decided to advance along the main road.','他们已决定沿主路前进。'),(1,1,'They will remain behind the wall until we approach.','他们将留在墙后直到我们靠近。'),(1,2,'Most of their team is crossing the river on our right.','他们大部分队员正在我们右侧渡河。'),
(2,0,'Rather than wait for supplies, they intend to attack immediately.','他们打算立即进攻，不再等待补给。（以 Rather 开头）'),(2,1,'Although the gate is open, they refuse to leave their position.','虽然大门开着，他们仍拒绝离开阵地。（以 Although 开头）'),(2,2,'They are circling the hill in order to reach our flank.','他们正绕山行进，以便接近我方侧翼。'),
(2,0,'The commander has ordered a rapid advance through the center.','指挥官已下令从中央迅速推进。'),(2,1,'Their supplies allow them to maintain a defensive position.','补给使他们能够保持防御阵地。'),(2,2,'While the guards distract us, the riders approach from the side.','卫兵分散我们注意时，骑手从侧面接近。（以 While 开头）'),
(3,0,'Their decision to abandon cover suggests an imminent frontal attack.','他们放弃掩护的决定暗示正面进攻迫在眉睫。'),(3,1,'The reinforced entrance indicates that they intend to preserve their advantage.','加固的入口表明他们打算保住优势。'),(3,2,'The visible activity is intended to conceal their approach along our flank.','显眼的活动意在掩盖他们沿我方侧翼接近的行动。'),
(3,0,'Despite the risk of exposure, they have committed to a direct advance.','尽管有暴露风险，他们已经决定直接推进。（以 Despite 开头）'),(3,1,'They are reluctant to surrender a position that controls the water supply.','他们不愿放弃控制水源的阵地。'),(3,2,'Their movements are consistent with an attempt to exploit our unprotected side.','他们的动向符合利用我方无防护侧面的企图。')
]
for i,(level,signal,text,zh) in enumerate(ORDERS):
    tokens=text.split();shuffled=tokens.copy();rng.shuffle(shuffled)
    questions.append(dict(id=f'o{i:03}',skill=3,level=level,signal=signal,title='整理侦察报告',text=text,zh=zh,prompt='把词块排成这句报告。标点留在原词块上。',tokens=shuffled,explain=zh,options=[],alternatives=[]))
ORDER_VARIANTS={
0:['Toward the gate they are coming.'],1:['Behind the wall they are waiting.'],
4:['At the bridge the guards will stay.'],10:['Until we approach they will remain behind the wall.'],
12:['Rather than wait for supplies they intend immediately to attack.'],
14:['In order to reach our flank they are circling the hill.'],
17:['The riders approach from the side while the guards distract us.'],
21:['They have committed to a direct advance despite the risk of exposure.']}
for index,variants in ORDER_VARIANTS.items():
    next(q for q in questions if q['id']==f'o{index:03}')['alternatives']=variants

# Reading room: general English beyond battle vocabulary. Parallel length versions.
LETTERS=[
('一张留给后来者的地图',
'A traveler leaves a map at our camp. It shows where to find clean water, not where to find gold. "The next person may be tired," she says. We put the map near the door so everyone can use it.',
'When Mara arrived, she asked for neither a bed nor a meal. She wanted a pencil. Her old map showed the hills clearly, but it said nothing about the places where a tired traveler could find clean water. She spent the evening adding those details. Before leaving, she placed the map beside the door. "A useful map tells people what they need," she said, "not just what is there." We have kept a pencil beside it ever since.',
'旅人补充了地图上的水源，留在门边给后来者使用。地图有用之处在于满足人的实际需要。','她主要补充了什么？',['寻找饮水的地点','藏黄金的地点','敌军的数量'],0),
('第一顿共同的晚饭',
'We have only one large pot, but six people want to cook. At first, everyone talks at once. Then we choose one simple dish. Two people cut vegetables, two bring water, and the others make a fire. Dinner is late, but nobody eats alone.',
'The first shared dinner nearly failed before anyone lit the fire. Six people had six recipes and only one pot. Arguing about the best dish took longer than preparing it would have. Finally, Jin suggested that they choose a meal everyone could help make. It was not anyone\'s favorite, but it gave each person a useful task. By the time they sat down, the food was almost beside the point: the strangers had learned how to work together.',
'大家一开始争论菜谱，后来选择人人都能参与的一道菜。共同完成比选出最完美的菜更重要。','让晚饭顺利进行的改变是什么？',['分工做一道共同的菜','购买六个新锅','让一个人做完所有工作'],0),
('会休息的菜园',
'The garden looks empty today. We picked the last vegetables yesterday. Our neighbor says the soil needs time to rest. We cover it with leaves instead of planting again at once. An empty field can still be part of a good plan.',
'After the harvest, I wanted to plant every empty patch immediately. A garden full of green leaves seemed more successful than bare soil. Our neighbor disagreed. She explained that the previous crop had used many of the nutrients that the next one would need. We covered part of the ground with fallen leaves and left it alone. For a while, progress looked like doing less. The following season helped me understand why waiting had been part of the work.',
'收获后给土壤休养的时间。暂时空着并不等于计划失败。','为什么暂时不立即再种？',['让土壤恢复','因为大家不再需要食物','为了把菜园改成道路'],0),
('走慢一点的快路',
'There are two roads to the village. The short road has deep mud. The longer one is dry. We choose the dry road and arrive before the other cart. Distance is not the only thing that makes a journey long.',
'The driver was embarrassed to choose the longer road. On the map, it looked like an unnecessary detour, and the other travelers laughed when he turned away from the shortcut. But the recent rain had changed the calculation. While the first cart struggled through deep mud, ours kept moving at a steady pace. We reached the village with daylight to spare. The experience reminded us that the shortest route on paper is not always the quickest route in practice.',
'雨后捷径泥泞，较长的干路反而更快。判断不能只看地图距离。','较长的路为什么更快？',['路面干燥，能持续前进','马匹会飞','地图把距离写反了'],0),
('一次没被嘲笑的错误',
'I use the wrong English word when I ask for a bowl. My friend looks confused, then shows me the word I need. We laugh together. Later, I use it again without help. The mistake becomes a small part of a real conversation.',
'I had practiced the sentence in my head, yet the wrong word came out when I finally spoke. For a moment, I considered pretending that I had meant something else. My friend simply picked up a bowl and said its name. There was no test to fail and no score to lose. Later that evening, I needed the same word again. This time it arrived more easily. What I remembered was not a rule on a page, but the moment when someone understood me.',
'说错单词后，朋友用实物帮助理解。真实语境中的再次使用，让词更容易被想起。','后来单词更容易想起，与什么有关？',['在真实情境中再次使用','把错误完全藏起来','从此不再说话'],0),
('借来的工具',
'Our hammer breaks, so we borrow one from the next camp. We return it the following day. A week later, they ask for our saw. Soon we build a small shelf for shared tools. We do not need to own everything ourselves.',
'At first, every household planned to buy a complete set of tools. The cost was high, and most tools would have remained unused for weeks. A broken hammer led to a different arrangement. After borrowing a replacement, we began keeping a list of what each neighbor could share. There were occasional delays, and someone had to maintain the list, but the system gave everyone access to more equipment than they could have afforded alone.',
'邻里借工具逐渐发展为共享制度，付出一些协调成本，换来更丰富的可用工具。','共享工具的主要好处是什么？',['能使用各家不必单独买齐的工具','从此工具不会损坏','不需要任何协调'],0),
('没有数字的进步',
'Last month, I could not read the notice at the gate. Today, I understand most of it. There is no prize, and nobody is watching. I still stop for a moment and smile. Something that once blocked my way has become useful.',
'The notice had been on the gate for weeks. On my first visit, its long sentences had looked like a wall of unfamiliar shapes. I took a photograph and forgot about it. When I returned, I could follow the main message without opening a dictionary. I still missed two details, but the difference was real. No level appeared above my head. The reward was that a piece of the world had become easier to understand.',
'真正的变化是原本难懂的告示现在能读懂大意，不一定需要外部奖品来证明。','文中进步体现在哪里？',['更能读懂同一则告示','获得一个新皮肤','告示被换成中文'],0),
('雨天的来信',
'A letter arrives after three days of rain. Our friend cannot visit this week because the river is too high. She sends a story instead. We read it together by the fire. The visit is delayed, but the friendship is not.',
'We had prepared an extra bed before the rain began. Three days later, a messenger arrived with a letter explaining that the river was no longer safe to cross. Our friend apologized for changing the plan and included a story from her own village. We read it aloud after dinner. The empty bed still reminded us of the visit we had expected, but the letter gave us something different to share. A postponed plan did not have to become a lost connection.',
'河水过高使拜访延期，朋友寄来故事，让联系得以继续。','朋友没能来访的直接原因是什么？',['河水过高，渡河不安全','不想再联系','营地没有准备床'],0),
('修好的旧门',
'The hall has a new roof and new windows. We keep the old front door. It is not perfect, but many visitors wrote their names on it. The building is better now, and it still remembers the people who helped us begin.',
'During the repairs, someone suggested replacing the old front door. A new one would fit the frame more neatly and keep out a little more wind. Yet the old wood carried the names of nearly everyone who had helped establish the camp. We repaired its weakest parts and kept it. The decision was a small compromise between efficiency and memory. Improving a place did not require removing every sign of the work that had made it possible.',
'旧门留着建设者的名字。修补而保留它，是效率与记忆之间的取舍。','大家为什么保留旧门？',['它记录了参与建设的人','它完全没有缺点','没有任何木材'],0),
('一次只改一个地方',
'Our bread is too hard. We change the flour, the water, and the cooking time. The next loaf is better, but we do not know why. After that, we change only one thing each time. Learning becomes slower to start and easier to trust.',
'The first successful loaf caused an argument. One cook credited the new flour, another the extra water, and a third the shorter baking time. Because we had changed everything at once, none of us had convincing evidence. For the next few attempts, we kept careful notes and changed one part of the recipe at a time. This approach felt less exciting than trying a completely new recipe, but it gave us knowledge that could be used again.',
'同时改许多因素会难以判断原因，一次改变一个因素更便于获得可靠经验。','为什么后来一次只改一个因素？',['更容易判断是什么造成变化','保证每次都成功','避免记录任何数据'],0),
('够用的一天',
'The roof is repaired. There is food for dinner and wood for the fire. We could keep working, but we choose to stop. Tomorrow has its own tasks. Tonight, we sit outside and enjoy the place we have made.',
'By late afternoon, the final leak had been fixed. Someone pointed out that the fence could still be straighter and the shelves could still be larger. Those observations were true, but they did not make the day incomplete. We had finished what we set out to do. Instead of opening another project immediately, we carried our chairs into the yard. For once, the camp was not a list of future improvements. It was a place where we could live.',
'仍有能改进的地方，不影响今天的目标已经完成。建设成果也值得被使用和享受。','为什么大家决定休息？',['当天约定的目标已完成','所有事物都已完美','他们决定永久放弃营地'],0),
('第一辆经过的商车',
'The bridge is ready. A cart crosses it slowly, carrying books, cloth, and tea. The driver stops to thank us. Until today, the bridge was our project. Now it is part of someone else\'s journey. We watch the cart disappear down the road.',
'We had spent so much time measuring, carrying, and repairing that the bridge had become a collection of tasks in our minds. Then the first cart arrived. Its driver knew nothing about the arguments over the design or the afternoon when a wheel had broken. He simply crossed the river, stopped to thank us, and continued toward the next village. Watching him leave changed the meaning of the work. The bridge was finished, and its usefulness had only just begun.',
'第一辆商车通过后，桥从建设任务变成真正帮助他人的道路。工程完成，价值开始兑现。','商车通过使大家意识到什么？',['桥的价值在实际使用中体现','必须立即拆桥重建','只有建造过程有意义'],0)
]
for i,(title,easy,hard,zh,prompt,opts,correct) in enumerate(LETTERS):
    for version,text in enumerate([easy,hard]):
        order=list(range(len(opts)));rng.shuffle(order)
        stories.append(dict(id=f's{i:02}_{version}',skill=1,level=version*2,title=title,text=text,zh=zh,prompt=prompt,options=[opts[j] for j in order],correct=order.index(correct),explain=zh,audio=f'audio/s{i:02}_{version}.mp3'))

OUT.mkdir(parents=True,exist_ok=True)
from visits import VISITS
visits=[]
for i,(title,easy,long,zh,options,choices_zh,outcomes) in enumerate(VISITS):
    for version,text in enumerate([easy,long]):
        visits.append(dict(id=f'e{i:02}_{version}',event=i,skill=1,level=version*2,title=title,text=text,zh=zh,prompt='按你的下一步计划选择，没有标准答案。',options=options,correct=-1,choicesZh=choices_zh,outcomes=outcomes,audio=f'audio/e{i:02}_{version}.mp3'))
parser=argparse.ArgumentParser(description='Rebuild authored content; reuse bundled dictionary when full ECDICT is unavailable.')
parser.add_argument('--ecdict', type=Path, help='Optional full ECDICT CSV')
parser.add_argument('--reuse-dictionary', action='store_true')
args=parser.parse_args()
corpus=args.ecdict or ROOT.parent/'research/ecdict.csv'
db_path=OUT/'dictionary.db'
dictionary={};inflections={};needed=set()
for q in questions+stories+visits: needed.update(re.findall(r"[a-z]+(?:'[a-z]+)?",q['text'].lower()))
if corpus.exists() and not args.reuse_dictionary:
    with corpus.open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            w=row['word'].lower();ranks=[int(row[k]) for k in ['bnc','frq'] if row[k].isdigit() and int(row[k])>0]
            if not re.fullmatch(r"[a-z]+(?:[-'][a-z]+)?",w):continue
            if w in needed or (ranks and min(ranks)<=12000):
                meaning=row['translation'].replace('\\n','\n')
                if meaning:dictionary[w]={'zh':meaning,'phonetic':row['phonetic']}
                for piece in row['exchange'].split('/'):
                    if ':' in piece:
                        k,form=piece.split(':',1)
                        if k!='0' and re.fullmatch('[a-z]+',form):inflections.setdefault(form,w)
    for form,base in inflections.items():
        if form not in dictionary and base in dictionary:dictionary[form]={'zh':base+' 的词形\n'+dictionary[base]['zh'],'phonetic':''}
    for _,w,zh,_ in word_rows:
        if w not in dictionary:dictionary[w]={'zh':zh,'phonetic':''}
    dictionary.update({"anyone's":{'zh':'anyone 的所有格：任何人的','phonetic':''},"else's":{'zh':"所有格词形。与 someone 等连用，如 someone else's journey：别人的旅程。",'phonetic':''},'right-hand':{'zh':'右侧的；右手的','phonetic':''}})
    if db_path.exists():db_path.unlink()
    with sqlite3.connect(db_path) as db:
        db.execute('CREATE TABLE words(word TEXT PRIMARY KEY, zh TEXT NOT NULL, phonetic TEXT NOT NULL) WITHOUT ROWID')
        db.executemany('INSERT INTO words VALUES(?,?,?)',[(w,d['zh'],d['phonetic']) for w,d in dictionary.items()])
        db.commit()
elif db_path.exists():
    with sqlite3.connect(db_path) as db:
        dictionary={w:{'zh':zh,'phonetic':p} for w,zh,p in db.execute('SELECT word,zh,phonetic FROM words')}
else:
    raise SystemExit('Restore bundled dictionary.db or pass --ecdict PATH to the full ECDICT CSV.')
import hashlib
dictionary_version=hashlib.sha256(db_path.read_bytes()).hexdigest()[:12]
(OUT/'content.json').write_text(json.dumps(dict(questions=questions,stories=stories,visits=visits,dictionaryCount=len(dictionary),dictionaryVersion=dictionary_version),ensure_ascii=False,indent=2),encoding='utf-8')
old_dictionary=OUT/'dictionary.json'
if old_dictionary.exists():old_dictionary.unlink()
license_source=ROOT.parent/'research/ECDICT-LICENSE.txt'
if license_source.exists():shutil.copy(license_source,OUT/'ECDICT-LICENSE.txt')
elif not (OUT/'ECDICT-LICENSE.txt').exists():raise SystemExit('Missing bundled ECDICT-LICENSE.txt')
audio=[{'id':q['id'],'path':q['audio'],'text':(q.get('word','')+'. ' if q['skill']==0 else '')+q['text']} for q in questions+stories+visits if q.get('audio')]
(ROOT/'tools/audio-manifest.json').write_text(json.dumps(audio,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'questions':len(questions),'vocabulary':len(word_rows),'read_reports':len(READS),'listening':len(LISTENS),'orders':len(ORDERS),'stories':len(stories),'dictionary_entries':len(dictionary),'audio_assets':len(audio)},ensure_ascii=True))
