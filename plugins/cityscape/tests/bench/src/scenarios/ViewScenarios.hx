package scenarios;

import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import glaze.Keystroke;
import glaze.Modifiers;
import glaze.Point;
import glaze.ScrollDelta;
import glaze.ScrollEvent;

/**
 * `view-open`: opening a 10 000 line JavaScript file in the editor: each
 * frame creates a new model from the text, sets it on the editor (the
 * previous one disposed) and draws the first frame (viewport tokenization,
 * line rendering and shaping of the visible lines), the background
 * tokenizer running for its frame budget.
 */
class ViewOpen extends ViewBench {

    var text:String;

    var previous:Null<TextModel> = null;

    public function new() {
        super('view-open');
        frameLimit = 20;
        warmupLimit = 3;
    }

    override function ready():Void {
        text = documentText();
    }

    override function input(frame:Int):Void {
        final next = new TextModel(text, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        view.widget.setModel(next);
        if (previous != null) {
            previous.dispose();
        }
        previous = next;
    }

    override function teardown():Void {
        super.teardown();
        if (previous != null) {
            previous.dispose();
            previous = null;
        }
    }

}

/**
 * Steady scrolling through the window (a wheel event at the editor's
 * center, the path of a real scroll): `view-scroll-line` one line per
 * frame, `view-scroll-page` one page per frame, down then up again at the
 * end. The document is tokenized beforehand: no background work.
 */
class ViewScroll extends ViewBench {

    final pixelsPerFrame:Float;

    var direction:Float = 1;

    final center = new Point(ViewBench.WIDTH / 4, ViewBench.HEIGHT / 2);

    public function new(name:String, page:Bool, ?text:() -> String, ?options:cityscape.common.config.EditorOptions.IEditorOptions) {
        super(name);
        this.pixelsPerFrame = page ? -1 : 19;
        this.textOf = text;
        this.options = options;
    }

    final textOf:Null<() -> String>;

    override function documentText():String {
        return textOf != null ? textOf() : super.documentText();
    }

    override function input(frame:Int):Void {
        final layout = view.viewModel.viewLayout;
        final amount = pixelsPerFrame > 0 ? pixelsPerFrame : layout.getCurrentViewport().height;
        final top = layout.getCurrentScrollTop();
        final max = layout.getScrollHeight() - layout.getCurrentViewport().height;
        if (direction > 0 && top + amount > max) {
            direction = -1;
        }
        else if (direction < 0 && top - amount < 0) {
            direction = 1;
        }
        // GPUI's wheel deltas: negative y scrolls down
        final event = new ScrollEvent(center, ScrollDelta.Pixels(new Point(0, -amount * direction)), Modifiers.none());
        ViewBench.app.update(cx -> window.dispatchEvent(event, cx));
    }

}

/**
 * Typing one character per frame (a keystroke through the window: key
 * bindings, then the text input) at the end of the longest line of the
 * middle of the document: a word typed, then removed with Backspace,
 * again and again (so long runs keep the line length).
 *
 * After each keystroke the pending quick suggestion runs (its 10 ms delay
 * is over before the next frame of an app), so the suggest widget opens and
 * refilters like in an app (the context's word based completions, computed
 * over the 10 000 lines).
 *
 * - `view-type`: the default options (the suggest widget opens on the words
 *   typed and closes when nothing matches, a new request at each key then;
 *   a space closes it);
 * - `view-type-suggest`: the suggest widget open while typing (`const`
 *   typed and erased again, its first letter kept: the widget refilters);
 * - `view-type-nosuggest`: quick suggestions and suggestions on trigger
 *   characters off (the suggest widget never opens);
 * - `view-type-multi`: 10 cursors on 10 consecutive lines;
 * - `view-type-two`: two editors on the model, typing in the first;
 * - `view-type-wrap`: word wrap on;
 * - `view-type-long`, `view-type-long-wrap`: in a line of 5000 characters
 *   in the middle of the document (wrap off, then on).
 */
class ViewType extends ViewBench {

