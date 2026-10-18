package com.wordfrontier.app;

import java.util.*;
import org.json.*;

/** Pure Java rules. Opponents commit before the player's current action. */
public final class Game {
  public static final String[] ACTIONS = {"突击", "固守", "迂回"};
  public static final String[] SKILLS = {"词义", "阅读", "听力", "组句"};
  public static final String[] LEVELS = {"短句起步", "日常短段", "连句进阶", "语意推理"};
  public static final String[] BUILDINGS = {"河岸菜圃", "修缮工坊", "渡河木桥", "旅人会馆"};
  public static final int[] COSTS = {6, 8, 10, 12};
  public static final String[] ENEMIES = {"赤狐 · 急攻手", "岩卫 · 守势派", "游隼 · 迂回者", "灰鸦 · 观察者"};
  public JSONObject s;

  public Game(long seed) {
    s = new JSONObject();
    put(s, "version", 1);
    put(s, "seed", seed == 0 ? 17 : seed);
    put(s, "materials", 4);
    put(s, "levels", new JSONArray().put(1).put(1).put(0).put(1));
  }

  public Game(JSONObject saved) {
    validate(saved);
    s = saved;
  }

  public static void put(JSONObject o, String k, Object v) {
    try {
      o.put(k, v);
    } catch (JSONException e) {
      throw new IllegalStateException(e);
    }
  }

  public static JSONObject obj(JSONObject o, String k) {
    JSONObject v = o.optJSONObject(k);
    if (v == null) {
      v = new JSONObject();
      put(o, k, v);
    }
    return v;
  }

  public static JSONArray arr(JSONObject o, String k) {
    JSONArray v = o.optJSONArray(k);
    if (v == null) {
      v = new JSONArray();
      put(o, k, v);
    }
    return v;
  }

  public static void validate(JSONObject d) {
    if (d.optInt("version", -1) != 1) throw new IllegalArgumentException("存档版本不支持");
    if (d.optInt("materials", 0) < 0 || d.optInt("materials", 0) > 1000000)
      throw new IllegalArgumentException("材料数据无效");
    if (d.optInt("built", 0) < 0 || d.optInt("built", 0) > 15)
      throw new IllegalArgumentException("建筑数据无效");
    JSONArray l = d.optJSONArray("levels");
    if (l == null || l.length() != 4) throw new IllegalArgumentException("学习数据不完整");
    for (int i = 0; i < 4; i++)
      if (l.optInt(i, -1) < 0 || l.optInt(i, -1) > 3) throw new IllegalArgumentException("难度数据无效");
    range(d, "pressure", 0, 2, 1);
    range(d, "growth", 0, 2, 0);
    range(d, "provisions", 0, 9, 0);
    JSONObject visits = d.optJSONObject("visits");
    if (visits != null) {
      Iterator<String> keys = visits.keys();
      while (keys.hasNext()) {
        String key = keys.next();
        if (!Arrays.asList("0", "1", "2", "3").contains(key))
          throw new IllegalArgumentException("来访记录无效");
        range(visits, key, 0, 1, -1);
      }
    }
    for (String key :
        new String[] {
          "answers", "unaided", "readWords", "listenSeconds", "expeditions", "wins", "harvests"
        }) range(d, key, 0, 100000000, 0);
    JSONObject vocabulary = d.optJSONObject("words");
    if (vocabulary != null) {
      Iterator<String> keys = vocabulary.keys();
      while (keys.hasNext()) {
        JSONObject w = vocabulary.optJSONObject(keys.next());
        if (w == null) throw new IllegalArgumentException("词汇记录格式无效");
        range(w, "stage", 0, 4, 0);
        range(w, "days", 0, 100000, 0);
      }
    }
    JSONObject b = d.optJSONObject("battle");
    if (b != null) {
      if (b.optInt("round", -1) < 0 || b.optInt("round", -1) > 8)
        throw new IllegalArgumentException("战斗回合无效");
      String p = b.optString("phase");
      if (!Arrays.asList("question", "feedback", "tactic", "aim", "aftermath", "finished")
          .contains(p)) throw new IllegalArgumentException("战斗阶段无效");
      range(b, "enemy", 0, 3, 0);
      range(b, "loadout", 0, 2, 0);
      range(b, "pressure", 0, 2, 1);
      range(b, "energy", 0, 4, 3);
      range(b, "enemyEnergy", 0, 4, 3);
      range(b, "hp", 0, 40, 36);
      range(b, "enemyHp", 0, 42, 36);
      range(b, "committed", 0, 2, 0);
      range(b, "report", 0, 2, 0);
      range(b, "action", 0, 2, 0);
      JSONArray history = b.optJSONArray("history");
      if (history != null) {
        if (history.length() > 8) throw new IllegalArgumentException("战术记录过长");
        for (int i = 0; i < history.length(); i++)
          if (history.optInt(i, -1) < 0 || history.optInt(i, -1) > 2)
            throw new IllegalArgumentException("战术记录无效");
      }
      if (p.equals("aftermath") && b.optJSONObject("result") == null)
        throw new IllegalArgumentException("缺少交锋结果");
      if (b.optInt("round") == 8 && !p.equals("aftermath") && !p.equals("finished"))
        throw new IllegalArgumentException("已结束的回合状态不一致");
    }
  }

