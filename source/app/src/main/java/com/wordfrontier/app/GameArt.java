package com.wordfrontier.app;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.View;
import java.io.InputStream;
import java.util.HashMap;
import org.json.JSONObject;

/** Raster game art with native, state-driven placement and battle animation. */
public final class GameArt extends View {
  private static final HashMap<String, Bitmap> CACHE = new HashMap<>();
  private final Paint paint = new Paint(3);
  private final Rect backgroundRect = new Rect();
  private final RectF spriteRect = new RectF();
  private static final int[] DRAW_ORDER = {2, 0, 1, 3};
  private static final String[] BUILDINGS = {"garden", "workshop", "bridge", "hall"},
      RIVALS = {"fox", "guardian", "raven", "raven"};
  private LinearGradient shade;
  private final Typeface damageFace = Typeface.create("sans-serif-black", Typeface.NORMAL);
  private final Game game;
  private final String mode;
  private final long began = SystemClock.uptimeMillis();
  private boolean attached;
  public static final float[][] SITES = {{.26f, .43f}, {.75f, .49f}, {.53f, .28f}, {.29f, .65f}};

  public GameArt(Context c, Game g, String mode) {
    super(c);
    this.game = g;
    this.mode = mode;
    setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
  }

  public static Bitmap bitmap(Context context, String name) {
    if (CACHE.containsKey(name)) return CACHE.get(name);
    try (InputStream in = context.getAssets().open("art/" + name + ".webp")) {
      Bitmap b = BitmapFactory.decodeStream(in);
      CACHE.put(name, b);
      return b;
    } catch (Exception e) {
      return null;
    }
  }

  private void sprite(Canvas c, String name, float x, float y, float width, float alpha) {
    Bitmap b = bitmap(getContext(), name);
    if (b == null) return;
    float h = width * b.getHeight() / b.getWidth();
    paint.setAlpha((int) (255 * alpha));
    spriteRect.set(x - width / 2, y - h, x + width / 2, y);
    c.drawBitmap(b, null, spriteRect, paint);
    paint.setAlpha(255);
  }

  @Override
  protected void onDraw(Canvas c) {
    int w = getWidth(), h = getHeight();
    if (w == 0 || h == 0) return;
    Bitmap bg = bitmap(getContext(), "valley");
    if (bg != null) c.drawBitmap(bg, null, backgroundRect, paint);
    float t = (SystemClock.uptimeMillis() - began) / 1000f;
    boolean still = game.s.optBoolean("still");
    if (mode.equals("home") || mode.equals("welcome")) {

      for (int i : DRAW_ORDER) {
        float x = w * SITES[i][0], y = h * SITES[i][1];
        if (game.has(i))
          sprite(
              c,
              i == 0 ? "garden-" + game.s.optInt("growth") : BUILDINGS[i],
              x,
              y,
              w * (i == 2 ? .29f : .39f),
              1);
        else {
          paint.setColor(0x49ffffff);
          c.drawOval(x - w * .13f, y - h * .028f, x + w * .13f, y + h * .004f, paint);
          paint.setColor(0xffffffff);
        }
      }
      sprite(
          c, "ranger", w * .61f, h * .75f + (still ? 0 : (float) Math.sin(t * 2) * 2), w * .21f, 1);
      if (game.s.optBoolean("completed")) sprite(c, "fox", w * .48f, h * .8f, w * .17f, 1);
    } else {
      JSONObject b = game.battle();
      int enemy =
          mode.equals("deploy") ? game.s.optInt("previewEnemy") : b == null ? 0 : b.optInt("enemy");
      String rival = RIVALS[enemy];
      float base = h * (mode.equals("learn") ? .41f : .37f),
          bob = still ? 0 : (float) Math.sin(t * 2.4) * 3;
      float lunge = 0;
      if (!still
          && mode.equals("battle")
          && b != null
          && b.optString("phase").equals("aftermath")
          && t < .75) lunge = (float) Math.sin(Math.min(1, t / .75) * Math.PI) * w * .16f;
      if (mode.equals("learn") || mode.equals("practice") || mode.equals("calibrate")) {
        sprite(c, "ranger", w * .5f, base + bob, w * .45f, 1);
      } else {
        sprite(c, "ranger", w * .25f + lunge, base + bob, w * .37f, 1);
        sprite(c, rival, w * .77f - lunge * .3f, base - bob, w * .36f, 1);
        if (mode.equals("battle") && b != null) {
          health(
              c,
              w * .08f,
              h * .14f,
              w * .34f,
              b.optInt("hp"),
              b.optBoolean("ration") ? 40 : 36,
              0xff69d64f);
          health(
              c,
              w * .59f,
              h * .14f,
              w * .33f,
              b.optInt("enemyHp"),
              b.optInt("enemyMaxHp", 36),
              0xffff745f);
          if (b.optString("phase").equals("aftermath") && b.optJSONObject("result") != null) {
            JSONObject r = b.optJSONObject("result");
            paint.setTypeface(damageFace);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTextSize(w * .09f);
            paint.setColor(Color.WHITE);
            paint.setShadowLayer(3, 0, 3, 0xff733827);
            c.drawText(
                "−" + r.optInt("received"),
                w * .25f,
                base - h * .15f - Math.min(t, 1) * h * .025f,
                paint);
            c.drawText(
                "−" + r.optInt("dealt"),
                w * .77f,
                base - h * .15f - Math.min(t, 1) * h * .025f,
                paint);
            paint.clearShadowLayer();
          }
        }
      }
    }
    paint.setShader(shade);
    c.drawRect(0, 0, w, h, paint);
    paint.setShader(null);
    if (attached && !still) postInvalidateDelayed(mode.equals("battle") ? 33 : 80);
  }

  @Override
  protected void onSizeChanged(int w, int h, int oldw, int oldh) {
    backgroundRect.set(0, 0, w, h);
    shade =
        new LinearGradient(
            0,
            0,
            0,
            h,
            new int[] {0x44072d48, 0x00072d48, 0x00072d48, 0x99345433},
            new float[] {0, .16f, .72f, 1},
            Shader.TileMode.CLAMP);
  }

  private void health(Canvas c, float x, float y, float width, int value, int max, int color) {
    float height = getWidth() * .033f;
    paint.setColor(0xff214057);
    c.drawRoundRect(x - 3, y - 3, x + width + 3, y + height + 3, 10, 10, paint);
    paint.setColor(color);
    c.drawRoundRect(
        x,
        y,
        x + width * Math.max(0, Math.min(1, value / (float) Math.max(1, max))),
        y + height,
        8,
        8,
        paint);
    paint.setColor(Color.WHITE);
    paint.setTextSize(getWidth() * .035f);
    paint.setTypeface(Typeface.DEFAULT_BOLD);
    paint.setTextAlign(Paint.Align.CENTER);
    c.drawText(value + " / " + max, x + width / 2, y - 8, paint);
  }

  @Override
  protected void onAttachedToWindow() {
    super.onAttachedToWindow();
    attached = true;
    invalidate();
  }

  @Override
  protected void onDetachedFromWindow() {
    attached = false;
    super.onDetachedFromWindow();
  }
}
