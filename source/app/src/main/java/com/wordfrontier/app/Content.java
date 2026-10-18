package com.wordfrontier.app;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import java.io.*;
import java.util.*;
import org.json.*;

public final class Content {
  public final ArrayList<Q> all = new ArrayList<>(),
      vocabulary = new ArrayList<>(),
      stories = new ArrayList<>(),
      visits = new ArrayList<>();
  public SQLiteDatabase dictionary;
  public int dictionaryCount;
  public final HashMap<String, Q> byId = new HashMap<>();

  public static final class Q {
    public final JSONObject j;
    public final String id, text, translation, prompt, explain, word, audio, title;
    public final int skill, level, signal, correct;
    public final String[] options, tokens, alternatives;

    Q(JSONObject j) {
      this.j = j;
      id = j.optString("id");
      text = j.optString("text");
      translation = j.optString("zh");
      prompt = j.optString("prompt");
      explain = j.optString("explain");
      word = j.optString("word");
      audio = j.optString("audio");
      title = j.optString("title");
      skill = j.optInt("skill");
      level = j.optInt("level");
      signal = j.optInt("signal", -1);
      correct = j.optInt("correct");
      options = strings(j.optJSONArray("options"));
      tokens = strings(j.optJSONArray("tokens"));
      alternatives = strings(j.optJSONArray("alternatives"));
    }

    public String answer() {
      return skill == 3 ? text : options.length > correct ? options[correct] : "";
    }

    public boolean matches(String value) {
      if (Game.normalized(text).equals(Game.normalized(value))) return true;
      for (String a : alternatives)
        if (Game.normalized(a).equals(Game.normalized(value))) return true;
      return false;
    }

    public int words() {
      return text.trim().isEmpty() ? 0 : text.trim().split("\\s+").length;
    }
  }

  public Content(Context context) throws Exception {
    JSONObject root = new JSONObject(read(context, "content.json"));
    JSONArray qs = root.getJSONArray("questions");
    for (int i = 0; i < qs.length(); i++) {
      Q q = new Q(qs.getJSONObject(i));
      all.add(q);
      byId.put(q.id, q);
      if (q.skill == 0) vocabulary.add(q);
    }
    JSONArray st = root.getJSONArray("stories");
    for (int i = 0; i < st.length(); i++) {
      Q q = new Q(st.getJSONObject(i));
      stories.add(q);
      byId.put(q.id, q);
    }
    dictionaryCount = root.optInt("dictionaryCount");
    JSONArray events = root.optJSONArray("visits");
    if (events != null)
      for (int i = 0; i < events.length(); i++) {
        Q q = new Q(events.getJSONObject(i));
        visits.add(q);
        byId.put(q.id, q);
      }
    File db =
        new File(
            context.getFilesDir(),
            "dictionary-" + root.optString("dictionaryVersion", "v1") + ".db");
    if (!db.exists()) {
      File temp = File.createTempFile("dictionary-", ".tmp", context.getFilesDir());
      try (InputStream in = context.getAssets().open("dictionary.db");
          OutputStream out = new FileOutputStream(temp)) {
        byte[] buffer = new byte[16384];
        int n;
        while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
      }
      if (!temp.renameTo(db)) {
        temp.delete();
        if (!db.exists()) throw new IOException("词典准备失败");
      }
    }
    dictionary =
        SQLiteDatabase.openDatabase(db.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY);
  }

  public static String[] strings(JSONArray a) {
    if (a == null) return new String[0];
    String[] b = new String[a.length()];
    for (int i = 0; i < b.length; i++) b[i] = a.optString(i);
    return b;
  }

  static String read(Context c, String path) throws Exception {
    try (InputStream in = c.getAssets().open(path);
        ByteArrayOutputStream out = new ByteArrayOutputStream()) {
      byte[] buf = new byte[8192];
      int n;
      while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
      return out.toString("UTF-8");
    }
  }

  public Q choose(Game g, int skill, int signal) {
    ArrayList<Q> candidates = new ArrayList<>();
    int desired = g.level(skill), best = 100;
    for (Q q : all) {
      if (q.skill != skill || (q.signal >= 0 && q.signal != signal)) continue;
      int d = Math.abs(q.level - desired);
      if (d < best) {
        candidates.clear();
        best = d;
      }
      if (d == best) candidates.add(q);
    }
    if (candidates.isEmpty()) throw new IllegalStateException("内容缺少这一类型");
    JSONObject seen = Game.obj(g.s, "seen");
    ArrayList<Q> fresh = new ArrayList<>();
    for (Q q : candidates) if (!seen.has(q.id)) fresh.add(q);
    if (!fresh.isEmpty()) return fresh.get(g.nextInt(fresh.size()));
    candidates.sort(
        Comparator.comparingLong(
            q -> seen.optJSONObject(q.id) == null ? 0 : seen.optJSONObject(q.id).optLong("last")));
    int pool = Math.max(1, candidates.size() / 3);
    return candidates.get(g.nextInt(pool));
  }