  private static void range(JSONObject o, String key, int min, int max, int fallback) {
    int n = o.optInt(key, fallback);
    if (n < min || n > max) throw new IllegalArgumentException(key + " 数据超出范围");
  }

  public int nextInt(int n) {
    long v = s.optLong("seed", 17);
    v ^= v << 13;
    v ^= v >>> 7;
    v ^= v << 17;
    put(s, "seed", v);
    return (int) ((v & Long.MAX_VALUE) % n);
  }

  public int level(int skill) {
    return arr(s, "levels").optInt(skill, 1);
  }

  public void level(int skill, int value) {
    try {
      arr(s, "levels").put(skill, Math.max(0, Math.min(3, value)));
    } catch (JSONException e) {
      throw new IllegalStateException(e);
    }
  }

  public boolean has(int building) {
    return (s.optInt("built") & (1 << building)) != 0;
  }

  public int builtCount() {
    return Integer.bitCount(s.optInt("built"));
  }

  public boolean build(int building) {
    if (building < 0 || building > 3 || has(building) || s.optInt("materials") < COSTS[building])
      return false;
    put(s, "materials", s.optInt("materials") - COSTS[building]);
    put(s, "built", s.optInt("built") | (1 << building));
    if (builtCount() == 4) put(s, "completed", true);
    return true;
  }

  public boolean harvest() {
    if (!has(0) || s.optInt("growth") < 2 || s.optInt("provisions") >= 9) return false;
    put(s, "growth", 0);
    put(s, "provisions", Math.min(9, s.optInt("provisions") + 1));
    put(s, "harvests", s.optInt("harvests") + 1);
    return true;
  }

  public boolean visitAvailable(int id) {
    return id >= 0 && id < 4 && (id == 0 || has(id - 1));
  }

  public boolean visitDone(int id) {
    return obj(s, "visits").has(String.valueOf(id));
  }

  public boolean acceptVisit(int id, int choice) {
    if (!visitAvailable(id) || visitDone(id) || choice < 0 || choice > 1) return false;
    if (choice == 1 && s.optInt("provisions") >= 9) return false;
    put(obj(s, "visits"), String.valueOf(id), choice);
    if (choice == 0) put(s, "materials", s.optInt("materials") + 2);
    else put(s, "provisions", s.optInt("provisions") + 1);
    return true;
  }

  public JSONObject battle() {
    return s.optJSONObject("battle");
  }

