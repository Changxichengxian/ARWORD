package com.wordfrontier.app;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.*;

/** A small illustrated world drawn by Android Canvas. No HTML, textures or WebView. */
public final class SceneView extends View {
  private final Paint p = new Paint(3);
  private final Path path = new Path();
  private final LinearGradient sky =
      new LinearGradient(0, 0, 0, 235, 0xff122c38, 0xff172a30, Shader.TileMode.CLAMP);
  private final Game g;
  private final boolean arena;
  private long start = SystemClock.uptimeMillis();
  private boolean running = true;
  private static final int MINT = Color.rgb(159, 225, 179), GOLD = Color.rgb(242, 196, 115);

  public SceneView(Context c, Game g, boolean arena) {
    super(c);
    this.g = g;
    this.arena = arena;
    setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
  }

  private void color(int c) {
    p.setColor(c);
    p.setStyle(Paint.Style.FILL);
    p.setShader(null);
  }

  private void poly(Canvas c, int col, float... xy) {
    color(col);
    path.reset();
    path.moveTo(xy[0], xy[1]);
    for (int i = 2; i < xy.length; i += 2) path.lineTo(xy[i], xy[i + 1]);
    path.close();
    c.drawPath(path, p);
  }

  private void line(Canvas c, int col, float width, float... xy) {
    color(col);
    p.setStrokeWidth(width);
    p.setStrokeCap(Paint.Cap.ROUND);
    for (int i = 2; i < xy.length; i += 2) c.drawLine(xy[i - 2], xy[i - 1], xy[i], xy[i + 1], p);
  }

  private void oval(Canvas c, int col, float x, float y, float rx, float ry) {
    color(col);
    c.drawOval(x - rx, y - ry, x + rx, y + ry, p);
  }

  private void rect(Canvas c, int col, float l, float t, float r, float b, float radius) {
    color(col);
    c.drawRoundRect(l, t, r, b, radius, radius, p);
  }

  private void tree(Canvas c, float x, float y, float size) {
    line(c, 0xff483f35, 3, x, y, x, y - size * .58f);
    poly(
        c,
        0xff254f4a,
        x,
        y - size,
        x - size * .32f,
        y - size * .2f,
        x + size * .32f,
        y - size * .2f);
    poly(c, 0xff376b59, x - 1, y - size, x - 1, y - size * .2f, x - size * .32f, y - size * .2f);
  }

  private void hut(Canvas c, float x, float y, float size, boolean lit) {
    oval(c, 0x45000000, x, y + 2, size * .75f, size * .22f);
    poly(
        c,
        0xff6b786c,
        x - size * .55f,
        y - size * .5f,
        x,
        y - size * .26f,
        x,
        y + 3,
        x - size * .55f,
        y - size * .2f);
    poly(
        c,
        0xffa7aa8b,
        x,
        y - size * .26f,
        x + size * .6f,
        y - size * .57f,
        x + size * .6f,
        y - size * .22f,
        x,
        y + 3);
    poly(
        c,
        0xffbd8558,
        x - size * .69f,
        y - size * .49f,
        x - size * .14f,
        y - size,
        x + size * .72f,
        y - size * .57f,
        x,
        y - size * .19f);
    poly(
        c,
        0xffe4b17a,
        x - size * .69f,
        y - size * .49f,
        x - size * .14f,
        y - size,
        x,
        y - size * .19f);
    rect(c, 0xff263d3b, x + size * .15f, y - size * .35f, x + size * .34f, y - size * .05f, 1);
    if (lit) rect(c, GOLD, x - size * .36f, y - size * .39f, x - size * .2f, y - size * .25f, 1);
  }

  @Override
  protected void onDraw(Canvas c) {
    super.onDraw(c);
    float scale = getWidth() / 360f;
    c.save();
    c.scale(scale, arena ? scale : getHeight() / 235f);
    if (arena) c.translate(0, getHeight() / scale - 225);
    float t = (SystemClock.uptimeMillis() - start) / 1000f;
    boolean motion = !g.s.optBoolean("still");
    p.setShader(sky);
    c.drawRect(0, 0, 360, 235, p);
    p.setShader(null);
    oval(c, 0xff24454d, 292, 36, 25, 25);
    oval(c, 0xff46686a, 292, 36, 18, 18);
    poly(
        c,
        0xff1c3d43,
        0,
        97,
        40,
        45,
        83,
        81,
        121,
        39,
        184,
        95,
        226,
        65,
        277,
        94,
        315,
        58,
        360,
        97,
        360,
        130,
        0,
        130);
    poly(
        c,
        0xff25474a,
        0,
        121,
        57,
        92,
        91,
        108,
        156,
        78,
        219,
        112,
        262,
        88,
        320,
        113,
        360,
        91,
        360,
        166,
        0,
        166);
    if (arena) drawArena(c, t, motion);
    else drawCamp(c, t, motion);
    c.restore();
    if (running && motion && isShown()) postInvalidateDelayed(33);
  }

