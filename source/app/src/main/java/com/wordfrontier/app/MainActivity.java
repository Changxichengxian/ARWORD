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
  private static final int BG = 0xffeef5fa,
      CARD = 0xfff8fcff,
      CARD2 = 0xffe0eff8,
      INK = 0xff193b55,
      MUTED = 0xff527089,
      MINT = 0xff177dba,
      GOLD = 0xff996407,
      RED = 0xffb63d45;
  private Game game;
  private Content content;
  private LinearLayout outer, body, nav;
  private FrameLayout frame;
  private ScrollView scroll;
  private String screen = "home";
  private MediaPlayer player;
  private android.speech.tts.TextToSpeech liveSpeech;
  private boolean speechReady;
  private String pendingSpeech = "";
  private static final int IMPORT_PACK = 44;
  private String apiToken = "";
  private AudioManager audioManager;
  private AudioFocusRequest speechFocus;
  private SoundPool sounds;
  private final int[] soundIds = new int[4];
  private final HashSet<Integer> loadedSounds = new HashSet<>();
  private TextView audioStatus;
  private SceneView.Timing timing;
  private int chosenEnemy = 0, chosenLoadout = 0;
  private int wordPage = 0;
  private int libraryPage = 0;
  private boolean showSavedWords = true;
  private int visitIndex = 0, visitVersion = 0;
  private boolean useRation = false;
  private String loadWarning = "";
  private static final int EXPORT = 41, IMPORT = 42, EXPORT_ORIGINAL = 43;
  private boolean ready = false;

  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    liveSpeech =
        new android.speech.tts.TextToSpeech(
            this,
            status -> {
              speechReady = status == android.speech.tts.TextToSpeech.SUCCESS;
              if (speechReady) {
                liveSpeech.setLanguage(Locale.US);
                if (!pendingSpeech.isEmpty()) {
                  String pending = pendingSpeech;
                  pendingSpeech = "";
                  speakText(pending, 1f);
                }
              }
            });
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
    getWindow().setStatusBarColor(Color.TRANSPARENT);
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
                  c.loadPack(g.s.optJSONArray("contentPack"));
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
    parent.addView(
        t,
        new LinearLayout.LayoutParams(
            parent.getOrientation() == LinearLayout.HORIZONTAL ? -2 : -1, -2));
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
    c.setPadding(dp(10), dp(10), dp(10), dp(10));
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
    b.setTextColor(INK);
    b.setGravity(Gravity.CENTER);
    b.setPadding(dp(14), dp(10), dp(14), dp(10));
    b.setMinHeight(dp(52));
    b.setMinimumHeight(dp(52));
    b.setStateListAnimator(null);
    b.setElevation(dp(2));
    GradientDrawable face =
        new GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            new int[] {primary ? 0xffffe277 : 0xfff6fcff, primary ? 0xffffc638 : 0xffd8ebf5});
    face.setCornerRadius(dp(12));
    face.setStroke(dp(2), primary ? 0xffdc9e23 : 0xff9ac4da);
    b.setBackground(new RippleDrawable(ColorStateList.valueOf(0x337fffff), face, null));
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
    r.setClipChildren(false);
    r.setClipToPadding(false);
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
    if (scroll != null) scroll.post(() -> scroll.scrollTo(0, y));
  }

  private void render() {
    if (!ready) return;
    if (gameScreen()) {
      renderGame();
      return;
    }
    audioStatus = null;
    getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
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
    icon(top, "‹", "返回", () -> go("home"));
    TextView brand = label("  旅行手册", 15, MINT);
    brand.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
    top.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));
    TextView local = label("", 11, MUTED);
    top.addView(local);
    if (!screen.equals("battle")) outer.addView(top);
    scroll = new ScrollView(this);
    scroll.setFillViewport(false);
    scroll.setClipToPadding(false);
    body = column();
    body.setPadding(dp(14), dp(4), dp(14), dp(14));
    scroll.addView(body, new ScrollView.LayoutParams(-1, -2));
    outer.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
    switch (screen) {
      case "welcome":
        welcomeGame();
        break;
      case "deploy":
        deployGame();
        break;
      case "battle":
        battleGame();
        break;
      case "learn":
        learnGame();
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
      case "workshop":
        contentWorkshop();
        break;
      case "settings":
        settings();
        break;
      default:
        homeGame();
    }
    frame.requestApplyInsets();
  }

  private void intro(String eyebrow, String title, String description) {
    text(body, eyebrow, 11, MINT);
    space(body, 7);
    body.addView(heading(title));
    space(body, 9);
    space(body, 12);
  }

  private boolean activeBattle() {
    return game.battle() != null && !game.battle().optString("phase").equals("finished");
  }

  private void stat(LinearLayout row, String name, String value) {
    LinearLayout c = column();
    text(c, value, 23, INK);
    space(c, 4);
    text(c, name, 12, MUTED);
    row.addView(c, new LinearLayout.LayoutParams(0, -2, 1));
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
                + "6. 独立理解情报获得 1 点专注，上限 3。花 2 点洞察本回合真实动作，或恢复 5 点耐久；每回合限一次。\n\n这里的对手是本地程序。")
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
    TextView t = label("", 18, INK);
    t.setLineSpacing(dp(4), 1.08f);
    t.setText(span);
    t.setMovementMethod(LinkMovementMethod.getInstance());
    t.setHighlightColor(0x669fe1b3);
    parent.addView(t, new LinearLayout.LayoutParams(-1, -2));
  }

  private void audioButtons(LinearLayout c, Content.Q q, JSONObject session) {
    LinearLayout r = row(c);
    smallButton(r, "▶ 播放", true, () -> play(q, session, 1f));
    smallButton(r, "0.8×", false, () -> play(q, session, .8f));
    audioStatus = label(q.audio.isEmpty() ? "设备朗读" : "美式英语", 12, MUTED);
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
    lp.topMargin = dp(9);
    c.addView(audioStatus, lp);
  }

  private void play(Content.Q q, JSONObject session, float speed) {
    try {
      stopAudio();
      if (q.audio.isEmpty()) {
        speakText(q.text.isEmpty() ? q.word : q.text, speed);
        if (session != null) Game.put(session, "played", true);
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
    if (liveSpeech != null) liveSpeech.stop();
    pendingSpeech = "";
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

  private void wordEvidence() {
    intro("词册", "带走这些表达", "");
    LinearLayout tabs = row(body);
    smallButton(
        tabs,
        "收藏",
        showSavedWords,
        () -> {
          showSavedWords = true;
          wordPage = 0;
          render();
        });
    smallButton(
        tabs,
        "最近练过",
        !showSavedWords,
        () -> {
          showSavedWords = false;
          wordPage = 0;
          render();
        });
    btn(
        body,
        "查一个词",
        false,
        () -> {
          EditText input = new EditText(this);
          input.setSingleLine(true);
          input.setHint("English word");
          new AlertDialog.Builder(this)
              .setTitle("查词")
              .setView(input)
              .setPositiveButton("查询", (d, w) -> showWord(input.getText().toString().trim()))
              .setNegativeButton("取消", null)
              .show();
        });
    JSONObject records = Game.obj(game.s, showSavedWords ? "savedWords" : "words");
    ArrayList<String> words = new ArrayList<>();
    Iterator<String> keys = records.keys();
    while (keys.hasNext()) words.add(keys.next());
    words.sort(
        (x, y) ->
            Long.compare(
                showSavedWords ? records.optLong(y) : records.optJSONObject(y).optLong("lastSeen"),
                showSavedWords
                    ? records.optLong(x)
                    : records.optJSONObject(x).optLong("lastSeen")));
    int pages = Math.max(1, (words.size() + 5) / 6);
    wordPage = Math.min(wordPage, pages - 1);
    space(body, 8);
    if (words.isEmpty()) {
      text(body, showSavedWords ? "在查词卡里点 ☆，就会留在这里。" : "练过的词会留在这里。", 16, MUTED);
      btn(body, "练五个词", true, this::startReview);
    }
    for (int i = wordPage * 6; i < Math.min(words.size(), wordPage * 6 + 6); i++) {
      String word = words.get(i);
      JSONObject evidence = Game.obj(game.s, "words").optJSONObject(word);
      String state =
          evidence == null
              ? "已收藏"
              : evidence.optInt("days") >= 3 && evidence.optInt("stage") >= 2
                  ? "跨日熟悉"
                  : evidence.optInt("right") > 0 ? "曾独立认出" : "继续巩固";
      btn(body, word + "   ·   " + state, false, () -> showWord(word));
    }
    if (pages > 1) {
      LinearLayout r = row(body);
      smallButton(
          r,
          "‹",
          false,
          () -> {
            wordPage = Math.max(0, wordPage - 1);
            render();
          });
      text(r, (wordPage + 1) + " / " + pages, 14, MUTED);
      smallButton(
          r,
          "›",
          false,
          () -> {
            wordPage = Math.min(pages - 1, wordPage + 1);
            render();
          });
    }
  }

  private void startCalibration() {
    startAdaptive();
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
      learnGame();
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
      learnGame();
      return;
    }
    text(
        body,
        mode.equals("story")
            ? q.title
            : Game.SKILLS[q.skill] + "  " + (p.optInt("index") + 1) + " / " + p.optInt("goal"),
        19,
        INK);
    space(body, 8);
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
          if (q.j.has("band") && !mode.equals("cal"))
            game.recordFrequency(q.j.optInt("band"), correct, help);
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
          p.optInt("index") + 1 >= p.optInt("goal") ? "完成" : "下一条",
          true,
          () -> advancePractice(p));
    if (mode.equals("cal")) {
      btn(body, "暂时停在这里，保留进度", false, () -> go("learn"));
      text(body, "四组表达，每组只抽 4 个词。样本少，只用于初始难度安排；高阶词碰巧认识也很正常。", 12, MUTED);
    }
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
              : (p.optInt("skill", 0) == 0
                      ? content.review(game)
                      : content.choose(game, p.optInt("skill"), -1))
                  .id);
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
    btn(c, cal ? "按这个起点出战" : "返回手册", true, () -> go(cal ? "deploy" : "learn"));
    if (!cal && !story) btn(c, "再来五个词", false, this::startReview);
    if (story) btn(c, "读另一封来信", false, () -> go("library"));
    btn(c, "回营地", false, () -> go("home"));
  }

  private void library() {
    intro("来信室", "路上有新故事", "");
    LinearLayout controls = row(body);
    smallButton(controls, "内容工坊", true, () -> go("workshop"));
    smallButton(
        controls,
        "我的短文",
        false,
        () -> {
          JSONArray personal = Game.arr(game.s, "articles");
          if (personal.length() == 0) {
            addArticle();
            return;
          }
          String[] names = new String[personal.length() + 1];
          for (int i = 0; i < personal.length(); i++)
            names[i] = personal.optJSONObject(i).optString("title");
          names[names.length - 1] = "＋ 添加短文";
          new AlertDialog.Builder(this)
              .setTitle("我的短文")
              .setItems(
                  names,
                  (d, i) -> {
                    if (i == personal.length()) addArticle();
                    else {
                      Game.put(game.s, "articleIndex", i);
                      go("custom");
                    }
                  })
              .show();
        });
    ArrayList<Content.Q> books = new ArrayList<>(content.extras);
    for (int i = 0; i < content.stories.size(); i += 2) books.add(content.stories.get(i));
    int pages = Math.max(1, (books.size() + 3) / 4);
    libraryPage = Math.max(0, Math.min(libraryPage, pages - 1));
    space(body, 12);
    for (int i = libraryPage * 4; i < Math.min(books.size(), libraryPage * 4 + 4); i++) {
      Content.Q q = books.get(i);
      LinearLayout c = card();
      text(c, q.title, 20, INK);
      space(c, 7);
      text(c, q.words() + " 词" + (q.audio.isEmpty() ? " · 设备朗读" : " · 神经语音"), 13, MUTED);
      LinearLayout r = row(c);
      smallButton(r, "阅读", true, () -> startStory(q.id));
      if (!q.id.startsWith("pack_")) {
        String longer = q.id.substring(0, q.id.length() - 1) + "1";
        smallButton(r, "长版", false, () -> startStory(longer));
      }
    }
    LinearLayout pager = row(body);
    smallButton(
        pager,
        "‹",
        false,
        () -> {
          libraryPage = Math.max(0, libraryPage - 1);
          render();
        });
    text(pager, (libraryPage + 1) + " / " + pages, 14, MUTED);
    smallButton(
        pager,
        "›",
        false,
        () -> {
          libraryPage = Math.min(pages - 1, libraryPage + 1);
          render();
        });
  }

  private void openVisit(int index) {
    visitIndex = index;
    visitVersion = game.level(1) >= 2 ? 1 : 0;
    go("visit");
  }

  private void campVisit() {
    if (!game.visitAvailable(visitIndex)) {
      screen = "home";
      homeGame();
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
    intro("设置", "", "进度只存在这台手机。导出存档后，可在另一台安装同一应用的安卓手机上导入。");
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
              validateContent(previous);
              game = previous;
              content.loadPack(game.s.optJSONArray("contentPack"));
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
    text(about, "词境前线 0.2", 21, INK);
    space(about, 10);
    text(about, "原生 Android · 本地对手\n内置录音：Kokoro 神经语音\n扩展文章：设备语音", 14, MUTED);
    btn(
        about,
        "内容与网络说明",
        false,
        () ->
            showInfo(
                "内容与网络",
                "内置 1,360 个词义练习、48 段交锋阅读、24 段听力、24 条组句、36"
                    + " 个故事版本。扩展阅读可导入，也可选择自己的接口生成。只有主动生成时才连接所填服务；不自动上传存档。自带录音在本地播放，设备朗读是否联网取决于你安装的语音引擎。"));
    btn(
        about,
        "语音与美术来源",
        false,
        () ->
            showInfo(
                "素材来源", "场景、建筑和角色使用内置图像生成工具制作。内置语音使用 Kokoro-82M（Apache 2.0），音色 af_heart。仍为合成语音。"));
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
    if (request == IMPORT_PACK) {
      if (result == RESULT_OK && data != null) readContentPack(data.getData());
      return;
    }
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
            if (out.size() + n > 8 * 1024 * 1024) throw new IOException("存档超过 8 MB");
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
                  content.loadPack(game.s.optJSONArray("contentPack"));
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
    try {
      content.loadPack(g.s.optJSONArray("contentPack"));
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
    } finally {
      content.loadPack(game.s.optJSONArray("contentPack"));
    }
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
    if (liveSpeech != null) liveSpeech.shutdown();
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

  private boolean gameScreen() {
    return Arrays.asList("home", "welcome", "deploy", "battle", "learn", "calibrate", "practice")
        .contains(screen);
  }

  private void renderGame() {
    audioStatus = null;
    getWindow().getDecorView().setSystemUiVisibility(0);
    frame = new FrameLayout(this);
    frame.setBackgroundColor(0xff75cdd9);
    frame.addView(new GameArt(this, game, screen), new FrameLayout.LayoutParams(-1, -1));
    outer = column();
    frame.addView(outer, new FrameLayout.LayoutParams(-1, -1));
    setContentView(frame);
    if (Build.VERSION.SDK_INT >= 30)
      outer.setOnApplyWindowInsetsListener(
          (v, insets) -> {
            android.graphics.Insets a =
                insets.getInsets(
                    WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
            outer.setPadding(a.left, a.top, a.right, a.bottom);
            return insets;
          });
    else outer.setFitsSystemWindows(true);
    LinearLayout top = row(outer);
    top.setPadding(dp(12), dp(10), dp(12), dp(6));
    if (screen.equals("home")) {
      TextView title = label("河谷小站", 21, Color.WHITE);
      title.setTypeface(Typeface.DEFAULT_BOLD);
      title.setShadowLayer(3, 0, 2, 0xff1a5474);
      top.addView(title, new LinearLayout.LayoutParams(0, dp(48), 1));
      Button stock = button("◆ " + game.s.optInt("materials"), false, () -> toast("建设材料"));
      stock.setContentDescription("建设材料 " + game.s.optInt("materials"));
      top.addView(stock, new LinearLayout.LayoutParams(dp(85), dp(44)));
      icon(top, "⚙", "设置", () -> go("settings"));
    } else {
      icon(top, "‹", "返回营地", () -> go("home"));
      String title =
          screen.equals("deploy")
              ? "选择对手"
              : screen.equals("learn")
                  ? "旅行手册"
                  : screen.equals("calibrate")
                      ? "寻找起点"
                      : screen.equals("battle") && game.battle() != null
                          ? Game.ENEMIES[game.battle().optInt("enemy")].split(" · ")[0]
                              + "  ·  "
                              + Math.min(
                                  8,
                                  game.battle().optInt("round")
                                      + (game.battle().optString("phase").equals("aftermath")
                                          ? 0
                                          : 1))
                              + " / 8"
                          : screen.equals("practice") ? "旅行手册" : "词境前线";
      TextView name = label(title, 20, Color.WHITE);
      name.setGravity(Gravity.CENTER);
      name.setTypeface(Typeface.DEFAULT_BOLD);
      name.setShadowLayer(3, 0, 2, 0xff1a5474);
      top.addView(name, new LinearLayout.LayoutParams(0, dp(44), 1));
      icon(
          top,
          "?",
          "帮助",
          screen.equals("battle") || screen.equals("deploy")
              ? this::rules
              : () -> showInfo("旅行手册", "点词查义。读、听、组句各自调难度。已完成的建设会保留。"));
    }
    if (screen.equals("home")) {
      homeGame();
    } else if (screen.equals("welcome")) {
      welcomeGame();
    } else if (screen.equals("deploy")) {
      deployGame();
    } else if (screen.equals("learn")) {
      learnGame();
    } else if (screen.equals("calibrate")) {
      calibrateGame();
    } else if (screen.equals("practice")) {
      gamePanel(.72f, true);
      practice();
    } else {
      battleGame();
    }
    frame.requestApplyInsets();
  }

  private void icon(LinearLayout r, String glyph, String description, Runnable action) {
    Button b = button(glyph, false, action);
    b.setTextSize(22);
    b.setPadding(0, 0, 0, 0);
    b.setContentDescription(description);
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(46), dp(46));
    lp.leftMargin = dp(7);
    r.addView(b, lp);
  }

  private void showInfo(String title, String message) {
    Dialog d = new Dialog(this);
    LinearLayout box = column();
    box.setPadding(dp(24), dp(24), dp(24), dp(20));
    box.setBackground(shape(CARD, 26));
    text(box, title, 23, INK);
    space(box, 14);
    text(box, message, 16, MUTED);
    btn(box, "知道了", true, d::dismiss);
    d.setContentView(box);
    d.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
    d.getWindow()
        .setLayout(Math.min(dp(420), getResources().getDisplayMetrics().widthPixels - dp(32)), -2);
    d.show();
    d.getWindow()
        .setLayout(Math.min(dp(420), getResources().getDisplayMetrics().widthPixels - dp(32)), -2);
  }

  private void gamePanel(float heightFraction, boolean scrolling) {
    Space sky = new Space(this);
    outer.addView(sky, new LinearLayout.LayoutParams(1, 0, 1));
    LinearLayout panel = column();
    panel.setPadding(dp(14), dp(15), dp(14), dp(14));
    panel.setBackground(shape(0xfaf8fcff, 26));
    panel.setElevation(dp(9));
    int available = getResources().getDisplayMetrics().heightPixels;
    int panelHeight = Math.max(dp(220), (int) (available * heightFraction));
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
    lp.setMargins(dp(10), 0, dp(10), dp(8));
    outer.addView(panel, lp);
    body = column();
    body.setPadding(dp(2), 0, dp(2), 0);
    scroll = new CappedScroll(this, panelHeight - dp(29));
    scroll.setFillViewport(false);
    scroll.setVerticalScrollBarEnabled(false);
    if (scrolling) {
      scroll.addView(body, new ScrollView.LayoutParams(-1, -2));
      panel.addView(scroll, new LinearLayout.LayoutParams(-1, -2));
    } else panel.addView(body, new LinearLayout.LayoutParams(-1, -2));
  }

  private void homeGame() {
    FrameLayout places = new FrameLayout(this);
    outer.addView(places, new LinearLayout.LayoutParams(-1, 0, 1));
    String[] names = {"菜圃", "工坊", "木桥", "会馆"};
    for (int i = 0; i < 4; i++) {
      final int index = i;
      String title = game.has(i) ? names[i] : ("＋ " + names[i]);
      boolean dot =
          (!game.has(i) && game.s.optInt("materials") >= Game.COSTS[i])
              || (i == 0 && game.has(0) && game.s.optInt("growth") >= 2);
      Button b = button(title + (dot ? "  •" : ""), dot, () -> buildingSheet(index));
      b.setTextSize(13);
      b.setPadding(dp(6), 0, dp(6), 0);
      b.setMinHeight(dp(38));
      b.setMinimumHeight(dp(38));
      FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(dp(94), dp(40));
      places.addView(b, p);
      places.addOnLayoutChangeListener(
          (v, l, t, r, bt, ol, ot, or, ob) -> {
            int[] xy = new int[2];
            places.getLocationInWindow(xy);
            int[] rootXY = new int[2];
            frame.getLocationInWindow(rootXY);
            b.setX(frame.getWidth() * GameArt.SITES[index][0] - dp(47));
            b.setY(
                Math.max(
                    0,
                    Math.min(
                        places.getHeight() - dp(44),
                        frame.getHeight() * GameArt.SITES[index][1]
                            - (xy[1] - rootXY[1])
                            + dp(3))));
          });
    }
    LinearLayout side = column();
    FrameLayout.LayoutParams sp =
        new FrameLayout.LayoutParams(dp(62), -2, Gravity.RIGHT | Gravity.TOP);
    sp.setMargins(0, dp(10), dp(12), 0);
    places.addView(side, sp);
    homeShortcut(side, "▤\n来信", false, () -> go("library"));
    homeShortcut(side, "Aa\n词册", false, () -> go("words"));
    int nextVisit = -1;
    for (int i = 0; i < 4; i++)
      if (game.visitAvailable(i) && !game.visitDone(i)) {
        nextVisit = i;
        break;
      }
    if (nextVisit >= 0) {
      final int index = nextVisit;
      homeShortcut(side, "✉\n来客", true, () -> openVisit(index));
    }
    if (!loadWarning.isEmpty()) btn(side, "!", true, () -> showInfo("存档提示", loadWarning));
    LinearLayout bottom = column();
    bottom.setPadding(dp(20), 0, dp(20), dp(14));
    outer.addView(bottom);
    TextView status =
        label(
            game.builtCount() < 4 ? "小站建设  " + game.builtCount() + " / 4" : "小站已建成 · 远行继续",
            14,
            Color.WHITE);
    status.setGravity(Gravity.CENTER);
    status.setShadowLayer(3, 0, 2, 0xff234a32);
    bottom.addView(status);
    space(bottom, 8);
    Button fight =
        button(
            activeBattle() ? "继续交锋  ›" : "出发交锋  ›",
            true,
            () -> go(activeBattle() ? "battle" : "deploy"));
    fight.setTextSize(22);
    bottom.addView(fight, new LinearLayout.LayoutParams(-1, dp(62)));
    LinearLayout r = row(bottom);
    smallButton(r, "⌂  营地", true, () -> {});
    smallButton(r, "▣  手册", false, () -> go("learn"));
  }

  private void homeShortcut(LinearLayout parent, String title, boolean active, Runnable action) {
    Button b = button(title, active, action);
    b.setTextSize(13);
    b.setPadding(dp(2), 0, dp(2), 0);
    b.setMinWidth(0);
    b.setMinimumWidth(0);
    b.setMaxLines(2);
    LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(60));
    lp.bottomMargin = dp(8);
    parent.addView(b, lp);
  }

  private void buildingSheet(int index) {
    Dialog d = new Dialog(this);
    LinearLayout box = column();
    box.setPadding(dp(22), dp(16), dp(22), dp(18));
    box.setBackground(shape(CARD, 28));
    ImageView art = new ImageView(this);
    art.setImageBitmap(
        GameArt.bitmap(this, new String[] {"garden", "workshop", "bridge", "hall"}[index]));
    art.setScaleType(ImageView.ScaleType.FIT_CENTER);
    box.addView(art, new LinearLayout.LayoutParams(-1, dp(145)));
    text(box, Game.BUILDINGS[index], 23, INK);
    space(box, 8);
    text(
        box,
        new String[] {"每完成两场交锋，收获一份行粮。", "解锁护具和侦察配装。", "通往对岸，解锁观察者灰鸦。", "为河谷来客留一个落脚处。"}[index],
        15,
        MUTED);
    if (!game.has(index))
      btn(
          box,
          "建造  ◆ " + Game.COSTS[index],
          true,
          () -> {
            if (game.build(index)) {
              playEffect(3);
              save();
              d.dismiss();
              render();
            } else toast("还差 " + (Game.COSTS[index] - game.s.optInt("materials")) + " 份材料");
          });
    else if (index == 0)
      btn(
          box,
          game.s.optInt("growth") >= 2 ? "收获行粮" : "生长中  " + game.s.optInt("growth") + " / 2",
          true,
          () -> {
            if (game.harvest()) {
              save();
              playEffect(3);
              d.dismiss();
              render();
            } else toast(game.s.optInt("provisions") >= 9 ? "行粮已满" : "再完成一场交锋试试");
          });
    else btn(box, "已建成 ✓", true, d::dismiss);
    btn(box, "返回", false, d::dismiss);
    d.setContentView(box);
    d.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
    d.show();
    d.getWindow()
        .setLayout(Math.min(dp(420), getResources().getDisplayMetrics().widthPixels - dp(28)), -2);
    d.getWindow().setGravity(Gravity.BOTTOM);
  }

  private void welcomeGame() {
    gamePanel(.30f, false);
    text(body, "你的河谷，开始生长。", 26, INK);
    space(body, 8);
    text(body, "读情报，打交锋，建起自己的小站。", 15, MUTED);
    btn(
        body,
        "测测我的起点",
        true,
        () -> {
          Game.put(game.s, "onboarded", true);
          startAdaptive();
        });
    btn(
        body,
        "先进去看看",
        false,
        () -> {
          Game.put(game.s, "onboarded", true);
          go("home");
        });
  }

  private void deployGame() {
    gamePanel(.56f, true);
    String[] shortNames = {"赤狐", "岩卫", "游隼", "灰鸦"};
    LinearLayout rivals = row(body);
    for (int i = 0; i < 4; i++) {
      final int k = i;
      smallButton(
          rivals,
          shortNames[i] + (i == 3 && !game.has(2) ? " 🔒" : ""),
          chosenEnemy == i,
          () -> {
            if (k == 3 && !game.has(2)) {
              toast("建好木桥后解锁");
              return;
            }
            chosenEnemy = k;
            Game.put(game.s, "previewEnemy", k);
            render();
          });
    }
    space(body, 10);
    text(
        body,
        new String[] {"急攻手 · 常用突击", "守势派 · 常用固守", "迂回者 · 常绕侧翼", "观察者 · 会记住你的惯用招"}[chosenEnemy],
        16,
        INK);
    space(body, 14);
    text(body, "交锋强度", 13, MUTED);
    LinearLayout dr = row(body);
    for (int i = 0; i < 3; i++) {
      final int p = i;
      smallButton(
          dr,
          new String[] {"轻松", "标准", "强敌"}[i],
          game.s.optInt("pressure", 1) == i,
          () -> {
            Game.put(game.s, "pressure", p);
            save();
            render();
          });
    }
    space(body, 14);
    text(body, "配装", 13, MUTED);
    LinearLayout load = row(body);
    if (!game.has(1)) chosenLoadout = 0;
    for (int i = 0; i < 3; i++) {
      final int k = i;
      smallButton(
          load,
          new String[] {"常规", "护具", "侦察"}[i],
          chosenLoadout == i,
          () -> {
            if (k > 0 && !game.has(1)) {
              toast("建好工坊后解锁");
              return;
            }
            chosenLoadout = k;
            render();
          });
    }
    if (game.s.optInt("provisions") > 0)
      btn(
          body,
          (useRation ? "✓ " : "") + "行粮 · 耐久 +4",
          useRation,
          () -> {
            useRation = !useRation;
            render();
          });
    btn(
        body,
        "开始交锋",
        true,
        () -> {
          game.start(chosenEnemy, chosenLoadout, useRation, System.currentTimeMillis());
          Game.put(game.battle(), "v2", true);
          save();
          go("battle");
        });
  }

  private void learnGame() {
    gamePanel(.54f, true);
    LinearLayout stats = row(body);
    stat(stats, "读过的词", String.valueOf(game.s.optInt("readWords")));
    stat(stats, "听力分钟", String.valueOf(game.s.optInt("listenSeconds") / 60));
    space(body, 12);
    JSONObject current = game.s.optJSONObject("practice");
    boolean resume = current != null && !current.optString("phase").equals("done");
    btn(
        body,
        resume
            ? "继续练习  ·  " + (current.optInt("index") + 1) + " / " + current.optInt("goal")
            : "词语补给  ·  练五个词",
        true,
        () -> {
          if (resume) go("practice");
          else startReview();
        });
    LinearLayout r = row(body);
    smallButton(r, "阅读来信", false, () -> go("library"));
    smallButton(r, "听力训练", false, () -> startSkill(2));
    LinearLayout r2 = row(body);
    smallButton(r2, "组织句子", false, () -> startSkill(3));
    smallButton(r2, "收藏词册", false, () -> go("words"));
    btn(body, game.s.has("adaptiveResult") ? "重新测起点" : "测测我的起点", false, this::startAdaptive);
    LinearLayout r3 = row(body);
    smallButton(r3, "难度", false, this::difficultyDialog);
    smallButton(r3, "内容工坊", false, () -> go("workshop"));
  }

  private void startSkill(int skill) {
    JSONObject p = new JSONObject();
    Game.put(p, "mode", "review");
    Game.put(p, "skill", skill);
    Game.put(p, "index", 0);
    Game.put(p, "goal", 5);
    Game.put(p, "phase", "question");
    Game.put(p, "question", content.choose(game, skill, -1).id);
    Game.put(game.s, "practice", p);
    go("practice");
  }

  private void battleGame() {
    JSONObject b = game.battle();
    if (b == null) {
      screen = "deploy";
      deployGame();
      return;
    }
    String phase = b.optString("phase");
    if (phase.equals("finished")) {
      gamePanel(.39f, false);
      text(body, b.optBoolean("win") ? "交锋胜利！" : b.optBoolean("tie") ? "势均力敌" : "下次再战", 28, INK);
      space(body, 12);
      text(body, "◆ +" + b.optInt("reward") + "   ·   " + b.optInt("round") + " 回合", 22, MINT);
      btn(body, "回营地", true, () -> go("home"));
      btn(body, "再来一场", false, () -> go("deploy"));
      return;
    }
    float height =
        phase.equals("question")
            ? .61f
            : phase.equals("aim") ? .31f : phase.equals("aftermath") ? .35f : .50f;
    gamePanel(height, true);
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
            if (q.j.has("band")) game.recordFrequency(q.j.optInt("band"), correct, helped);
            game.answer(correct, helped, selected);
            save();
            stopAudio();
            render();
          });
    } else if (phase.equals("feedback") || phase.equals("tactic")) {
      Content.Q q = content.byId.get(b.optString("question"));
      LinearLayout h = row(body);
      TextView tx =
          label(
              b.optBoolean("correct") ? "✓ 情报收到" : "正确答案：" + (q == null ? "" : q.answer()),
              15,
              b.optBoolean("correct") ? MINT : RED);
      h.addView(tx, new LinearLayout.LayoutParams(0, -2, 1));
      icon(h, "?", "答案解释", () -> showInfo("这条表达", q == null ? "" : q.text + "\n\n" + q.explain));
      space(body, 8);
      text(
          body,
          "侦察：" + Game.ACTIONS[b.optInt("report")] + "  ·  可靠度 " + b.optInt("reliability") + "%",
          20,
          INK);
      space(body, 7);
      text(
          body,
          "体力 " + b.optInt("energy") + " / 4    对手 " + b.optInt("enemyEnergy") + " / 4",
          14,
          MUTED);
      if (b.optBoolean("v2")) {
        LinearLayout abilities = row(body);
        String charge = "✦ " + b.optInt("focus") + " / 3";
        text(abilities, charge, 13, MINT);
        smallButton(
            abilities,
            "洞察 −2",
            false,
            () -> {
              if (game.ability(0)) {
                save();
                render();
              } else toast("需要 2 点专注，每回合限一次");
            });
        smallButton(
            abilities,
            "恢复 −2",
            false,
            () -> {
              if (game.ability(1)) {
                save();
                render();
              } else
                toast(
                    b.optInt("hp") >= (b.optBoolean("ration") ? 40 : 36)
                        ? "耐久已满"
                        : "需要 2 点专注，每回合限一次");
            });
      }

      space(body, 6);
      text(body, "固守挡突击 · 迂回破固守 · 突击截迂回", 13, MUTED);
      LinearLayout actions = row(body);
      String[] marks = {"⚔", "▣", "➜"};
      for (int i = 0; i < 3; i++) {
        final int a = i;
        Button action =
            button(
                marks[i]
                    + "\n"
                    + Game.ACTIONS[i]
                    + "\n"
                    + (i == 1 ? "体力 +2" : "体力 −" + Game.cost(i)),
                false,
                () -> {
                  Game.put(b, "phase", "tactic");
                  game.choose(a);
                  save();
                  render();
                });
        action.setEnabled(Game.canUse(i, b.optInt("energy")));
        if (!action.isEnabled()) action.setAlpha(.4f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(90), 1);
        lp.setMargins(dp(3), dp(9), dp(3), 0);
        actions.addView(action, lp);
      }
      JSONArray logs = Game.arr(b, "logs");
      if (logs.length() > 0) {
        StringBuilder last = new StringBuilder("对手近三招：");
        for (int i = Math.max(0, logs.length() - 3); i < logs.length(); i++)
          last.append(Game.ACTIONS[logs.optJSONObject(i).optInt("enemyAction")]).append("  ");
        space(body, 9);
        text(body, last.toString(), 13, MUTED);
      }
    } else if (phase.equals("aim")) {
      text(body, Game.ACTIONS[b.optInt("action")] + " · 抓住出手时机", 20, INK);
      timing = new SceneView.Timing(this, game.s.optBoolean("still"));
      body.addView(timing, new LinearLayout.LayoutParams(-1, dp(65)));
      LinearLayout r = row(body);
      smallButton(r, "出手！", true, () -> resolve(timing.precision()));
      smallButton(r, "稳定出手 +1", false, () -> resolve(1));
    } else if (phase.equals("aftermath")) {
      JSONObject r = b.optJSONObject("result");
      text(body, r.optString("headline"), 27, INK);
      space(body, 8);
      text(
          body,
          Game.ACTIONS[r.optInt("playerAction")] + "  对  " + Game.ACTIONS[r.optInt("enemyAction")],
          16,
          MUTED);
      space(body, 8);
      text(body, "“" + r.optString("reaction") + "”", 16, MINT);
      btn(
          body,
          game.battleOver() ? "领取收获" : "下一回合  ›",
          true,
          () -> {
            if (game.battleOver()) game.finish();
            else game.prepareRound();
            save();
            render();
          });
    }
  }

  private void speakText(String text, float speed) {
    if (liveSpeech == null) return;
    if (!speechReady) {
      pendingSpeech = text;
      toast("正在准备设备语音");
      return;
    }
    liveSpeech.setSpeechRate(speed);
    int start = 0, part = 0;
    while (start < text.length()) {
      int end = Math.min(text.length(), start + 3000);
      if (end < text.length()) {
        int stop = text.lastIndexOf('.', end);
        if (stop > start + 1500) end = stop + 1;
      }
      int ok =
          liveSpeech.speak(
              text.substring(start, end),
              part == 0
                  ? android.speech.tts.TextToSpeech.QUEUE_FLUSH
                  : android.speech.tts.TextToSpeech.QUEUE_ADD,
              null,
              "text-" + part);
      if (ok == android.speech.tts.TextToSpeech.ERROR) {
        toast("请在系统设置中安装英语语音");
        return;
      }
      start = end;
      part++;
    }
  }

  private void showWord(String word) {
    String key = word.toLowerCase(Locale.ROOT);
    Dialog d = new Dialog(this);
    LinearLayout box = column();
    box.setPadding(dp(24), dp(24), dp(24), dp(20));
    box.setBackground(shape(CARD, 28));
    LinearLayout head = row(box);
    TextView name = label(word, 30, INK);
    name.setTypeface(Typeface.DEFAULT_BOLD);
    head.addView(name, new LinearLayout.LayoutParams(0, -2, 1));
    icon(
        head,
        "▶",
        "读这个词",
        () -> {
          Content.Q q = content.byId.get("x_" + key);
          if (q != null) play(q, null, 1f);
          else speakText(word, 1f);
        });
    space(box, 18);
    String meaning = content.lookup(word);
    TextView definition = label(meaning, 17, INK);
    definition.setLineSpacing(dp(8), 1.1f);
    ScrollView defScroll = new ScrollView(this);
    defScroll.addView(definition);
    box.addView(
        defScroll,
        new LinearLayout.LayoutParams(
            -1, Math.min(dp(220), Math.max(dp(90), meaning.split("\n").length * dp(30)))));
    boolean saved = Game.obj(game.s, "savedWords").has(key);
    btn(
        box,
        saved ? "★ 已收藏 · 点击取消" : "☆ 收藏这个词",
        true,
        () -> {
          if (saved) Game.obj(game.s, "savedWords").remove(key);
          else Game.put(Game.obj(game.s, "savedWords"), key, System.currentTimeMillis());
          save();
          d.dismiss();
        });
    btn(box, "继续阅读", false, d::dismiss);
    d.setContentView(box);
    d.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
    d.show();
    d.getWindow()
        .setLayout(Math.min(dp(460), getResources().getDisplayMetrics().widthPixels - dp(20)), -2);
    d.getWindow().setGravity(Gravity.BOTTOM);
  }

  private void startAdaptive() {
    JSONObject p = game.s.optJSONObject("adaptive");
    if (p == null || p.optString("phase").equals("done")) {
      p = Adaptive.begin();
      Game.put(game.s, "adaptive", p);
    }
    go("calibrate");
  }

  private void calibrateGame() {
    JSONObject p = Game.obj(game.s, "adaptive");
    if (p.optString("phase").equals("done")) {
      gamePanel(.53f, true);
      text(body, "找到一个更合适的起点", 24, INK);
      space(body, 14);
      text(body, Adaptive.result(p), 20, MINT);
      space(body, 12);
      text(body, "这是词义识别抽样，阅读和听力会分别调整。", 14, MUTED);
      btn(body, "开始词语补给", true, this::startReview);
      btn(body, "回到营地", false, () -> go("home"));
      btn(
          body,
          "查看抽样分布",
          false,
          () -> {
            int[] n = new int[8], yes = new int[8];
            JSONArray a = Game.arr(p, "answers");
            for (int i = 0; i < a.length(); i++) {
              JSONObject x = a.optJSONObject(i);
              n[x.optInt("band")]++;
              if (x.optBoolean("right")) yes[x.optInt("band")]++;
            }
            StringBuilder out = new StringBuilder();
            for (int i = 0; i < 8; i++)
              out.append("词频 ")
                  .append(1000 + i * 2000)
                  .append("–")
                  .append(2999 + i * 2000)
                  .append("：")
                  .append(yes[i])
                  .append(" / ")
                  .append(n[i])
                  .append("\n");
            out.append("\n频率依据 ECDICT 的 BNC 标记。频率不等于难度；这不是经过人群标定的词汇量考试。");
            showInfo("本次抽样", out.toString());
          });
      return;
    }
    Content.Q q = content.byId.get(p.optString("question"));
    if (q == null) {
      int band = Adaptive.band(p);
      ArrayList<Content.Q> pool = new ArrayList<>();
      JSONArray used = Game.arr(p, "used");
      HashSet<String> seen = new HashSet<>();
      for (int i = 0; i < used.length(); i++) seen.add(used.optString(i));
      for (Content.Q candidate : content.extraWords)
        if (candidate.j.optInt("band") == band && !seen.contains(candidate.id)) pool.add(candidate);
      q = pool.get(game.nextInt(pool.size()));
      Game.put(p, "question", q.id);
      used.put(q.id);
      save();
    }
    final Content.Q item = q;
    gamePanel(.61f, true);
    LinearLayout progress = row(body);
    text(progress, "词义探测  " + (p.optInt("n") + 1) + " / 24", 14, MUTED);
    space(body, 15);
    TextView word = label(q.word, 35, INK);
    word.setTypeface(Typeface.DEFAULT_BOLD);
    word.setGravity(Gravity.CENTER);
    body.addView(word, new LinearLayout.LayoutParams(-1, dp(70)));
    JSONArray order = optionOrder(q, p);
    for (int j = 0; j < order.length(); j++) {
      final int index = order.optInt(j);
      btn(
          body,
          q.options[index],
          false,
          () -> adaptiveAnswer(p, item, index == item.correct, !p.optBoolean("guessed")));
    }
    CheckBox guess = new CheckBox(this);
    guess.setText("不太确定，是猜的");
    guess.setTextColor(MUTED);
    guess.setChecked(p.optBoolean("guessed"));
    guess.setOnCheckedChangeListener(
        (v, c) -> {
          Game.put(p, "guessed", c);
          save();
        });
    body.addView(guess);
    btn(body, "不认识", false, () -> adaptiveAnswer(p, item, false, false));
  }

  private void adaptiveAnswer(JSONObject p, Content.Q q, boolean correct, boolean certain) {
    if (!p.optString("question").equals(q.id)) return;
    game.record(q.id, 0, q.word, correct, !certain, System.currentTimeMillis(), 0, 0);
    Adaptive.answer(p, q.j.optInt("band"), correct, certain);
    if (p.optString("phase").equals("done")) {
      Game.put(game.s, "adaptiveResult", p);
      Game.put(
          game.s, "wordBand", Math.max(0, Math.min(7, (int) Math.round(p.optDouble("theta", 3)))));
      Game.put(game.s, "calibrated", true);
      game.level(0, Math.min(3, game.s.optInt("wordBand") / 2 + 1));
    }
    save();
    render();
  }

  private void renderQuestion(Content.Q q, JSONObject session, Answer answer) {
    boolean feedback = session.optString("phase").equals("feedback");
    LinearLayout c = card();
    LinearLayout header = row(c);
    TextView kind =
        label(Game.SKILLS[q.skill] + (q.skill == 1 ? " · " + q.words() + " 词" : ""), 12, MUTED);
    header.addView(kind, new LinearLayout.LayoutParams(0, -2, 1));
    if (!feedback) {
      Button help =
          button(
              "?",
              false,
              () -> {
                Game.put(session, "hinted", true);
                save();
                showInfo("理解帮助", q.translation.isEmpty() ? q.explain : q.translation);
              });
      help.setPadding(0, 0, 0, 0);
      help.setMinHeight(dp(34));
      help.setMinimumHeight(dp(34));
      header.addView(help, new LinearLayout.LayoutParams(dp(40), dp(34)));
    }
    space(c, 9);
    if (feedback) {
      text(
          c,
          session.optBoolean("correct") ? "✓ 理解了" : "再记一次",
          24,
          session.optBoolean("correct") ? MINT : RED);
      space(c, 10);
      if (q.skill == 3 || q.skill == 0) text(c, q.skill == 0 ? q.word : q.text, 24, INK);
      space(c, 8);
      text(c, q.explain, 16, INK);
      if (!q.audio.isEmpty()) btn(c, "▶ 再听一次", false, () -> play(q, session, 1f));
      return;
    }
    if (q.skill == 0) {
      LinearLayout title = row(c);
      TextView word = label(q.word, 31, INK);
      word.setTypeface(Typeface.DEFAULT_BOLD);
      title.addView(word, new LinearLayout.LayoutParams(0, -2, 1));
      icon(title, "▶", "播放单词", () -> play(q, session, 1));
      if (!q.text.isEmpty()) {
        space(c, 10);
        addEnglish(c, q.text, session);
      }
    } else if (q.skill == 1) {
      addEnglish(c, q.text, session);
    } else if (q.skill == 2) {
      text(c, "斥候来报", 23, INK);
      audioButtons(c, q, session);
      if (session.optBoolean("transcript")) addEnglish(c, q.text, session);
      else
        btn(
            c,
            "字幕",
            false,
            () -> {
              Game.put(session, "transcript", true);
              Game.put(session, "hinted", true);
              save();
              render();
            });
    } else {
      text(c, q.translation, 18, INK);
    }
    space(c, 12);
    if (q.skill != 3) text(c, q.prompt, 15, INK);
    if (q.skill == 3) {
      JSONArray chosen = Game.arr(session, "chosen");
      FlowLayout assembled = new FlowLayout(this);
      assembled.setPadding(dp(4), dp(7), dp(4), dp(7));
      assembled.setBackground(shape(CARD2, 12));
      c.addView(assembled, new LinearLayout.LayoutParams(-1, -2));
      if (chosen.length() == 0) {
        TextView hint = label("点词块组句", 14, MUTED);
        hint.setPadding(dp(12), dp(14), dp(12), dp(14));
        assembled.addView(hint);
      }
      for (int i = 0; i < chosen.length(); i++) {
        final int pos = i;
        Button token =
            button(
                q.tokens[chosen.optInt(i)],
                false,
                () -> {
                  JSONArray next = new JSONArray();
                  for (int k = 0; k < chosen.length(); k++)
                    if (k != pos) next.put(chosen.optInt(k));
                  Game.put(session, "chosen", next);
                  save();
                  renderAtSamePosition();
                });
        token.setTextSize(15);
        token.setMinWidth(0);
        token.setMinimumWidth(0);
        token.setPadding(dp(12), 0, dp(12), 0);
        token.setMinHeight(dp(44));
        token.setMinimumHeight(dp(44));
        assembled.addView(token);
      }
      space(c, 9);
      FlowLayout pool = new FlowLayout(this);
      c.addView(pool, new LinearLayout.LayoutParams(-1, -2));
      for (int i = 0; i < q.tokens.length; i++) {
        final int k = i;
        Button t =
            button(
                q.tokens[i],
                false,
                () -> {
                  chosen.put(k);
                  save();
                  renderAtSamePosition();
                });
        t.setTextSize(15);
        t.setMinWidth(0);
        t.setMinimumWidth(0);
        t.setPadding(dp(12), 0, dp(12), 0);
        t.setMinHeight(dp(44));
        t.setMinimumHeight(dp(44));
        boolean used = false;
        for (int j = 0; j < chosen.length(); j++) if (chosen.optInt(j) == i) used = true;
        if (!used) pool.addView(t);
      }
      btn(
          c,
          "提交",
          true,
          () -> {
            if (chosen.length() != q.tokens.length) {
              toast("还有词块没有放好");
              return;
            }
            StringBuilder out = new StringBuilder();
            for (int i = 0; i < chosen.length(); i++) {
              if (i > 0) out.append(' ');
              out.append(q.tokens[chosen.optInt(i)]);
            }
            answer.submit(0, q.matches(out.toString()));
          });
    } else {
      JSONArray order = optionOrder(q, session);
      for (int pos = 0; pos < order.length(); pos++) {
        final int i = order.optInt(pos);
        btn(c, q.options[i], false, () -> answer.submit(i, i == q.correct));
      }
    }
    LinearLayout footer = row(c);
    smallButton(
        footer,
        q.skill == 3 ? "看示范" : "还不懂",
        false,
        () -> {
          Game.put(session, "hinted", true);
          answer.submit(-1, false);
        });
    if (q.skill == 1 && q.level > 0 && !q.id.startsWith("pack_"))
      smallButton(
          footer,
          "短一点",
          false,
          () -> {
            game.level(1, Math.max(0, q.level - 1));
            Content.Q easier =
                session.optString("mode").equals("story")
                    ? content.byId.get(q.id.substring(0, q.id.length() - 1) + "0")
                    : content.choose(game, 1, session.optInt("report", -1));
            if (easier == null) {
              toast("这篇没有短版");
              return;
            }
            Game.put(session, "question", easier.id);
            Game.put(session, "hinted", false);
            session.remove("optionOrder");
            session.remove("optionQuestion");
            save();
            stopAudio();
            renderAtSamePosition();
          });
  }

  private void contentWorkshop() {
    intro("内容工坊", "新的旅程", " ");
    LinearLayout c = card();
    text(c, "词库 " + content.vocabulary.size() + " · 外加阅读 " + content.extras.size(), 20, INK);
    space(c, 9);
    btn(
        c,
        "导入内容包",
        true,
        () -> {
          Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
          i.setType("*/*");
          i.addCategory(Intent.CATEGORY_OPENABLE);
          startActivityForResult(i, IMPORT_PACK);
        });
    btn(c, "粘贴自己的短文", false, this::addArticle);
    btn(c, "用自己的 API 生成阅读", false, this::apiDialog);
    if (content.extras.size() > 0) btn(c, "整理已读扩展", false, this::archiveReadPack);
    if (game.s.optJSONArray("packArchive") != null
        && game.s.optJSONArray("packArchive").length() > 0)
      btn(
          c,
          "恢复上次整理",
          false,
          () -> {
            JSONArray all = Game.arr(game.s, "contentPack"),
                archived = Game.arr(game.s, "packArchive"),
                merged = new JSONArray();
            HashSet<String> ids = new HashSet<>();
            for (JSONArray batch : new JSONArray[] {all, archived})
              for (int i = 0; i < batch.length(); i++) {
                JSONObject q = batch.optJSONObject(i);
                if (ids.add(q.optString("id"))) merged.put(q);
              }
            if (merged.length() > 300) {
              toast("恢复后超过 300 篇，请先整理其他已读材料");
              return;
            }
            try {
              content.loadPack(merged);
              Game.put(game.s, "contentPack", merged);
              game.s.remove("packArchive");
              save();
              render();
            } catch (Exception e) {
              toast("没有恢复：内容格式无效");
            }
          });
    text(c, "可用兼容 OpenAI 的 HTTPS 接口。生成时使用你的服务额度，材料可先预览再保存。", 13, MUTED);
    btn(
        c,
        "内容包格式",
        false,
        () ->
            showInfo(
                "内容包",
                "JSON 对象包含 readings 数组。每项包含 title、text、zh、prompt、options（2–4 个）、correct（从 0"
                    + " 开始）、explain、level（0–3）。最多 300 篇，每篇英文最多 4,000 字符。"));
  }

  private void archiveReadPack() {
    JSONArray current = Game.arr(game.s, "contentPack"),
        keep = new JSONArray(),
        archive = new JSONArray();
    String battle = game.battle() == null ? "" : game.battle().optString("question"),
        practice =
            game.s.optJSONObject("practice") == null
                ? ""
                : game.s.optJSONObject("practice").optString("question");
    JSONObject read = Game.obj(game.s, "readStories");
    for (int i = 0; i < current.length(); i++) {
      JSONObject q = current.optJSONObject(i);
      String id = q.optString("id");
      if (read.has(id) && !id.equals(battle) && !id.equals(practice)) archive.put(q);
      else keep.put(q);
    }
    if (archive.length() == 0) {
      toast("还没有可整理的已读扩展，当前练习会保留。");
      return;
    }
    Game.put(game.s, "packArchive", archive);
    Game.put(game.s, "contentPack", keep);
    content.loadPack(keep);
    save();
    render();
    toast("已整理 " + archive.length() + " 篇，可以恢复。");
  }

  private void readContentPack(Uri uri) {
    try (InputStream in = getContentResolver().openInputStream(uri);
        ByteArrayOutputStream out = new ByteArrayOutputStream()) {
      byte[] buf = new byte[8192];
      int n;
      while ((n = in.read(buf)) != -1) {
        out.write(buf, 0, n);
        if (out.size() > 1500000) throw new IOException("内容包超过 1.5 MB");
      }
      previewPack(Content.parsePack(new JSONObject(out.toString("UTF-8"))));
    } catch (Exception e) {
      toast("没有导入：" + e.getMessage());
    }
  }

  private void previewPack(JSONArray items) {
    Dialog d = new Dialog(this);
    LinearLayout box = column();
    box.setPadding(dp(20), dp(20), dp(20), dp(16));
    box.setBackground(shape(CARD, 24));
    text(box, "预览 · " + items.length() + " 篇", 23, INK);
    ScrollView sv = new ScrollView(this);
    LinearLayout list = column();
    sv.addView(list);
    box.addView(sv, new LinearLayout.LayoutParams(-1, dp(330)));
    for (int i = 0; i < items.length(); i++) {
      JSONObject q = items.optJSONObject(i);
      text(list, q.optString("title"), 18, INK);
      space(list, 8);
      text(list, q.optString("text"), 16, INK);
      space(list, 8);
      text(
          list,
          "答案："
              + q.optJSONArray("options").optString(q.optInt("correct"))
              + "\n"
              + q.optString("explain"),
          13,
          MUTED);
      space(list, 22);
    }
    btn(
        box,
        "加入我的阅读",
        true,
        () -> {
          JSONArray existing = Game.arr(game.s, "contentPack");
          HashSet<String> ids = new HashSet<>();
          for (int i = 0; i < existing.length(); i++)
            ids.add(existing.optJSONObject(i).optString("id"));
          JSONArray merged = new JSONArray();
          for (int i = 0; i < existing.length(); i++) merged.put(existing.optJSONObject(i));
          for (int i = 0; i < items.length(); i++)
            if (ids.add(items.optJSONObject(i).optString("id"))) merged.put(items.optJSONObject(i));
          if (merged.length() > 300) {
            toast("最多保存 300 篇，请先导出存档再整理");
            return;
          }
          try {
            content.loadPack(merged);
          } catch (Exception e) {
            toast(e.getMessage());
            return;
          }
          Game.put(game.s, "contentPack", merged);
          save();
          d.dismiss();
          go("library");
        });
    btn(box, "取消", false, d::dismiss);
    d.setContentView(box);
    d.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
    d.show();
    d.getWindow()
        .setLayout(Math.min(dp(520), getResources().getDisplayMetrics().widthPixels - dp(24)), -2);
  }

  private void apiDialog() {
    LinearLayout form = column();
    form.setPadding(dp(18), dp(10), dp(18), dp(10));
    EditText endpoint = new EditText(this);
    endpoint.setSingleLine(true);
    endpoint.setHint("https://服务地址/v1/chat/completions");
    endpoint.setText(getPreferences(0).getString("apiEndpoint", ""));
    form.addView(endpoint);
    EditText model = new EditText(this);
    model.setSingleLine(true);
    model.setHint("模型名称");
    model.setText(getPreferences(0).getString("apiModel", ""));
    form.addView(model);
    EditText token = new EditText(this);
    token.setSingleLine(true);
    token.setHint("API Key（仅本次运行保留）");
    token.setInputType(129);
    token.setText(apiToken);
    form.addView(token);
    EditText topic = new EditText(this);
    topic.setHint("想读什么：探险、科技、动漫……");
    topic.setText("A surprising but believable journey");
    form.addView(topic);
    text(form, "只发送主题、当前阅读档位和请求格式。密钥发给你填的地址，请核对域名；可能产生服务费用。", 13, MUTED);
    AlertDialog d =
        new AlertDialog.Builder(this)
            .setTitle("生成 6 篇短文")
            .setView(scrollingForm(form))
            .setNegativeButton("取消", null)
            .setPositiveButton("生成", null)
            .create();
    d.setOnShowListener(
        v ->
            d.getButton(AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener(
                    view -> {
                      String url = endpoint.getText().toString().trim(),
                          m = model.getText().toString().trim(),
                          key = token.getText().toString().trim();
                      try {
                        java.net.URL parsed = new java.net.URL(url);
                        if (!parsed.getProtocol().equals("https") || parsed.getUserInfo() != null)
                          throw new Exception();
                      } catch (Exception e) {
                        toast("请填完整 HTTPS 接口地址");
                        return;
                      }
                      if (m.isEmpty() || key.isEmpty()) {
                        toast("还需要模型名称和密钥");
                        return;
                      }
                      apiToken = key;
                      getPreferences(0)
                          .edit()
                          .putString("apiEndpoint", url)
                          .putString("apiModel", m)
                          .apply();
                      d.dismiss();
                      generatePack(url, m, key, topic.getText().toString());
                    }));
    d.show();
    d.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
  }

  private void generatePack(String url, String model, String token, String topic) {
    ProgressDialog progress = new ProgressDialog(this);
    progress.setMessage("正在生成阅读材料…");
    progress.setCancelable(false);
    progress.show();
    final int level = game.level(1);
    new Thread(
            () -> {
              try {
                JSONArray items = Content.generate(url, model, token, topic, level);
                runOnUiThread(
                    () -> {
                      if (isFinishing() || isDestroyed()) return;
                      progress.dismiss();
                      previewPack(items);
                    });
              } catch (Exception e) {
                runOnUiThread(
                    () -> {
                      if (isFinishing() || isDestroyed()) return;
                      progress.dismiss();
                      showInfo("没有生成成功", "请检查接口、模型和额度。" + e.getMessage());
                    });
              }
            },
            "content-generation")
        .start();
  }

  private static final class CappedScroll extends ScrollView {
    private final int maximum;

    CappedScroll(Context c, int maximum) {
      super(c);
      this.maximum = maximum;
    }

    @Override
    protected void onMeasure(int w, int h) {
      super.onMeasure(
          w,
          View.MeasureSpec.makeMeasureSpec(
              Math.min(maximum, View.MeasureSpec.getSize(h)), View.MeasureSpec.AT_MOST));
    }
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
