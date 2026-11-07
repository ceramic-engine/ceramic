package scenarios;

import Scenario;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.Modifiers;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.Point;
import gpui.Window;
import gpui.base.input.EditorState;
import gpui.component.highlighter.Highlighter;
import gpui.component.highlighter.TextMateGrammars;
import gpui.component.input.Editor;

import gpui.Prelude.*;

/**
 * Base of the code editor scenarios: a gpui-kit `EditorState` with the JSON
 * language and TextMate highlighting on (`Highlighter.enable`, like the
 * `kit-highlight-editor` scene), loaded with 5000 lines of JSON (or the
 * `lineCount` given), in an
 * editor filling the standard window (12 px padding), focused by a click at
 * the first line like `kit-editor-typing`.
 *
 * On node the grammar files cannot be read synchronously: call the static
 * `preload(done)` (the grammars of the language, through the Ceramic asset
 * system) and wait for `done` before `setup`, otherwise the editor renders
 * without colors and `setup` logs a warning.
 */
class EditorBench extends BaseScenario {

    public static inline final LINE_COUNT = 5000;

    public static inline final PADDING:Float = 12;

    /** Elements created by a full draw (needs `gpui_count_allocations`). */
    public var elementCount:Int = 0;

    var app:App;

    var window:Window;

    var state:Entity<EditorState>;

    /** The center of the editor, where scroll events are dispatched. */
    var center:Point;

    static var codes:Map<Int, String> = new Map();

    /** Lines of JSON of this scenario (`LINE_COUNT` by default). */
    final lineCount:Int;

    public static inline final LANGUAGE = 'json';

    /** Loads the grammar files of the language (needed before `setup` on targets without synchronous asset reads). */
    public static function preload(done:(Bool) -> Void):Void {
        Highlighter.preload([LANGUAGE], done);
    }

    /** Whether the grammar of the language is loaded (so the editor highlights). */
    public static function grammarReady():Bool {
        final info = TextMateGrammars.findByToken(LANGUAGE);
        return info != null && TextMateGrammars.grammar(info) != null;
    }

    public function new(name:String, lineCount:Int = LINE_COUNT) {
        super(name);
        this.lineCount = lineCount;
    }

    /** `lineCount` lines of deterministic JSON (an array of objects, one object field per line). */
    public static function jsonCode(lineCount:Int = LINE_COUNT):String {
        final cached = codes.get(lineCount);
        if (cached != null)
            return cached;
        final buf = new StringBuf();
        buf.add('[\n');
        var line = 1;
        var item = 0;
        while (line < lineCount - 1) {
            switch (line % 8) {
                case 1: buf.add('  {\n');
                case 2: buf.add('    "id": $item,\n');
                case 3: buf.add('    "name": "item-$item",\n');
                case 4: buf.add('    "tags": ["alpha", "beta", "gamma"],\n');
                case 5: buf.add('    "ratio": ${(item % 100) / 100},\n');
                case 6: buf.add('    "enabled": ${item % 2 == 0 ? 'true' : 'false'},\n');
                case 7: buf.add('    "parent": ${item % 3 == 0 ? 'null' : Std.string(item - 1)}\n');
                case _: buf.add('  },\n'); item++;
            }
            line++;
        }
        buf.add('  {}\n');
        buf.add(']');
        final code = buf.toString();
        codes.set(lineCount, code);
        return code;
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        KitBench.initKit(app);
        app.update(cx -> {
            if (!Highlighter.enabled)
                Highlighter.enable(cx);
        });
        if (!grammarReady())
            ceramic.Shortcuts.log.warning('$name: the $LANGUAGE grammar is not loaded, call EditorBench.preload before setup (the editor renders without highlighting)');
        final text = jsonCode(lineCount);
        window = KitBench.openWindow(app, caching, (window, cx) -> {
            state = cx.newEntity((c:Context<EditorState>) -> new EditorState(window, c).language(LANGUAGE).defaultValue(text));
            final state = this.state;
            return cx.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
                div().sizeFull().p(px(PADDING)).child(new Editor(state).sizeFull())
            ));
        });
        center = new Point(KitBench.WIDTH / 2, KitBench.HEIGHT / 2);
        // Focus the editor with a click on its first line (gutter excluded), like the golden script.
        final position = new Point(200, PADDING + 10);
        KitBench.dispatch(app, window, new MouseMoveEvent(position, null, Modifiers.none()));
        KitBench.dispatch(app, window, new MouseDownEvent(MouseButton.Left, position, Modifiers.none(), 1, false));
        KitBench.dispatch(app, window, new MouseUpEvent(MouseButton.Left, position, Modifiers.none(), 1));
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        elementCount = KitBench.countElements(window);
        return window;
    }

}
