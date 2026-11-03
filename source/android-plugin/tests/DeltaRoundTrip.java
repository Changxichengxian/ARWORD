package io.github.changxichengxian.arword;
import java.io.File;
public final class DeltaRoundTrip {
    public static void main(String[] args) throws Exception {
        File old=new File(args[0]), patch=new File(args[1]), target=new File(args[2]), result=new File(args[3]);
        ApkDelta.apply(old,patch,result,ApkDelta.hash(old),ApkDelta.hash(target),target.length());
        if (!ApkDelta.hash(result).equals(ApkDelta.hash(target))) throw new AssertionError("different APK");
        System.out.println("exact target rebuilt");
    }
}
