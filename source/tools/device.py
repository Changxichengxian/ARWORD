from pathlib import Path
import subprocess,sys,xml.etree.ElementTree as ET,re,time,json,os,shutil
sdk=os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or str(Path(os.environ.get('LOCALAPPDATA',''))/'Android/Sdk')
ADB=os.environ.get('ADB') or shutil.which('adb') or str(Path(sdk)/'platform-tools'/('adb.exe' if os.name=='nt' else 'adb'))
QA=Path(os.environ.get('FRONTIER_QA',str(Path(__file__).resolve().parents[2]/'qa')))
QA.mkdir(exist_ok=True)
def adb(*args,check=True):return subprocess.run([ADB,*args],capture_output=True,check=check)
def dump():
    adb('shell','uiautomator','dump','/sdcard/wordfrontier-window.xml')
    data=adb('exec-out','cat','/sdcard/wordfrontier-window.xml').stdout
    (QA/'window.xml').write_bytes(data)
    return ET.fromstring(data)
def peek():
    root=dump()
    rows=[]
    for n in root.iter('node'):
        if n.get('text') or n.get('content-desc'):rows.append({k:n.get(k) for k in ['text','content-desc','class','clickable','enabled','bounds']})
    print(json.dumps(rows,ensure_ascii=False))
def shot(name):
    path=QA/(name+'.png');path.write_bytes(adb('exec-out','screencap','-p').stdout);print(path)
def tap(text):
    root=dump()
    nodes=[n for n in root.iter('node') if n.get('text')==text and n.get('enabled')=='true' and n.get('clickable')=='true']
    if not nodes:raise RuntimeError('No visible exact text: '+text)
    n=nodes[-1];bounds=list(map(int,re.findall(r'\d+',n.get('bounds'))));x=(bounds[0]+bounds[2])//2;y=(bounds[1]+bounds[3])//2
    adb('shell','input','tap',str(x),str(y));time.sleep(.8)
if __name__=='__main__':
    cmd=sys.argv[1]
    if cmd=='peek':peek()
    elif cmd=='shot':shot(sys.argv[2])
    elif cmd=='tap':tap(sys.argv[2]);peek()
    elif cmd=='swipe':adb('shell','input','swipe',*sys.argv[2:]);time.sleep(.4);peek()