  public void start(int enemy, int loadout, boolean ration, long now) {
    if (battle() != null && !battle().optString("phase").equals("finished"))
      throw new IllegalStateException("先结束或继续当前出战");
    JSONObject b = new JSONObject();
    put(b, "enemy", Math.max(0, Math.min(3, enemy)));
    put(b, "loadout", has(1) ? loadout : 0);
    put(b, "hp", 36);
    put(b, "enemyHp", 36);
    put(b, "energy", 3);
    put(b, "enemyEnergy", 3);
    put(b, "round", 0);
    put(b, "phase", "question");
    put(b, "started", now);
    put(b, "history", new JSONArray());
    put(b, "logs", new JSONArray());
    if (ration && s.optInt("provisions") > 0) {
      put(s, "provisions", s.optInt("provisions") - 1);
      put(b, "hp", 40);
      put(b, "ration", true);
    }
    int pressure = Math.max(0, Math.min(2, s.optInt("pressure", 1)));
    put(b, "pressure", pressure);
    int maximum = new int[] {30, 36, 42}[pressure];
    put(b, "enemyHp", maximum);
    put(b, "enemyMaxHp", maximum);
    put(s, "battle", b);
    prepareRound();
  }

  public void prepareRound() {
    JSONObject b = battle();
    if (b == null) throw new IllegalStateException();
    int kind = b.optInt("enemy"), roll = nextInt(100), action;
    JSONArray hist = arr(b, "history");
    if (kind == 3 && hist.length() > 0 && roll < 70) {
      int[] counts = new int[3];
      for (int i = Math.max(0, hist.length() - 3); i < hist.length(); i++) counts[hist.optInt(i)]++;
      int frequent = 0;
      for (int i = 1; i < 3; i++) if (counts[i] > counts[frequent]) frequent = i;
      action = (frequent + 1) % 3;
    } else if (kind < 3 && roll < 58) action = kind;
    else action = nextInt(3);
    if (!canUse(action, b.optInt("enemyEnergy", 3))) action = 1;
    // The opponent also budgets stamina; these values precede the player's choice.
    put(b, "committed", action);
    int pressure = b.optInt("pressure", 1);
    put(b, "enemyPrecision", pressure == 0 ? 1 : pressure == 2 ? 2 : nextInt(100) < 25 ? 1 : 2);
    int reliability = new int[] {80, 65, 55}[pressure] + (b.optInt("loadout") == 2 ? 10 : 0);
    int report = nextInt(100) < reliability ? action : (action + 1 + nextInt(2)) % 3;
    put(b, "report", report);
    put(b, "reliability", reliability);
    put(b, "phase", "question");
    put(b, "hinted", false);
    put(b, "correct", false);
    put(b, "selected", -2);
    put(b, "chosen", new JSONArray());
    b.remove("question");
    b.remove("result");
    b.remove("transcript");
    b.remove("played");
    b.remove("optionOrder");
    b.remove("optionQuestion");
  }

  public int skillThisRound() {
    int[] seq = {1, 0, 2, 1, 3, 2, 1, 0};
    return seq[battle().optInt("round") % seq.length];
  }

