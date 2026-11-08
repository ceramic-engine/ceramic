package;

import ceramic.Key;
import ceramic.KeyCode;
import ceramic.Platform;
import ceramic.Scene;
import examples.Examples;
import glaze.App;
import glaze.Glaze;

/**
 * GPUI's own examples ported to Haxe (`shared/examples`), one at a time:
 * left / right arrows switch example (the window title shows its name).
 * Start with another one with `GLAZE_EXAMPLE=<name>` (`hello_world`,
 * `uniform_list`, `text_wrapper`, `tab_stop`, `drag_drop`, `animation`).
 *
 * Self-test (`GLAZE_EXAMPLES_SELFTEST=<dir>`): shows every example, writes
 * `<dir>/<name>.png` for each one, then quits.
 */
class MainScene extends Scene {

    var ui:Glaze;

    var index:Int = 0;

    final setupDone:Map<String, Bool> = new Map();

    override function create() {

        // The SVG of the animation example (needed before rendering on the web)
        App.defaultAssetSource().preload(['image/arrow_circle.svg'], _ -> start());

    }

    function start():Void {

        final id = Platform.getEnv('GLAZE_EXAMPLE');
        if (id != null && id != '') {
            for (i in 0...Examples.ALL.length) {
                if (Examples.ALL[i].id == id) index = i;
            }
        }

        show();
        input.onKeyDown(this, handleKey);

        final selfTest = Platform.getEnv('GLAZE_EXAMPLES_SELFTEST');
        if (selfTest != null && selfTest != '') {
            index = 0;
            show();
            runSelfTest(selfTest);
        }

    }

    function show():Void {

        if (ui != null) {
            ui.destroy();
            ui = null;
        }

        final example = Examples.ALL[index];
        final cx = Glaze.app;
        if (example.setup != null && !setupDone.exists(example.id)) {
            setupDone.set(example.id, true);
            example.setup(cx);
        }

        ui = new Glaze(example.open);
        ui.size(width, height);
        add(ui);
        app.settings.title = 'GPUI examples: ${example.id} (${index + 1}/${Examples.ALL.length}, left / right to switch)';

    }

    function handleKey(key:Key):Void {

        switch key.keyCode {
            case KeyCode.LEFT:
                index = (index + Examples.ALL.length - 1) % Examples.ALL.length;
                show();
            case KeyCode.RIGHT:
                index = (index + 1) % Examples.ALL.length;
                show();
            case _:
        }

    }

    function runSelfTest(dir:String):Void {

        ceramic.Timer.delay(this, 1.0, () -> {
            final path = haxe.io.Path.join([dir, Examples.ALL[index].id + '.png']);
            screen.toPng(path, () -> {
                log.success('Captured $path');
                if (index + 1 < Examples.ALL.length) {
                    index++;
                    show();
                    runSelfTest(dir);
                }
                else {
                    log.success('Self-test done');
                    app.quit();
                }
            });
        });

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

}