    static final WORD = 'value_1 ';

    /** Typed after the first letter `c` while the suggest widget is open (`view-type-suggest`: const, console...). */
    static final SUGGEST_WORD = 'onst';

    final keys:Array<Keystroke>;

    final suggestOpen:Bool;

    var suggestFrames = 0;

    var frames = 0;

    final backspace = Keystroke.parse('backspace');

    final cursors:Int;

    final longLine:Bool;

    var line:Int = 1;

    public function new(name:String, ?options:cityscape.common.config.EditorOptions.IEditorOptions, cursors:Int = 1, editors:Int = 1, longLine:Bool = false, suggestOpen:Bool = false) {
        super(name);
        this.options = options;
        this.cursors = cursors;
        this.editorCount = editors;
        this.longLine = longLine;
        this.suggestOpen = suggestOpen;
        keys = ViewBench.keystrokesOf(suggestOpen ? SUGGEST_WORD : WORD);
    }

    function suggest():cityscape.contrib.suggest.view.SuggestController {
        return cityscape.contrib.suggest.view.SuggestController.get(view.widget);
    }

    /** A keystroke, then the quick suggestion that would run before the next frame. */
    function typeKey(key:Keystroke):Void {
        keystroke(key);
        suggest().model._flushQuickSuggest();
        // The providers answer through the app's executor and immediates
        runUntilParked();
        ceramic.App.app.flushImmediate();
    }

    override function documentText():String {
        final text = super.documentText();
        if (!longLine) {
            return text;
        }
        final lines = text.split('\n');
        lines[4999] = longLineText(5000);
        return lines.join('\n');
    }

    /** About `length` characters of JavaScript on one line. */
    public static function longLineText(length:Int):String {
        final buf = new StringBuf();
        buf.add('const table = [');
        var i = 0;
        while (buf.length < length - 2) {
            buf.add('{id: ${i}, name: "item${i}", ok: ${i % 2 == 0}}, ');
            i++;
        }
        buf.add('];');
        return buf.toString();
    }

    override function ready():Void {
        final middle = Std.int(model.getLineCount() / 2);
        line = longLine ? 5000 : longestCodeLineFrom(middle, 60);
        final selections = [];
        for (i in 0...cursors) {
            final ln = line + i;
            final column = model.getLineMaxColumn(ln);
            selections.push(new Selection(ln, column, ln, column));
        }
        setSelections(selections);
        view.widget.revealLineInCenter(line, cityscape.common.EditorCommon.ScrollType.Immediate);
        final before = model.getLineContent(line);
        keystroke(keys[0]);
        if (model.getLineContent(line) == before) {
            throw '$name: the keystroke did not type';
        }
        keystroke(backspace);
        if (model.getLineContent(line) != before) {
            throw '$name: backspace did not restore the line';
        }
        if (suggestOpen) {
            // The first letter of the word, kept: the widget stays open while
            // the rest is typed and erased
            typeKey(ViewBench.keystrokesOf('c')[0]);
            if (!suggest().widget.isVisible()) {
                throw '$name: the suggest widget did not open';
            }
        }
    }

    /**
     * The longest line among the `count` lines from `from` that ends with
     * code (its last token neither a comment nor a string: quick suggestions
     * are on there), followed by `cursors - 1` lines.
     */
    function longestCodeLineFrom(from:Int, count:Int):Int {
        var best = -1;
        for (ln in from...Std.int(Math.min(model.getLineCount() - cursors, from + count))) {
            final length = model.getLineLength(ln);
            if (length == 0) {
                continue;
            }
            final tokens = model.tokenization.getLineTokens(ln);
            if (tokens.getStandardTokenType(tokens.findTokenIndexAtOffset(length - 1)) != cityscape.common.EncodedTokenAttributes.StandardTokenType.Other) {
                continue;
            }
            if (best == -1 || length > model.getLineLength(best)) {
                best = ln;
            }
        }
        return best != -1 ? best : from;
    }