  public void record(
      String id,
      int skill,
      String word,
      boolean correct,
      boolean assisted,
      long now,
      int words,
      int audioSeconds) {
    put(s, "answers", s.optInt("answers") + 1);
    if (correct && !assisted) put(s, "unaided", s.optInt("unaided") + 1);
    JSONObject seen = obj(s, "seen"), item = obj(seen, id);
    put(item, "n", item.optInt("n") + 1);
    put(item, "last", now);
    put(item, "correct", correct);
    put(item, "assisted", assisted);
    if (!word.isEmpty()) {
      JSONObject w = obj(obj(s, "words"), word);
      put(w, "seen", w.optInt("seen") + 1);
      put(w, "lastSeen", now);
      if (correct && !assisted) {
        put(w, "right", w.optInt("right") + 1);
        // Same-session repetitions cannot masquerade as long-term mastery.
        long previous = w.optLong("lastIndependent", 0);
        if (now - w.optLong("lastHelp", 0) >= 10 * 60 * 1000L
            && (previous == 0 || now - previous >= 20 * 60 * 60 * 1000L)) {
          put(w, "days", w.optInt("days") + 1);
          put(w, "lastIndependent", now);
        }
        long due = w.optLong("due", 0);
        if (due <= now) {
          int stage = Math.min(4, w.optInt("stage") + 1);
          put(w, "stage", stage);
          long[] gaps = {
            0,
            10 * 60 * 1000L,
            24 * 60 * 60 * 1000L,
            3 * 24 * 60 * 60 * 1000L,
            7 * 24 * 60 * 60 * 1000L
          };
          put(w, "due", now + gaps[stage]);
        }
      } else {
        put(w, "stage", 0);
        put(w, "lastHelp", now);
        put(w, "due", now + 5 * 60 * 1000L);
      }
    }
    put(s, "readWords", s.optInt("readWords") + words);
    put(s, "listenSeconds", s.optInt("listenSeconds") + audioSeconds);
    JSONObject perf = obj(s, "performance");
    String h = perf.optString("s" + skill, "") + (correct && !assisted ? "1" : "0");
    if (h.length() > 8) h = h.substring(h.length() - 8);
    put(perf, "s" + skill, h);
    if (!s.optBoolean("manualLevel") && h.endsWith("000") && level(skill) > 0) {
      level(skill, level(skill) - 1);
      put(perf, "s" + skill, "");
      put(s, "adjustment", SKILLS[skill] + "：连续几次需要帮助，先缩短一点；随时可以调回。");
    } else if (!s.optBoolean("manualLevel") && h.length() == 8) {
      int good = 0;
      for (char c : h.toCharArray()) if (c == '1') good++;
      if (good >= 7 && level(skill) < 3) {
        level(skill, level(skill) + 1);
        put(perf, "s" + skill, "");
        put(s, "adjustment", SKILLS[skill] + "：试一小步更长的表达；随时可调回。");
      } else if (good <= 3 && level(skill) > 0) {
        level(skill, level(skill) - 1);
        put(perf, "s" + skill, "");
        put(s, "adjustment", SKILLS[skill] + "：先换成更短的表达。");
      }
    }
  }

  public void answer(boolean correct, boolean assisted, int selected) {
    JSONObject b = battle();
    if (!b.optString("phase").equals("question")) return;
    put(b, "correct", correct);
    put(b, "hinted", assisted);
    put(b, "selected", selected);
    put(b, "phase", "feedback");
  }

  public static int cost(int action) {
    return action == 0 ? 2 : action == 2 ? 1 : 0;
  }

  public static boolean canUse(int action, int energy) {
    return action >= 0 && action <= 2 && energy >= cost(action);
  }

  public void choose(int action) {
    JSONObject b = battle();
    if (!b.optString("phase").equals("tactic")) return;
    if (!canUse(action, b.optInt("energy", 3))) return;
    put(b, "action", action);
    put(b, "phase", "aim");
  }

