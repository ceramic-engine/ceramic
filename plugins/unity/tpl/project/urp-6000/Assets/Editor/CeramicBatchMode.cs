using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>
/// Runs the Ceramic scene in play mode from the command line, without any window:
///
///   Unity -batchmode -nographics -projectPath &lt;project&gt; -executeMethod CeramicBatchMode.Play -logFile &lt;log&gt;
///
/// Do not pass -quit: the editor stays alive to run play mode. The app ends the
/// run itself, with EditorApplication.Exit(code), or with app.quit() (which stops
/// play mode in the editor): the editor then exits with code 0. The editor exits
/// with code 1 if play mode stops by itself or the app hits a critical error, and
/// with code 124 after -ceramicTimeout &lt;seconds&gt; (default 600) if it is still
/// running. Without -nographics there is still no window; when no camera
/// renders, the app is updated by the batch frame driver of Main.regularUpdate().
///
/// Several runs in one editor: -ceramicRuns &lt;file&gt;, one run per line, each line
/// a list of NAME=value environment variables separated by tabs (empty lines and
/// lines starting with # are skipped). Every run sets its variables (and removes
/// those of the previous run), enters play mode (a fresh domain, so a fresh app)
/// and must end with app.quit(). A run that hits a critical error, stops by
/// itself or takes more than -ceramicRunTimeout &lt;seconds&gt; (default 300) is
/// counted as failed and the next run starts. The editor exits with code 0 when
/// every run ended with app.quit(), 1 otherwise (124 after -ceramicTimeout).
/// </summary>
[InitializeOnLoad]
public static class CeramicBatchMode
{
    const string ScenePath = "Assets/Scenes/CeramicScene.unity";
    const string PlayingKey = "CeramicBatchMode.playing";
    const string QuitRequestedKey = "CeramicBatchMode.quitRequested";
    const string RunIndexKey = "CeramicBatchMode.runIndex";
    const string RunStartKey = "CeramicBatchMode.runStart";
    const string FailedRunsKey = "CeramicBatchMode.failedRuns";
    const string StoppingKey = "CeramicBatchMode.stopping";

    static double timeout = 600;

    static double runTimeout = 300;

    static List<List<KeyValuePair<string, string>>> runs;

    static CeramicBatchMode()
    {
        if (!Application.isBatchMode || !IsBatchPlayRun())
            return;

        timeout = ReadNumberArg("-ceramicTimeout", 600);
        runTimeout = ReadNumberArg("-ceramicRunTimeout", 300);
        runs = ReadRuns();
        EditorApplication.update += Watch;
        EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
    }

    /// <summary>Entry point for -executeMethod.</summary>
    public static void Play()
    {
        if (!Application.isBatchMode)
        {
            Debug.LogError("CeramicBatchMode.Play is meant for -batchmode runs");
            return;
        }

        if (runs != null)
        {
            if (runs.Count == 0)
            {
                Debug.LogError("CeramicBatchMode: -ceramicRuns lists no run");
                EditorApplication.Exit(1);
                return;
            }
            SessionState.SetInt(FailedRunsKey, 0);
            StartRun(0);
            return;
        }

        EditorSceneManager.OpenScene(ScenePath);
        SessionState.SetBool(QuitRequestedKey, false);
        SessionState.SetBool(PlayingKey, true);
        EditorApplication.EnterPlaymode();
    }

