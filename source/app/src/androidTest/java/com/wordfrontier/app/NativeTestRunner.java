package com.wordfrontier.app;

import android.app.*;
import android.content.*;
import android.graphics.Rect;
import android.media.MediaPlayer;
import android.os.*;
import android.view.*;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.*;
import java.lang.reflect.*;
import java.util.*;
import org.json.*;

/** Runs real native widgets and bundled data on the emulator; no mocked UI. */
public class NativeTestRunner extends Instrumentation {
  MainActivity activity;
  int checks = 0;
  StringBuilder report = new StringBuilder();

  @Override
  public void onCreate(Bundle args) {
    super.onCreate(args);
    start();
  }

  @Override
  public void onStart() {
    Bundle result = new Bundle();
    try {
      runSuite();
      result.putString("stream", "\nPASS " + checks + " native checks\n" + report);
      finish(Activity.RESULT_OK, result);
    } catch (Throwable failure) {
      android.util.Log.e("FrontierTest", "FAILED", failure);
      result.putString(
          "stream",
          "\nFAIL after "
              + checks
              + " checks: "
              + android.util.Log.getStackTraceString(failure)
              + "\n"
              + report);
      finish(Activity.RESULT_CANCELED, result);
    }
  }

  void check(boolean ok, String description) {
    checks++;
    if (!ok) throw new AssertionError(description);
  }

  void log(String value) {
    report.append(value).append('\n');
    android.util.Log.i("FrontierTest", value);
  }

  void ui(Runnable task) {
    final Throwable[] error = {null};
    runOnMainSync(
        () -> {
          try {
            task.run();
          } catch (Throwable e) {
            error[0] = e;
          }
        });
    if (error[0] != null) throw new RuntimeException(error[0]);
    waitForIdleSync();
  }

