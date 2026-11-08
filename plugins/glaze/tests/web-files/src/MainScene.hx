package;

import ceramic.Files;
import ceramic.Scene;
import glaze.App;
import glaze.Glaze;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.PathPromptOptions;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Three click zones of a GPUI window, each asking a path prompt from its
 * click handler (a user gesture), and one prompt asked from a timer (no
 * gesture). Every result is printed on the console as a `WEBFILES` line,
 * which `check.js` reads:
 *
 * - top left (0..320, 0..240): `promptForNewPath('', 'export.csv')`, then
 *   `Files.saveContent` of a small CSV on the answered path;
 * - top right (320..640, 0..240): `promptForPaths` for several files, then
 *   the content of each picked path;
 * - bottom (0..640, 240..480): `promptForPaths` for a folder, then the files
 *   under each picked folder;
 * - one second after start: `promptForPaths` outside of any gesture.
 */
class MainScene extends Scene {

    override function create() {
        final cx = Glaze.app;
        final window = Window.open(cx, {width: width, height: height}, (window, cx) -> {
            return cx.newEntity((_:Context<ZonesView>) -> new ZonesView());
        });
        add(window.renderable);

        ceramic.Timer.delay(this, 1.0, () -> {
            report('outside', cx.promptForPaths(new PathPromptOptions(true, false, false)));
        });
        trace('WEBFILES ready');
    }

    public static function report(label:String, task:glaze.Task<Null<Array<String>>>):Void {
        task.catchError(error -> {
            trace('WEBFILES $label error $error');
            return null;
        }).then(paths -> {
            if (paths == null) {
                trace('WEBFILES $label none');
                return;
            }
            for (path in paths) {
                if (Files.isDirectory(path)) {
                    for (file in Files.getFlatDirectory(path))
                        trace('WEBFILES $label dir $path $file ${Files.getContent(path + "/" + file)}');
                }
                else {
                    trace('WEBFILES $label file $path ${Files.getContent(path)}');
                }
            }
        });
    }

}

private class ZonesView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final app = cx.app;
        return div().sizeFull().flex().flexCol()
            .child(div().flex().flexRow().w(px(640)).h(px(240))
                .child(div().id('save').w(px(320)).h(px(240)).bg(rgb(0xddeeff)).onClick((_, _, _) -> {
                    app.promptForNewPath('', 'export.csv').catchError(error -> {
                        trace('WEBFILES save error $error');
                        return null;
                    }).then(path -> {
                        trace('WEBFILES save path $path');
                        if (path != null) Files.saveContent(path, 'Name,Price\nA,1\n');
                    });
                }))
                .child(div().id('open').w(px(320)).h(px(240)).bg(rgb(0xffeedd)).onClick((_, _, _) -> {
                    MainScene.report('files', app.promptForPaths(new PathPromptOptions(true, false, true)));
                })))
            .child(div().id('folder').w(px(640)).h(px(240)).bg(rgb(0xeeffdd)).onClick((_, _, _) -> {
                MainScene.report('folder', app.promptForPaths(new PathPromptOptions(false, true, false)));
            }));
    }

}
