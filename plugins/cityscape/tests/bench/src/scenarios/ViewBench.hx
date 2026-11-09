package scenarios;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.standalone.common.VSCodeTheme;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Modifiers;
import glaze.TestDispatcher;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Base of the view scenarios: real `CityscapeEditor`s in a headless Glaze
 * window (1280x1024 at scale 2, view caching on, like an app), over a
 * JavaScript model (Glaze's `javascript.json` grammar) with VS Code's Dark+
 * theme (the token rules of the TextMate truth, the editor colors of VS
 * Code's `dark_vs.json`).
 *
 * `setup` opens the window, tokenizes the whole document and runs the
 * background work until idle, then focuses the first editor; each frame
 * (`step`) gives the scenario's input (`input(frame)`: a keystroke, a
 * scroll...), runs the context's background scheduler for one frame budget
 * (what Ceramic's update event does in an app), flushes and draws the window
 * when it is dirty. The frame time is all of it.
 */
class ViewBench implements Scenario {

    /** The Glaze app of the bench (created by `Project`). */
    public static var app:Null<App> = null;

    public static inline final WIDTH:Float = 1280;

    public static inline final HEIGHT:Float = 1024;

    public static inline final SCALE_FACTOR:Float = 2;

    /** VS Code's `dark_vs.json` editor colors (theme-defaults), like the visual check. */
    static final DARK_COLORS:Dynamic = {
        'editor.background': '#1E1E1E',
        'editor.foreground': '#D4D4D4',
        'editor.inactiveSelectionBackground': '#3A3D41',
        'editorIndentGuide.background1': '#404040',
        'editorIndentGuide.activeBackground1': '#707070',
        'editor.selectionHighlightBackground': '#ADD6FF26'
    };

    public var name:String;

    /**
     * Measured frames for this scenario when above 0 (heavy scenarios run
     * fewer frames than `CITYSCAPE_BENCH_FRAMES`).
     */
    public var frameLimit:Int = 0;

    /** Warmup frames when above or equal to 0 (instead of `CITYSCAPE_BENCH_WARMUP`). */
    public var warmupLimit:Int = -1;

    /** The number of editors on the model (side by side). */
    var editorCount:Int = 1;

    /** Editor options (Monaco's), merged over `baseOptions()`. */
    var options:Null<IEditorOptions> = null;

    var context:Cityscape;

    var model:TextModel;

    var window:Window;

    final views:Array<CityscapeView> = [];

    var view(get, never):CityscapeView;
    inline function get_view():CityscapeView {
        return views[0];
    }

    public function new(name:String) {
        this.name = name;
    }

    /** The document (10 000 lines of JavaScript by default). */
    function documentText():String {
        return Tokenize.documentText(10000);
    }

    /** After the model is created, before the window opens (decorations...). */
    function prepare():Void {}

    /** After the window is open and drawn, the editor focused. */
    function ready():Void {}

    /** The input of a frame. */
    function input(frame:Int):Void {}

    public static function themedContext():Cityscape {
        final context = Tokenize.javascriptContext();
        final truth:Dynamic = haxe.Json.parse(testing.BenchData.load('monaco/textmate-tokens.json'));
        for (theme in (truth.themes : Array<Dynamic>)) {
            if (theme.id == 'dark-plus') {
                context.themeService.defineTheme('dark-plus', VSCodeTheme.toStandaloneThemeData({
                    name: 'Dark+',
                    type: 'dark',
                    colors: DARK_COLORS,
                    settings: theme.theme.settings
                }));
                context.themeService.setTheme('dark-plus');
            }
        }
        return context;
    }

    public function setup():Void {
        final app = ViewBench.app;
        if (verify) {
            // By reflection: the bench also builds against Cityscape versions without it (A/B)
            Reflect.setField(CityscapeView, 'checkRenderCache', true);
        }
        context = themedContext();
        final start = haxe.Timer.stamp();
        model = new TextModel(documentText(), 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        prepare();
        views.resize(0);
        mergedOptions = null;
        window = Window.open(app, {
            width: WIDTH, height: HEIGHT, scaleFactor: SCALE_FACTOR,
            autoDraw: false, bindInput: false, active: false, viewCaching: true
        }, (_, _) -> BenchEditors.component(this));
        window.draw();
        app.update(_ -> window.setActive(true));
        runUntilParked();
        final opened = (haxe.Timer.stamp() - start) * 1000;
        // Steady state: the whole document tokenized, no background work left
        model.tokenization.forceTokenization(model.getLineCount());
        context.backgroundScheduler.runUntilIdle();
        app.update(cx -> view.focusHandle.focus(window, cx));
        runUntilParked();
        ceramic.App.app.flushImmediate();
        window.draw();
        ready();
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        println('$name: ${model.getLineCount()} lines, ${editorCount} editor(s), opened and drawn in ${Math.round(opened * 10) / 10} ms');
    }

    public function step(frame:Int):Void {
        input(frame);
        if (!context.backgroundScheduler.isIdle()) {
            context.backgroundScheduler.runFor(context.backgroundScheduler.budgetMs);
        }
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        if (verify) {
            // The frame drawn with the view caches against a full redraw
            final cachedCount = @:privateAccess window.renderedFrame.scene.len();
            window.refresh();
            window.draw();
            final fullCount = @:privateAccess window.renderedFrame.scene.len();
            if (cachedCount != fullCount) {
                staleFrames++;
            }
            if (digest) {
                println('DIGEST $name $frame ${sceneDigest()}');
            }
        }
        if (debug && frame % 10 == 0) {
            println('$name frame $frame: scrollTop ${view.viewModel.viewLayout.getCurrentScrollTop()}, rendered views ${window.renderedViewCount}, reused ${window.reusedViewCount}, selection ${view.viewModel.getSelection()}, primitives ${@:privateAccess window.renderedFrame.scene.len()}');
        }
    }

    /**
     * `CITYSCAPE_BENCH_VERIFY=1`: each frame is drawn again in full and
     * compared (primitive count), and every rendered line is checked against
     * its rendering input (`CityscapeView.checkRenderCache`); the stale
     * frames and lines are reported at teardown.
     */
    static final verify = env('CITYSCAPE_BENCH_VERIFY') == '1';

    var staleFrames = 0;

    /**
     * `CITYSCAPE_BENCH_DIGEST=1` (with `CITYSCAPE_BENCH_VERIFY=1`): prints
     * a digest of each fully redrawn frame (Glaze's scene dump, the unused
     * gradient fields of solid quads left out), to compare two builds frame
     * by frame.
     */
    static final digest = env('CITYSCAPE_BENCH_DIGEST') == '1';

    function sceneDigest():String {
        final dump:Dynamic = glaze.scene.SceneDump.dump(@:privateAccess window.renderedFrame.scene, WIDTH * SCALE_FACTOR, HEIGHT * SCALE_FACTOR);
        for (q in (dump.quads : Array<Dynamic>)) {
            if (q.background.tag == 0) {
                q.background.colors = null;
                q.background.gradient_angle_or_pattern_height = null;
                q.background.color_space = null;
            }
        }
        return haxe.crypto.Md5.encode(haxe.Json.stringify(dump));
    }

    public static final debug = env('CITYSCAPE_BENCH_DEBUG') == '1';

    static function env(name:String):Null<String> {
        #if js
        return js.Syntax.code('(typeof process !== "undefined" ? process.env[{0}] : null)', name);
        #elseif sys
        return Sys.getEnv(name);
        #else
        return null;
        #end
    }

    public function teardown():Void {
        if (verify) {
            println('$name: ${staleFrames} stale frames (cached draw differs from a full redraw), ${Reflect.field(CityscapeView, 'renderCacheErrors')} lines kept while their rendering input changed');
            staleFrames = 0;
            Reflect.setField(CityscapeView, 'renderCacheErrors', 0);
        }
        window.destroy();
        ceramic.App.app.flushImmediate();
        model.dispose();
        context.textMate.dispose();
        views.resize(0);
    }

    /** The editor options of the scenario over the defaults of the bench. */
    var mergedOptions:Null<IEditorOptions> = null;

    @:allow(scenarios.BenchEditors)
    function editorOptions():IEditorOptions {
        // One object: the editor applies its options when they change (by reference)
        if (mergedOptions != null) {
            return mergedOptions;
        }
        final base:IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 19,
            cursorBlinking: 'solid'
        };
        if (options != null) {
            for (field in Reflect.fields(options)) {
                Reflect.setField(base, field, Reflect.field(options, field));
            }
        }
        mergedOptions = base;
        return base;
    }

    @:allow(scenarios.BenchEditors)
    function editorCreated(editor:CityscapeEditor):Void {
        final v:CityscapeView = editor.getView();
        views.push(v);
    }

    @:allow(scenarios.BenchEditors)
    function benchModel():TextModel {
        return model;
    }

    @:allow(scenarios.BenchEditors)
    function benchEditorCount():Int {
        return editorCount;
    }

    function runUntilParked():Void {
        final dispatcher = Std.downcast(app.dispatcher, TestDispatcher);
        if (dispatcher != null) {
            dispatcher.runUntilParked();
        }
    }

    /** One keystroke through the window (key bindings, then the text input), like a real key press. */
    function keystroke(keystroke:Keystroke):Void {
        app.update(cx -> window.dispatchKeystroke(keystroke, cx));
        runUntilParked();
    }

    /** Places the cursors (view model of the first editor). */
    function setSelections(selections:Array<Selection>):Void {
        view.viewModel.setSelections('bench', selections);
    }

    /** The keystrokes of a text (`space` for a space). */
    static function keystrokesOf(text:String):Array<Keystroke> {
        final keys:Array<Keystroke> = [];
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final buf = new StringBuf();
            buf.addChar(c);
            keys.push(new Keystroke(Modifiers.none(), c == ' '.code ? 'space' : buf.toString(), null));
        }
        return keys;
    }

    /** The longest line among the `window` lines from `from`. */
    function longestLineFrom(from:Int, count:Int):Int {
        var best = from;
        for (line in from...Std.int(Math.min(model.getLineCount(), from + count))) {
            if (model.getLineLength(line) > model.getLineLength(best)) {
                best = line;
            }
        }
        return best;
    }

    public static function println(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

}

/**
 * The root of a view scenario's window: the editors of the scenario side by
 * side, sized by the flex layout.
 */
class BenchEditors extends glaze.Component {

    final bench:ViewBench;

    public function new(bench:ViewBench) {
        super();
        this.bench = bench;
    }

    public function render(window:Window, cx:App):IntoElement {
        final root = div().flex().sizeFull();
        final model = bench.benchModel();
        for (i in 0...bench.benchEditorCount()) {
            root.child(CityscapeEditor.component().model(model).context(model.context).options(bench.editorOptions()).onCreate(e -> bench.editorCreated(e)).flex1());
        }
        return root;
    }

}
