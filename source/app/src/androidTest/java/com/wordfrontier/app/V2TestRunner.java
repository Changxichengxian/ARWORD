package com.wordfrontier.app;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.media.MediaPlayer;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.util.*;
import org.json.*;

/** Exercises the shipped native views, pack parser, adaptive probe and real audio. */
public final class V2TestRunner extends NativeTestRunner {
  boolean layoutOnly;

  @Override
  public void onCreate(android.os.Bundle args) {
    layoutOnly = args != null && args.getBoolean("layoutOnly", false);
    if (args != null && "true".equals(args.getString("layoutOnly"))) layoutOnly = true;
    super.onCreate(args);
  }

  void dialogClick(String label) throws Exception {
    Thread.sleep(200);
    android.view.accessibility.AccessibilityNodeInfo root =
        getUiAutomation().getRootInActiveWindow();
    for (android.view.accessibility.AccessibilityNodeInfo n :
        root.findAccessibilityNodeInfosByText(label))
      if (label.contentEquals(n.getText()) && n.isClickable()) {
        check(
            n.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK),
            "dialog click " + label);
        Thread.sleep(250);
        waitForIdleSync();
        return;
      }
    throw new AssertionError("Missing dialog action " + label);
  }

  @Override
  void fresh() {
    super.fresh();
    ui(() -> content().loadPack(null));
  }

  void screenshot(String name) throws Exception {
    Thread.sleep(350);
    android.view.accessibility.AccessibilityNodeInfo root =
        getUiAutomation().getRootInActiveWindow();
    check(
        root != null && "com.wordfrontier.app".contentEquals(root.getPackageName()),
        "no system dialog covers screenshot");
    Bitmap b = getUiAutomation().takeScreenshot();
    File dir = new File(getTargetContext().getExternalFilesDir(null), "v2-qa");
    dir.mkdirs();
    try (FileOutputStream out = new FileOutputStream(new File(dir, name + ".png"))) {
      b.compress(Bitmap.CompressFormat.PNG, 100, out);
    }
    b.recycle();
  }

  int scrollCount(View v) {
    int n = v instanceof ScrollView ? 1 : 0;
    if (v instanceof ViewGroup) {
      ViewGroup g = (ViewGroup) v;
      for (int i = 0; i < g.getChildCount(); i++) n += scrollCount(g.getChildAt(i));
    }
    return n;
  }

  @Override
  void click(String value, boolean exact) {
    ui(
        () -> {
          View v = view(value, exact);
          check(v != null, "view exists: " + value);
          v.requestRectangleOnScreen(
              new android.graphics.Rect(0, 0, v.getWidth(), v.getHeight()), true);
        });
    ui(
        () -> {
          View v = view(value, exact);
          android.graphics.Rect r = new android.graphics.Rect();
          check(
              v.getGlobalVisibleRect(r) && r.width() > 20 && r.height() > 20,
              "button is visibly laid out: " + value);
        });
    super.click(value, exact);
  }

  @Override
  void runSuite() throws Exception {
    getUiAutomation();
    Intent launch = new Intent(getTargetContext(), MainActivity.class);
    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    activity = (MainActivity) startActivitySync(launch);
    long until = System.currentTimeMillis() + 40000;
    while (!(Boolean) field("ready") && System.currentTimeMillis() < until) Thread.sleep(100);
    check((Boolean) field("ready"), "app ready");
    String saved = game().s.toString();
    try {
      if (layoutOnly) {
        fresh();
        go("home");
        screenshot("10-compact-camp");
        click("出发交锋  ›", true);
        screenshot("11-compact-deploy");
        click("开始交锋", true);
        screenshot("12-compact-question");
        go("learn");
        screenshot("13-compact-learn");
        click("组织句子", true);
        screenshot("14-compact-ordering");
        return;
      }
      check(content().extraWords.size() == 1200, "1200 additional words");
      check(content().vocabulary.size() == 1360, "1360 word exercises");
      for (Content.Q q : content().extraWords) {
        check(q.options.length == 4, "four options " + q.id);
        check(new HashSet<>(Arrays.asList(q.options)).size() == 4, "distinct options " + q.id);
        check(q.j.optInt("band") >= 0 && q.j.optInt("band") < 8, "band " + q.id);
      }
      check(content().lookup("defend").contains("防"), "native dictionary");
      JSONObject high = Adaptive.begin(), low = Adaptive.begin();
      for (int i = 0; i < 24; i++) {
        Adaptive.answer(high, Adaptive.band(high), true, true);
        Adaptive.answer(low, Adaptive.band(low), false, false);
      }
      check(high.optDouble("theta") > 7, "all-correct reaches extended ceiling");
      check(low.optDouble("theta") < 0, "all-wrong moves to foundation");
      Adaptive.validate(high);
      Adaptive.validate(low);
      JSONObject guessed = Adaptive.begin();
      Adaptive.answer(guessed, 3, true, false);
      check(!Game.arr(guessed, "answers").optJSONObject(0).optBoolean("right"), "guessed excluded");
      JSONObject root =
          new JSONObject(
              "{\"readings\":[{\"title\":\"测试来信\",\"text\":\"The bridge was closed, so Mina took"
                  + " the boat.\",\"zh\":\"桥关闭了，因此米娜乘船。\",\"prompt\":\"她为什么坐船？\",\"options\":[\"桥关闭了\",\"她在比赛\",\"她没有地图\"],\"correct\":0,\"explain\":\"第一句说明桥关闭了。\",\"level\":1}]}");
      JSONArray pack = Content.parsePack(root);
      check(pack.length() == 1, "parse content pack");
      String id = pack.optJSONObject(0).optString("id");
      JSONObject again = new JSONObject().put("readings", pack);
      check(
          Content.parsePack(again).optJSONObject(0).optString("id").equals(id),
          "stable content id");
      root.getJSONArray("readings").getJSONObject(0).put("correct", 8);
      boolean rejected = false;
      try {
        Content.parsePack(root);
      } catch (Exception e) {
        rejected = true;
      }
      check(rejected, "invalid answer rejected");
      content().loadPack(pack);
      boolean atomic = false;
      try {
        content().loadPack(root.getJSONArray("readings"));
      } catch (Exception e) {
        atomic = true;
      }
      check(
          atomic && content().byId.containsKey(id),
          "invalid replacement preserves previous catalog");
      fresh();
      File packFile = new File(getTargetContext().getCacheDir(), "qa-pack.json");
      try (FileOutputStream f = new FileOutputStream(packFile)) {
        f.write(
            new JSONObject()
                .put("readings", pack)
                .toString()
                .getBytes(java.nio.charset.StandardCharsets.UTF_8));
      }
      ui(
          () ->
              call(
                  "readContentPack",
                  new Class[] {android.net.Uri.class},
                  android.net.Uri.fromFile(packFile)));
      check(content().extras.isEmpty(), "preview does not import automatically");
      dialogClick("加入我的阅读");
      check(
          content().extras.size() == 1 && Game.arr(game().s, "contentPack").length() == 1,
          "native preview imports content");
      ui(
          () -> {
            Game.put(Game.obj(game().s, "readStories"), id, true);
            call("archiveReadPack", new Class[0]);
          });
      check(content().extras.isEmpty(), "archive removes read items from active pool");
      go("workshop");
      click("恢复上次整理", true);
      check(content().extras.size() == 1, "archive restore restores content");
      fresh();
      ui(
          () -> {
            Game.put(game().s, "contentPack", pack);
            content().loadPack(pack);
            call("startStory", new Class[] {String.class}, id);
          });
      check(content().byId.containsKey(id), "import available");
      click("桥关闭了", true);
      check(game().s.optJSONObject("practice").optBoolean("correct"), "imported question playable");
      content().validateState(new Game(new JSONObject(game().s.toString())));
      log("Content, frequency ceiling, guessing and pack roundtrip passed");
      ui(() -> content().loadPack(new JSONArray()));
      check(content().extras.isEmpty(), "empty saved pack accepted");
      fresh();
      ui(() -> call("startSkill", new Class[] {int.class}, 2));
      JSONObject listening = game().s.optJSONObject("practice");
      check(
          content().byId.get(listening.optString("question")).skill == 2,
          "listening practice selects all signals");
      click("▶ 播放", true);
      click("0.8×", true);
      ui(
          () ->
              check(
                  Math.abs(((MediaPlayer) field("player")).getPlaybackParams().getSpeed() - .8f)
                      < .01,
                  "slow neural speech"));
      click("字幕", true);
      check(listening.optBoolean("hinted"), "subtitles mark help");
      screenshot("08-listening");
      fresh();
      ui(
          () -> {
            game().level(3, 0);
            call("startSkill", new Class[] {int.class}, 3);
          });
      JSONObject ordering = game().s.optJSONObject("practice");
      Content.Q sentence = content().byId.get(ordering.optString("question"));
      for (String word : sentence.text.split(" ")) click(word, true);
      screenshot("09-ordering");
      click("提交", true);
      check(ordering.optBoolean("correct"), "native word tiles produce a correct sentence");
      log("Separate listening, slow playback, subtitles and sentence tiles passed");
      fresh();
      ui(() -> call("startAdaptive", new Class[0]));
      HashSet<String> sampled = new HashSet<>();
      int highest = 0;
      for (int i = 0; i < 24; i++) {
        JSONObject p = game().s.optJSONObject("adaptive");
        Content.Q q = content().byId.get(p.optString("question"));
        check(sampled.add(q.id), "assessment samples without repeats");
        highest = Math.max(highest, q.j.optInt("band"));
        click(q.options[q.correct], true);
      }
      check(highest == 7, "UI reaches hardest band");
      check(game().s.has("adaptiveResult"), "assessment result persisted");
      check(
          game().level(1) == 1 && game().level(2) == 0,
          "vocabulary does not overwrite reading/listening");
      screenshot("03-assessment");
      fresh();
      ui(
          () -> {
            Game.put(game().s, "materials", 100);
            for (int i = 0; i < 4; i++) game().build(i);
            Game.put(game().s, "growth", 2);
            call("go", new Class[] {String.class}, "home");
          });
      check(scrollCount(activity.getWindow().getDecorView()) == 0, "home has no scroll container");
      screenshot("01-camp");
      ui(() -> call("go", new Class[] {String.class}, "deploy"));
      screenshot("02-deploy");
      click("开始交锋", true);
      int rounds = 0;
      while (!game().battle().optString("phase").equals("finished") && rounds < 9) {
        JSONObject b = game().battle();
        Content.Q q = content().byId.get(b.optString("question"));
        if (rounds == 0) screenshot("04-reading-battle");
        if (q.skill == 3) click("看示范", true);
        else {
          if (q.skill == 2) {
            click("▶ 播放", true);
            Thread.sleep(350);
            ui(
                () -> {
                  MediaPlayer mp = (MediaPlayer) field("player");
                  check(mp != null && mp.getDuration() > 1000, "bundled listening playable");
                });
          }
          click(q.options[q.correct], true);
        }
        if (b.optInt("focus") >= 2 && !b.has("ability")) {
          click("洞察 −2", true);
          check(
              b.optInt("report") == b.optInt("committed") && b.optInt("reliability") == 100,
              "insight reveals committed move");
        }
        if (rounds == 1) screenshot("05-tactics");
        int action = (b.optInt("committed") + 1) % 3;
        if (!Game.canUse(action, b.optInt("energy"))) action = 1;
        String[] marks = {"⚔", "▣", "➜"};
        click(
            marks[action]
                + "\n"
                + Game.ACTIONS[action]
                + "\n"
                + (action == 1 ? "体力 +2" : "体力 −" + Game.cost(action)),
            true);
        click("稳定出手 +1", true);
        if (rounds == 1) screenshot("06-clash");
        click(game().battleOver() ? "领取收获" : "下一回合  ›", true);
        rounds++;
      }
      check(game().battle().optBoolean("rewarded"), "full battle rewards exactly once");
      int material = game().s.optInt("materials");
      ui(() -> game().finish());
      check(game().s.optInt("materials") == material, "reward idempotent");
      ui(() -> call("showWord", new Class[] {String.class}, "ambiguous"));
      screenshot("07-word-card");
      ui(() -> activity.onBackPressed());
      log("24-step native assessment, building scene, full battle and real media passed");
      for (int kind = 0; kind < 2; kind++) {
        Game g = new Game(12);
        g.start(0, 0, false, 1);
        Game.put(g.battle(), "v2", true);
        Game.put(g.battle(), "phase", "feedback");
        Game.put(g.battle(), "focus", 3);
        Game.put(g.battle(), "hp", 30);
        check(g.ability(kind), "ability usable");
        check(g.battle().optInt("focus") == 1, "ability spends two");
        check(!g.ability(kind), "no repeated ability");
        Game.validate(g.s);
      }
      log("Focus spending and save validation passed");
    } finally {
      ui(
          () -> {
            try {
              Game original = new Game(new JSONObject(saved));
              set("game", original);
              content().loadPack(original.s.optJSONArray("contentPack"));
              call("go", new Class[] {String.class}, "home");
            } catch (Exception e) {
              throw new RuntimeException(e);
            }
          });
    }
  }
}
