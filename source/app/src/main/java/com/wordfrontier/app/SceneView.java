package com.wordfrontier.app;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.*;

/** Native timing control; world art is provided by GameArt. */
public final class SceneView {
  private static final int MINT = 0xff80dc52, GOLD = 0xffffc83f;

  public static final class Timing extends View {
    Paint p = new Paint(3);
    long start = SystemClock.uptimeMillis();
    boolean running = true, still;

    public Timing(Context c, boolean still) {
      super(c);
      this.still = still;
      setContentDescription("出手时机条，游标到中央绿色区域时点出手。可用稳定出手跳过。");
    }

    float position() {
      return still
          ? .5f
          : (float) ((Math.sin((SystemClock.uptimeMillis() - start) / 700.0) + 1) / 2);
    }

    public int precision() {
      if (still) return 1;
      float d = Math.abs(position() - .5f);
      return d < .1 ? 2 : d < .24 ? 1 : 0;
    }

    @Override
    protected void onDraw(Canvas c) {
      float w = getWidth(), h = getHeight(), pad = 14;
      p.setColor(0xff243c42);
      c.drawRoundRect(pad, h * .35f, w - pad, h * .65f, 12, 12, p);
      p.setColor(0xff3c7860);
      c.drawRoundRect(w * .3f, h * .35f, w * .7f, h * .65f, 8, 8, p);
      p.setColor(MINT);
      c.drawRoundRect(w * .4f, h * .3f, w * .6f, h * .7f, 8, 8, p);
      p.setColor(GOLD);
      float x = pad + (w - 2 * pad) * position();
      c.drawCircle(x, h / 2, 9, p);
      p.setColor(0xff0e252b);
      c.drawCircle(x, h / 2, 3, p);
      if (running && !still) postInvalidateDelayed(16);
    }

    @Override
    protected void onDetachedFromWindow() {
      running = false;
      super.onDetachedFromWindow();
    }
  }
}
