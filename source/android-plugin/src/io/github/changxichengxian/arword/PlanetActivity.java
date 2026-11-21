package io.github.changxichengxian.arword;

import android.os.Build;

import org.godotengine.godot.GodotActivity;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public abstract class PlanetActivity extends GodotActivity {
    @Override
    public List<String> getCommandLine() {
        List<String> args = super.getCommandLine();
        // Select the graphics API before Godot creates its Android surface.
        if (!isFindX7Ultra(Build.MODEL) && !isFindX7Ultra(Build.DEVICE)) {
            return args;
        }
        int separator = args.indexOf("--");
        int end = separator < 0 ? args.size() : separator;
        List<String> engineArgs = args.subList(0, end);
        if (engineArgs.contains("--rendering-method") || engineArgs.contains("--rendering-driver")) {
            return args;
        }
        List<String> result = new ArrayList<>(args);
        result.addAll(end, Arrays.asList("--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"));
        return result;
    }

    private static boolean isFindX7Ultra(String model) {
        return "PHY110".equalsIgnoreCase(model) || "PHY120".equalsIgnoreCase(model)
                || "OPPO Find X7 Ultra".equalsIgnoreCase(model) || "Find X7 Ultra".equalsIgnoreCase(model);
    }
}
