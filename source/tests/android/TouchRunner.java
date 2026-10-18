package com.wordfrontier.probe;
import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.os.*;
import android.view.*;
import java.io.*;
import org.json.*;

/** Injects actual Android MotionEvents. Only packaged in a separate test APK. */
public class TouchRunner extends Instrumentation {
    Bundle args;
    long down;
    @Override public void onCreate(Bundle b){super.onCreate(b);args=b;start();}
    void event(int action,float[][] xy){
        MotionEvent.PointerProperties[] pp=new MotionEvent.PointerProperties[xy.length];
        MotionEvent.PointerCoords[] cc=new MotionEvent.PointerCoords[xy.length];
        for(int i=0;i<xy.length;i++){
            pp[i]=new MotionEvent.PointerProperties();pp[i].id=i;pp[i].toolType=MotionEvent.TOOL_TYPE_FINGER;
            cc[i]=new MotionEvent.PointerCoords();cc[i].x=xy[i][0];cc[i].y=xy[i][1];cc[i].pressure=1;cc[i].size=1;
        }
        MotionEvent e=MotionEvent.obtain(down,SystemClock.uptimeMillis(),action,xy.length,pp,cc,0,0,1,1,0,0,InputDevice.SOURCE_TOUCHSCREEN,0);
        if(!getUiAutomation().injectInputEvent(e,true))throw new RuntimeException("Input injection rejected");
        e.recycle();
    }
    void tap(float x,float y){down=SystemClock.uptimeMillis();event(0,new float[][]{{x,y}});SystemClock.sleep(70);event(1,new float[][]{{x,y}});}
    void capture(String name)throws Exception{
        Bitmap b=getUiAutomation().takeScreenshot();if(b==null)throw new RuntimeException("No screenshot");
        File f=new File(getTargetContext().getExternalFilesDir(null),name+".png");
        try(FileOutputStream out=new FileOutputStream(f)){b.compress(Bitmap.CompressFormat.PNG,100,out);}b.recycle();
    }
    void hold(JSONArray op)throws Exception{
        int n=op.getInt(1),ms=op.getInt(2);float[][] xy=new float[n][2];
        for(int i=0;i<n;i++){xy[i][0]=(float)op.getDouble(3+i*2);xy[i][1]=(float)op.getDouble(4+i*2);}
        down=SystemClock.uptimeMillis();event(0,new float[][]{xy[0]});
        if(n==2)event(MotionEvent.ACTION_POINTER_DOWN|(1<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),xy);
        for(int k=0;k<ms;k+=40){event(MotionEvent.ACTION_MOVE,xy);SystemClock.sleep(40);}
        if(n==2)event(MotionEvent.ACTION_POINTER_UP|(1<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),xy);
        event(MotionEvent.ACTION_UP,new float[][]{xy[0]});
    }
    @Override public void onStart(){
        Bundle result=new Bundle();
        try{
            if(args.containsKey("seed")){
                // Explicit test fixture; does not run in or ship with the game APK.
                File data=new File(getTargetContext().getFilesDir(),"frontier3d.json");
                try(FileOutputStream out=new FileOutputStream(data)){
                    out.write(("{\"version\":1,\"wood\":"+Integer.parseInt(args.getString("seed"))+",\"bridge\":false,\"wins\":0,\"band\":3,\"words\":{},\"checks\":[],\"sound\":true,\"read_words\":0,\"listen_count\":0,\"challenge\":1,\"next_lesson\":0}").getBytes("UTF-8"));
                }
            }
            if(!args.getString("launch","true").equals("false")){
                Intent launch=new Intent().setClassName("com.wordfrontier.frontier3d","com.godot.game.GodotApp").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getTargetContext().startActivity(launch);
            }
            JSONArray seq=new JSONArray(args.getString("seq","[]"));
            for(int i=0;i<seq.length();i++){
                JSONArray op=seq.getJSONArray(i);String kind=op.getString(0);
                if(kind.equals("wait"))SystemClock.sleep(op.getInt(1));
                else if(kind.equals("tap"))tap((float)op.getDouble(1),(float)op.getDouble(2));
                else if(kind.equals("hold"))hold(op);
                else if(kind.equals("capture"))capture(op.getString(1));
                else if(kind.equals("key")){
                    int key=op.getInt(1);ParcelFileDescriptor descriptor=getUiAutomation().executeShellCommand("input keyevent "+key);
                    try(InputStream stream=new ParcelFileDescriptor.AutoCloseInputStream(descriptor)){byte[] buffer=new byte[256];while(stream.read(buffer)!=-1){}}
                }
                else throw new RuntimeException("Unknown action "+kind);
            }
            File data=new File(getTargetContext().getFilesDir(),"frontier3d.json");
            String state="no internal save";
            if(data.isFile())try(FileInputStream in=new FileInputStream(data)){byte[] b=new byte[(int)data.length()];in.read(b);state=new String(b,"UTF-8");}
            result.putString("stream","\nANDROID_TOUCH_SEQUENCE_OK "+seq.length()+" actions\nSAVE "+state+"\n");finish(Activity.RESULT_OK,result);
        }catch(Throwable t){result.putString("stream","\nFAILED "+t+"\n");finish(Activity.RESULT_CANCELED,result);}
    }
}