    /// <summary>
    /// Entry point for -executeMethod CeramicBatchMode.CheckShaders (no -quit needed):
    /// compiles every pass of the shaders under Assets/Ceramic (only those whose name
    /// contains -ceramicShaderFilter &lt;text&gt; when given) for the graphics API of the
    /// editor, prints their messages, and exits with code 1 if any shader has an error
    /// or none was found, 0 otherwise. Run it without -nographics to compile for the
    /// API of a real device (Metal on macOS).
    /// </summary>
    public static void CheckShaders()
    {
        var filter = ReadArg("-ceramicShaderFilter");
        var checkedShaders = 0;
        var failedShaders = 0;
        Debug.Log("CeramicBatchMode: checking shaders for " + SystemInfo.graphicsDeviceType);
        foreach (var guid in AssetDatabase.FindAssets("t:Shader", new[] { "Assets/Ceramic" }))
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
            if (shader == null || (filter != null && !shader.name.Contains(filter)))
                continue;
            checkedShaders++;
            var material = new Material(shader);
            for (var pass = 0; pass < shader.passCount; pass++)
                ShaderUtil.CompilePass(material, pass, true);
            UnityEngine.Object.DestroyImmediate(material);
            var errors = 0;
            foreach (var message in ShaderUtil.GetShaderMessages(shader))
            {
                var text = "CeramicBatchMode: " + shader.name + " " + message.severity + " (" + message.platform + "): " + message.message + " at " + message.file + ":" + message.line;
                if (message.severity == UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error)
                {
                    errors++;
                    Debug.LogError(text);
                }
                else
                {
                    Debug.LogWarning(text);
                }
            }
            if (errors > 0 || ShaderUtil.ShaderHasError(shader))
                failedShaders++;
            Debug.Log("CeramicBatchMode: shader " + shader.name + " (" + shader.passCount + " pass(es)): " + (errors > 0 || ShaderUtil.ShaderHasError(shader) ? "ERROR" : "ok"));
        }
        Debug.Log("CeramicBatchMode: " + checkedShaders + " shaders checked, " + failedShaders + " with errors");
        EditorApplication.Exit(failedShaders > 0 || checkedShaders == 0 ? 1 : 0);
    }

    static void StartRun(int index)
    {
        if (index > 0)
        {
            foreach (var variable in runs[index - 1])
                Environment.SetEnvironmentVariable(variable.Key, null);
            // Textures and meshes of the previous app are no scene objects:
            // release them before the next run
            EditorUtility.UnloadUnusedAssetsImmediate();
        }
        foreach (var variable in runs[index])
            Environment.SetEnvironmentVariable(variable.Key, variable.Value);

        Debug.Log("CeramicBatchMode: run " + (index + 1) + "/" + runs.Count + " " + Describe(runs[index]));
        SessionState.SetInt(RunIndexKey, index);
        SessionState.SetFloat(RunStartKey, (float)EditorApplication.timeSinceStartup);
        SessionState.SetBool(StoppingKey, false);
        SessionState.SetBool(QuitRequestedKey, false);
        SessionState.SetBool(PlayingKey, true);
        EditorSceneManager.OpenScene(ScenePath);
        EditorApplication.EnterPlaymode();
    }

    static string Describe(List<KeyValuePair<string, string>> run)
    {
        var parts = new List<string>();
        foreach (var variable in run)
            parts.Add(variable.Key + "=" + variable.Value);
        return string.Join(" ", parts);
    }

    /// <summary>Ends the current run of a run list and starts the next one, or exits.</summary>
    static void FinishRun(bool success)
    {
        var index = SessionState.GetInt(RunIndexKey, 0);
        var failed = SessionState.GetInt(FailedRunsKey, 0);
        if (!success)
        {
            failed++;
            SessionState.SetInt(FailedRunsKey, failed);
        }
        if (index + 1 < runs.Count)
        {
            EditorApplication.delayCall += () => StartRun(index + 1);
            return;
        }
        Debug.Log("CeramicBatchMode: " + runs.Count + " runs, " + failed + " failed");
        EditorApplication.Exit(failed > 0 ? 1 : 0);
    }

    /// <summary>Stops the current run of a run list (it failed); the next one starts once play mode stopped.</summary>
    static void StopRun(string reason)
    {
        if (SessionState.GetBool(StoppingKey, false))
            return;
        SessionState.SetBool(StoppingKey, true);
        Debug.LogError("CeramicBatchMode: run " + (SessionState.GetInt(RunIndexKey, 0) + 1) + " failed: " + reason);
        EditorApplication.ExitPlaymode();
    }

    static bool IsBatchPlayRun()
    {
        var args = Environment.GetCommandLineArgs();
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == "-executeMethod" && args[i + 1] == "CeramicBatchMode.Play")
                return true;
        }
        return false;
    }

    static string ReadArg(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == name)
                return args[i + 1];
        }
        return null;
    }

    static double ReadNumberArg(string name, double defaultValue)
    {
        var text = ReadArg(name);
        if (text != null && double.TryParse(text, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var value))
            return value;
        return defaultValue;
    }

    static List<List<KeyValuePair<string, string>>> ReadRuns()
    {
        var path = ReadArg("-ceramicRuns");
        if (path == null)
            return null;
        var result = new List<List<KeyValuePair<string, string>>>();
        foreach (var line in File.ReadAllLines(path))
        {
            if (line.Trim().Length == 0 || line.TrimStart().StartsWith("#"))
                continue;
            var run = new List<KeyValuePair<string, string>>();
            foreach (var field in line.Split('\t'))
            {
                if (field.Length == 0)
                    continue;
                var equal = field.IndexOf('=');
                if (equal <= 0)
                {
                    Debug.LogError("CeramicBatchMode: invalid variable \"" + field + "\" in " + path);
                    continue;
                }
                run.Add(new KeyValuePair<string, string>(field.Substring(0, equal), field.Substring(equal + 1)));
            }
            result.Add(run);
        }
        return result;
    }

    static void Watch()
    {
        if (EditorApplication.timeSinceStartup > timeout)
        {
            Debug.LogError("CeramicBatchMode: timed out after " + timeout + " seconds");
            EditorApplication.Exit(124);
            return;
        }

        if (runs != null)
        {
            if (!EditorApplication.isPlaying || !SessionState.GetBool(PlayingKey, false))
                return;
            if (haxe.root.Main.hasCriticalError())
                StopRun("the app hit a critical error");
            else if (EditorApplication.timeSinceStartup - SessionState.GetFloat(RunStartKey, 0) > runTimeout)
                StopRun("timed out after " + runTimeout + " seconds");
            return;
        }

        if (EditorApplication.isPlaying && haxe.root.Main.hasCriticalError())
        {
            Debug.LogError("CeramicBatchMode: the app hit a critical error");
            EditorApplication.Exit(1);
        }
    }

    static void OnPlayModeStateChanged(PlayModeStateChange change)
    {
        if (change != PlayModeStateChange.EnteredEditMode || !SessionState.GetBool(PlayingKey, false))
            return;

        SessionState.SetBool(PlayingKey, false);
        var quitRequested = SessionState.GetBool(QuitRequestedKey, false);
        SessionState.SetBool(QuitRequestedKey, false);

        if (runs != null)
        {
            var stopped = SessionState.GetBool(StoppingKey, false);
            if (!quitRequested && !stopped)
                Debug.LogError("CeramicBatchMode: run " + (SessionState.GetInt(RunIndexKey, 0) + 1) + " failed: play mode stopped before the app quit");
            FinishRun(quitRequested && !stopped);
            return;
        }

        if (quitRequested)
        {
            EditorApplication.Exit(0);
            return;
        }

        Debug.LogError("CeramicBatchMode: play mode stopped before the app exited");
        EditorApplication.Exit(1);
    }
}
