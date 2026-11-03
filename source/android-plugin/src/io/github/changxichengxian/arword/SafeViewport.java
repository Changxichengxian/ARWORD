package io.github.changxichengxian.arword;

import android.app.Activity;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

/** Read Android window insets without consuming or replacing Godot's input listeners. */
final class SafeViewport {
    private volatile float[] edges = new float[0];
    private View decor;
    private View surface;
    private final android.view.ViewTreeObserver.OnGlobalLayoutListener listener = this::measure;

    void attach(Activity activity) {
        if (activity == null) return;
        View next = activity.getWindow().getDecorView();
        if (next != decor) {
            detach();
            decor = next;
            decor.getViewTreeObserver().addOnGlobalLayoutListener(listener);
        }
        measure();
    }
    void detach() {
        if (decor != null && decor.getViewTreeObserver().isAlive())
            decor.getViewTreeObserver().removeOnGlobalLayoutListener(listener);
        decor = null;
        surface = null;
        edges = new float[0];
    }
    float[] fractions() { return edges; }

    private View findSurface(View view) {
        if (view instanceof SurfaceView) return view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i=0; i<group.getChildCount(); i++) {
                View found = findSurface(group.getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }
    private void measure() {
        if (decor == null) return;
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(decor);
        if (insets == null) return;
        if (surface == null || !surface.isAttachedToWindow()) surface = findSurface(decor);
        if (surface == null || surface.getWidth()<=0 || surface.getHeight()<=0) return;
        Insets bars = insets.getInsetsIgnoringVisibility(
                WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
        Insets gestures = insets.getInsets(WindowInsetsCompat.Type.systemGestures());
        int[] d=new int[2], s=new int[2];
        decor.getLocationOnScreen(d); surface.getLocationOnScreen(s);
        // Subtract any space already reserved by Android around the render view.
        float width=surface.getWidth(), height=surface.getHeight();
        edges = new float[]{
            Math.max(0,d[0]+Math.max(bars.left,gestures.left)-s[0])/width,
            Math.max(0,d[1]+Math.max(bars.top,gestures.top)-s[1])/height,
            Math.max(0,s[0]+width-d[0]-decor.getWidth()+Math.max(bars.right,gestures.right))/width,
            Math.max(0,s[1]+height-d[1]-decor.getHeight()+Math.max(bars.bottom,gestures.bottom))/height
        };
    }
}