  private void drawCamp(Canvas c, float t, boolean motion) {
    oval(c, 0x35000000, 182, 208, 142, 18);
    poly(c, 0xff233c38, 24, 145, 167, 85, 333, 143, 313, 187, 184, 232, 48, 182);
    poly(c, 0xff37534a, 24, 145, 167, 85, 333, 143, 185, 205);
    poly(c, 0xff416355, 24, 145, 167, 85, 181, 155, 185, 205);
    poly(c, 0xff254848, 24, 153, 185, 211, 333, 151, 313, 187, 184, 232, 48, 182);
    poly(
        c,
        0xff38858a,
        191,
        96,
        212,
        103,
        190,
        124,
        226,
        144,
        262,
        149,
        263,
        167,
        222,
        160,
        171,
        133,
        172,
        118);
    line(c, 0xff67b5ae, 1.2f, 205, 106, 185, 125, 224, 149, 250, 156);
    for (int i = 0; i < 10; i++) {
      float x = 57 + i * 23;
      tree(c, x, 133 - (float) Math.sin(i * .8) * 17, 23 + i % 3 * 5);
    }
    line(c, 0xff9f9978, 13, 63, 163, 131, 156, 185, 168, 265, 145);
    line(c, 0xffb6ab83, 8, 63, 163, 131, 156, 185, 168, 265, 145);
    if (g.has(2)) {
      poly(c, 0xff795c45, 210, 143, 226, 135, 248, 148, 232, 156);
      for (int i = 0; i < 6; i++)
        line(c, 0xffc49e70, 2, 212 + i * 4, 144 + i * 2, 226 + i * 4, 136 + i * 2);
      line(c, 0xffe1b982, 2, 211, 138, 234, 151);
      line(c, 0xffe1b982, 2, 227, 130, 250, 143);
    } else {
      line(c, 0xff797653, 3, 203, 146, 212, 151);
      line(c, 0xff797653, 3, 243, 143, 252, 148);
    }
    if (g.has(0)) {
      poly(c, 0xff523f32, 72, 168, 112, 151, 150, 166, 109, 185);
      for (int i = 0; i < 5; i++)
        for (int j = 0; j < 4; j++) {
          float x = 80 + i * 7 + j * 6, y = 168 - i * 3 + j * 3;
          line(c, 0xffa49261, 1, x - 3, y, x + 3, y + 3);
          float h = g.s.optInt("growth") == 2 ? 8 : 4;
          line(c, g.s.optInt("growth") == 2 ? GOLD : MINT, 1.5f, x, y, x, y - h);
          if (h == 8) {
            oval(c, GOLD, x - 2, y - 5, 2, 1);
            oval(c, GOLD, x + 2, y - 7, 2, 1);
          }
        }
    } else {
      poly(c, 0xff53705a, 78, 166, 110, 153, 141, 166, 109, 179);
      line(c, 0xff749179, 1, 85, 164, 114, 176);
      line(c, 0xff749179, 1, 96, 159, 127, 171);
    }
    if (g.has(1)) {
      hut(c, 153, 144, 41, true);
      line(c, 0xff646357, 7, 158, 117, 158, 101);
      if (motion) {
        for (int i = 0; i < 3; i++) {
          float rise = (t * 9 + i * 10) % 35;
          oval(
              c,
              Color.argb((int) (75 - rise), 159, 181, 175),
              158 + (float) Math.sin(t + i) * 4,
              100 - rise,
              3 + rise * .12f,
              3 + rise * .12f);
        }
      }
    } else {
      poly(c, 0xffd0a16d, 116, 143, 137, 113, 153, 143);
      poly(c, 0xff906d4e, 137, 113, 167, 134, 153, 143);
      poly(c, 0xff35463d, 135, 139, 141, 124, 147, 140);
    }
    if (g.has(3)) hut(c, 204, 184, 49, true);
    else {
      rect(c, 0xff645843, 182, 180, 206, 185, 1);
      line(c, 0xffb4996b, 2, 185, 186, 185, 190);
      line(c, 0xffb4996b, 2, 203, 186, 203, 190);
    }
    oval(c, 0xff483c30, 159, 168, 9, 4);
    poly(c, GOLD, 153, 168, 158, 153 - (motion ? (float) Math.sin(t * 5) * 2 : 0), 163, 168);
    poly(c, 0xffef8d53, 157, 168, 161, 158, 165, 168);
    unit(c, 174, 162, MINT, 0, t, motion);
    unit(c, 120, 147, 0xffe4cba7, 0, t + 1, motion);
    if (g.s.optBoolean("completed")) {
      float x = motion ? 265 + (float) Math.sin(t * .15) * 8 : 265;
      rect(c, 0xffc89f6c, x - 11, 139, x + 11, 149, 3);
      oval(c, 0xff1f3535, x - 6, 150, 3, 3);
      oval(c, 0xff1f3535, x + 7, 150, 3, 3);
      poly(c, 0xffdce1be, x - 12, 139, x, 128, x + 12, 139);
    }
    for (int i = 0; i < 6; i++) {
      float x = 95 + i * 31, y = 88 + (i * 13) % 22;
      if (motion) y += (float) Math.sin(t * .4 + i) * 2;
      line(c, 0xff6b9291, 1, x - 2, y, x, y + 1, x + 2, y);
    }
  }