  public Q review(Game g) {
    ArrayList<Q> due = new ArrayList<>(), fresh = new ArrayList<>();
    long now = System.currentTimeMillis();
    JSONObject words = Game.obj(g.s, "words");
    for (Q q : vocabulary) {
      JSONObject w = words.optJSONObject(q.word);
      if (w != null && w.optLong("due", Long.MAX_VALUE) <= now) due.add(q);
      else if (w == null && Math.abs(q.level - g.level(0)) <= 1) fresh.add(q);
    }
    if (!due.isEmpty()) return due.get(g.nextInt(due.size()));
    if (!fresh.isEmpty()) return fresh.get(g.nextInt(fresh.size()));
    return choose(g, 0, -1);
  }

  public void validateState(Game g) {
    for (String key : new String[] {"battle", "practice"}) {
      JSONObject session = g.s.optJSONObject(key);
      if (session == null) continue;
      String id = session.optString("question");
      if (id.isEmpty() && key.equals("battle") && session.optString("phase").equals("question"))
        continue;
      Q q = byId.get(id);
      if (q == null) throw new IllegalArgumentException("存档含当前版本不支持的题目");
      JSONArray chosen = session.optJSONArray("chosen");
      if (chosen != null) {
        HashSet<Integer> unique = new HashSet<>();
        for (int i = 0; i < chosen.length(); i++) {
          int index = chosen.optInt(i, -1);
          if (index < 0 || index >= q.tokens.length || !unique.add(index))
            throw new IllegalArgumentException("组句顺序记录无效");
        }
      }
      int selected = session.optInt("selected", -2);
      if (selected < -2 || (q.skill != 3 && selected >= q.options.length))
        throw new IllegalArgumentException("答案记录无效");
      JSONArray order = session.optJSONArray("optionOrder");
      if (order != null && q.id.equals(session.optString("optionQuestion"))) {
        HashSet<Integer> unique = new HashSet<>();
        if (order.length() != q.options.length) throw new IllegalArgumentException("选项记录不完整");
        for (int i = 0; i < order.length(); i++) {
          int option = order.optInt(i, -1);
          if (option < 0 || option >= q.options.length || !unique.add(option))
            throw new IllegalArgumentException("选项顺序记录无效");
        }
      }
      if (key.equals("practice")) {
        String mode = session.optString("mode"), phase = session.optString("phase");
        if (!Arrays.asList("cal", "review", "story").contains(mode)
            || !Arrays.asList("question", "feedback", "done").contains(phase))
          throw new IllegalArgumentException("练习状态无效");
        int goal = session.optInt("goal"), index = session.optInt("index", -1);
        if (goal < 1 || goal > 16 || index < 0 || index > goal)
          throw new IllegalArgumentException("练习进度无效");
        if (mode.equals("cal")) {
          JSONArray ids = session.optJSONArray("ids"), scores = session.optJSONArray("scores");
          if (ids == null || ids.length() != 16 || scores == null || scores.length() != 4)
            throw new IllegalArgumentException("抽样记录不完整");
          for (int i = 0; i < 16; i++)
            if (!byId.containsKey(ids.optString(i))) throw new IllegalArgumentException("抽样词条无效");
        }
      }
    }
    JSONArray articles = g.s.optJSONArray("articles");
    if (articles != null) {
      if (articles.length() > 30) throw new IllegalArgumentException("自选文章过多");
      for (int i = 0; i < articles.length(); i++) {
        JSONObject a = articles.optJSONObject(i);
        if (a == null
            || a.optString("text").length() > 15000
            || a.optString("title").length() > 200) throw new IllegalArgumentException("自选文章格式无效");
      }
    }
  }

  public String lookup(String raw) {
    String w = raw.toLowerCase(Locale.ROOT).replaceAll("[^a-z'-]", "");
    try (Cursor c =
        dictionary.rawQuery("SELECT zh,phonetic FROM words WHERE word=?", new String[] {w})) {
      if (!c.moveToFirst()) return "词典中暂未收录这个词形。可以试试它的原形，或换成单个词再查。";
      String zh = c.getString(0), phonetic = c.getString(1);
      return phonetic.isEmpty() ? zh : "/" + phonetic + "/\n\n" + zh;
    }
  }
}