    override function input(frame:Int):Void {
        final n = keys.length;
        final k = frame % (2 * n);
        typeKey(k < n ? keys[k] : backspace);
        frames++;
        if (suggest().widget.isVisible()) {
            suggestFrames++;
        }
        if (ViewBench.debug) {
            ViewBench.println('$name key ${k < n ? keys[k].key : 'backspace'}: suggest visible ${suggest().widget.isVisible()}, line end "${model.getLineContent(line).substr(-12)}"');
        }
    }

    override function teardown():Void {
        ViewBench.println('$name: suggest widget visible after $suggestFrames of $frames keystrokes');
        super.teardown();
    }

}

/**
 * `view-decorated`: scrolling one line per frame through a decorated
 * document: 2000 inline decorations (a registered class style, typed pills
 * with a background, rounded corners and padding, typed italic colors),
 * 500 hidden ranges revealed on the cursor line and 200 whole line styles.
 */
class ViewDecorated extends ViewScroll {

    public function new() {
        super('view-decorated', false);
    }

    override function prepare():Void {
        context.registerDecorationStyle('bench-strong', {fontWeight: 'bold', color: '#e06c75'});
        final decorations:Array<cityscape.common.Model.IModelDeltaDecoration> = [];
        final lineCount = model.getLineCount();
        var placed = 0;
        var line = 1;
        while (placed < 2000 && line <= lineCount) {
            final length = model.getLineLength(line);
            if (length >= 12) {
                final start = 3;
                final end = Std.int(Math.min(length + 1, start + 8));
                switch (placed % 3) {
                    case 0:
                        decorations.push({range: new Range(line, start, line, end), options: {description: 'strong', inlineClassName: 'bench-strong'}});
                    case 1:
                        decorations.push({range: new Range(line, start, line, end), options: {description: 'pill', inlineStyle: {background: '#2c313c', borderRadius: 4, paddingTop: 1, paddingBottom: 1}}});
                    case _:
                        decorations.push({range: new Range(line, start, line, end), options: {description: 'italic', inlineStyle: {color: '#6a9955', fontStyle: 'italic'}}});
                }
                placed++;
            }
            line += 5;
        }
        var hidden = 0;
        line = 3;
        while (hidden < 500 && line <= lineCount) {
            final length = model.getLineLength(line);
            if (length >= 20) {
                decorations.push({range: new Range(line, length - 5, line, length + 1), options: {description: 'tag', hidden: true, revealOnCursorLine: true}});
                hidden++;
            }
            line += 20;
        }
        for (i in 0...200) {
            final ln = 7 + i * 50;
            if (ln <= lineCount) {
                decorations.push({range: new Range(ln, 1, ln, 1), options: {description: 'line', isWholeLine: true, lineStyle: {background: '#2a2a22'}}});
            }
        }
        model.deltaDecorations([], decorations);
    }

}

/**
 * Documents of the scroll scenarios.
 */
class ViewTexts {

    /**
     * 10 000 lines of JavaScript heavy in CJK and emoji (strings and
     * comments: ideographs, kana, hangul, ZWJ sequences, flags, skin tones,
     * keycaps).
     */
    public static function cjkEmoji():String {
        final samples = [
            'const 名前 = "こんにちは世界"; // 日本語のコメント 😀',
            'let message = "你好，世界 👨‍👩‍👧‍👦 和 🇫🇷🇯🇵";',
            '    console.log(`한국어 텍스트 $${名前} 👍🏽👍🏿`);',
            '    // 絵文字: 🎉🎊✨ 1️⃣ 2️⃣ #️⃣ 🏳️‍🌈',
            'function 計算(値) { return 値 * 2; } // 中文注释',
            '    const 表 = ["一", "二", "三", "四", "五"]; // 😀😃😄😁',
            '',
            'export default { 名前, message }; // 終わり 🏁',
        ];
        final lines = [];
        var i = 0;
        while (lines.length < 10000) {
            lines.push(samples[i % samples.length]);
            i++;
        }
        return lines.join('\n');
    }

}