  public void resolve(int precision) {
    JSONObject b = battle();
    if (b == null || !b.optString("phase").equals("aim")) return;
    int a = b.optInt("action"), e = b.optInt("committed"), outcome = (a - e + 3) % 3;
    int dealt = outcome == 1 ? 6 : outcome == 0 ? 3 : 1;
    int received = outcome == 2 ? 6 : outcome == 0 ? 3 : 1;
    boolean initiative = b.optBoolean("correct") && !b.optBoolean("hinted");
    if (initiative) dealt++;
    dealt += Math.max(0, Math.min(2, precision));
    received += b.optInt("enemyPrecision", 2);
    boolean shield = b.optInt("loadout") == 1 && b.optInt("round") < 2;
    if (shield) received = Math.max(0, received - 2);
    put(b, "hp", Math.max(0, b.optInt("hp") - received));
    put(b, "enemyHp", Math.max(0, b.optInt("enemyHp") - dealt));
    put(
        b,
        "energy",
        a == 1 ? Math.min(4, b.optInt("energy", 3) + 2) : b.optInt("energy", 3) - cost(a));
    put(
        b,
        "enemyEnergy",
        e == 1
            ? Math.min(4, b.optInt("enemyEnergy", 3) + 2)
            : b.optInt("enemyEnergy", 3) - cost(e));
    arr(b, "history").put(a);
    String headline = outcome == 1 ? "抓住破绽" : outcome == 2 ? "对方反制" : "正面交锋";
    String detail =
        "你用"
            + ACTIONS[a]
            + "，对方用"
            + ACTIONS[e]
            + "。"
            + (outcome == 1 ? "战术克制成功。" : outcome == 2 ? "这次被对方克制。" : "双方选择相同。")
            + (e != b.optInt("report") ? "这次情报与实际动作不同。" : "实际动作与情报一致。")
            + (initiative ? "本回合英语独立答对，先手 +1。" : "")
            + (shield ? "工坊护具抵挡 2 点。" : "");
    JSONObject result = new JSONObject();
    put(result, "headline", headline);
    put(result, "detail", detail);
    put(result, "dealt", dealt);
    put(result, "received", received);
    put(result, "precision", precision);
    put(result, "enemyPrecision", b.optInt("enemyPrecision", 2));
    put(result, "outcome", outcome);
    put(result, "playerAction", a);
    put(result, "enemyAction", e);
    String[][] reactions = {
      {"这一步一样？那就再来。", "被你抓到破绽了。", "这一下，被我逮到了。"},
      {"稳住，看看下一步。", "好判断。这回是我失算了。", "这一回合，我等到了。"},
      {"看来这一步没拉开差距。", "你把我的打算看穿了。", "你漏了这一手。"},
      {"这次想到一起了。", "这步没猜中，再看一回合。", "这一回合，判断对了。"}
    };
    put(result, "reaction", reactions[b.optInt("enemy")][outcome]);
    put(b, "result", result);
    arr(b, "logs").put(result);
    put(b, "round", b.optInt("round") + 1);
    put(b, "phase", "aftermath");
  }

  public boolean battleOver() {
    JSONObject b = battle();
    return b.optInt("hp") <= 0 || b.optInt("enemyHp") <= 0 || b.optInt("round") >= 8;
  }

  public void finish() {
    JSONObject b = battle();
    if (b == null || b.optBoolean("rewarded")) return;
    if (!battleOver()) throw new IllegalStateException("战斗尚未结束");
    boolean win = b.optInt("hp") > b.optInt("enemyHp");
    boolean tie = b.optInt("hp") == b.optInt("enemyHp");
    int reward = win ? 8 : tie ? 6 : 5;
    put(s, "materials", s.optInt("materials") + reward);
    put(s, "expeditions", s.optInt("expeditions") + 1);
    if (win) put(s, "wins", s.optInt("wins") + 1);
    if (has(0)) put(s, "growth", Math.min(2, s.optInt("growth") + 1));
    put(b, "reward", reward);
    put(b, "win", win);
    put(b, "tie", tie);
    put(b, "rewarded", true);
    put(b, "phase", "finished");
  }

  public int knownCount() {
    int n = 0;
    JSONObject words = obj(s, "words");
    Iterator<String> it = words.keys();
    while (it.hasNext()) {
      JSONObject w = words.optJSONObject(it.next());
      if (w != null && w.optInt("days") >= 3 && w.optInt("stage") >= 2) n++;
    }
    return n;
  }

  public int recognizedCount() {
    int n = 0;
    JSONObject words = obj(s, "words");
    Iterator<String> it = words.keys();
    while (it.hasNext()) {
      JSONObject word = words.optJSONObject(it.next());
      if (word != null && word.optInt("right") > 0) n++;
    }
    return n;
  }

  public int dueCount(long now) {
    int n = 0;
    JSONObject words = obj(s, "words");
    Iterator<String> it = words.keys();
    while (it.hasNext()) {
      JSONObject w = words.optJSONObject(it.next());
      if (w != null && w.optLong("due", Long.MAX_VALUE) <= now) n++;
    }
    return n;
  }

  public static String normalized(String a) {
    return a.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9']+", " ").trim().replaceAll(" +", " ");
  }
}
