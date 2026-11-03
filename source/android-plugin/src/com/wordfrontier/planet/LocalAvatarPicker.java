package com.wordfrontier.planet;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/** Read only the document the user selects. No storage or network permission. */
public final class LocalAvatarPicker extends GodotPlugin {
    private static final int REQUEST_AVATAR = 0x5371;
    static final long MAX_BYTES = 64L * 1024L * 1024L;
    private final AtomicBoolean busy = new AtomicBoolean(false);
    private final ExecutorService reader = Executors.newSingleThreadExecutor();
    private volatile boolean destroyed;

    public LocalAvatarPicker(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "LocalAvatarPicker"; }

    @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("avatar_picked", String.class),
            new SignalInfo("avatar_pick_failed", String.class),
            new SignalInfo("avatar_pick_cancelled")
        ));
    }

    @UsedByGodot public void pick_avatar() {
        if (destroyed) return;
        if (!busy.compareAndSet(false, true)) {
            emitSignal("avatar_pick_failed", "正在选择角色文件");
            return;
        }
        runOnHostThread(() -> {
            Activity activity = getActivity();
            if (activity == null || activity.isFinishing()) {
                fail("文件选择器暂时不可用");
                return;
            }
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*"); // VRM files commonly have no registered MIME type.
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false);
            intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
            try {
                activity.startActivityForResult(intent, REQUEST_AVATAR);
            } catch (RuntimeException error) {
                fail("无法打开系统文件选择器");
            }
        });
    }

    @Override public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_AVATAR || !busy.get() || destroyed) return;
        if (resultCode != Activity.RESULT_OK) {
            busy.set(false);
            emitSignal("avatar_pick_cancelled");
            return;
        }
        Uri uri = data == null ? null : data.getData();
        Activity activity = getActivity();
        if (uri == null || !ContentResolver.SCHEME_CONTENT.equals(uri.getScheme()) || activity == null) {
            fail("没有取得可读取的文件");
            return;
        }
        Context context = activity.getApplicationContext();
        reader.execute(() -> copyDocument(context, uri));
    }

    private void copyDocument(Context context, Uri uri) {
        File partial = null;
        try {
            ContentResolver resolver = context.getContentResolver();
            long declared = -1;
            try (Cursor cursor = resolver.query(uri, new String[]{OpenableColumns.SIZE}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst() && !cursor.isNull(0)) declared = cursor.getLong(0);
            } catch (RuntimeException ignored) {
                // Some document providers omit size. The stream limit remains authoritative.
            }
            if (declared > MAX_BYTES) throw new BoundedDocumentCopy.LimitExceeded();
            File directory = new File(context.getCacheDir(), "local-avatar-picker");
            if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("cache unavailable");
            File selected = new File(directory, "selected.vrm");
            partial = new File(directory, "selected.part");
            // Only these two plugin-owned cache files are ever removed.
            if (partial.exists() && !partial.delete()) throw new IOException("cache busy");
            try (InputStream input = resolver.openInputStream(uri);
                 FileOutputStream output = new FileOutputStream(partial)) {
                if (input == null) throw new IOException("document unavailable");
                BoundedDocumentCopy.copy(input, output, MAX_BYTES);
                output.getFD().sync();
            }
            if (destroyed || Thread.currentThread().isInterrupted()) throw new IOException("interrupted");
            if (selected.exists() && !selected.delete()) throw new IOException("cache busy");
            if (!partial.renameTo(selected)) throw new IOException("cache commit failed");
            partial = null;
            busy.set(false);
            if (!destroyed) emitSignal("avatar_picked", selected.getAbsolutePath());
        } catch (BoundedDocumentCopy.LimitExceeded error) {
            fail("角色文件不能超过 64 MB");
        } catch (Exception error) {
            fail("读取失败，请重新选择本机的 VRM 文件");
        } finally {
            if (partial != null && partial.isFile()) partial.delete();
        }
    }

    private void fail(String message) {
        busy.set(false);
        if (!destroyed) emitSignal("avatar_pick_failed", message);
    }

    @Override public void onMainDestroy() {
        destroyed = true;
        busy.set(false);
        reader.shutdownNow();
    }

}
