from pathlib import Path
import os,subprocess,zipfile,argparse
root=Path(__file__).resolve().parents[1];parser=argparse.ArgumentParser();parser.add_argument('--java',type=Path,required=True);parser.add_argument('--sdk',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
sdk=args.sdk;java=args.java/'bin'
bt=sdk/'build-tools/36.1.0';jar=sdk/'platforms/android-36/android.jar';src=root/'tests/android';out=args.out;out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['JAVA_HOME']=str(java.parent)
def run(args):subprocess.run(list(map(str,args)),check=True,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
(out/'classes').mkdir(exist_ok=True);(out/'dex').mkdir(exist_ok=True)
run([java/'javac.exe','-encoding','UTF-8','-source','8','-target','8','-classpath',jar,'-d',out/'classes',src/'TouchRunner.java'])
run([bt/'d8.bat','--lib',jar,'--output',out/'dex',*list((out/'classes').rglob('*.class'))])
apk=out/'probe-unsigned.apk'
run([bt/'aapt2.exe','link','-I',jar,'--manifest',src/'AndroidManifest.xml','-o',apk])
with zipfile.ZipFile(apk,'a') as z:z.write(out/'dex/classes.dex','classes.dex')
print('Probe built')
