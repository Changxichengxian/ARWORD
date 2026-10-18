import com.wordfrontier.app.Game;
import java.util.*;
import org.json.*;

public class CoreTest {
  static int assertions = 0;

  static void check(boolean condition, String message) {
    assertions++;
    if (!condition) throw new AssertionError(message);
  }

  static Game game(long seed) {
    return new Game(seed);
  }

  public static void main(String[] args) throws Exception {
    Game g = game(7);
    g.start(0, 0, false, 1000);
    int committed = g.battle().optInt("committed");
    Game.put(g.battle(), "phase", "tactic");
    g.choose((committed + 1) % 3);
    check(
        g.battle().optInt("committed") == committed,
        "current input cannot alter opponent commitment");
    g.resolve(1);
    int hp = g.battle().optInt("hp");
    g.resolve(2);
    check(hp == g.battle().optInt("hp"), "duplicate input cannot apply damage twice");
    check(g.battle().optInt("round") == 1, "one resolved round");
    Game resumed = new Game(new JSONObject(g.s.toString()));
    check(resumed.s.toString().equals(g.s.toString()), "exact JSON roundtrip");
    for (int i = 0; i < 30; i++)
      check(resumed.nextInt(100) == g.nextInt(100), "random sequence survives restarts");
    Game economy = game(3);
    check(!economy.build(0), "cannot build without resources");
    Game.put(economy.s, "materials", 100);
    for (int i = 0; i < 4; i++) {
      check(economy.build(i), "build available");
      check(!economy.build(i), "no duplicate building charge");
    }
    check(economy.s.optInt("materials") == 64, "exact construction cost");
    check(economy.s.optBoolean("completed"), "finite completion");
    check(!economy.harvest(), "no unripe harvest");
    Game.put(economy.s, "growth", 2);
    check(economy.harvest(), "ripe harvest");
    check(economy.s.optInt("provisions") == 1, "one provision");
    check(!economy.harvest(), "harvest idempotence");
    Game words = game(1);
    long now = 2_000_000_000_000L;
    words.record("x", 0, "sample", true, false, now, 0, 0);
    check(words.knownCount() == 0, "one correct answer is not mastery");
    for (int i = 0; i < 20; i++) words.record("x", 0, "sample", true, false, now + i * 1000, 0, 0);
    check(words.knownCount() == 0, "immediate repeats are not independent days");
    words.record("x", 0, "sample", true, true, now + 86400000, 0, 0);
    check(words.knownCount() == 0, "assistance cannot establish mastery");
    words.record("x", 0, "sample", true, false, now + 86400000 + 660001, 0, 0);
    words.record("x", 0, "sample", true, false, now + 2 * 86400000L + 660002, 0, 0);
    check(words.knownCount() == 1, "spaced independent retrieval contributes");
    words.record("x", 0, "sample", false, false, now + 3 * 86400000L, 0, 0);
    check(words.knownCount() == 0, "failure returns word to learning");
    Game adapt = game(1);
    int oldListen = adapt.level(2);
    for (int i = 0; i < 8; i++) adapt.record("a" + i, 1, "", true, false, now + i, 20, 0);
    check(adapt.level(1) == 2, "reading moves up one level after evidence");
    check(adapt.level(2) == oldListen, "reading does not certify listening");
    check(adapt.s.optInt("readWords") == 160, "read exposure count");
    boolean rejected = false;
    try {
      new Game(new JSONObject("{\"version\":999}"));
    } catch (IllegalArgumentException e) {
      rejected = true;
    }
    check(rejected, "reject unknown save format");
    Game relief = game(11);
    relief.level(1, 3);
    for (int i = 0; i < 3; i++) relief.record("hard" + i, 1, "", true, true, now + i, 30, 0);
    check(relief.level(1) == 2, "three consecutive assisted readings reduce length promptly");
    check(relief.level(2) == 0, "reading relief leaves listening unchanged");
    Game manual = game(12);
    Game.put(manual.s, "manualLevel", true);
    manual.level(1, 3);
    for (int i = 0; i < 16; i++) manual.record("manual" + i, 1, "", false, false, now + i, 30, 0);
    check(manual.level(1) == 3, "manual level is respected despite repeated errors");
    Game bad = game(1);
    bad.start(0, 0, false, now);
    Game.put(bad.battle(), "energy", 99);
    rejected = false;
    try {
      new Game(new JSONObject(bad.s.toString()));
    } catch (IllegalArgumentException e) {
      rejected = true;
    }
    check(rejected, "invalid stamina cannot be imported");
    Game visitors = game(21);
    check(visitors.acceptVisit(0, 0), "first visitor can be accepted");
    check(visitors.s.optInt("materials") == 6, "visitor gives promised boards");
    check(!visitors.acceptVisit(0, 1), "visitor reward is one-time");
    check(!visitors.acceptVisit(1, 0), "garden visitor requires garden");
    check(visitors.build(0), "visitor can enable first building");
    check(visitors.acceptVisit(1, 1), "garden visitor offers provision");
    Game.put(visitors.s, "provisions", 9);
    Game.put(visitors.s, "growth", 2);
    check(!visitors.harvest(), "full food inventory preserves crop");
    check(visitors.s.optInt("growth") == 2, "ripe crop not lost at inventory limit");
    simulate();
    System.out.println("PASS " + assertions + " assertions");
  }

  static void simulate() {
    for (int policy = 0; policy < 3; policy++) {
      int win = 0, tie = 0, totalRounds = 0;
      for (int i = 1; i <= 2000; i++) {
        Game g = game(i * 719L);
        g.start(i % 4, 0, false, 1);
        while (true) {
          JSONObject b = g.battle();
          Game.put(b, "correct", true);
          Game.put(b, "phase", "tactic");
          int action = policy == 0 ? (b.optInt("report") + 1) % 3 : policy == 1 ? g.nextInt(3) : 0;
          if (!Game.canUse(action, b.optInt("energy", 3))) action = 1;
          g.choose(action);
          g.resolve(1);
          totalRounds++;
          if (g.battleOver()) break;
          g.prepareRound();
        }
        g.finish();
        int before = g.s.optInt("materials");
        g.finish();
        check(before == g.s.optInt("materials"), "finish reward once");
        check(g.s.optInt("materials") >= 9, "completed defeat earns progress");
        check(g.battle().optInt("round") <= 8, "encounter bounded");
        if (g.battle().optBoolean("win")) win++;
        if (g.battle().optBoolean("tie")) tie++;
      }
      System.out.println(
          "policy="
              + policy
              + " wins="
              + win
              + " ties="
              + tie
              + " /2000 averageRounds="
              + (totalRounds / 2000.0));
    }
  }
}