  Object field(String name) {
    try {
      Field f = MainActivity.class.getDeclaredField(name);
      f.setAccessible(true);
      return f.get(activity);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  void set(String name, Object value) {
    try {
      Field f = MainActivity.class.getDeclaredField(name);
      f.setAccessible(true);
      f.set(activity, value);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  void call(String name, Class<?>[] types, Object... args) {
    try {
      Method m = MainActivity.class.getDeclaredMethod(name, types);
      m.setAccessible(true);
      m.invoke(activity, args);
    } catch (InvocationTargetException e) {
      throw new RuntimeException(e.getCause());
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  Game game() {
    return (Game) field("game");
  }

  Content content() {
    return (Content) field("content");
  }

  void go(String name) {
    ui(() -> call("go", new Class[] {String.class}, name));
  }

  View find(View root, String value, boolean exact) {
    View found = null;
    if (root instanceof TextView && root.isEnabled()) {
      String t = ((TextView) root).getText().toString();
      if (exact ? t.equals(value) : t.startsWith(value)) found = root;
    }
    if (root instanceof ViewGroup) {
      ViewGroup group = (ViewGroup) root;
      for (int i = 0; i < group.getChildCount(); i++) {
        View candidate = find(group.getChildAt(i), value, exact);
        if (candidate != null) found = candidate;
      }
    }
    return found;
  }

  View view(String value, boolean exact) {
    return find(activity.getWindow().getDecorView(), value, exact);
  }

  void click(String value, boolean exact) {
    ui(
        () -> {
          View v = view(value, exact);
          check(v != null, "visible tree contains " + value);
          check(v.isEnabled(), "enabled: " + value);
          v.requestRectangleOnScreen(new Rect(0, 0, v.getWidth(), v.getHeight()), true);
          boolean delivered = v.performClick();
          check(delivered || v instanceof CompoundButton, "click delivered: " + value);
        });
  }

  void fresh() {
    ui(
        () -> {
          Game g = new Game(321);
          Game.put(g.s, "onboarded", true);
          Game.put(g.s, "still", true);
          Game.put(g.s, "sound", false);
          Game.put(g.s, "haptics", false);
          set("game", g);
          call("go", new Class[] {String.class}, "home");
        });
  }

  ArrayList<AccessibilityNodeInfo> editors(AccessibilityNodeInfo root) {
    ArrayList<AccessibilityNodeInfo> found = new ArrayList<>();
    if (root == null) return found;
    if ("android.widget.EditText".contentEquals(root.getClassName())) found.add(root);
    for (int i = 0; i < root.getChildCount(); i++) found.addAll(editors(root.getChild(i)));
    return found;
  }

  void accessibilityText(AccessibilityNodeInfo node, String value) {
    Bundle arguments = new Bundle();
    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value);
    check(
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments),
        "native text input accepted");
    waitForIdleSync();
  }

  void scenario(String id) {
    ui(
        () -> {
          Game g = game();
          g.s.remove("battle");
          g.start(0, 0, false, System.currentTimeMillis());
          Game.put(g.battle(), "question", id);
          if (content().byId.get(id).signal >= 0)
            Game.put(g.battle(), "report", content().byId.get(id).signal);
          Game.put(g.battle(), "phase", "question");
          call("go", new Class[] {String.class}, "battle");
        });
  }

  void answerCorrect() {
    JSONObject b = game().battle();
    Content.Q q = content().byId.get(b.optString("question"));
    click(q.options[q.correct], true);
  }

  void runSuite() throws Exception {
    getUiAutomation();
    Intent launch =
        new Intent(getTargetContext(), MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    activity = (MainActivity) startActivitySync(launch);
    long until = System.currentTimeMillis() + 30000;
    while (!(Boolean) field("ready") && System.currentTimeMillis() < until) Thread.sleep(100);
    check((Boolean) field("ready"), "native app reaches ready state");
    waitForIdleSync();
    check(content().all.size() == 244, "bundled exercise count");
    check(content().stories.size() == 24, "bundled story count");
    check(content().dictionaryCount > 20000, "offline dictionary present");
    String meaning = content().lookup("defend");
    check(meaning.contains("防") || meaning.contains("保"), "Chinese dictionary encoding correct");
    check(!meaning.contains("�"), "dictionary has no replacement characters");
    log("Startup and native SQLite dictionary passed");
    fresh();
    ui(() -> call("startCalibration", new Class[0]));
    for (int i = 0; i < 16; i++) {
      JSONObject p = game().s.optJSONObject("practice");
      Content.Q q = content().byId.get(p.optString("question"));
      if (i == 0) click("这题靠猜测，不计作独立认识", true);
      click(q.options[q.correct], true);
      check(p.optString("phase").equals("feedback"), "calibration feedback visible");
      click(i == 15 ? "完成这一小段" : "下一条", true);
    }
    check(game().s.optBoolean("calibrated"), "calibration persists");
    check(game().s.optInt("unaided") == 15, "guessed correct excluded from unaided count");
    check(game().knownCount() == 0, "calibration does not claim stable mastery");
    check(game().level(1) == 3, "tentative high reading band placed");
    check(game().level(2) == 2, "listening starts more gently");
    log("16-item calibration, guessing, independent domain placement passed");
    fresh();
    scenario("l000");
    click("▶ 播放 / 重播", true);
    Thread.sleep(500);
    ui(
        () -> {
          MediaPlayer p = (MediaPlayer) field("player");
          check(p != null && p.isPlaying(), "real MediaPlayer plays bundled asset");
          check(p.getDuration() > 1000, "nonempty audio duration");
        });
    click("0.8 倍慢速", true);
    ui(
        () ->
            check(
                Math.abs(((MediaPlayer) field("player")).getPlaybackParams().getSpeed() - .8f)
                    < .01,
                "slow playback works"));
    click("打开英文字幕（计为借助帮助）", true);
    check(game().battle().optBoolean("hinted"), "transcript is assistance");
    answerCorrect();
    check(game().battle().optBoolean("correct"), "listening answer accepted");
    check(game().s.optInt("unaided") == 0, "assisted listening excluded");
    log("Bundled listening playback, slow speed, subtitles passed");
    fresh();
    scenario("v000");
    String positions = game().battle().optJSONArray("optionOrder").toString();
    ui(() -> call("render", new Class[0]));
    check(
        game().battle().optJSONArray("optionOrder").toString().equals(positions),
        "choice positions do not jump within the same question");
    content().validateState(new Game(new JSONObject(game().s.toString())));
    int beforeListening = game().s.optInt("listenSeconds");
    click("听读", true);
    Thread.sleep(300);
    ui(
        () -> {
          MediaPlayer p = (MediaPlayer) field("player");
          check(p != null && p.isPlaying(), "word example audio plays");
          p.seekTo(Math.max(0, p.getDuration() - 150));
        });
    Thread.sleep(1600);
    ui(
        () -> {
          check(field("player") == null, "completed playback releases MediaPlayer");
          check(
              game().s.optInt("listenSeconds") > beforeListening, "completed playback is counted");
          check(((HashSet<?>) field("loadedSounds")).size() == 4, "all four feedback sounds load");
        });
    fresh();
    scenario("r027");
    int oldCommit = game().battle().optInt("committed");
    int oldReport = game().battle().optInt("report");
    int oldPressure = game().battle().optInt("pressure");
    click("这段太难，换短一点", true);
    Content.Q easier = content().byId.get(game().battle().optString("question"));
    check(easier.level == 2, "reading moves from long to shorter band immediately");
    check(easier.signal == oldReport, "shortened text preserves the same intelligence");
    check(game().battle().optInt("committed") == oldCommit, "shortening cannot reroll opponent");
    check(
        game().battle().optInt("pressure") == oldPressure,
        "English adjustment preserves combat difficulty");
    log("Word audio completion, sound resources, immediate reading relief passed");
    fresh();
    scenario("o009");
    Content.Q order = content().byId.get("o009");
    for (String token : order.text.split(" ")) click(token, true);
    check(
        Game.arr(game().battle(), "chosen").length() == order.tokens.length,
        "all sentence tokens selected");
    click("提交这句报告", true);
    check(game().battle().optBoolean("correct"), "correct sentence recognized");
    log("Native wrapping word blocks and full sentence submission passed");
    JSONObject corrupt = new JSONObject(game().s.toString());
    Game.put(corrupt.getJSONObject("battle"), "chosen", new JSONArray().put(99));
    boolean rejected = false;
    try {
      content().validateState(new Game(corrupt));
    } catch (IllegalArgumentException expected) {
      rejected = true;
    }
    check(rejected, "out-of-bounds sentence token import rejected");
    for (Content.Q q : content().all) {
      if (q.skill == 3) {
        check(q.matches(q.text), "reference sentence accepted " + q.id);
        for (String alternative : q.alternatives)
          check(q.matches(alternative), "authored alternate sentence accepted " + q.id);
      }
    }
    ui(
        () ->
            check(
                new SceneView.Timing(activity, true).precision() == 1,
                "reduced motion does not grant free perfect precision"));
    log("Sentence variants, malformed save rejection, reduced-motion precision passed");
    fresh();
    scenario("r000");
    String question = game().battle().optString("question");
    int committed = game().battle().optInt("committed");
    click("先回营地，保留这一局", true);
    click("出战", true);
    check(game().battle().optString("question").equals(question), "pausing preserves the question");
    check(game().battle().optInt("committed") == committed, "pausing cannot reroll opponent");
    answerCorrect();
    check(game().battle().optString("phase").equals("feedback"), "answer flows into tactics");
    click("固守\n", false);
    check(game().battle().optString("phase").equals("aim"), "tactic locks before precision step");
    click("稳定出手 · +1", true);
    check(game().battle().optString("phase").equals("aftermath"), "native combat resolves");
    check(game().battle().optInt("energy") == 4, "guard replenishes capped stamina");
    click("下一回合", true);
    check(game().battle().optInt("round") == 1, "next round begins exactly once");
    log("Reading -> tactics -> timing -> result -> next round, plus pause passed");
    fresh();
    ui(
        () -> {
          game().start(0, 0, false, System.currentTimeMillis());
          call("go", new Class[] {String.class}, "battle");
        });
    int completedRounds = 0;
    while (completedRounds < 8) {
      JSONObject liveBattle = game().battle();
      Content.Q liveQuestion = content().byId.get(liveBattle.optString("question"));
      check(
          liveQuestion.signal < 0 || liveQuestion.signal == liveBattle.optInt("report"),
          "authored question and committed intelligence agree");
      int committedAction = liveBattle.optInt("committed");
      if (liveQuestion.skill == 3) {
        for (String token : liveQuestion.text.split(" ")) click(token, true);
        click("提交这句报告", true);
      } else answerCorrect();
      int action = (liveBattle.optInt("report") + 1) % 3;
      if (!Game.canUse(action, liveBattle.optInt("energy"))) action = 1;
      click(Game.ACTIONS[action] + "\n", false);
      click("稳定出手 · +1", true);
      completedRounds++;
      check(liveBattle.optInt("round") == completedRounds, "complete playthrough round count");
      check(
          liveBattle.getJSONObject("result").getInt("enemyAction") == committedAction,
          "actual native playthrough keeps opponent commitment");
      if (game().battleOver()) {
        click("查看这次出战的收获", true);
        break;
      }
      click("下一回合", true);
    }
    check(game().battle().optBoolean("rewarded"), "full native encounter rewards completion");
    check(game().s.optInt("expeditions") == 1, "one full native encounter recorded");
    check(game().s.optInt("materials") >= 9, "completed playthrough advances construction");
    log("Complete native encounter with real question selection, combat, and reward passed");
    fresh();
    ui(
        () -> {
          Game.put(game().s, "materials", 100);
          call("render", new Class[0]);
        });
    for (int i = 0; i < 4; i++) {
      click("建造 · " + Game.COSTS[i] + " 材料", true);
      check(game().has(i), "native building persists " + i);
    }
    check(game().s.optBoolean("completed"), "completed settlement has a real ending");
    check(game().s.optInt("materials") == 64, "native construction spends once");
    ui(
        () -> {
          Game.put(game().s, "growth", 2);
          call("render", new Class[0]);
        });
    click("收获一份行粮", true);
    check(game().s.optInt("provisions") == 1, "native harvest grants ration");
    check(game().s.optInt("growth") == 0, "native harvest resets growth only");
    log("All four buildings, permanent completion, harvest passed");
    fresh();
    ui(() -> call("startStory", new Class[] {String.class}, "s00_0"));
    JSONObject p = game().s.optJSONObject("practice");
    Content.Q story = content().byId.get("s00_0");
    click(story.options[story.correct], true);
    click("完成这一小段", true);
    check(Game.obj(game().s, "readStories").has(story.id), "reading completion saved");
    check(
        game().s.optInt("readWords") == story.words(),
        "reading exposure counts the actual passage");
    log("Reading room comprehension and exposure accounting passed");
    fresh();
    ui(() -> call("addArticle", new Class[0]));
    AccessibilityNodeInfo dialog = null;
    ArrayList<AccessibilityNodeInfo> inputs = new ArrayList<>();
    long inputDeadline = System.currentTimeMillis() + 5000;
    while (inputs.size() != 2 && System.currentTimeMillis() < inputDeadline) {
      Thread.sleep(200);
      dialog = getUiAutomation().getRootInActiveWindow();
      inputs = editors(dialog);
    }
    check(inputs.size() == 2, "article dialog has native title and passage inputs");
    String longTitle = String.join("", Collections.nCopies(240, "a"));
    String passage = String.join(" ", Collections.nCopies(40, "The river is quiet today."));
    accessibilityText(inputs.get(0), longTitle);
    accessibilityText(inputs.get(1), passage);
    dialog = getUiAutomation().getRootInActiveWindow();
    ArrayList<AccessibilityNodeInfo> buttons =
        new ArrayList<>(dialog.findAccessibilityNodeInfosByText("保存"));
    check(!buttons.isEmpty(), "article save control is accessible");
    check(buttons.get(0).performAction(AccessibilityNodeInfo.ACTION_CLICK), "article save click");
    waitForIdleSync();
    JSONObject article = game().s.getJSONArray("articles").getJSONObject(0);
    check(
        article.getString("title").length() == 200,
        "long title is bounded without invalidating save");
    check(
        article.getString("text").equals(passage),
        "full 200-word article retained without truncation");
    content().validateState(new Game(new JSONObject(game().s.toString())));
    click("打开阅读", true);
    click("这次读完了", true);
    check(game().s.optInt("readWords") == 200, "personal article records actual word exposure");
    log("Native article dialog, full text entry, title bound, read completion passed");
    fresh();
    ui(() -> call("openVisit", new Class[] {int.class}, 0));
    Content.Q visit = content().byId.get("e00_0");
    click(visit.options[0], true);
    check(game().visitDone(0), "finite visitor choice persists");
    check(game().s.optInt("materials") == 6, "visitor delivers the chosen construction help");
    check(
        game().s.optInt("answers") == 0, "open choice is not misreported as a correct quiz answer");
    check(game().s.optInt("readWords") == visit.words(), "visitor reading exposure recorded once");
    int beforeVisitReplay = game().s.optInt("materials");
    ui(() -> call("openVisit", new Class[] {int.class}, 0));
    check(game().s.optInt("materials") == beforeVisitReplay, "revisiting cannot duplicate reward");
    fresh();
    ui(
        () -> {
          for (int i = 0; i < 15; i++) {
            Content.Q word = content().vocabulary.get(i);
            game().record(word.id, 0, word.word, true, false, System.currentTimeMillis(), 0, 0);
          }
          call("go", new Class[] {String.class}, "words");
        });
    click("下一页", true);
    check((Integer) field("wordPage") == 1, "word evidence pagination advances");
    click("上一页", true);
    check((Integer) field("wordPage") == 0, "word evidence pagination returns");
    check(game().knownCount() == 0, "word archive cannot create long-term mastery");
    log("Finite visitor choice, no quiz inflation, vocabulary evidence pagination passed");
    fresh();
    go("settings");
    click("减少动画（时机条也会静止）", true);
    check(!game().s.optBoolean("still"), "native switch updates preference");
    click("减少动画（时机条也会静止）", true);
    check(game().s.optBoolean("still"), "native switch can restore preference");
    // A clean, small saved scenario remains for subsequent adb lifecycle tests.
    fresh();
    scenario("r003");
    answerCorrect();
    ui(() -> call("save", new Class[0]));
    log("Saved feedback scenario for process-death continuation checks");
  }
}
