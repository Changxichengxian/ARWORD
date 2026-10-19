"""Five reusable work notes for the finite expansion chapters."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
rows=[
 dict(title='把岸边接起来',focus=['expand','surface','gradual','distance'],
 short='We can expand the island beside the shore. Keep each new surface close to the old land. A gradual change leaves a short distance for the worker to cross.',
 text='We can expand the island beside the shore. Keep each new surface close to the old land. A gradual change leaves a short distance for the worker to cross. Start with the nearest section, then connect the next one. The trees can remain where they are. There is no need to clear the whole forest before making a path.',
 zh='沿岸逐步扩地，让新地面贴着旧陆地。先连接最近的一块，再接下一块；保留已有树木，不用先清空树林。',
 question='这次先接哪一块？',options=['紧挨岸边的那块','先接远处的那块','清完树林再接地'],correct=0,
 cue='Connect the nearest section first, and leave the trees beside the path.',cue_options=['先接近岸，留住路边树','先接远岸，留住路边树','先接近岸，清掉路边树'],cue_correct=0,
 sentence='Connect the nearest section to the shore.',sentence_zh='把最近的一块接到岸边。'),
 dict(title='第一批木板',focus=['efficient','surface','reduce','preserve'],
 short='The sawmill turns short logs into boards. Keep the surface clear and move one log at a time. This is efficient: it can reduce waste and preserve useful pieces.',
 text='The sawmill turns short logs into boards. Keep the surface clear and move one log at a time. This is efficient: it can reduce waste and preserve useful pieces. Put the finished boards beside the table, away from the moving blade. Later, the boards will form the cottage floor and the narrow path beside the water.',
 zh='锯木坊把原木切成木板。台面保持清空，一次送一根木头，减少浪费；成品放在台旁，远离锯片，用于地板和栈道。',
 question='木板切好后放哪里？',options=['台子旁，离锯片远些','台面上，紧挨锯片','和待切原木堆在一起'],correct=0,
 cue='Place the finished boards beside the table, away from the moving blade.',cue_options=['成品放台旁，远离锯片','成品放台上，靠近锯片','原木放台旁，暂停加工'],cue_correct=0,
 sentence='Keep the finished boards beside the table.',sentence_zh='把切好的木板放在台子旁。'),
 dict(title='石岸上的砖窑',focus=['gather','patient','retain','avoid'],
 short='Gather stone for the kiln base. The thick walls retain heat, but the front opening must remain clear. Be patient after firing. Avoid moving the bricks while they are hot.',
 text='Gather stone for the kiln base. The thick walls retain heat, but the front opening must remain clear. Be patient after firing. Avoid moving the bricks while they are hot. Leave a small space between each row so air can pass through. Once the bricks cool, carry them to the new garden wall and the windmill base.',
 zh='先收集石料搭窑基。厚墙保温，前面的开口要畅通，砖排之间留空隙。烧好后等砖冷却，再送去花园和风车。',
 question='刚烧好的砖应该怎么处理？',options=['原地冷却后再搬','立刻搬到花园去','堆紧后封住窑口'],correct=0,
 cue='Leave the front opening clear, and wait for the bricks to cool.',cue_options=['保持窑口畅通，等砖冷却','封住窑口，等砖冷却','保持窑口畅通，立即搬砖'],cue_correct=0,
 sentence='Let the bricks cool before moving them.',sentence_zh='搬动这些砖之前，先让它们冷却。'),
 dict(title='留一条可以走的路',focus=['allocate','adequate','choice','beyond'],
 short='The meadow has room for a garden and a path. Allocate adequate space between them. Our choice matters: the worker must still reach the small hill beyond the garden.',
 text='The meadow has room for a garden and a path. Allocate adequate space between them. Our choice matters: the worker must still reach the small hill beyond the garden. Put the new beds on one side instead of across the middle. Flowers can grow along the edge, while the open path connects the old shore to the new ground.',
 zh='草地要给花园和道路都留出空间。种植床放在一边，不要横断中间的路，让工人能穿过花园到后面的小丘。',
 question='种植床怎么摆更合适？',options=['靠一边，留出通路','横着摆满道路中间','先占满，再挪出通路'],correct=0,
 cue='Place the beds on one side, and keep the middle path open.',cue_options=['床靠一边，中间留路','床在中间，两侧留空','床靠一边，中间加床'],cue_correct=0,
 sentence='Keep a clear path beside the garden.',sentence_zh='在花园旁边留出一条畅通的路。'),
 dict(title='石缝里的晶簇',focus=['fragile','distinguish','preserve','notice'],
 short='Notice the pale crystals in the dark stone. Distinguish the loose pieces from the large cluster. The points are fragile, so preserve the cluster and collect the loose pieces first.',
 text='Notice the pale crystals in the dark stone. Distinguish the loose pieces from the large cluster. The points are fragile, so preserve the cluster and collect the loose pieces first. A heavy blow could break several points at once. Use a small tool near the base. Leave the tallest crystal as a bright feature of the new bay.',
 zh='观察深色岩石里的浅色晶体。先区分松散小块和大晶簇，优先采小块；尖端易碎，用小工具从根部操作，留下最高的一簇。',
 question='应该先采哪一部分？',options=['旁边松散的小块','最高晶簇的尖端','把整簇一口气敲碎'],correct=0,
 cue='Collect the loose pieces first, and leave the tallest crystal in place.',cue_options=['先采松散小块，保留最高晶簇','先采最高晶簇，留下松散小块','先敲碎整簇，再分拣小块'],cue_correct=0,
 sentence='Leave the tallest crystal beside the bay.',sentence_zh='把最高的一簇晶体留在小湾旁。')
]
for i,row in enumerate(rows):row.update(id=f'land{i:02}',site=[0,0,1,2,1][i])
(R/'assets/frontier_missions.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),'utf-8')
print('FRONTIER_NOTES',len(rows))
