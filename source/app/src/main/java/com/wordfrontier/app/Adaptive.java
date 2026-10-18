package com.wordfrontier.app;

import java.util.*;
import org.json.*;

/** Low-stakes adaptive frequency probe. Does not claim standardized vocabulary size. */
public final class Adaptive {
  public static JSONObject begin() {
    JSONObject p = new JSONObject();
    Game.put(p, "n", 0);
    Game.put(p, "theta", 3.0);
    Game.put(p, "answers", new JSONArray());
    Game.put(p, "phase", "question");
    return p;
  }

  public static int band(JSONObject p) {
    int n = p.optInt("n");
    if (n == 8) return 1;
    if (n == 16) return 3;
    return Math.max(0, Math.min(7, (int) Math.round(p.optDouble("theta", 3))));
  }

  public static void answer(JSONObject p, int band, boolean correct, boolean certain) {
    int n = p.optInt("n");
    boolean pass = correct && certain;
    double theta = p.optDouble("theta", 3);
    double probability = .25 + .75 / (1 + Math.exp((band - theta) * 1.25));
    double step = n < 6 ? 1.8 : 1.0;
    theta = Math.max(-1, Math.min(9, theta + step * ((pass ? 1 : 0) - probability)));
    JSONObject a = new JSONObject();
    Game.put(a, "band", band);
    Game.put(a, "right", pass);
    Game.arr(p, "answers").put(a);
    Game.put(p, "theta", theta);
    Game.put(p, "n", n + 1);
    Game.put(p, "phase", n + 1 >= 24 ? "done" : "question");
    p.remove("question");
    p.remove("optionOrder");
    p.remove("optionQuestion");
    Game.put(p, "guessed", false);
  }

  public static String result(JSONObject p) {
    double t = p.optDouble("theta", 3);
    int low = Math.max(0, (int) Math.floor(t - 1)), hi = Math.min(7, (int) Math.ceil(t + 1));
    if (t > 7) return "已触及本词库的高阶词上限";
    if (t < 0) return "先巩固常用基础词";
    return "词义起点：" + (t < 1.5 ? "日常常用" : t < 3.5 ? "抽象表达" : t < 5.5 ? "进阶拓展" : "较少见词");
  }

  public static void validate(JSONObject p) {
    if (p == null) return;
    int n = p.optInt("n", -1);
    double t = p.optDouble("theta", Double.NaN);
    JSONArray a = p.optJSONArray("answers");
    if (n < 0 || n > 24 || !Double.isFinite(t) || t < -1 || t > 9 || a == null || a.length() != n)
      throw new IllegalArgumentException("词频抽样记录无效");
    if (!Arrays.asList("question", "done").contains(p.optString("phase")))
      throw new IllegalArgumentException("词频抽样状态无效");
    for (int i = 0; i < a.length(); i++) {
      JSONObject x = a.optJSONObject(i);
      if (x == null || x.optInt("band", -1) < 0 || x.optInt("band") > 7)
        throw new IllegalArgumentException("词频段无效");
    }
  }
}
