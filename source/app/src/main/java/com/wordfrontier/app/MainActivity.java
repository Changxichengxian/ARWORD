package com.wordfrontier.app;

import android.app.*;
import android.content.*;
import android.content.res.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.media.*;
import android.net.Uri;
import android.os.*;
import android.text.*;
import android.text.method.LinkMovementMethod;
import android.text.style.ClickableSpan;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.util.*;
import java.util.regex.*;
import org.json.*;

public final class MainActivity extends Activity {
  private static final int BG = 0xff0c181f,
      CARD = 0xff162a32,
      CARD2 = 0xff203841,
      INK = 0xffedf2e7,
      MUTED = 0xffa9beb9,
      MINT = 0xff9fe1b3,
      GOLD = 0xffefc47b,
      RED = 0xfff1ac98;
  private Game game;
  private Content content;
  private LinearLayout outer, body, nav;
  private FrameLayout frame;
  private ScrollView scroll;
  private String screen = "home";
  private MediaPlayer player;
  private AudioManager audioManager;
  private AudioFocusRequest speechFocus;
  private SoundPool sounds;
  private final int[] soundIds = new int[4];
  private final HashSet<Integer> loadedSounds = new HashSet<>();
  private TextView audioStatus;
  private SceneView.Timing timing;
  private int chosenEnemy = 0, chosenLoadout = 0;
  private int wordPage = 0;
  private int visitIndex = 0, visitVersion = 0;
  private boolean useRation = false;
  private String loadWarning = "";
  private static final int EXPORT = 41, IMPORT = 42, EXPORT_ORIGINAL = 43;
  private boolean ready = false;

  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
    speechFocus =
        new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build())
            .setOnAudioFocusChangeListener(
                change -> {
                  if (change < 0) {
                    stopAudio();
                    if (audioStatus != null) audioStatus.setText("声音被打断，可以点播放重听。");
                  }
                })
            .build();
    sounds =
        new SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
            .build();
    sounds.setOnLoadCompleteListener(
        (pool, id, status) -> {
          if (status == 0) loadedSounds.add(id);
        });
    int[] resources = {R.raw.duel_good, R.raw.duel_even, R.raw.duel_bad, R.raw.build_complete};
    for (int i = 0; i < resources.length; i++) soundIds[i] = sounds.load(this, resources[i], 1);
    getWindow().setStatusBarColor(BG);
    getWindow().setNavigationBarColor(BG);
    getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
    if (Build.VERSION.SDK_INT >= 30) getWindow().setDecorFitsSystemWindows(false);
    LinearLayout loading = new LinearLayout(this);
    loading.setGravity(Gravity.CENTER);
    loading.setBackgroundColor(BG);
    TextView t = label("词境前线\n正在打开你的河谷…", 24, INK);
    t.setGravity(Gravity.CENTER);
    loading.addView(t);
    setContentView(loading);
    new Thread(
            () -> {
              try {
                Content c = new Content(this);
                String saved = getPreferences(0).getString("save", "");
                Game g;
                try {
                  g =
                      saved.isEmpty()
                          ? new Game(System.nanoTime())
                          : new Game(new JSONObject(saved));
                  c.validateState(g);
                } catch (Exception bad) {
                  g = new Game(System.nanoTime());
                  loadWarning = "原存档未能读取，已保留原文本。可在设置中导出原存档检查。";
                }
                final Game loaded = g;
                runOnUiThread(
                    () -> {
                      if (isFinishing() || isDestroyed()) {
                        c.dictionary.close();
                        return;
                      }
                      content = c;
                      game = loaded;
                      ready = true;
                      screen = game.s.optBoolean("onboarded") ? "home" : "welcome";
                      render();
                    });
              } catch (Exception e) {
                runOnUiThread(
                    () -> {
                      if (isFinishing() || isDestroyed()) return;
                      loading.removeAllViews();
                      TextView err = label("内容加载失败\n" + e.getMessage(), 18, INK);
                      loading.addView(err);
                    });
              }
            },
            "content-loader")
        .start();
  }

  private int dp(float n) {
    return Math.round(n * getResources().getDisplayMetrics().density);
  }

  private TextView label(String text, float size, int color) {
    TextView t = new TextView(this);
    t.setText(text);
    t.setTextSize(size);
    t.setTextColor(color);
    t.setFontFeatureSettings("kern");
    t.setLineSpacing(dp(3), 1.08f);
    t.setIncludeFontPadding(false);
    return t;
  }

  private TextView heading(String text) {
    TextView t = label(text, 27, INK);
    t.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
    return t;
  }

  private GradientDrawable shape(int color, int radius) {
    GradientDrawable d = new GradientDrawable();
    d.setColor(color);
    d.setCornerRadius(dp(radius));
    return d;
  }

  private void space(LinearLayout parent, int height) {
    Space s = new Space(this);
    parent.addView(s, new LinearLayout.LayoutParams(1, dp(height)));
  }

  private void text(LinearLayout parent, String value, float size, int color) {
    TextView t = label(value, size, color);
    parent.addView(t, new LinearLayout.LayoutParams(-1, -2));
  }

  private LinearLayout column() {
    LinearLayout l = new LinearLayout(this);
    l.setOrientation(LinearLayout.VERTICAL);
    return l;
  }

  private ScrollView scrollingForm(View form) {
    ScrollView container = new ScrollView(this);
    container.setFillViewport(false);
    container.addView(form, new ScrollView.LayoutParams(-1, -2));
    return container;
  }

  private LinearLayout card() {
    LinearLayout c = column();
    c.setPadding(dp(17), dp(17), dp(17), dp(17));
    c.setBackground(shape(CARD, 20));
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
    lp.bottomMargin = dp(12);
    body.addView(c, lp);
    return c;
  }

  private Button button(String title, boolean primary, Runnable action) {
    Button b = new Button(this);
    b.setText(title);
    b.setAllCaps(false);
    b.setTextSize(15);
    b.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
    b.setTextColor(primary ? BG : INK);
    b.setGravity(Gravity.CENTER);
    b.setPadding(dp(14), dp(10), dp(14), dp(10));
    b.setMinHeight(dp(52));
    b.setMinimumHeight(dp(52));
    b.setStateListAnimator(null);
    b.setBackground(
        new RippleDrawable(
            ColorStateList.valueOf(0x337fffff), shape(primary ? MINT : CARD2, 13), null));
    b.setOnClickListener(
        v -> {
          if (game != null && game.s.optBoolean("haptics", true))
            v.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK);
          action.run();
        });
    return b;
  }

  private void btn(LinearLayout parent, String text, boolean primary, Runnable action) {
    Button b = button(text, primary, action);
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
    lp.topMargin = dp(9);
    parent.addView(b, lp);
  }

  private void smallButton(LinearLayout row, String title, boolean active, Runnable fn) {
    Button b = button(title, active, fn);
    b.setTextSize(13);
    b.setPadding(dp(5), dp(10), dp(5), dp(10));
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1);
    lp.setMargins(dp(3), 0, dp(3), 0);
    row.addView(b, lp);
  }

  private LinearLayout row(LinearLayout parent) {
    LinearLayout r = new LinearLayout(this);
    r.setGravity(Gravity.CENTER_VERTICAL);
    parent.addView(r, new LinearLayout.LayoutParams(-1, -2));
    return r;
  }

  private void save() {
    if (!ready) return;
    if (!loadWarning.isEmpty() && !getPreferences(0).contains("unreadable_save"))
      getPreferences(0)
          .edit()
          .putString("unreadable_save", getPreferences(0).getString("save", ""))
          .commit();
    getPreferences(0).edit().putString("save", game.s.toString()).commit();
  }

  private void go(String target) {
    stopAudio();
    screen = target;
    save();
    render();
  }

  private void renderAtSamePosition() {
    int y = scroll == null ? 0 : scroll.getScrollY();
    render();
    scroll.post(() -> scroll.scrollTo(0, y));
  }

  private void render() {
    if (!ready) return;
    audioStatus = null;
    frame = new FrameLayout(this);
    frame.setBackgroundColor(BG);
    outer = column();
    FrameLayout.LayoutParams center =
        new FrameLayout.LayoutParams(
            Math.min(getResources().getDisplayMetrics().widthPixels, dp(760)),
            -1,
            Gravity.CENTER_HORIZONTAL);
    frame.addView(outer, center);
    setContentView(frame);
    if (Build.VERSION.SDK_INT >= 30)
      frame.setOnApplyWindowInsetsListener(
          (v, insets) -> {
            android.graphics.Insets a =
                insets.getInsets(
                    WindowInsets.Type.systemBars()
                        | WindowInsets.Type.displayCutout()
                        | WindowInsets.Type.ime());
            frame.setPadding(a.left, a.top, a.right, a.bottom);
            return insets;
          });
    else frame.setFitsSystemWindows(true);
    LinearLayout top = new LinearLayout(this);
    top.setPadding(dp(22), dp(16), dp(22), dp(12));
    top.setGravity(Gravity.CENTER_VERTICAL);
    TextView brand = label("词境前线", 15, MINT);
    brand.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
    top.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));
    TextView local = label("离线 · 本地对手", 11, MUTED);
    top.addView(local);
    if (!screen.equals("battle")) outer.addView(top);
    scroll = new ScrollView(this);
    scroll.setFillViewport(false);
    scroll.setClipToPadding(false);
    body = column();
    body.setPadding(dp(19), dp(4), dp(19), dp(22));
    scroll.addView(body, new ScrollView.LayoutParams(-1, -2));
    outer.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
    switch (screen) {
      case "welcome":
        welcome();
        break;
      case "deploy":
        deploy();
        break;
      case "battle":
        battle();
        break;
      case "learn":
        learn();
        break;
      case "words":
        wordEvidence();
        break;
      case "visit":
        campVisit();
        break;
      case "practice":
        practice();
        break;
      case "library":
        library();
        break;
      case "custom":
        customArticle();
        break;
      case "settings":
        settings();
        break;
      default:
        home();
    }
    if (!screen.equals("welcome")) {
      nav = new LinearLayout(this);
      nav.setPadding(dp(12), dp(8), dp(12), dp(10));
      nav.setBackgroundColor(BG);
      smallButton(nav, "营地", screen.equals("home"), () -> go("home"));
      smallButton(
          nav,
          "出战",
          screen.equals("battle") || screen.equals("deploy"),
          () -> go(activeBattle() ? "battle" : "deploy"));
      smallButton(
          nav,
          "学习",
          Arrays.asList("learn", "practice", "library", "custom", "words", "visit")
              .contains(screen),
          () -> go("learn"));
      smallButton(nav, "设置", screen.equals("settings"), () -> go("settings"));
      outer.addView(nav, new LinearLayout.LayoutParams(-1, -2));
    }
    frame.requestApplyInsets();
  }

  private void intro(String eyebrow, String title, String description) {
    text(body, eyebrow, 11, MINT);
    space(body, 7);
    body.addView(heading(title));
    space(body, 9);
    text(body, description, 14, MUTED);
    space(body, 21);
  }

  private void welcome() {
    intro("一片可以慢慢改变的地方", "读懂局势。\n建起自己的小站。", "用英语获得情报，靠判断打完一场交锋。然后，把带回的材料变成营地真正的变化。");
    SceneView v = new SceneView(this, game, false);
    v.setBackground(shape(CARD, 20));
    v.setClipToOutline(true);
    body.addView(v, new LinearLayout.LayoutParams(-1, dp(240)));
    space(body, 16);
    LinearLayout c = card();
    text(c, "阅读时可以慢慢来", 18, INK);
    space(c, 9);
    text(c, "没有阅读倒计时。词语能点开查，听力能重播。建筑只有这一章的四项，作物离开后不会枯萎。", 14, MUTED);
    btn(
        c,
        "用 16 题找一个起点",
        true,
        () -> {
          Game.put(game.s, "onboarded", true);
          startCalibration();
        });
    btn(
        c,
        "先用日常短段开始",
        false,
        () -> {
          Game.put(game.s, "onboarded", true);
          go("home");
        });
    text(c, "小测用于安排起点，后续会根据实际理解继续调整。", 12, MUTED);
  }

  private boolean activeBattle() {
    return game.battle() != null && !game.battle().optString("phase").equals("finished");
  }

  private void home() {
    boolean done = game.s.optBoolean("completed");
    intro(
        "河谷纪事  /  第一章",
        done ? "这里，已经是家了。" : "把落脚处，变成小站。",
        done ? "四项建设已经完成。成果会留在这里，今天也可以到此为止。" : "菜圃、工坊、木桥和会馆。完成这四项，让第一辆商车穿过河谷。");
    SceneView scene = new SceneView(this, game, false);
    scene.setBackground(shape(CARD, 20));
    scene.setClipToOutline(true);
    body.addView(scene, new LinearLayout.LayoutParams(-1, dp(245)));
    space(body, 13);
    LinearLayout stats = row(body);
    stat(stats, "建设", game.builtCount() + " / 4");
    stat(stats, "材料", String.valueOf(game.s.optInt("materials")));
    stat(stats, "出战", String.valueOf(game.s.optInt("expeditions")));
    space(body, 18);
    if (!loadWarning.isEmpty()) {
      LinearLayout w = card();
      text(w, loadWarning, 14, RED);
    }
    LinearLayout action = card();
    text(action, activeBattle() ? "有一场尚未结束的交锋" : "下一次改变，从出发开始", 19, INK);
    space(action, 8);
    text(
        action,
        activeBattle() ? "已记住情报、双方状态和当前选择。可以随时接着打。" : "一场最多 8 回合，读、听、判断，再交锋。战败也能带回部分建设材料。",
        14,
        MUTED);
    btn(
        action,
        activeBattle() ? "继续这场交锋" : "准备出战",
        true,
        () -> go(activeBattle() ? "battle" : "deploy"));
    if (done) {
      LinearLayout ending = card();
      text(ending, "第一辆商车，已经过桥。", 21, GOLD);
      space(ending, 9);
      text(ending, "路通了，屋顶不再漏雨，门边有一张留给后来者的地图。你不必立刻再建一座更大的营地。", 15, INK);
      btn(ending, "读这封收尾的来信", false, () -> startStory("s11_" + (game.level(1) >= 2 ? 1 : 0)));
    }
    for (int i = 0; i < 4; i++) {
      if (!game.visitAvailable(i) || game.visitDone(i)) continue;
      final int index = i;
      LinearLayout visitor = card();
      text(
          visitor,
          "河谷来客 · " + content.byId.get(String.format(Locale.ROOT, "e%02d_0", i)).title,
          19,
          GOLD);
      space(visitor, 8);
      text(visitor, "读一段来意，选你更需要的帮助。两种选择都成立，没有限期；也可以稍后再看。", 14, MUTED);
      btn(visitor, "听听来客怎么说", false, () -> openVisit(index));
      break;
    }
    text(body, "想先改变哪一处", 18, INK);
    space(body, 11);
    String[] desc = {
      "种一小块麦田。每完成两次出战成熟，可收获行粮，为下一场增加 4 点耐久。",
      "修好工具，出战时可以选择护具或侦察配装。各有用途，不叠加无限数值。",
      "接通河的另一岸，遇见会观察你旧打法的对手：灰鸦。",
      "为旅人留一个落脚处。四项建设齐备后，第一辆商车将通过小站。"
    };
    for (int i = 0; i < 4; i++) {
      final int index = i;
      LinearLayout c = card();
      text(
          c,
          (game.has(i) ? "✓  " : "0" + (i + 1) + "  ") + Game.BUILDINGS[i],
          19,
          game.has(i) ? MINT : INK);
      space(c, 8);
      text(c, desc[i], 14, MUTED);
      if (!game.has(i)) {
        boolean can = game.s.optInt("materials") >= Game.COSTS[i];
        btn(
            c,
            "建造 · "
                + Game.COSTS[i]
                + " 材料"
                + (can ? "" : "（现有 " + game.s.optInt("materials") + "）"),
            can,
            () -> {
              if (game.build(index)) {
                playEffect(3);
                save();
                render();
                toast("建设完成。这个变化会一直保留。");
              } else
                toast(
                    "还需要 " + (Game.COSTS[index] - game.s.optInt("materials")) + " 份材料。出战无论输赢都有收获。");
            });
      } else if (i == 0) {
        space(c, 8);
        text(
            c,
            "麦田生长 "
                + game.s.optInt("growth")
                + " / 2  ·  行粮 "
                + game.s.optInt("provisions")
                + " / 9",
            14,
            GOLD);
        btn(
            c,
            game.s.optInt("growth") >= 2 ? "收获一份行粮" : "已种好，随出战慢慢长",
            game.s.optInt("growth") >= 2,
            () -> {
              if (game.s.optInt("provisions") >= 9) {
                toast("行粮已满，留在田里也不会坏。");
                return;
              }
              if (game.harvest()) {
                save();
                render();
                toast("收获了。麦田已经重新播种。");
              } else toast("再完成 " + (2 - game.s.optInt("growth")) + " 次出战就能收获；不用等现实时间。");
            });
      }
    }
    btn(body, "去来信室坐一会儿", false, () -> go("library"));
  }

  private void stat(LinearLayout row, String name, String value) {
    LinearLayout c = column();
    text(c, value, 23, INK);
    space(c, 4);
    text(c, name, 12, MUTED);
    row.addView(c, new LinearLayout.LayoutParams(0, -2, 1));
  }

  private void deploy() {
    intro("每一场都可以学会一点", "挑一个对手。", "对手会先决定动作，再等你选择。不会读取你这回合按了什么，也不会暗中强制你输。");
    String[] descriptions = {
      "偏好突击，有时会突然固守。用固守应对突击，也要提防其变招。",
      "常守住有利位置。迂回能绕开防线，盲目进攻容易吃亏。",
      "偏爱绕侧，行动比较灵活。突击可以在它迂回时截住它。",
      "观察你最近三次行动，常反制你用得最多的招。连续重复就容易被摸透。"
    };
    LinearLayout rivals = card();
    for (int i = 0; i < 4; i += 2) {
      LinearLayout rr = row(rivals);
      for (int j = i; j < i + 2; j++) {
        final int k = j;
        smallButton(
            rr,
            Game.ENEMIES[j] + (j == 3 && !game.has(2) ? "\n木桥解锁" : ""),
            chosenEnemy == j,
            () -> {
              if (k == 3 && !game.has(2)) {
                toast("修好木桥后，就能遇到灰鸦。");
                return;
              }
              chosenEnemy = k;
              render();
            });
      }
      space(rivals, 8);
    }
    text(rivals, descriptions[chosenEnemy], 14, MUTED);
    LinearLayout difficulty = card();
    text(difficulty, "交锋强度", 18, INK);
    space(difficulty, 10);
    LinearLayout dr = row(difficulty);
    String[] names = {"轻松", "标准", "强敌"};
    for (int i = 0; i < 3; i++) {
      final int p = i;
      smallButton(
          dr,
          names[i],
          game.s.optInt("pressure", 1) == i,
          () -> {
            Game.put(game.s, "pressure", p);
            save();
            render();
          });
    }
    space(difficulty, 9);
    text(
        difficulty,
        new String[] {
                  "对手耐久 30，情报可靠度 80%，适合先熟悉规则。",
                  "对手耐久 36，情报可靠度 65%，需要判断和留体力。",
                  "对手耐久 42，情报可靠度 55%，更依赖习惯、体力和出手。"
                }
                [game.s.optInt("pressure", 1)]
            + " 英语长度单独调整。",
        13,
        MUTED);
    LinearLayout load = card();
    text(load, "带什么出发", 19, INK);
    space(load, 9);
    if (game.has(1)) {
      LinearLayout lr = row(load);
      smallButton(
          lr,
          "轻装\n情报 +10%",
          chosenLoadout == 2,
          () -> {
            chosenLoadout = 2;
            render();
          });
      smallButton(
          lr,
          "护具\n前两回合减伤",
          chosenLoadout == 1,
          () -> {
            chosenLoadout = 1;
            render();
          });
      smallButton(
          lr,
          "常规",
          chosenLoadout == 0,
          () -> {
            chosenLoadout = 0;
            render();
          });
    } else {
      text(load, "常规配装。工坊建成后可选护具减伤，或轻装提高情报可靠度。", 14, MUTED);
      chosenLoadout = 0;
    }
    if (game.s.optInt("provisions") > 0) {
      btn(
          load,
          (useRation ? "✓ " : "") + "携带行粮 · 开场耐久 +4（库存 " + game.s.optInt("provisions") + "）",
          useRation,
          () -> {
            useRation = !useRation;
            render();
          });
    }
    btn(
        body,
        "出发 · 最多 8 回合",
        true,
        () -> {
          game.start(chosenEnemy, chosenLoadout, useRation, System.currentTimeMillis());
          save();
          go("battle");
        });
    btn(body, "先看交锋规则", false, this::rules);
  }

  private void rules() {
    new AlertDialog.Builder(this)
        .setTitle("怎样打赢一场交锋")
        .setMessage(
            "1. 先读或听情报，判断侦察时的动向。查词、字幕随时可用，独立答对有 1 点先手伤害。\n\n"
                + "2. 选战术：固守克制突击，迂回克制固守，突击克制迂回。克制时造成 6 点、承受 1 点；相同时双方 3 点；被克制时相反。\n\n"
                + "3. 体力初始 3，上限 4。突击消耗 2，迂回消耗 1，固守恢复 2；双方遵守同一规则。出手时机增加 0–2 点伤害，可选固定 +1"
                + " 的稳定出手。对手出手加成：轻松固定 +1，标准 +1 或 +2，强敌固定 +2。阅读没有限时。\n\n"
                + "4. 情报可能过时或判断有误。轻松、标准、强敌的整体报告准确率分别为 80%、65%、55%，轻装再提高 10"
                + " 个百分点。单次还要结合体力和习惯判断。对手在你选择前已决定动作。\n\n"
                + "5. 一方耐久耗尽或达到 8 回合后，比剩余耐久。胜利带回 8 份材料，平局 6 份，战败 5 份。中途暂停可以继续，撤离则无材料。\n\n"
                + "这里的对手是本地程序，无法替代真人对战的社交感。")
        .setPositiveButton("明白了", null)
        .show();
  }

  private void toast(String text) {
    Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
  }

  private Content.Q battleQuestion() {
    JSONObject b = game.battle();
    Content.Q q = content.byId.get(b.optString("question"));
    if (q == null) {
      q = content.choose(game, game.skillThisRound(), b.optInt("report"));
      Game.put(b, "question", q.id);
      save();
    }
    return q;
  }

  private void battle() {
    JSONObject b = game.battle();
    if (b == null) {
      screen = "deploy";
      deploy();
      return;
    }
    String phase = b.optString("phase");
    if (phase.equals("finished")) {
      battleEnd();
      return;
    }
    int round = b.optInt("round") + (phase.equals("aftermath") ? 0 : 1);
    text(
        body,
        "第 " + Math.min(8, round) + " / 8 回合  ·  " + Game.ENEMIES[b.optInt("enemy")],
        18,
        INK);
    space(body, 7);
    text(
        body,
        phase.equals("question")
            ? "读消息时，战斗暂停。"
            : phase.equals("aim") ? "等你准备好了，再出手。" : "你可以读懂对手，也可以改变自己的打法。",
        12,
        MUTED);
    space(body, 13);
    LinearLayout numbers = row(body);
    stat(numbers, "我方耐久", String.valueOf(b.optInt("hp")));
    stat(numbers, "对方耐久", String.valueOf(b.optInt("enemyHp")));
    stat(numbers, "我方 / 对方体力", b.optInt("energy", 3) + " / " + b.optInt("enemyEnergy", 3));
    space(body, 12);
    SceneView field = new SceneView(this, game, true);
    field.setBackground(shape(CARD, 20));
    field.setClipToOutline(true);
    body.addView(
        field, new LinearLayout.LayoutParams(-1, dp(phase.equals("question") ? 110 : 145)));
    space(body, 14);
    if (phase.equals("question")) {
      Content.Q q = battleQuestion();
      renderQuestion(
          q,
          b,
          (selected, correct) -> {
            if (!b.optString("phase").equals("question")) return;
            boolean helped = b.optBoolean("hinted") || (q.skill == 2 && !b.optBoolean("played"));
            game.record(
                q.id,
                q.skill,
                q.word,
                correct,
                helped,
                System.currentTimeMillis(),
                q.skill == 1 ? q.words() : 0,
                0);
            game.answer(correct, helped, selected);
            save();
            stopAudio();
            render();
          });
    } else if (phase.equals("feedback") || phase.equals("tactic")) {
      if (phase.equals("feedback")) {
        Content.Q q = content.byId.get(b.optString("question"));
        LinearLayout feedback = card();
        boolean independent = b.optBoolean("correct") && !b.optBoolean("hinted");
        LinearLayout feedbackHead = row(feedback);
        TextView verdict =
            label(
                independent
                    ? "✓ " + new String[] {"认对词义", "读懂情报", "听懂情报", "组好指令"}[q.skill] + " · 先手 +1"
                    : b.optBoolean("correct") ? "借助帮助，也读懂了" : "把这一处弄懂，再出手",
                18,
                independent ? MINT : GOLD);
        feedbackHead.addView(verdict, new LinearLayout.LayoutParams(0, -2, 1));
        feedbackHead.addView(
            button(
                "复看",
                false,
                () ->
                    new AlertDialog.Builder(this)
                        .setTitle("这条表达")
                        .setMessage(q.text + "\n\n" + q.explain)
                        .setPositiveButton("继续", null)
                        .show()),
            new LinearLayout.LayoutParams(dp(76), -2));
        space(feedback, 8);
        if (!b.optBoolean("correct") || q.skill == 0 || q.skill == 3) {
          if (q.skill == 3) text(feedback, q.text, 17, INK);
          text(feedback, q.explain, 14, MUTED);
        }
      }
      LinearLayout c = card();
      text(c, "侦察动向 · " + Game.ACTIONS[b.optInt("report")], 21, MINT);
      space(c, 8);
      text(c, "侦察整体准确率约 " + b.optInt("reliability") + "%。这一次还要结合对手习惯和体力判断。", 14, MUTED);
      space(c, 11);
      text(c, "固守挡突击 · 迂回破固守 · 突击截迂回", 14, GOLD);
      JSONArray hist = Game.arr(b, "history");
      if (hist.length() > 0) {
        StringBuilder h = new StringBuilder();
        for (int i = Math.max(0, hist.length() - 3); i < hist.length(); i++) {
          if (h.length() > 0) h.append(" → ");
          h.append(Game.ACTIONS[hist.optInt(i)]);
        }
        space(c, 10);
        text(c, "你最近的打法：" + h, 13, MUTED);
        JSONArray logs = Game.arr(b, "logs");
        StringBuilder enemyMoves = new StringBuilder();
        for (int i = Math.max(0, logs.length() - 3); i < logs.length(); i++) {
          JSONObject previous = logs.optJSONObject(i);
          if (previous != null && previous.has("enemyAction")) {
            if (enemyMoves.length() > 0) enemyMoves.append(" → ");
            enemyMoves.append(Game.ACTIONS[previous.optInt("enemyAction")]);
          }
        }
        if (enemyMoves.length() > 0) text(c, "对手刚才用了：" + enemyMoves, 13, MUTED);
        if (b.optInt("enemy") == 3) text(c, "灰鸦会根据你过去的习惯预判。", 13, RED);
      }
      String[] tips = {"体力 −2 · 克制迂回，被固守克制", "体力 +2 · 克制突击，被迂回克制", "体力 −1 · 克制固守，被突击克制"};
      for (int i = 0; i < 3; i++) {
        final int a = i;
        boolean available = Game.canUse(i, b.optInt("energy", 3));
        Button action =
            button(
                Game.ACTIONS[i] + (available ? "" : " · 体力不足") + "\n" + tips[i],
                false,
                () -> {
                  Game.put(b, "phase", "tactic");
                  game.choose(a);
                  save();
                  render();
                });
        action.setEnabled(available);
        if (!available) action.setAlpha(.45f);
        LinearLayout.LayoutParams ap = new LinearLayout.LayoutParams(-1, -2);
        ap.topMargin = dp(9);
        c.addView(action, ap);
      }
      space(c, 8);
      text(c, "双方体力上限 4。体力不足时，固守能恢复；对手遵守同一消耗规则。", 12, MUTED);
      btn(
          body,
          "再看一眼情报",
          false,
          () -> {
            Content.Q q = content.byId.get(b.optString("question"));
            new AlertDialog.Builder(this)
                .setTitle("侦察记录")
                .setMessage(q.text + "\n\n" + q.explain)
                .setPositiveButton("继续判断", null)
                .show();
          });
    } else if (phase.equals("aim")) {
      LinearLayout c = card();
      text(c, "已选：" + Game.ACTIONS[b.optInt("action")], 21, INK);
      space(c, 9);
      text(
          c,
          game.s.optBoolean("still")
              ? "减少动画已开启，出手固定加成 +1。准备好了再点，不限时。"
              : "游标到中央亮绿区时点出手，额外伤害 +2。也可稳定出手，固定 +1。没有等待上限。",
          14,
          MUTED);
      timing = new SceneView.Timing(this, game.s.optBoolean("still"));
      c.addView(timing, new LinearLayout.LayoutParams(-1, dp(75)));
      btn(c, "出手", true, () -> resolve(timing.precision()));
      btn(c, "稳定出手 · +1", false, () -> resolve(1));
    } else if (phase.equals("aftermath")) {
      JSONObject r = b.optJSONObject("result");
      LinearLayout c = card();
      text(
          c,
          r.optString("headline"),
          25,
          r.optInt("outcome") == 1 ? MINT : r.optInt("outcome") == 2 ? RED : GOLD);
      space(c, 10);
      text(c, "造成 " + r.optInt("dealt") + " 点  ·  承受 " + r.optInt("received") + " 点", 20, INK);
      space(c, 10);
      text(c, r.optString("detail"), 15, MUTED);
      if (!r.optString("reaction").isEmpty()) {
        space(c, 12);
        text(c, "对手回应 · “" + r.optString("reaction") + "”", 16, GOLD);
      }
      space(c, 7);
      text(
          c,
          "你的出手加成 +" + r.optInt("precision") + " · 对手出手加成 +" + r.optInt("enemyPrecision"),
          13,
          GOLD);
      btn(
          c,
          game.battleOver() ? "查看这次出战的收获" : "下一回合",
          true,
          () -> {
            if (game.battleOver()) game.finish();
            else game.prepareRound();
            save();
            render();
          });
    }
    btn(body, "先回营地，保留这一局", false, () -> go("home"));
  }

  private void resolve(int precision) {
    JSONObject b = game.battle();
    if (b == null || !b.optString("phase").equals("aim")) return;
    game.resolve(precision);
    save();
    int outcome = b.optJSONObject("result").optInt("outcome");
    playEffect(outcome == 1 ? 0 : outcome == 2 ? 2 : 1);
    render();
  }

  private void playEffect(int kind) {
    if (sounds != null
        && game != null
        && game.s.optBoolean("sound", true)
        && loadedSounds.contains(soundIds[kind])) sounds.play(soundIds[kind], .35f, .35f, 1, 0, 1f);
  }

  private void battleEnd() {
    JSONObject b = game.battle();
    intro(
        "一场交锋，已经结束",
        b.optBoolean("win") ? "这次，你掌握了局面。" : b.optBoolean("tie") ? "势均力敌。" : "这次没拿下，也有收获。",
        "材料已带回营地。新学到的表达和已经建好的东西都会保留。");
    SceneView s = new SceneView(this, game, false);
    body.addView(s, new LinearLayout.LayoutParams(-1, dp(210)));
    space(body, 15);
    LinearLayout c = card();
    text(c, "+ " + b.optInt("reward") + " 份建设材料", 28, MINT);
    space(c, 10);
    text(
        c,
        "交锋 " + b.optInt("round") + " 回合 · 耐久 " + b.optInt("hp") + " : " + b.optInt("enemyHp"),
        16,
        INK);
    space(c, 10);
    text(
        c,
        b.optBoolean("win") ? "可以把这次赢来的东西，变成营地的一处变化。" : "看看哪次选择被反制。下次可以换打法，英语难度也可以单独调。",
        14,
        MUTED);
    btn(c, "回营地，看看能建什么", true, () -> go("home"));
    btn(c, "再挑一个对手", false, () -> go("deploy"));
    JSONArray logs = Game.arr(b, "logs");
    for (int i = 0; i < logs.length(); i++) {
      JSONObject r = logs.optJSONObject(i);
      LinearLayout l = card();
      text(l, "第 " + (i + 1) + " 回合 · " + r.optString("headline"), 16, INK);
      space(l, 7);
      text(l, r.optString("detail"), 13, MUTED);
    }
  }

  private interface Answer {
    void submit(int selection, boolean correct);
  }

  private JSONArray optionOrder(Content.Q q, JSONObject session) {
    JSONArray order = session.optJSONArray("optionOrder");
    if (!q.id.equals(session.optString("optionQuestion"))
        || order == null
        || order.length() != q.options.length) {
      ArrayList<Integer> indices = new ArrayList<>();
      for (int i = 0; i < q.options.length; i++) indices.add(i);
      Collections.shuffle(indices);
      order = new JSONArray();
      for (int i : indices) order.put(i);
      Game.put(session, "optionOrder", order);
      Game.put(session, "optionQuestion", q.id);
      save();
    }
    return order;
  }

  private void renderQuestion(Content.Q q, JSONObject session, Answer answer) {
    boolean feedback = session.optString("phase").equals("feedback");
    LinearLayout c = card();
    text(
        c,
        Game.SKILLS[q.skill]
            + "  /  "
            + Game.LEVELS[q.level]
            + (q.skill == 1 ? " · " + q.words() + " 词" : ""),
        12,
        MINT);
    space(c, 11);
    if (!feedback && q.skill == 1 && q.level > 0) {
      btn(
          c,
          "这段太难，换短一点",
          false,
          () -> {
            game.level(1, Math.max(0, q.level - 1));
            Game.put(Game.obj(game.s, "performance"), "s1", "");
            Game.put(game.s, "adjustment", "阅读已按你的要求缩短。交锋强度不受影响。");
            Content.Q easier =
                session.optString("mode").equals("story")
                    ? content.byId.get(q.id.substring(0, q.id.length() - 1) + "0")
                    : content.choose(game, 1, session.optInt("report"));
            Game.put(session, "question", easier.id);
            Game.put(session, "hinted", false);
            Game.put(session, "played", false);
            Game.put(session, "chosen", new JSONArray());
            save();
            stopAudio();
            renderAtSamePosition();
          });
      space(c, 10);
    }
    if (q.skill == 0) {
      LinearLayout wordHeading = row(c);
      TextView wordTitle = label(q.word, 32, INK);
      wordHeading.addView(wordTitle, new LinearLayout.LayoutParams(0, -2, 1));
      wordHeading.addView(
          button("听读", false, () -> play(q, session, 1f)),
          new LinearLayout.LayoutParams(dp(82), -2));
      space(c, 12);
      addEnglish(c, q.text, session);
    } else if (q.skill == 1) {
      addEnglish(c, q.text, session);
    } else if (q.skill == 2) {
      text(c, "听一段斥候的消息", 22, INK);
      space(c, 7);
      text(c, "录音已在手机里，可反复听。", 13, MUTED);
      audioButtons(c, q, session);
      if (session.optBoolean("transcript") || feedback) {
        space(c, 12);
        addEnglish(c, q.text, session);
      }
      if (!feedback)
        btn(
            c,
            session.optBoolean("transcript") ? "已打开英文字幕" : "打开英文字幕（计为借助帮助）",
            false,
            () -> {
              Game.put(session, "transcript", true);
              Game.put(session, "hinted", true);
              save();
              render();
            });
    } else if (q.skill == 3) {
      text(c, q.translation, 19, INK);
      space(c, 8);
      text(c, "按中文意思组织报告；可点已选词块撤回。", 13, MUTED);
    }
    space(c, 15);
    text(c, q.prompt, 16, INK);
    space(c, 9);
    if (!feedback && session.optString("mode").equals("cal")) {
      CheckBox guessed = new CheckBox(this);
      guessed.setText("这题靠猜测，不计作独立认识");
      guessed.setTextColor(MUTED);
      guessed.setTextSize(13);
      guessed.setChecked(session.optBoolean("guessed"));
      guessed.setOnCheckedChangeListener(
          (v, checked) -> {
            Game.put(session, "guessed", checked);
            save();
          });
      c.addView(guessed);
    }
    if (q.skill == 3) {
      JSONArray chosen = Game.arr(session, "chosen");
      FlowLayout assembled = new FlowLayout(this);
      assembled.setPadding(dp(6), dp(7), dp(6), dp(7));
      assembled.setBackground(shape(BG, 12));
      c.addView(assembled, new LinearLayout.LayoutParams(-1, -2));
      if (chosen.length() == 0) {
        TextView place = label("点下面的词块，在这里组成句子", 14, MUTED);
        place.setPadding(dp(8), dp(14), dp(8), dp(14));
        assembled.addView(place);
      }
      for (int i = 0; i < chosen.length(); i++) {
        final int pos = i;
        int idx = chosen.optInt(i);
        Button token =
            button(
                q.tokens[idx],
                false,
                () -> {
                  if (feedback) return;
                  JSONArray next = new JSONArray();
                  for (int j = 0; j < chosen.length(); j++)
                    if (j != pos) next.put(chosen.optInt(j));
                  Game.put(session, "chosen", next);
                  save();
                  renderAtSamePosition();
                });
        token.setTextSize(14);
        assembled.addView(token);
      }
      if (!feedback) {
        space(c, 10);
        FlowLayout available = new FlowLayout(this);
        c.addView(available, new LinearLayout.LayoutParams(-1, -2));
        for (int i = 0; i < q.tokens.length; i++) {
          final int idx = i;
          boolean used = false;
          for (int j = 0; j < chosen.length(); j++) if (chosen.optInt(j) == i) used = true;
          Button token =
              button(
                  q.tokens[i],
                  false,
                  () -> {
                    chosen.put(idx);
                    save();
                    renderAtSamePosition();
                  });
          token.setTextSize(14);
          token.setMinWidth(dp(42));
          token.setMinimumWidth(dp(42));
          if (used) {
            token.setEnabled(false);
            token.setAlpha(.25f);
          }
          available.addView(token);
        }
        btn(
            c,
            "提交这句报告",
            true,
            () -> {
              if (chosen.length() != q.tokens.length) {
                toast("还有词块没放入。也可以直接看示范。");
                return;
              }
              StringBuilder text = new StringBuilder();
              for (int j = 0; j < chosen.length(); j++) {
                if (j > 0) text.append(' ');
                text.append(q.tokens[chosen.optInt(j)]);
              }
              answer.submit(0, q.matches(text.toString()));
            });
        btn(
            c,
            "看示范，先学一遍",
            false,
            () -> {
              Game.put(session, "hinted", true);
              answer.submit(-1, false);
            });
      }
    } else {
      JSONArray order = optionOrder(q, session);
      for (int position = 0; position < order.length(); position++) {
        int i = order.optInt(position);
        final int index = i;
        String prefix =
            feedback && i == q.correct
                ? "✓ "
                : feedback && i == session.optInt("selected") ? "× " : "";
        Button option =
            button(
                prefix + q.options[i],
                feedback && i == q.correct,
                () -> answer.submit(index, index == q.correct));
        option.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        option.setEnabled(!feedback);
        if (feedback && i != q.correct)
          option.setAlpha(i == session.optInt("selected") ? .9f : .55f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(8);
        c.addView(option, lp);
      }
      if (!feedback) {
        btn(c, "还不认识，直接学这条", false, () -> answer.submit(-1, false));
        if (q.skill != 2)
          btn(
              c,
              "看中文帮助（计为借助帮助）",
              false,
              () -> {
                Game.put(session, "hinted", true);
                save();
                new AlertDialog.Builder(this)
                    .setTitle("理解帮助")
                    .setMessage(q.skill == 0 ? q.word + "：" + q.translation : q.translation)
                    .setPositiveButton("继续", null)
                    .show();
              });
      }
    }
    if (feedback) {
      space(c, 15);
      boolean independent = session.optBoolean("correct") && !session.optBoolean("hinted");
      text(
          c,
          independent ? "✓ 独立理解了" : session.optBoolean("correct") ? "✓ 借助帮助理解了" : "再看一遍，就多懂一点",
          20,
          independent ? MINT : GOLD);
      space(c, 10);
      if (q.skill == 3) {
        text(c, q.text, 19, INK);
        space(c, 8);
      }
      text(c, q.explain, 15, MUTED);
      if (independent && screen.equals("battle")) {
        space(c, 8);
        text(c, "这回合获得先手伤害 +1", 14, MINT);
      }
    } else if (q.skill != 3) {
      space(c, 12);
      text(c, "英文词语可以点开查。需要帮助很正常，不会清空进度。", 12, MUTED);
    }
  }

  private void addEnglish(LinearLayout parent, String value, JSONObject session) {
    SpannableString span = new SpannableString(value);
    Matcher m = Pattern.compile("[A-Za-z]+(?:[-'][A-Za-z]+)?").matcher(value);
    while (m.find()) {
      String word = m.group();
      span.setSpan(
          new ClickableSpan() {
            @Override
            public void onClick(View v) {
              if (session != null && session.optString("phase").equals("question")) {
                Game.put(session, "hinted", true);
                save();
              }
              showWord(word);
            }

            @Override
            public void updateDrawState(TextPaint p) {
              p.setColor(INK);
              p.setUnderlineText(false);
            }
          },
          m.start(),
          m.end(),
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    }
    TextView t = label("", 19, INK);
    t.setLineSpacing(dp(7), 1.12f);
    t.setText(span);
    t.setMovementMethod(LinkMovementMethod.getInstance());
    t.setHighlightColor(0x669fe1b3);
    parent.addView(t, new LinearLayout.LayoutParams(-1, -2));
  }

  private void showWord(String word) {
    new AlertDialog.Builder(this)
        .setTitle(word)
        .setMessage(content.lookup(word))
        .setPositiveButton("知道了", null)
        .setNeutralButton(
            "收藏这个词",
            (d, w) -> {
              Game.put(
                  Game.obj(game.s, "savedWords"),
                  word.toLowerCase(Locale.ROOT),
                  System.currentTimeMillis());
              save();
              toast("已加入学习页的收藏词。");
            })
        .show();
  }

  private void audioButtons(LinearLayout c, Content.Q q, JSONObject session) {
    LinearLayout r = row(c);
    smallButton(r, "▶ 播放 / 重播", true, () -> play(q, session, 1f));
    smallButton(r, "0.8 倍慢速", false, () -> play(q, session, .8f));
    audioStatus = label("离线合成录音 · 美式英语", 12, MUTED);
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
    lp.topMargin = dp(9);
    c.addView(audioStatus, lp);
  }

  private void play(Content.Q q, JSONObject session, float speed) {
    try {
      stopAudio();
      if (q.audio.isEmpty()) {
        toast("这条内容没有配套录音。");
        return;
      }
      if (audioManager.requestAudioFocus(speechFocus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
        toast("暂时没能获得声音播放权，请再点一次播放。");
        return;
      }
      AssetFileDescriptor afd = getAssets().openFd(q.audio);
      player = new MediaPlayer();
      player.setAudioAttributes(
          new AudioAttributes.Builder()
              .setUsage(AudioAttributes.USAGE_MEDIA)
              .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
              .build());
      player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
      afd.close();
      player.prepare();
      player.setPlaybackParams(new PlaybackParams().setSpeed(speed));
      if (session != null) Game.put(session, "played", true);
      Game.put(game.s, "audioPlays", game.s.optInt("audioPlays") + 1);
      save();
      if (audioStatus != null)
        audioStatus.setText("正在播放 · " + (speed == 1 ? "原速" : "0.8 倍") + " · 再点可重播");
      final int seconds = player.getDuration() / 1000;
      player.setOnCompletionListener(
          mp -> {
            if (player != mp) return;
            Game.put(game.s, "listenSeconds", game.s.optInt("listenSeconds") + seconds);
            save();
            if (audioStatus != null) audioStatus.setText("播放完毕，可以重听。");
            stopAudio();
          });
      player.setOnErrorListener(
          (mp, what, extra) -> {
            toast("录音未能播放，请重试。");
            stopAudio();
            return true;
          });
      player.start();
    } catch (Exception e) {
      toast("播放失败：" + e.getMessage());
      stopAudio();
    }
  }

  private void stopAudio() {
    if (player != null) {
      try {
        player.stop();
      } catch (Exception ignored) {
      }
      player.release();
      player = null;
    }
    if (audioManager != null && speechFocus != null)
      audioManager.abandonAudioFocusRequest(speechFocus);
  }

  private void learn() {
    intro("进步，来自你真的读懂了", "找到舒服的难度。", "词义、阅读、听力、组句分别观察。一次答对只是线索，隔一段时间还能想起，才更有把握。");
    LinearLayout c = card();
    text(c, "目前观察到的词汇证据", 20, INK);
    space(c, 12);
    LinearLayout r = row(c);
    stat(r, "接触词条", String.valueOf(Game.obj(game.s, "words").length()));
    stat(r, "独立认出", String.valueOf(game.recognizedCount()));
    stat(r, "跨日熟悉", String.valueOf(game.knownCount()));
    space(c, 12);
    text(c, "“跨日熟悉”要求至少 3 次相隔约一天的独立提取，并保有复习进展。它不是你的全部英语词汇量。", 13, MUTED);
    btn(
        c,
        "复习 / 认识 5 个词 · 到期 " + game.dueCount(System.currentTimeMillis()),
        true,
        this::startReview);
    btn(
        c,
        "打开词汇档案",
        false,
        () -> {
          wordPage = 0;
          go("words");
        });
    JSONObject p = game.s.optJSONObject("practice");
    if (p != null && !p.optString("phase").equals("done"))
      btn(c, "继续刚才的学习", false, () -> go("practice"));
    LinearLayout levels = card();
    text(levels, "现在给你的表达长度", 20, INK);
    for (int i = 0; i < 4; i++) {
      space(levels, 8);
      text(levels, Game.SKILLS[i] + "  ·  " + Game.LEVELS[game.level(i)], 15, INK);
    }
    space(levels, 10);
    text(levels, game.s.optString("adjustment", "初始安排还很粗略。根据后续独立理解情况，逐步调整；随时可以自己改。"), 13, MUTED);
    btn(levels, "16 题，重新找词义起点", false, this::startCalibration);
    btn(levels, "自己调节各项难度", false, this::difficultyDialog);
    LinearLayout readings = card();
    text(readings, "今天读得下去的一小段", 20, INK);
    space(readings, 8);
    text(readings, "12 封来信，每封有短版和长版。点词可查，配套录音离线播放，也能加入自己的英文短文。", 14, MUTED);
    btn(readings, "打开来信室", true, () -> go("library"));
    LinearLayout facts = card();
    text(facts, "累计接触", 19, INK);
    space(facts, 10);
    text(
        facts,
        "阅读文本 "
            + game.s.optInt("readWords")
            + " 词次\n完整听完 "
            + game.s.optInt("listenSeconds") / 60
            + " 分 "
            + game.s.optInt("listenSeconds") % 60
            + " 秒\n独立答对 "
            + game.s.optInt("unaided")
            + " / "
            + game.s.optInt("answers")
            + " 次",
        16,
        INK);
    space(facts, 9);
    text(facts, "词次按完成题目、来访选择或标记读完的文本累计；重复完成阅读会重复计数。听力只累计播放到末尾的录音。这些是接触记录，不是学习效果测量。", 12, MUTED);
    LinearLayout dict = card();
    text(dict, "离线查词", 20, INK);
    space(dict, 8);
    EditText word = new EditText(this);
    word.setSingleLine(true);
    word.setHint("输入英文词语");
    word.setHintTextColor(MUTED);
    word.setTextColor(INK);
    word.setTextSize(18);
    word.setInputType(
        android.text.InputType.TYPE_CLASS_TEXT
            | android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
    dict.addView(word, new LinearLayout.LayoutParams(-1, dp(55)));
    btn(
        dict,
        "查这个词",
        false,
        () -> {
          String value = word.getText().toString().trim();
          if (!value.isEmpty()) showWord(value);
        });
    space(dict, 9);
    text(
        dict, "内置词典 " + content.dictionaryCount + " 个词条/词形。精编练习是另一个较小的内容库，词典数量不等于课程数量。", 12, MUTED);
    JSONObject saved = Game.obj(game.s, "savedWords");
    if (saved.length() > 0) {
      LinearLayout savedCard = card();
      text(savedCard, "收藏词", 20, INK);
      Iterator<String> it = saved.keys();
      int n = 0;
      while (it.hasNext() && n++ < 100) {
        String w = it.next();
        btn(savedCard, w, false, () -> showWord(w));
      }
    }
  }

  private void wordEvidence() {
    intro("能看见依据的进步", "这些词，与你照过面。", "只列出内置练习里实际遇到的词。查词、收藏和看到答案，都不会自动增加“独立认出”。");
    JSONObject records = Game.obj(game.s, "words");
    ArrayList<Content.Q> encountered = new ArrayList<>();
    for (Content.Q q : content.vocabulary) if (records.has(q.word)) encountered.add(q);
    encountered.sort(
        (a, b) ->
            Long.compare(
                records.optJSONObject(b.word).optLong("lastSeen"),
                records.optJSONObject(a.word).optLong("lastSeen")));
    if (encountered.isEmpty()) {
      LinearLayout empty = card();
      text(empty, "还没有词义练习记录", 20, INK);
      space(empty, 10);
      text(empty, "先玩一场，或认识五个词。这里会留下具体记录，不给你凭空估一个总词汇量。", 15, MUTED);
      btn(empty, "先认识五个词", true, this::startReview);
    } else {
      wordPage = Math.min(wordPage, (encountered.size() - 1) / 12);
      int start = wordPage * 12, end = Math.min(start + 12, encountered.size());
      text(body, "按最近接触排序 · " + (start + 1) + "–" + end + " / " + encountered.size(), 13, MUTED);
      space(body, 12);
      long now = System.currentTimeMillis();
      for (int i = start; i < end; i++) {
        Content.Q q = encountered.get(i);
        JSONObject evidence = records.optJSONObject(q.word);
        boolean familiar = evidence.optInt("days") >= 3 && evidence.optInt("stage") >= 2;
        LinearLayout c = card();
        text(c, q.word, 26, INK);
        space(c, 8);
        text(
            c,
            familiar ? "跨日熟悉" : evidence.optInt("right") > 0 ? "曾独立认出，还在观察" : "接触过，继续巩固",
            14,
            familiar ? MINT : GOLD);
        space(c, 8);
        text(
            c,
            "独立认出 " + evidence.optInt("right") + " 次 · 间隔约一天的观察 " + evidence.optInt("days") + " 次",
            13,
            MUTED);
        long due = evidence.optLong("due", Long.MAX_VALUE);
        text(c, due <= now ? "现在可复习，晚一点也不会扣进度。" : "已安排稍后再遇见，现在可以休息。", 12, MUTED);
        btn(
            c,
            "看例句和读音",
            false,
            () -> {
              AlertDialog d =
                  new AlertDialog.Builder(this)
                      .setTitle(q.word)
                      .setMessage(q.text + "\n\n" + q.translation + "\n\n" + content.lookup(q.word))
                      .setPositiveButton("关闭", null)
                      .setNeutralButton("听读", null)
                      .create();
              d.setOnShowListener(
                  v ->
                      d.getButton(AlertDialog.BUTTON_NEUTRAL)
                          .setOnClickListener(w -> play(q, null, 1f)));
              d.setOnDismissListener(v -> stopAudio());
              d.show();
            });
      }
      LinearLayout pages = row(body);
      if (wordPage > 0)
        smallButton(
            pages,
            "上一页",
            false,
            () -> {
              wordPage--;
              render();
            });
      if (end < encountered.size())
        smallButton(
            pages,
            "下一页",
            false,
            () -> {
              wordPage++;
              render();
            });
    }
    btn(body, "回到学习页", false, () -> go("learn"));
  }

  private void startCalibration() {
    JSONObject p = new JSONObject();
    Game.put(p, "mode", "cal");
    Game.put(p, "index", 0);
    Game.put(p, "goal", 16);
    Game.put(p, "phase", "question");
    Game.put(p, "scores", new JSONArray().put(0).put(0).put(0).put(0));
    JSONArray ids = new JSONArray();
    for (int level = 0; level < 4; level++) {
      ArrayList<Content.Q> pool = new ArrayList<>();
      for (Content.Q q : content.vocabulary) if (q.level == level) pool.add(q);
      for (int j = 0; j < 4; j++) ids.put(pool.remove(game.nextInt(pool.size())).id);
    }
    Game.put(p, "ids", ids);
    Game.put(p, "question", ids.optString(0));
    Game.put(game.s, "practice", p);
    go("practice");
  }

  private void startReview() {
    JSONObject p = new JSONObject();
    Game.put(p, "mode", "review");
    Game.put(p, "index", 0);
    Game.put(p, "goal", 5);
    Game.put(p, "phase", "question");
    Game.put(p, "right", 0);
    Game.put(p, "question", content.review(game).id);
    Game.put(game.s, "practice", p);
    go("practice");
  }

  private void startStory(String id) {
    JSONObject p = new JSONObject();
    Game.put(p, "mode", "story");
    Game.put(p, "index", 0);
    Game.put(p, "goal", 1);
    Game.put(p, "phase", "question");
    Game.put(p, "question", id);
    Game.put(game.s, "practice", p);
    go("practice");
  }

  private void practice() {
    JSONObject p = game.s.optJSONObject("practice");
    if (p == null) {
      screen = "learn";
      learn();
      return;
    }
    String mode = p.optString("mode");
    if (p.optString("phase").equals("done")) {
      practiceDone(p);
      return;
    }
    Content.Q q = content.byId.get(p.optString("question"));
    if (q == null) {
      game.s.remove("practice");
      screen = "learn";
      learn();
      return;
    }
    intro(
        mode.equals("cal") ? "初始安排 · 不是标准化考试" : mode.equals("story") ? "来信室" : "五个词，一小步",
        mode.equals("story") ? q.title : mode.equals("cal") ? "找一个起点。" : "把表达留在脑海里。",
        mode.equals("story")
            ? "读得懂多少就先读多少。点英文词语可查，录音也可以重复听。"
            : "第 " + (p.optInt("index") + 1) + " / " + p.optInt("goal") + " 条 · 不认识可以直接说，不必硬猜。");
    if (mode.equals("story")) {
      LinearLayout a = card();
      audioButtons(a, q, p);
    }
    renderQuestion(
        q,
        p,
        (selection, correct) -> {
          if (!p.optString("phase").equals("question")) return;
          boolean help =
              p.optBoolean("hinted")
                  || p.optBoolean("guessed")
                  || (q.skill == 2 && !p.optBoolean("played"));
          Game.put(p, "correct", correct);
          Game.put(p, "hinted", help);
          Game.put(p, "selected", selection);
          Game.put(p, "phase", "feedback");
          game.record(
              q.id,
              q.skill,
              q.word,
              correct,
              help,
              System.currentTimeMillis(),
              q.skill == 1 ? q.words() : 0,
              0);
          if (correct && !help) {
            Game.put(p, "right", p.optInt("right") + 1);
            if (mode.equals("cal")) {
              JSONArray scores = Game.arr(p, "scores");
              try {
                scores.put(q.level, scores.optInt(q.level) + 1);
              } catch (Exception e) {
                throw new IllegalStateException(e);
              }
            }
          }
          save();
          stopAudio();
          render();
        });
    if (p.optString("phase").equals("feedback"))
      btn(
          body,
          p.optInt("index") + 1 >= p.optInt("goal") ? "完成这一小段" : "下一条",
          true,
          () -> advancePractice(p));
    if (mode.equals("cal")) {
      btn(body, "暂时停在这里，保留进度", false, () -> go("learn"));
      text(body, "四组表达，每组只抽 4 个词。样本少，只用于初始难度安排；高阶词碰巧认识也很正常。", 12, MUTED);
    } else btn(body, "回到学习页", false, () -> go("learn"));
  }

  private void advancePractice(JSONObject p) {
    int index = p.optInt("index") + 1;
    Game.put(p, "index", index);
    if (index >= p.optInt("goal")) {
      Game.put(p, "phase", "done");
      if (p.optString("mode").equals("cal")) {
        JSONArray scores = Game.arr(p, "scores");
        int level = 0;
        for (int i = 0; i < 4; i++) {
          if (scores.optInt(i) >= 3) level = i;
          else if (i > 0) break;
        }
        game.level(0, level);
        game.level(1, level);
        game.level(2, Math.max(0, level - 1));
        game.level(3, Math.max(0, level - 1));
        Game.put(game.s, "calibrated", true);
        Game.put(game.s, "calibration", new JSONObject());
        Game.put(Game.obj(game.s, "calibration"), "scores", scores);
        Game.put(Game.obj(game.s, "calibration"), "time", System.currentTimeMillis());
        Game.put(game.s, "adjustment", "刚完成词义抽样。阅读暂按相近长度开始，听力和组句稍短；需要分别继续观察。");
      } else if (p.optString("mode").equals("story"))
        Game.put(
            Game.obj(game.s, "readStories"), p.optString("question"), System.currentTimeMillis());
    } else {
      Game.put(
          p,
          "question",
          p.optString("mode").equals("cal")
              ? Game.arr(p, "ids").optString(index)
              : content.review(game).id);
      Game.put(p, "phase", "question");
      Game.put(p, "hinted", false);
      Game.put(p, "guessed", false);
      Game.put(p, "selected", -2);
      Game.put(p, "correct", false);
      Game.put(p, "played", false);
      Game.put(p, "transcript", false);
      Game.put(p, "chosen", new JSONArray());
      p.remove("optionOrder");
      p.remove("optionQuestion");
    }
    save();
    render();
  }

  private void practiceDone(JSONObject p) {
    boolean cal = p.optString("mode").equals("cal"), story = p.optString("mode").equals("story");
    intro(
        "这一小段，已完成",
        cal ? "先从这里开始。" : story ? "信读完了。" : "五个词，留一个印象。",
        cal ? "这是有限样本下的起点，接下来会按实际阅读和听力继续修正。" : "可以再来一点，也可以今天到这里。");
    LinearLayout c = card();
    if (cal) {
      JSONArray scores = Game.arr(p, "scores");
      for (int i = 0; i < 4; i++) {
        text(c, Game.LEVELS[i] + " · 独立认义 " + scores.optInt(i) + " / 4", 17, INK);
        space(c, 9);
      }
      text(c, "不能由这 16 个词推算出精确的全英语词汇量，也不能证明同等听力或写作能力。", 14, MUTED);
    } else {
      text(c, "独立答对 " + p.optInt("right") + " / " + p.optInt("goal"), 24, MINT);
      space(c, 9);
      text(c, "借助提示读懂也有价值。后面会在需要时再遇见这些表达。", 14, MUTED);
    }
    btn(c, cal ? "按这个起点出战" : "返回学习页", true, () -> go(cal ? "deploy" : "learn"));
    if (!cal && !story) btn(c, "再来五个词", false, this::startReview);
    if (story) btn(c, "读另一封来信", false, () -> go("library"));
    btn(c, "回营地", false, () -> go("home"));
  }

  private void library() {
    intro("营地来信室", "读一小段，也算前进。", "同一封信有短版和长版。故事不要求按顺序读，也不需要用材料解锁。");
    btn(body, "加入自己的英文短文", true, this::addArticle);
    space(body, 14);
    LinearLayout visitors = card();
    text(visitors, "河谷来客", 20, GOLD);
    space(visitors, 7);
    text(visitors, "四次有限的来访，随营地建设出现。用英文理解对方的提议，再决定自己想要什么；没有标准答案。", 14, MUTED);
    for (int i = 0; i < 4; i++) {
      if (!game.visitAvailable(i)) continue;
      final int index = i;
      Content.Q visit = content.byId.get(String.format(Locale.ROOT, "e%02d_0", i));
      btn(
          visitors,
          (game.visitDone(i) ? "✓ 回看 · " : "来访 · ") + visit.title,
          false,
          () -> openVisit(index));
    }
    JSONArray personal = Game.arr(game.s, "articles");
    for (int i = 0; i < personal.length(); i++) {
      JSONObject a = personal.optJSONObject(i);
      final int idx = i;
      LinearLayout c = card();
      text(c, a.optString("title"), 20, INK);
      space(c, 7);
      text(c, "自己带来的文本 · " + a.optString("text").trim().split("\\s+").length + " 词", 13, MUTED);
      btn(
          c,
          "打开阅读",
          false,
          () -> {
            Game.put(game.s, "articleIndex", idx);
            go("custom");
          });
    }
    for (int i = 0; i < content.stories.size(); i += 2) {
      Content.Q shortQ = content.stories.get(i), longQ = content.stories.get(i + 1);
      LinearLayout c = card();
      boolean read =
          Game.obj(game.s, "readStories").has(shortQ.id)
              || Game.obj(game.s, "readStories").has(longQ.id);
      text(c, (read ? "✓ " : "") + shortQ.title, 20, INK);
      space(c, 7);
      text(c, "短版 " + shortQ.words() + " 词 · 长版 " + longQ.words() + " 词 · 都有离线录音", 13, MUTED);
      space(c, 10);
      LinearLayout r = row(c);
      smallButton(r, "读短版", game.level(1) < 2, () -> startStory(shortQ.id));
      smallButton(r, "读长版", game.level(1) >= 2, () -> startStory(longQ.id));
    }
  }

  private void openVisit(int index) {
    visitIndex = index;
    visitVersion = game.level(1) >= 2 ? 1 : 0;
    go("visit");
  }

  private void campVisit() {
    if (!game.visitAvailable(visitIndex)) {
      screen = "home";
      home();
      return;
    }
    Content.Q q =
        content.byId.get(String.format(Locale.ROOT, "e%02d_%d", visitIndex, visitVersion));
    intro("河谷来客 · 本地故事", q.title, "这次由你决定。可以查词、听录音或看中文，两种选择都成立。");
    LinearLayout formats = row(body);
    smallButton(
        formats,
        "读短版",
        visitVersion == 0,
        () -> {
          stopAudio();
          visitVersion = 0;
          render();
        });
    smallButton(
        formats,
        "读长版",
        visitVersion == 1,
        () -> {
          stopAudio();
          visitVersion = 1;
          render();
        });
    space(body, 12);
    LinearLayout letter = card();
    addEnglish(letter, q.text, null);
    space(letter, 14);
    audioButtons(letter, q, null);
    btn(
        letter,
        "看中文来意和选项",
        false,
        () ->
            new AlertDialog.Builder(this)
                .setTitle("理解来意")
                .setMessage(
                    q.translation
                        + "\n\n"
                        + String.join("\n", Content.strings(q.j.optJSONArray("choicesZh"))))
                .setPositiveButton("继续", null)
                .show());
    if (game.visitDone(visitIndex)) {
      int chosen = Game.obj(game.s, "visits").optInt(String.valueOf(visitIndex));
      LinearLayout outcome = card();
      text(outcome, "这次相遇，已经留下结果。", 20, MINT);
      space(outcome, 10);
      text(outcome, q.j.optJSONArray("outcomes").optString(chosen), 16, INK);
      space(outcome, 10);
      text(outcome, chosen == 0 ? "已收到 2 份建设材料。" : "已收到 1 份行粮，出战前可选择携带。", 15, GOLD);
      btn(outcome, "回营地，安排下一步", true, () -> go("home"));
    } else {
      LinearLayout choice = card();
      text(choice, "你现在更需要什么？", 20, INK);
      space(choice, 9);
      text(choice, "这次交换只发生一次；理解提议后，按自己的计划选择。", 13, MUTED);
      for (int i = 0; i < q.options.length; i++) {
        final int index = i;
        Button option =
            button(
                q.options[i] + (i == 1 && game.s.optInt("provisions") >= 9 ? "\n行粮已满" : ""),
                false,
                () -> {
                  if (!game.acceptVisit(visitIndex, index)) return;
                  Game.put(game.s, "readWords", game.s.optInt("readWords") + q.words());
                  save();
                  stopAudio();
                  playEffect(3);
                  render();
                });
        if (i == 1 && game.s.optInt("provisions") >= 9) {
          option.setEnabled(false);
          option.setAlpha(.5f);
        }
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(10);
        choice.addView(option, lp);
      }
    }
    btn(body, "回到来信室", false, () -> go("library"));
  }

  private void addArticle() {
    LinearLayout form = column();
    form.setPadding(dp(20), dp(8), dp(20), 0);
    EditText title = new EditText(this);
    title.setHint("标题（选填）");
    title.setFilters(
        new android.text.InputFilter[] {new android.text.InputFilter.LengthFilter(200)});
    title.setSingleLine(true);
    form.addView(title);
    EditText passage = new EditText(this);
    passage.setHint("粘贴一段英文。只存到这台手机。\n建议每篇 50–500 词。不会自动生成翻译或测试。");
    passage.setMinLines(6);
    passage.setMaxLines(10);
    passage.setGravity(Gravity.TOP);
    form.addView(passage);
    AlertDialog d =
        new AlertDialog.Builder(this)
            .setTitle("带一段自己的英文来")
            .setView(scrollingForm(form))
            .setNegativeButton("取消", null)
            .setPositiveButton("保存", null)
            .create();
    d.setOnShowListener(
        v ->
            d.getButton(AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener(
                    w -> {
                      String value = passage.getText().toString().trim();
                      if (value.length() < 10) {
                        passage.setError("请粘贴一段英文");
                        return;
                      }
                      if (value.length() > 15000) {
                        passage.setError("这段太长了，请拆成 15000 字符以内的短文");
                        return;
                      }
                      JSONArray articles = Game.arr(game.s, "articles");
                      if (articles.length() >= 30) {
                        toast("最多保留 30 篇，可先删除不需要的文章。");
                        return;
                      }
                      JSONObject a = new JSONObject();
                      Game.put(
                          a,
                          "title",
                          title.getText().toString().trim().isEmpty()
                              ? "自己的第 " + (articles.length() + 1) + " 篇短文"
                              : title.getText().toString().trim());
                      Game.put(a, "text", value);
                      articles.put(a);
                      save();
                      d.dismiss();
                      go("library");
                    }));
    d.show();
    d.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
  }

  private void customArticle() {
    JSONArray articles = Game.arr(game.s, "articles");
    int index = game.s.optInt("articleIndex");
    JSONObject a = articles.optJSONObject(index);
    if (a == null) {
      screen = "library";
      library();
      return;
    }
    intro("自己带来的英文", a.optString("title"), "点词可查。没有自动翻译和理解测验，这里只记录你手动标记的阅读接触。");
    LinearLayout c = card();
    addEnglish(c, a.optString("text"), null);
    btn(
        c,
        "这次读完了",
        true,
        () -> {
          Game.put(
              game.s,
              "readWords",
              game.s.optInt("readWords") + a.optString("text").trim().split("\\s+").length);
          Game.put(a, "reads", a.optInt("reads") + 1);
          save();
          toast("已记录这次阅读。累计读过 " + a.optInt("reads") + " 次。");
          go("library");
        });
    btn(body, "返回来信室", false, () -> go("library"));
    btn(
        body,
        "删除这篇短文",
        false,
        () ->
            new AlertDialog.Builder(this)
                .setTitle("删除这篇短文？")
                .setMessage("只删除这段自己加入的文本，累计接触记录保留。")
                .setNegativeButton("保留", null)
                .setPositiveButton(
                    "删除",
                    (d, w) -> {
                      JSONArray next = new JSONArray();
                      for (int i = 0; i < articles.length(); i++)
                        if (i != index) next.put(articles.optJSONObject(i));
                      Game.put(game.s, "articles", next);
                      go("library");
                    })
                .show());
  }

  private void difficultyDialog() {
    LinearLayout form = column();
    form.setPadding(dp(18), dp(10), dp(18), dp(5));
    Spinner[] choices = new Spinner[4];
    for (int i = 0; i < 4; i++) {
      TextView label = label(Game.SKILLS[i], 16, INK);
      form.addView(label);
      Spinner select = new Spinner(this);
      ArrayAdapter<String> adapter =
          new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, Game.LEVELS);
      select.setAdapter(adapter);
      select.setSelection(game.level(i));
      choices[i] = select;
      form.addView(select, new LinearLayout.LayoutParams(-1, dp(52)));
    }
    CheckBox automatic = new CheckBox(this);
    automatic.setText("按后续独立理解情况，继续小步调整");
    automatic.setTextColor(INK);
    automatic.setChecked(!game.s.optBoolean("manualLevel"));
    form.addView(automatic);
    new AlertDialog.Builder(this)
        .setTitle("英语难度单独调整")
        .setView(scrollingForm(form))
        .setNegativeButton("取消", null)
        .setPositiveButton(
            "使用这些设置",
            (d, w) -> {
              for (int i = 0; i < 4; i++) game.level(i, choices[i].getSelectedItemPosition());
              Game.put(game.s, "manualLevel", !automatic.isChecked());
              Game.put(game.s, "performance", new JSONObject());
              Game.put(
                  game.s,
                  "adjustment",
                  automatic.isChecked() ? "从你选定的长度开始，后续小步调整。" : "使用你手动选定的长度，暂不自动调整。");
              save();
              render();
            })
        .show();
  }

  private void settings() {
    intro("按自己的节奏来", "没有要追的倒计时。", "进度只存在这台手机。导出存档后，可在另一台安装同一应用的安卓手机上导入。");
    LinearLayout c = card();
    text(c, "声音与动作", 20, INK);
    toggle(c, "交锋短音效", "sound", true);
    toggle(c, "轻触反馈", "haptics", true);
    toggle(c, "减少动画（时机条也会静止）", "still", false);
    space(c, 7);
    text(c, "听力录音由播放按钮独立控制。减少动画时仍可用稳定出手。", 12, MUTED);
    btn(c, "英语难度", false, this::difficultyDialog);
    btn(c, "交锋规则", false, this::rules);
    LinearLayout saves = card();
    text(saves, "自己的存档", 20, INK);
    space(saves, 9);
    text(saves, "卸载应用会删除本机进度。需要保留时，先导出一份文件。导入前会展示内容概况，并保留当前存档以便撤销。", 14, MUTED);
    btn(
        saves,
        "导出存档",
        true,
        () -> {
          Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
          i.setType("application/json");
          i.addCategory(Intent.CATEGORY_OPENABLE);
          i.putExtra(
              Intent.EXTRA_TITLE,
              "wordfrontier-save-"
                  + new java.text.SimpleDateFormat("yyyyMMdd-HHmm", Locale.ROOT).format(new Date())
                  + ".json");
          startActivityForResult(i, EXPORT);
        });
    btn(
        saves,
        "导入存档",
        false,
        () -> {
          Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
          i.setType("*/*");
          i.addCategory(Intent.CATEGORY_OPENABLE);
          startActivityForResult(i, IMPORT);
        });
    if (getPreferences(0).contains("unreadable_save"))
      btn(
          saves,
          "导出未能读取的原存档",
          false,
          () -> {
            Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            i.setType("application/json");
            i.addCategory(Intent.CATEGORY_OPENABLE);
            i.putExtra(Intent.EXTRA_TITLE, "wordfrontier-original-save.json");
            startActivityForResult(i, EXPORT_ORIGINAL);
          });
    if (getPreferences(0).contains("before_import"))
      btn(
          saves,
          "撤销上一次导入",
          false,
          () -> {
            try {
              Game previous =
                  new Game(new JSONObject(getPreferences(0).getString("before_import", "")));
              game = previous;
              getPreferences(0).edit().remove("before_import").commit();
              save();
              go("home");
              toast("已恢复导入前的进度。");
            } catch (Exception e) {
              toast("备份无法读取，现有进度未修改。");
            }
          });
    if (activeBattle())
      btn(
          saves,
          "结束当前出战，回到准备页",
          false,
          () ->
              new AlertDialog.Builder(this)
                  .setTitle("撤离这场交锋？")
                  .setMessage("本场已完成的英语记录保留，但不获得建设材料。想稍后继续，只需要回营地即可。")
                  .setNegativeButton("继续保留", null)
                  .setPositiveButton(
                      "撤离",
                      (d, w) -> {
                        game.s.remove("battle");
                        save();
                        go("deploy");
                      })
                  .show());
    LinearLayout about = card();
    text(about, "词境前线  0.1", 21, INK);
    space(about, 10);
    text(
        about,
        "原生 Android 界面与绘图，没有浏览器内核；应用没有网络权限，也没有广告或账号。\n\n"
            + "内置 160 条词义练习、36 段侦察阅读、24 段听力、24 条组句；来信室有 12 篇故事的长短版本，共 24 段。另有 4"
            + " 次有限的来客选择，也各有长短版和录音。\n\n"
            + "词汇小测用于安排起点，不提供标准化能力等级。组句只练所给词块的组织，不能替代开放写作。对手是本地程序，社交和真人心理较量仍有明显差别。\n\n"
            + "录音为 Microsoft Zira 合成美式英语，已随安装包提供。词典来自 ECDICT，包含词形，不把其条目总数当作英语词汇量。",
        14,
        MUTED);
    btn(
        about,
        "词典许可与来源",
        false,
        () -> {
          try {
            new AlertDialog.Builder(this)
                .setTitle("ECDICT · MIT License")
                .setMessage(
                    "来源：https://github.com/skywind3000/ECDICT\n\n"
                        + Content.read(this, "ECDICT-LICENSE.txt"))
                .setPositiveButton("关闭", null)
                .show();
          } catch (Exception e) {
            toast("许可文件读取失败。");
          }
        });
    btn(
        about,
        "这版在尝试什么",
        false,
        () ->
            new AlertDialog.Builder(this)
                .setTitle("有选择、有完成，也有退出的余地")
                .setMessage(
                    "这是一版用来验证体验的个人原型：\n\n"
                        + "· 英语帮助理解情报，战术选择影响胜负。\n"
                        + "· 对手有习惯，也会变招，行动在你选择前确定。\n"
                        + "· 阅读阶段停住战斗，不因读得慢受伤。\n"
                        + "· 建设有四项明确终点，不再无限升本。\n"
                        + "· 离开不会让作物枯萎，也没有连续签到损失。\n\n"
                        + "这些设计参考了游戏动机、反馈、学习整合及词汇测试研究。但研究不能保证这个原型一定适合你，是否好玩、有没有学会，需要实际使用判断。研究推导随交付文件提供。")
                .setPositiveButton("继续", null)
                .show());
  }

  private void toggle(LinearLayout parent, String text, String key, boolean defaultValue) {
    Switch s = new Switch(this);
    s.setText(text);
    s.setTextSize(14);
    s.setTextColor(INK);
    s.setPadding(0, dp(12), 0, dp(12));
    s.setChecked(game.s.optBoolean(key, defaultValue));
    s.setOnCheckedChangeListener(
        (v, value) -> {
          Game.put(game.s, key, value);
          save();
        });
    parent.addView(s, new LinearLayout.LayoutParams(-1, -2));
  }

  @Override
  protected void onActivityResult(int request, int result, Intent data) {
    super.onActivityResult(request, result, data);
    if (result != RESULT_OK || data == null || data.getData() == null) return;
    Uri uri = data.getData();
    try {
      if (request == EXPORT || request == EXPORT_ORIGINAL) {
        save();
        try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
          if (out == null) throw new IOException("无法打开文件");
          String payload =
              request == EXPORT
                  ? game.s.toString(2)
                  : getPreferences(0).getString("unreadable_save", "");
          out.write(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
        toast("存档已导出。");
      } else if (request == IMPORT) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (InputStream in = getContentResolver().openInputStream(uri)) {
          if (in == null) throw new IOException("无法读取文件");
          byte[] block = new byte[8192];
          int n;
          while ((n = in.read(block)) != -1) {
            if (out.size() + n > 2 * 1024 * 1024) throw new IOException("存档超过 2 MB");
            out.write(block, 0, n);
          }
        }
        Game candidate = new Game(new JSONObject(out.toString("UTF-8")));
        validateContent(candidate);
        new AlertDialog.Builder(this)
            .setTitle("使用这份存档？")
            .setMessage(
                "建设 "
                    + candidate.builtCount()
                    + " / 4\n材料 "
                    + candidate.s.optInt("materials")
                    + "\n出战 "
                    + candidate.s.optInt("expeditions")
                    + " 次\n\n将替换当前进度。设置页可以撤销这次导入。")
            .setNegativeButton("取消", null)
            .setPositiveButton(
                "导入",
                (d, w) -> {
                  getPreferences(0).edit().putString("before_import", game.s.toString()).commit();
                  game = candidate;
                  save();
                  go("home");
                  toast("存档已导入。");
                })
            .show();
      }
    } catch (Exception e) {
      new AlertDialog.Builder(this)
          .setTitle("没有修改当前进度")
          .setMessage("文件未能处理：" + e.getMessage())
          .setPositiveButton("知道了", null)
          .show();
    }
  }

  private void validateContent(Game g) {
    content.validateState(g);
    JSONObject b = g.battle();
    if (b != null) {
      if (b.has("question") && !content.byId.containsKey(b.optString("question")))
        throw new IllegalArgumentException("存档含有当前版本没有的题目");
      if (b.optInt("enemy", -1) < 0 || b.optInt("enemy", -1) > 3)
        throw new IllegalArgumentException("对手记录无效");
      for (String key : new String[] {"committed", "report"})
        if (b.optInt(key, -1) < 0 || b.optInt(key, -1) > 2)
          throw new IllegalArgumentException("战术记录无效");
    }
    JSONObject p = g.s.optJSONObject("practice");
    if (p != null && !content.byId.containsKey(p.optString("question")))
      throw new IllegalArgumentException("练习记录无效");
  }

  @Override
  protected void onPause() {
    super.onPause();
    stopAudio();
    if (sounds != null) sounds.autoPause();
    save();
  }

  @Override
  protected void onDestroy() {
    stopAudio();
    if (sounds != null) {
      sounds.release();
      sounds = null;
    }
    if (content != null && content.dictionary != null && content.dictionary.isOpen())
      content.dictionary.close();
    super.onDestroy();
  }

  @Override
  public void onConfigurationChanged(Configuration c) {
    super.onConfigurationChanged(c);
    if (ready) render();
  }

  @Override
  public void onBackPressed() {
    if (!ready || screen.equals("home") || screen.equals("welcome")) {
      super.onBackPressed();
      return;
    }
    go(
        screen.equals("practice") || screen.equals("words")
            ? "learn"
            : screen.equals("custom") ? "library" : "home");
  }

  private static final class FlowLayout extends ViewGroup {
    int gap;

    FlowLayout(Context c) {
      super(c);
      gap = (int) (5 * c.getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onMeasure(int ws, int hs) {
      int width = MeasureSpec.getSize(ws), x = getPaddingLeft(), y = getPaddingTop(), line = 0;
      for (int i = 0; i < getChildCount(); i++) {
        View v = getChildAt(i);
        measureChild(
            v,
            MeasureSpec.makeMeasureSpec(
                Math.max(1, width - getPaddingLeft() - getPaddingRight()), MeasureSpec.AT_MOST),
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));
        int w = v.getMeasuredWidth(), h = v.getMeasuredHeight();
        if (x + w > width - getPaddingRight() && x > getPaddingLeft()) {
          x = getPaddingLeft();
          y += line + gap;
          line = 0;
        }
        x += w + gap;
        line = Math.max(line, h);
      }
      setMeasuredDimension(width, y + line + getPaddingBottom());
    }

    @Override
    protected void onLayout(boolean changed, int l, int t, int r, int b) {
      int x = getPaddingLeft(), y = getPaddingTop(), line = 0;
      for (int i = 0; i < getChildCount(); i++) {
        View v = getChildAt(i);
        int w = v.getMeasuredWidth(), h = v.getMeasuredHeight();
        if (x + w > r - l - getPaddingRight() && x > getPaddingLeft()) {
          x = getPaddingLeft();
          y += line + gap;
          line = 0;
        }
        v.layout(x, y, x + w, y + h);
        x += w + gap;
        line = Math.max(line, h);
      }
    }

    @Override
    protected LayoutParams generateDefaultLayoutParams() {
      return new LayoutParams(-2, -2);
    }
  }
}
