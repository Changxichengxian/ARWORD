package io.github.changxichengxian.arword;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.*;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.HashMap;
import java.util.Map;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.net.ssl.HttpsURLConnection;

/** User initiated checks only. The OS installer handles consent and the final signature check. */
public final class PlanetUpdates extends GodotPlugin {
    private static final int SOURCE_SETTINGS = 0x5451, INSTALLER = 0x5452;
    private final AtomicBoolean busy = new AtomicBoolean();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile String status = "{\"phase\":\"idle\",\"message\":\"\"}";
    private volatile boolean dead;
    private volatile File candidate;
    private JSONObject full, selected;
    private String remoteVersion, tag, baseHash;
    private int targetCode;
    private boolean delta;
    private final Map<String,URL> assetApi = new HashMap<>();
    private final SafeViewport viewportInsets = new SafeViewport();
    @Override public void onMainResume() { viewportInsets.attach(getActivity()); }
    @UsedByGodot public float[] safe_viewport_insets() { return viewportInsets.fractions(); }
    public PlanetUpdates(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PlanetUpdates"; }
    @UsedByGodot public String update_state() { return status; }

    private void report(String phase, String msg) {
        try { status = new JSONObject().put("phase",phase).put("message",msg).toString(); }
        catch (Exception impossible) { throw new AssertionError(impossible); }
    }
    private String phase() {
        try { return new JSONObject(status).getString("phase"); } catch (Exception e) { return ""; }
    }
    private interface Operation { void run(Context ctx) throws Exception; }
    private void run(String initial, String msg, Operation operation) {
        Activity activity=getActivity();
        if (dead || activity==null || !busy.compareAndSet(false,true)) return;
        Context ctx=activity.getApplicationContext();
        report(initial,msg);
        worker.execute(() -> {
            try { operation.run(ctx); }
            catch (Exception e) {
                String detail=e.getMessage();
                if (detail==null || !detail.matches("[\\p{IsHan}，。 A-Za-z0-9]{1,70}")) detail="请检查网络与存储空间";
                report("error","更新失败 · "+detail);
            } finally { busy.set(false); }
        });
    }

    @UsedByGodot public void check_update() {
        run("checking","正在检查版本",ctx -> {
            candidate=null; full=null; selected=null;
            JSONObject manifest=latestManifest();
            if (manifest.getInt("format")!=1 || !ctx.getPackageName().equals(manifest.getString("package"))) throw new IOException("更新清单不匹配");
            targetCode=manifest.getInt("code");
            PackageInfo self=ctx.getPackageManager().getPackageInfo(ctx.getPackageName(),0);
            if (targetCode<1) throw new IOException("更新版本无效");
            if (targetCode<=version(self)) { report("current","当前已是最新版本 · "+self.versionName); return; }
            remoteVersion=manifest.getString("version"); tag=manifest.getString("tag");
            if (!remoteVersion.matches("[0-9]+(\\.[0-9]+){2}") || !tag.equals("v"+remoteVersion)) throw new IOException("更新标签无效");
            full=validated(manifest.getJSONObject("full"));
            selected=full; delta=false;
            baseHash=ApkDelta.hash(new File(ctx.getApplicationInfo().sourceDir));
            JSONArray patches=manifest.getJSONArray("patches");
            if (patches.length()>128) throw new IOException("差异清单过大");
            for (int i=0;i<patches.length();i++) {
                JSONObject patch=patches.getJSONObject(i);
                if (baseHash.equals(patch.getString("base_sha256")) && validated(patch).getLong("bytes")<selected.getLong("bytes")) {
                    selected=patch; delta=true;
                }
            }
            report("offer","新版 "+remoteVersion+" · "+(delta?"差异下载 ":"完整下载 ")+amount(selected.getLong("bytes")));
        });
    }
    private JSONObject readJson(URL url,long maxBytes) throws Exception {
        ByteArrayOutputStream body=new ByteArrayOutputStream();
        fetch(url,body,-1,maxBytes,false);
        return new JSONObject(body.toString("UTF-8"));
    }
    private JSONObject latestManifest() throws Exception {
        String repo="https://api.github.com/repos/"+UpdateChannel.REPO;
        assetApi.clear();
        try {
            JSONObject release=readJson(new URL(repo+"/releases/latest"),512*1024);
            JSONArray files=release.getJSONArray("assets");
            if (files.length()>256) throw new IOException("发布附件过多");
            for (int i=0;i<files.length();i++) {
                JSONObject f=files.getJSONObject(i);
                long id=f.getLong("id");
                if (id>0) assetApi.put(f.getString("name"),new URL(repo+"/releases/assets/"+id));
            }
            URL manifestUrl=assetApi.get("update.json");
            if (manifestUrl==null) throw new IOException("发布缺少更新清单");
            JSONObject manifest=readJson(manifestUrl,65536);
            if (!release.getString("tag_name").equals(manifest.getString("tag"))) throw new IOException("清单不属于此版本");
            return manifest;
        } catch (IOException unreachable) {
            // The public web endpoint remains useful on networks where the API rate limit is shared.
            assetApi.clear();
            return readJson(new URL("https://github.com/"+UpdateChannel.REPO+"/releases/latest/download/update.json"),65536);
        }
    }
    private static JSONObject validated(JSONObject item) throws Exception {
        if (!item.getString("asset").matches("[A-Za-z0-9_-][A-Za-z0-9._-]{0,119}")
                || !item.getString("sha256").matches("[a-f0-9]{64}")
                || item.getLong("bytes")<1 || item.getLong("bytes")>ApkDelta.LIMIT) throw new IOException("更新资源无效");
        return item;
    }
    private static String amount(long bytes) {
        return bytes<1048576?String.format(Locale.ROOT,"%.1f KB",bytes/1024.0):String.format(Locale.ROOT,"%.1f MB",bytes/1048576.0);
    }
    private void fetch(URL url, OutputStream out, long expected, long limit, boolean progress) throws Exception {
        for (int redirects=0;redirects<=5;redirects++) {
            String host=url.getHost().toLowerCase(Locale.ROOT);
            if (!url.getProtocol().equals("https") || (url.getPort()!=-1 && url.getPort()!=443) || url.getUserInfo()!=null ||
                    !(host.equals("github.com") || host.equals("api.github.com") || host.equals("release-assets.githubusercontent.com") || host.equals("objects.githubusercontent.com")))
                throw new IOException("更新地址无效");
            HttpsURLConnection c=(HttpsURLConnection)url.openConnection();
            c.setInstanceFollowRedirects(false); c.setConnectTimeout(12000); c.setReadTimeout(30000);
            c.setRequestProperty("Accept-Encoding","identity"); c.setRequestProperty("User-Agent","LittleTide-Android-Updater/1");
            if (host.equals("api.github.com")) {
                c.setRequestProperty("Accept",url.getPath().contains("/releases/assets/")?"application/octet-stream":"application/vnd.github+json");
            }
            c.setUseCaches(false);
            try {
                int response=c.getResponseCode();
                if (response==301||response==302||response==303||response==307||response==308) {
                    String location=c.getHeaderField("Location"); if (location==null) throw new IOException("更新地址无效");
                    url=new URL(url,location); continue;
                }
                if (response!=200) throw new IOException(response==404?"尚无可用发布":"下载服务返回 "+response);
                long declared=c.getContentLengthLong();
                if (declared>limit || (expected>0 && declared>=0 && declared!=expected)) throw new IOException("下载长度不匹配");
                try (InputStream in=new BufferedInputStream(c.getInputStream())) {
                    byte[] buffer=new byte[131072]; long total=0, last=0; int n;
                    while ((n=in.read(buffer))!=-1) {
                        if (dead || Thread.currentThread().isInterrupted()) throw new IOException("已中断");
                        total+=n;
                        if (total>limit || (expected>=0 && total>expected)) throw new IOException("下载超出限制");
                        out.write(buffer,0,n);
                        if (progress && total-last>=262144) { report("working","正在下载 "+amount(total)+" / "+amount(expected)); last=total; }
                    }
                    if (expected>=0 && total!=expected) throw new IOException("下载不完整");
                    return;
                }
            } finally { c.disconnect(); }
        }
        throw new IOException("下载跳转过多");
    }
    @UsedByGodot public void download_update() {
        if (!phase().equals("offer")) return;
        run("working","准备更新",ctx -> {
            File dir=new File(ctx.getCacheDir(),"planet-update");
            if (!dir.isDirectory()&&!dir.mkdirs()) throw new IOException("存储不可用");
            File input=new File(dir,"download.tmp"), rebuilt=new File(dir,"verified.apk");
            input.delete(); rebuilt.delete(); candidate=null;
            long size=full.getLong("bytes"), transfer=selected.getLong("bytes");
            if (dir.getUsableSpace()<size+(delta?transfer:0)+32L*1024*1024) throw new IOException("可用存储空间不足");
            try {
                String assetName=selected.getString("asset");
                URL url=assetApi.get(assetName);
                if (url==null) url=new URL("https://github.com/"+UpdateChannel.REPO+"/releases/download/"+tag+"/"+assetName);
                try (FileOutputStream out=new FileOutputStream(input)) { fetch(url,out,transfer,transfer,true); out.getFD().sync(); }
                report("working","正在校验安装包");
                if (!ApkDelta.hash(input).equals(selected.getString("sha256"))) throw new IOException("下载校验失败");
                if (delta) {
                    report("working","正在复用原有资源");
                    ApkDelta.apply(new File(ctx.getApplicationInfo().sourceDir),input,rebuilt,baseHash,full.getString("sha256"),size);
                } else if (!input.renameTo(rebuilt)) throw new IOException("保存失败");
                checkSigner(ctx,rebuilt);
                candidate=rebuilt;
                report("install","已校验 · 等待系统安装");
                runOnHostThread(this::launchInstaller);
            } finally {
                input.delete(); if (candidate==null) rebuilt.delete();
            }
        });
    }
    private static long version(PackageInfo p) { return Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode; }
    private static Signature[] signers(PackageInfo p) {
        return Build.VERSION.SDK_INT>=28?(p.signingInfo==null?null:p.signingInfo.getApkContentsSigners()):p.signatures;
    }
    private void checkSigner(Context ctx, File apk) throws Exception {
        PackageManager pm=ctx.getPackageManager();
        int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
        PackageInfo self=pm.getPackageInfo(ctx.getPackageName(),flags), next=pm.getPackageArchiveInfo(apk.getPath(),flags);
        if (next==null || !ctx.getPackageName().equals(next.packageName) || version(next)!=targetCode ||
                !remoteVersion.equals(next.versionName) || version(next)<=version(self)) throw new IOException("安装包或版本不匹配");
        Signature[] a=signers(self), b=signers(next);
        if (a==null||a.length==0||b==null||!new HashSet<>(Arrays.asList(a)).equals(new HashSet<>(Arrays.asList(b)))) throw new IOException("应用签名不匹配");
    }
    @UsedByGodot public void install_update() { runOnHostThread(this::launchInstaller); }
    private void launchInstaller() {
        Activity a=getActivity(); File checked=candidate;
        if (dead||a==null||a.isFinishing()||checked==null||!checked.isFile()) return;
        try {
            if (Build.VERSION.SDK_INT>=26 && !a.getPackageManager().canRequestPackageInstalls()) {
                report("install","请允许 ARWORD 安装更新");
                a.startActivityForResult(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+a.getPackageName())),SOURCE_SETTINGS); return;
            }
            Uri uri=FileProvider.getUriForFile(a,a.getPackageName()+".updates",checked);
            Intent i=new Intent(Intent.ACTION_VIEW).setDataAndType(uri,"application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).putExtra(Intent.EXTRA_RETURN_RESULT,true);
            a.startActivityForResult(i,INSTALLER);
        } catch (RuntimeException e) { report("install","系统安装器未打开，可再试一次"); }
    }
    @Override public void onMainActivityResult(int requestCode,int resultCode,Intent data) {
        Activity a=getActivity();
        if (requestCode==SOURCE_SETTINGS && Build.VERSION.SDK_INT>=26 && a!=null && a.getPackageManager().canRequestPackageInstalls()) {
            runOnHostThread(this::launchInstaller);
        } else if (requestCode==INSTALLER) report("install","已下载安装包，可再次安装");
    }
    @Override public void onMainDestroy() { dead=true; viewportInsets.detach(); worker.shutdownNow(); }
}
