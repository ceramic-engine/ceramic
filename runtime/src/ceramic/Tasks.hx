package ceramic;

import ceramic.Shortcuts.*;

class Tasks {

    #if (sys || nodejs || node || hxnodejs)
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
