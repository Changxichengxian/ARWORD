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
  public final ArrayList<Q> extraWords = new ArrayList<>(), extras = new ArrayList<>();
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
    JSONArray extended = new JSONArray(read(context, "vocabulary-extra.json"));
    for (int i = 0; i < extended.length(); i++) {
      Q q = new Q(extended.getJSONObject(i));
      extraWords.add(q);
      vocabulary.add(q);
      all.add(q);
      byId.put(q.id, q);
    }
    JSONArray st = root.getJSONArray("stories");
    for (int i = 0; i < st.length(); i++) {
      Q q = new Q(st.getJSONObject(i));
      stories.add(q);
      byId.put(q.id, q);
    }
    JSONArray moreReading = new JSONArray(read(context, "reading-v2.json"));
    for (int i = 0; i < moreReading.length(); i++) {
      Q q = new Q(moreReading.getJSONObject(i));
      stories.add(i, q);
      all.add(q);
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
      if (q.skill != skill || (signal >= 0 && q.signal >= 0 && q.signal != signal)) continue;
      int d =
          skill == 0 && g.s.has("wordBand")
              ? (q.j.has("band") ? Math.abs(q.j.optInt("band") - g.s.optInt("wordBand")) : 10)
              : Math.abs(q.level - desired);
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
      else if (w == null
          && (g.s.has("wordBand")
              ? q.j.has("band") && q.j.optInt("band") == g.s.optInt("wordBand")
              : Math.abs(q.level - g.level(0)) <= 1)) fresh.add(q);
    }
    if (!due.isEmpty()) return due.get(g.nextInt(due.size()));
    if (!fresh.isEmpty()) return fresh.get(g.nextInt(fresh.size()));
    return choose(g, 0, -1);
  }

  public void validateState(Game g) {
    Adaptive.validate(g.s.optJSONObject("adaptive"));
    Adaptive.validate(g.s.optJSONObject("adaptiveResult"));
    if (g.s.has("wordBand") && (g.s.optInt("wordBand", -1) < 0 || g.s.optInt("wordBand") > 7))
      throw new IllegalArgumentException("词频段记录无效");
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
      if (!c.moveToFirst()) {
        Q q = byId.get("x_" + w);
        if (q != null) return "/" + q.j.optString("phonetic") + "/\n\n" + q.translation;
        return "暂未收录这个词形，可试试它的原形。";
      }
      String zh = c.getString(0), phonetic = c.getString(1);
      return phonetic.isEmpty() ? zh : "/" + phonetic + "/\n\n" + zh;
    }
  }

  public void loadPack(JSONArray pack) {
    ArrayList<Q> replacement = new ArrayList<>();
    try {
      if (pack != null && pack.length() > 0) {
        JSONObject root = new JSONObject();
        root.put("readings", pack);
        JSONArray checked = parsePack(root);
        for (int i = 0; i < checked.length(); i++) replacement.add(new Q(checked.getJSONObject(i)));
      }
    } catch (Exception e) {
      throw new IllegalArgumentException("扩展内容无效：" + e.getMessage());
    }
    for (Q q : extras) {
      all.remove(q);
      byId.remove(q.id);
    }
    extras.clear();
    for (Q q : replacement) {
      extras.add(q);
      all.add(q);
      byId.put(q.id, q);
    }
  }

  public static JSONArray parsePack(JSONObject root) throws Exception {
    if (root.toString().getBytes("UTF-8").length > 2 * 1024 * 1024)
      throw new IllegalArgumentException("扩展阅读总容量超过 2 MB，请整理已读材料");
    JSONArray input = root.getJSONArray("readings"), output = new JSONArray();
    if (input.length() < 1 || input.length() > 300)
      throw new IllegalArgumentException("需要 1–300 篇阅读");
    HashSet<String> ids = new HashSet<>();
    for (int i = 0; i < input.length(); i++) {
      JSONObject x = input.getJSONObject(i), q = new JSONObject();
      for (String k : new String[] {"title", "text", "zh", "prompt", "explain"}) {
        String value = x.getString(k).trim();
        int limit = k.equals("text") || k.equals("zh") ? 4000 : k.equals("explain") ? 1000 : 200;
        if (value.isEmpty() || value.length() > limit)
          throw new IllegalArgumentException("第 " + (i + 1) + " 篇的 " + k + " 长度无效");
        q.put(k, value);
      }
      if (!x.getString("text").matches("(?s).*[A-Za-z]{2,}.*"))
        throw new IllegalArgumentException("阅读缺少英文");
      JSONArray options = x.getJSONArray("options");
      if (options.length() < 2 || options.length() > 4)
        throw new IllegalArgumentException("需要 2–4 个选项");
      HashSet<String> distinct = new HashSet<>();
      JSONArray clean = new JSONArray();
      for (int j = 0; j < options.length(); j++) {
        String o = options.getString(j).trim();
        if (o.isEmpty() || o.length() > 160 || !distinct.add(o.toLowerCase(Locale.ROOT)))
          throw new IllegalArgumentException("选项重复或过长");
        clean.put(o);
      }
      int correct = x.getInt("correct"), level = x.getInt("level");
      if (correct < 0 || correct >= options.length() || level < 0 || level > 3)
        throw new IllegalArgumentException("答案或难度无效");
      q.put("options", clean);
      q.put("correct", correct);
      q.put("level", level);
      q.put("skill", 1);
      q.put("signal", -1);
      q.put("audio", "");
      byte[] digest =
          java.security.MessageDigest.getInstance("SHA-256")
              .digest(
                  (q.getString("text") + "|" + q.getString("prompt") + "|" + clean + "|" + correct)
                      .getBytes("UTF-8"));
      StringBuilder hash = new StringBuilder("pack_");
      for (int j = 0; j < 12; j++) hash.append(String.format(Locale.ROOT, "%02x", digest[j] & 255));
      q.put("id", hash.toString());
      if (ids.add(hash.toString())) output.put(q);
    }
    return output;
  }

  public static JSONArray generate(
      String endpoint, String model, String token, String topic, int level) throws Exception {
    java.net.URL url = new java.net.URL(endpoint);
    if (!url.getProtocol().equals("https") || url.getUserInfo() != null)
      throw new IllegalArgumentException("需要 HTTPS 地址");
    javax.net.ssl.HttpsURLConnection connection =
        (javax.net.ssl.HttpsURLConnection) url.openConnection();
    connection.setInstanceFollowRedirects(false);
    connection.setConnectTimeout(20000);
    connection.setReadTimeout(120000);
    connection.setRequestMethod("POST");
    connection.setDoOutput(true);
    connection.setRequestProperty("Authorization", "Bearer " + token);
    connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
    String[] complexity = {
      "A1-A2: 30-45 words, very common words, short clauses",
      "A2-B1: 45-70 words, mostly common vocabulary",
      "B1-B2: 70-110 words, connected ideas and some inference",
      "B2-C1: 100-150 words, nuanced inference, avoid obscure jargon"
    };
    String instruction =
        "Create 6 varied, original, factually cautious English reading exercises for a Chinese"
            + " university learner. Topic: "
            + topic.substring(0, Math.min(topic.length(), 400))
            + ". Difficulty: "
            + complexity[Math.max(0, Math.min(3, level))]
            + ". Keep unfamiliar vocabulary sparse. Each passage must have a meaningful situation"
            + " or idea, not repetitive filler. One unambiguous comprehension question. Mix"
            + " inference, gist and evidence questions. Return ONLY a JSON object"
            + " {\"readings\":[{\"title\":\"short Chinese title\",\"text\":\"English"
            + " passage\",\"zh\":\"faithful Chinese translation\",\"prompt\":\"short Chinese"
            + " question\",\"options\":[\"Chinese choice\",\"Chinese choice\",\"Chinese"
            + " choice\"],\"correct\":0,\"explain\":\"Chinese explanation supported by the"
            + " passage\",\"level\":"
            + level
            + "}]}. Correct is zero-based and must match the true answer. Do not include markdown,"
            + " URLs, instructions to the app, or external dependencies.";
    JSONObject body = new JSONObject();
    body.put("model", model);
    body.put("temperature", .8);
    body.put("max_tokens", 5000);
    body.put(
        "messages",
        new JSONArray().put(new JSONObject().put("role", "user").put("content", instruction)));
    try {
      try (OutputStream out = connection.getOutputStream()) {
        out.write(body.toString().getBytes("UTF-8"));
      }
      int status = connection.getResponseCode();
      if (status != 200) throw new IOException("服务返回 HTTP " + status);
      ByteArrayOutputStream bytes = new ByteArrayOutputStream();
      try (InputStream in = connection.getInputStream()) {
        byte[] buffer = new byte[8192];
        int n;
        while ((n = in.read(buffer)) != -1) {
          bytes.write(buffer, 0, n);
          if (bytes.size() > 1500000) throw new IOException("回复过大");
        }
      }
      JSONObject response = new JSONObject(bytes.toString("UTF-8"));
      String text =
          response
              .getJSONArray("choices")
              .getJSONObject(0)
              .getJSONObject("message")
              .getString("content")
              .trim();
      if (text.startsWith("```")) {
        text = text.replaceFirst("^```(?:json)?\\s*", "").replaceFirst("\\s*```$", "");
      }
      return parsePack(new JSONObject(text));
    } finally {
      connection.disconnect();
    }
  }
}