  private void unit(Canvas c, float x, float y, int col, int action, float t, boolean motion) {
    float bob = motion ? (float) Math.sin(t * 3) * .7f : 0;
    oval(c, 0x50000000, x, y + 1, 9, 3);
    line(c, 0xff263d40, 3, x - 3, y, x - 3, y - 7, x + 2, y - 7, x + 4, y);
    poly(c, col, x - 7, y - 7 + bob, x - 5, y - 18 + bob, x + 5, y - 18 + bob, x + 7, y - 7 + bob);
    oval(c, 0xffe1c3a1, x, y - 23 + bob, 4, 4);
    poly(
        c,
        0xff627b75,
        x - 5,
        y - 22 + bob,
        x - 4,
        y - 28 + bob,
        x + 4,
        y - 28 + bob,
        x + 5,
        y - 22 + bob);
    if (action == 1) {
      oval(c, 0xffd1be8e, x - 7, y - 13, 5, 7);
      line(c, 0xff7d785e, 1, x - 7, y - 19, x - 7, y - 8);
    } else line(c, 0xffd8e2d9, 2, x + 5, y - 13, x + 13, y - 26);
  }

  private void drawArena(Canvas c, float t, boolean motion) {
    poly(c, 0xff35594f, 0, 155, 88, 115, 179, 138, 268, 103, 360, 146, 360, 235, 0, 235);
    poly(c, 0xff28453f, 0, 184, 104, 160, 204, 185, 300, 148, 360, 166, 360, 235, 0, 235);
    line(c, 0xff6a7660, 35, 13, 188, 126, 168, 238, 169, 351, 143);
    for (int i = 0; i < 5; i++) tree(c, 20 + i * 78, 158 - i % 2 * 13, 34 + i % 3 * 7);
    rect(c, 0xff768377, 24, 162, 70, 176, 3);
    rect(c, 0xff778074, 278, 131, 326, 145, 3);
    org.json.JSONObject b = g.battle();
    if (b == null) return;
    String phase = b.optString("phase");
    boolean hit = phase.equals("aftermath");
    int a = b.optInt("action"), e = b.optInt("committed");
    int outcome =
        hit && b.optJSONObject("result") != null ? b.optJSONObject("result").optInt("outcome") : 0;
    float pulse = hit && motion ? Math.max(0, 1 - t / .9f) : 0;
    float ground =
        (b.optInt("hp") / (b.optBoolean("ration") ? 40f : 36f)
                - b.optInt("enemyHp") / (float) b.optInt("enemyMaxHp", 36))
            * 23;
    c.save();
    c.translate(ground, 0);
    unit(c, 101 + pulse * 15, 179, MINT, phase.equals("question") ? 1 : a, t, motion);
    unit(c, 256 - pulse * 15, 170, 0xffefaa91, hit ? e : 1, t + 2, motion);
    if (hit) {
      if (outcome == 2) {
        line(c, 0xffeead93, 2.5f, 241, 151, 117, 158);
      } else if (a == 2) {
        p.setColor(MINT);
        p.setStrokeWidth(2);
        p.setStyle(Paint.Style.STROKE);
        c.drawArc(100, 146, 268, 204, 0, 180, false, p);
        p.setStyle(Paint.Style.FILL);
      } else if (a == 1) {
        color(0x889fe1b3);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(3);
        c.drawCircle(103, 164, 23, p);
        p.setStyle(Paint.Style.FILL);
      } else line(c, MINT, 2, 117, 158, 241, 151);
      color(outcome == 1 ? MINT : outcome == 2 ? 0xffeead93 : GOLD);
      for (int i = 0; i < 8; i++) {
        float angle = i * .785f;
        float radius = 8 + ((t * 15) % 25);
        c.drawCircle(
            (outcome == 2 ? 110 : 248) + (float) Math.cos(angle) * radius,
            152 + (float) Math.sin(angle) * radius,
            1.5f,
            p);
      }
    } else {
      color(0xff6f9990);
      p.setStyle(Paint.Style.STROKE);
      p.setStrokeWidth(1);
      c.drawOval(78, 172, 126, 187, p);
      c.drawOval(232, 163, 280, 179, p);
      p.setStyle(Paint.Style.FILL);
    }
    rect(c, 0xff152e32, 79, 191, 126, 196, 2);
    rect(c, MINT, 79, 191, 79 + 47 * b.optInt("hp") / (b.optBoolean("ration") ? 40f : 36f), 196, 2);
    rect(c, 0xff152e32, 233, 183, 280, 188, 2);
    rect(
        c,
        0xffeead93,
        233,
        183,
        233 + 47 * b.optInt("enemyHp") / (float) b.optInt("enemyMaxHp", 36),
        188,
        2);
    line(c, 0xff9a9b7f, 2, 182, 146, 182, 118);
    poly(c, 0xffd3b477, 182, 118, 199, 124, 182, 130);
    c.restore();
  }

  @Override
  protected void onDetachedFromWindow() {
    running = false;
    super.onDetachedFromWindow();
  }

  @Override
  protected void onAttachedToWindow() {
    super.onAttachedToWindow();
    running = true;
    invalidate();
  }

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
