package com.wordfrontier.planet;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/** Shared by the document reader and the plain-Java boundary checks. */
final class BoundedDocumentCopy {
    static void copy(InputStream input, OutputStream output, long limit) throws IOException {
        byte[] buffer = new byte[65536];
        long total = 0;
        int count;
        while ((count = input.read(buffer)) != -1) {
            if (Thread.currentThread().isInterrupted()) throw new IOException("interrupted");
            total += count;
            if (total > limit) throw new LimitExceeded();
            output.write(buffer, 0, count);
        }
        if (total == 0) throw new IOException("empty document");
    }

    static final class LimitExceeded extends IOException {}
}
