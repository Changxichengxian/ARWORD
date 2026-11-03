package com.wordfrontier.planet;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Arrays;

public final class BoundedCopyTest {
    private static int passed;
    private static final long LIMIT = 64L * 1024L * 1024L;
    private static final class CountOutput extends OutputStream {
        long count;
        public void write(int value) { count++; }
        public void write(byte[] bytes,int offset,int length) { count+=length; }
    }
    private static InputStream sized(long size) {
        return new InputStream() {
            long remaining=size;
            public int read() { return remaining-- > 0 ? 0 : -1; }
            public int read(byte[] data,int offset,int length) {
                if(remaining<=0)return -1;
                int count=(int)Math.min(remaining,length);remaining-=count;return count;
            }
        };
    }
    private static void check(boolean ok,String label) {
        if(!ok)throw new AssertionError(label);
        passed++;System.out.println("PASS "+label);
    }
    public static void main(String[] args) throws Exception {
        byte[] bytes={0,103,108,84,70,-1,3,8};ByteArrayOutputStream out=new ByteArrayOutputStream();
        BoundedDocumentCopy.copy(new ByteArrayInputStream(bytes),out,LIMIT);
        check(Arrays.equals(bytes,out.toByteArray()),"binary bytes are preserved without text decoding");
        CountOutput exact=new CountOutput();BoundedDocumentCopy.copy(sized(LIMIT),exact,LIMIT);
        check(exact.count==LIMIT,"exactly 64 MiB is accepted using bounded memory");
        CountOutput tooBig=new CountOutput();boolean rejected=false;
        try{BoundedDocumentCopy.copy(sized(LIMIT+1),tooBig,LIMIT);}catch(BoundedDocumentCopy.LimitExceeded expected){rejected=true;}
        check(rejected&&tooBig.count==LIMIT,"unknown-size streams cannot write beyond 64 MiB");
        rejected=false;try{BoundedDocumentCopy.copy(sized(0),new CountOutput(),LIMIT);}catch(IOException expected){rejected=true;}
        check(rejected,"empty documents are rejected");
        rejected=false;Thread.currentThread().interrupt();
        try{BoundedDocumentCopy.copy(sized(8),new CountOutput(),LIMIT);}catch(IOException expected){rejected=true;}finally{Thread.interrupted();}
        check(rejected,"activity teardown can interrupt copying");
        rejected=false;
        try{BoundedDocumentCopy.copy(new InputStream(){public int read() throws IOException{throw new IOException("provider failed");}},new CountOutput(),LIMIT);}catch(IOException expected){rejected=true;}
        check(rejected,"document-provider read failures propagate for cleanup");
        System.out.println("BOUNDED_COPY_RESULT "+passed+" passed / 0 failed");
    }
}
