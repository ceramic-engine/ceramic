using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>
/// Runs the Ceramic scene in play mode from the command line, without any window:
///
///   Unity -batchmode -nographics -projectPath &lt;project&gt; -executeMethod CeramicBatchMode.Play -logFile &lt;log&gt;
///
/// Do not pass -quit: the editor stays alive to run play mode. The app ends the
/// run itself with EditorApplication.Exit(code). The editor also exits with
/// code 1 if play mode stops or the app hits a critical error, and with code
/// 124 after -ceramicTimeout &lt;seconds&gt; (default 600) if it is still running.
/// Without -nographics there is still no window; when no camera renders, the
/// app is updated by the batch frame driver of Main.regularUpdate().
/// </summary>
[InitializeOnLoad]
public static class CeramicBatchMode
{
    const string ScenePath = "Assets/Scenes/CeramicScene.unity";
    const string PlayingKey = "CeramicBatchMode.playing";

    static double timeout = 600;

    static CeramicBatchMode()
    {
        if (!Application.isBatchMode || !IsBatchPlayRun())
            return;

        timeout = ReadTimeout();
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

        EditorSceneManager.OpenScene(ScenePath);
        SessionState.SetBool(PlayingKey, true);
        EditorApplication.EnterPlaymode();
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

    static double ReadTimeout()
    {
        var args = Environment.GetCommandLineArgs();
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == "-ceramicTimeout" && double.TryParse(args[i + 1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var value))
                return value;
        }
        return 600;
    }

    static void Watch()
    {
        if (EditorApplication.timeSinceStartup > timeout)
        {
            Debug.LogError("CeramicBatchMode: timed out after " + timeout + " seconds");
            EditorApplication.Exit(124);
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
        if (change == PlayModeStateChange.EnteredEditMode && SessionState.GetBool(PlayingKey, false))
        {
            Debug.LogError("CeramicBatchMode: play mode stopped before the app exited");
            EditorApplication.Exit(1);
        }
    }
}
