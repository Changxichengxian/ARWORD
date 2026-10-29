"""Create a named static 600-weight subset for predictable Android text rendering."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset
root=Path(__file__).resolve().parents[1]
font=TTFont(root/'assets/fonts/NotoSansSC.ttf')
instantiateVariableFont(font,{'wght':600},inplace=True)
runtime_json=list((root/'assets').glob('*.json'))+[root/'assets/wordbooks/lexicon.json',root/'assets/wordbooks/catalog.json']
chars=''.join(p.read_text(encoding='utf-8-sig') for p in list((root/'scripts').glob('*.gd'))+runtime_json if p.exists())
codes=set(map(ord,chars))|set(range(32,0x300))|set(range(0x2000,0x2070))|set(range(0x3000,0x3040))|set(range(0xff00,0xfff0))
options=subset.Options();options.name_IDs=['*'];options.name_languages=['*'];options.layout_features=['*']
s=subset.Subsetter(options=options);s.populate(unicodes=codes);s.subset(font)
for record in font['name'].names:
    replacements={1:'Frontier Sans SC',2:'Semibold',4:'Frontier Sans SC Semibold',6:'FrontierSansSC-Semibold',16:'Frontier Sans SC',17:'Semibold'}
    if record.nameID in replacements:record.string=replacements[record.nameID].encode(record.getEncoding())
font.save(root/'assets/fonts/FrontierSC.ttf')
print('Font subset:',len(font.getBestCmap()),'characters')
latin=TTFont(root/'assets/fonts/NotoSans.ttf')
instantiateVariableFont(latin,{'wght':600,'wdth':100},inplace=True)
s=subset.Subsetter(options=options);s.populate(unicodes=codes);s.subset(latin)
for record in latin['name'].names:
    replacements={1:'Frontier Sans Latin',2:'Semibold',4:'Frontier Sans Latin Semibold',6:'FrontierSansLatin-Semibold',16:'Frontier Sans Latin',17:'Semibold'}
    if record.nameID in replacements:record.string=replacements[record.nameID].encode(record.getEncoding())
latin.save(root/'assets/fonts/FrontierLatin.ttf')
print('Phonetic fallback subset:',len(latin.getBestCmap()),'characters')
