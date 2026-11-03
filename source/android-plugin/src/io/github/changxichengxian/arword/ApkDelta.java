package io.github.changxichengxian.arword;

import java.io.*;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.zip.GZIPInputStream;

/** Bounded, sequential output. Rebuilds even the APK signing block and ZIP directory exactly. */
public final class ApkDelta {
    public static final long LIMIT = 512L * 1024 * 1024;
    static String hex(byte[] bytes) {
        char[] digits = "0123456789abcdef".toCharArray();
        StringBuilder out = new StringBuilder(2 * bytes.length);
        for (byte b : bytes) out.append(digits[(b & 255) >>> 4]).append(digits[b & 15]);
        return out.toString();
    }
    static String hash(File file) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] buf = new byte[131072];
        try (InputStream in = new FileInputStream(file)) {
            int n;
            while ((n = in.read(buf)) != -1) md.update(buf, 0, n);
        }
        return hex(md.digest());
    }
    static void apply(File old, File patch, File out, String expectedBase, String expectedHash, long expectedSize) throws Exception {
        if (expectedSize <= 0 || expectedSize > LIMIT || !hash(old).equals(expectedBase))
            throw new IOException("安装版本与差异包不匹配");
        try (RandomAccessFile base = new RandomAccessFile(old, "r");
             DataInputStream in = new DataInputStream(new BufferedInputStream(new GZIPInputStream(new FileInputStream(patch))));
             FileOutputStream dest = new FileOutputStream(out)) {
            byte[] magic = new byte[4], baseHash = new byte[32], targetHash = new byte[32];
            in.readFully(magic); in.readFully(baseHash); in.readFully(targetHash);
            if (!Arrays.equals(magic, new byte[]{'L','T','D','1'}) || !hex(baseHash).equals(expectedBase)
                || !hex(targetHash).equals(expectedHash) || in.readLong() != expectedSize)
                throw new IOException("差异包标记错误");
            byte[] buf = new byte[131072];
            long written = 0;
            int count = 0;
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            while (true) {
                int op = in.readUnsignedByte();
                if (op == 2) break;
                if (++count > 300000 || (op != 0 && op != 1)) throw new IOException("差异包指令错误");
                long length = in.readLong();
                if (length <= 0 || length > expectedSize - written) throw new IOException("差异包长度错误");
                if (op == 1) {
                    long offset = in.readLong();
                    if (offset < 0 || offset > base.length() - length) throw new IOException("差异包位置错误");
                    base.seek(offset);
                }
                written += length;
                while (length > 0) {
                    int n = (int)Math.min(length, buf.length);
                    if (op == 1) base.readFully(buf, 0, n); else in.readFully(buf, 0, n);
                    dest.write(buf, 0, n); digest.update(buf, 0, n);
                    length -= n;
                }
            }
            if (written != expectedSize || in.read() != -1 || !hex(digest.digest()).equals(expectedHash))
                throw new IOException("还原的安装包未通过校验");
            dest.getFD().sync();
        } catch (Exception e) {
            out.delete();
            throw e;
        }
    }
}
