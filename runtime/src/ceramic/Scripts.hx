package ceramic;

import ceramic.Shortcuts.*;

class Scripts {

    public static function runFromArgs():Void {

        var argv = [].concat(Sys.args());
        var i = 0;
        var len = argv.length;

        var script:String = null;
        while (i < len - 1) {
            if (argv[i] == '--script') {
                script = argv[i + 1];
                break;
            }
            i++;
        }

        if (script != null) {
            run(script);
        }

    } //runFromArgs

    public static function run(scriptName:String):Void {

        var clazz = Type.resolveClass('scripts.$scriptName');

        if (clazz == null) {
            log.error('Unknown script with name: $scriptName');
            Sys.exit(-1);
            return;
        }

        try {
            var instance:Script = Type.createInstance(clazz, []);

            instance.onceDone(null, function() {
                instance.destroy();
                Sys.exit(0);
            });

            instance.onceFail(null, function(reason) {
                instance.destroy();
                log.error('Error when running script $scriptName: $reason');
                Sys.exit(-1);
            });

            instance.run();

        } catch (e:Dynamic) {
            log.error('Error when running script $scriptName: $e');
            Sys.exit(-1);
        }

    } //run

} //Scripts
