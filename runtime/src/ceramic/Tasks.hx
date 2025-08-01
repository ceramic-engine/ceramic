package ceramic;

import ceramic.Shortcuts.*;

/**
 * Utility class for running Task instances from command-line arguments.
 *
 * This class provides a simple task runner system that can execute Task
 * subclasses by name, typically used for build scripts (`ceramic task` command), asset processing,
 * or other command-line utilities and not called directly.
 *
 * Tasks are expected to be in the `tasks` package and extend the Task class.
 *
 * Usage from command line:
 * ```bash
 * haxe build.hxml --task MyTaskName
 * ```
 *
 * Example task implementation:
 * ```haxe
 * package tasks;
 *
 * class ProcessAssets extends ceramic.Task {
 *     override function run():Void {
 *         // Process assets...
 *         if (success) {
 *             done();
 *         } else {
 *             fail("Failed to process assets");
 *         }
 *     }
 * }
 * ```
 */
class Tasks {

    #if (sys || nodejs || node || hxnodejs)
    /**
     * Parse command-line arguments and run the specified task.
     *
     * Looks for `--task TaskName` in the command-line arguments and runs
     * the corresponding task class from the `tasks` package.
     *
     * If no task argument is found, logs a warning.
     * If the task fails or throws an exception, the process exits with code -1.
     * If the task completes successfully, the process exits with code 0.
     */
    public static function runFromArgs():Void {

        var argv = [].concat(Sys.args());
        var i = 0;
        var len = argv.length;

        var task:String = null;
        while (i < len - 1) {
            if (argv[i] == '--task') {
                task = argv[i + 1];
                break;
            }
            i++;
        }

        if (task != null) {
            run(task);
        }
        else {
            log.warning('No task to run (missing --task argument)');
        }

    }

    /**
     * Run a task by name.
     *
     * @param taskName The name of the task class to run (without the `tasks.` package prefix).
     *                 The class must exist in the `tasks` package and extend ceramic.Task.
     *
     * The task lifecycle:
     * 1. Resolves the task class by name from the `tasks` package
     * 2. Creates an instance of the task
     * 3. Sets up done/fail handlers that exit the process
     * 4. Calls the task's run() method
     *
     * Process exit codes:
     * - 0: Task completed successfully
     * - -1: Task failed, was not found, or threw an exception
     */
    public static function run(taskName:String):Void {

        var clazz = Type.resolveClass('tasks.$taskName');

        if (clazz == null) {
            log.error('Unknown task with name: $taskName');
            Sys.exit(-1);
            return;
        }

        try {
            var instance:Task = Type.createInstance(clazz, []);

            instance.onceDone(null, function() {
                instance.destroy();
                Sys.exit(0);
            });

            instance.onceFail(null, function(reason) {
                instance.destroy();
                log.error('Error when running task $taskName: $reason');
                Sys.exit(-1);
            });

            instance.run();

        } catch (e:Dynamic) {
            log.error('Error when running task $taskName: $e');
            Sys.exit(-1);
        }

    }
    #end

}
