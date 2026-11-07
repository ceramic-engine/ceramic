// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mode.rs, crates/base/src/input/editor/indent.rs (the `impl LayoutMode` block)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Context;
import glaze.Range;
import glaze.Window;
import ropey.Rope;

using glaze.kit.base.input.RopeExt;

/**
 * The variants of `LayoutMode`.
 */
enum abstract LayoutModeKind(Int) {
    /** A plain text input mode. */
    var PlainText = 0;
    /** An auto grow input mode. */
    var AutoGrow = 1;
    /** A code editor input mode. */
    var CodeEditor = 2;
}


/**
 * What changed, handed to the syntax highlighter.
 */
class HighlighterUpdate {

    public final selectedRange:Range;
    public final oldText:Rope;
    public final newText:Rope;
    public final changeText:String;
    public final force:Bool;

    public function new(selectedRange:Range, oldText:Rope, newText:Rope, changeText:String, force:Bool) {
        this.selectedRange = selectedRange;
        this.oldText = oldText;
        this.newText = newText;
        this.changeText = changeText;
        this.force = force;
    }

}

/**
 * How the input lays its text out: rows, growth, and the code-editor
 * extras.
 *
 * This does not say what *kind* of input this is: that is the state's
 * `InputModeKind`. Rust's enum variants are `kind`; the fields of the other
 * variants are unused (`tab` and `rows` exist in every variant here, `tab`
 * is only read for `PlainText` and `CodeEditor`).
 */
class LayoutMode {

    public var kind(default, null):LayoutModeKind;

    var tab:TabSize;

    var _rows:Int;

    // AutoGrow
    var _minRows:Int = 1;
    var _maxRows:Int = 1;

    // CodeEditor
    var _lineNumber:Bool = false;
    var language:Null<EditorLanguage> = null;
    var indentGuides:Bool = false;
    var folding:Bool = false;
    var _highlighter:Null<HighlighterCell> = null;
    var highlighterFactory:Null<InputHighlighterFactory> = null;
    var _diagnostics:Null<DiagnosticSet> = null;
    /** Automatic delimiter ranges, adjusted with document edits. */
    var _autoClosedPairs:Null<AutoClosedPairs> = null;
    var autoClose:Bool = false;
    var smartIndent:Bool = false;

    function new(kind:LayoutModeKind, tab:TabSize, rows:Int) {
        this.kind = kind;
        this.tab = tab;
        this._rows = rows;
    }

    /** `LayoutMode::PlainText { tab, rows }`. */
    public static function plainTextWith(tab:TabSize, rows:Int):LayoutMode {
        return new LayoutMode(PlainText, tab, rows);
    }

    /** `LayoutMode::AutoGrow { rows, min_rows, max_rows }`. */
    public static function autoGrowWith(rows:Int, minRows:Int, maxRows:Int):LayoutMode {
        final mode = new LayoutMode(AutoGrow, TabSize.defaultValue(), rows);
        mode._minRows = minRows;
        mode._maxRows = maxRows;
        return mode;
    }

    /** `LayoutMode::CodeEditor { .. }` with every field given. */
    public static function codeEditorWith(tab:TabSize, rows:Int, lineNumber:Bool, language:EditorLanguage, indentGuides:Bool, folding:Bool,
            highlighter:HighlighterCell, highlighterFactory:Null<InputHighlighterFactory>, diagnostics:DiagnosticSet, autoClosedPairs:AutoClosedPairs,
            autoClose:Bool, smartIndent:Bool):LayoutMode {
        final mode = new LayoutMode(CodeEditor, tab, rows);
        mode._lineNumber = lineNumber;
        mode.language = language;
        mode.indentGuides = indentGuides;
        mode.folding = folding;
        mode._highlighter = highlighter;
        mode.highlighterFactory = highlighterFactory;
        mode._diagnostics = diagnostics;
        mode._autoClosedPairs = autoClosedPairs;
        mode.autoClose = autoClose;
        mode.smartIndent = smartIndent;
        return mode;
    }

    /** `LayoutMode::default()`: a plain text mode. */
    public static inline function defaultValue():LayoutMode {
        return plainText();
    }

    /** Create a plain input mode with default settings. */
    public static function plainText():LayoutMode {
        return plainTextWith(TabSize.defaultValue(), 1);
    }

    /**
     * Create a code editor input mode with default settings. Starts with the
     * given language; the state sets one through its own builder.
     */
    public static function codeEditor(language:EditorLanguage):LayoutMode {
        return codeEditorWith(TabSize.defaultValue(), 2, true, language, true, true, new HighlighterCell(), null, new DiagnosticSet(Rope.fromStr('')),
            new AutoClosedPairs(), true, true);
    }

    /** Create an auto grow input mode with given min and max rows. */
    public static function autoGrow(minRows:Int, maxRows:Int):LayoutMode {
        return autoGrowWith(minRows, minRows, maxRows);
    }

    /**
     * A copy (Rust `Clone`): the highlighter cell is shared like its `Rc`,
     * the language, diagnostics and pairs are cloned.
     */
    public function clone():LayoutMode {
        final mode = new LayoutMode(kind, tab.copy(), _rows);
        mode._minRows = _minRows;
        mode._maxRows = _maxRows;
        mode._lineNumber = _lineNumber;
        mode.language = language != null ? language.clone() : null;
        mode.indentGuides = indentGuides;
        mode.folding = folding;
        mode._highlighter = _highlighter;
        mode.highlighterFactory = highlighterFactory;
        mode._diagnostics = _diagnostics;
        mode._autoClosedPairs = _autoClosedPairs != null ? _autoClosedPairs.clone() : null;
        mode.autoClose = autoClose;
        mode.smartIndent = smartIndent;
        return mode;
    }

    /**
     * Whether this build stands for Rust's `cfg!(target_family = "wasm")`
     * (true on the web). Assign it to simulate the other target (the golden
     * scenes run on the web against truths rendered by a native build).
     */
    public static var wasmTarget:Bool = #if (js && !node) true #else false #end;

    /**
     * Return true if this layout is a code editor with folding enabled.
     * Folding is off on the web, like Rust's `wasm` builds.
     */
    public inline function isFolding():Bool {
        if (wasmTarget)
            return false;
        return kind == CodeEditor && folding;
    }

    public function languageConfig():Null<LanguageConfig> {
        return kind == CodeEditor ? language.config() : null;
    }

    public function syntaxContextAt(text:Rope, offset:Int):SyntaxContext {
        return kind == CodeEditor ? language.contextAt(text, offset) : SyntaxContext.Code;
    }

    public inline function isAutoClose():Bool {
        return kind == CodeEditor && autoClose;
    }

    public inline function isSmartIndent():Bool {
        return kind == CodeEditor && smartIndent;
    }

    public function setAutoClose(enabled:Bool):Void {
        if (kind == CodeEditor) autoClose = enabled;
    }

    public function setSmartIndent(enabled:Bool):Void {
        if (kind == CodeEditor) smartIndent = enabled;
    }

    /** The automatic pairs (a shared empty set outside a code editor: never modify it). */
    public function autoClosedPairs():AutoClosedPairs {
        return kind == CodeEditor ? _autoClosedPairs : AutoClosedPairs.empty();
    }

    public function restoreAutoClosedPairs(pairs:AutoClosedPairs):Void {
        if (kind == CodeEditor) _autoClosedPairs = pairs;
    }

    public function trackAutoClosedPair(open:Range, close:Range):Void {
        if (kind == CodeEditor) _autoClosedPairs.record(open, close);
    }

    public function adjustAutoClosedPair(edit:Range, newLen:Int):Void {
        if (kind != CodeEditor) {
            return;
        }
        _autoClosedPairs.adjust(edit, newLen);
    }

    public inline function isAutoGrow():Bool {
        return kind == AutoGrow;
    }

    public function setRows(newRows:Int):Void {
        switch kind {
            case PlainText:
                _rows = newRows;
            case CodeEditor:
                _rows = newRows;
            case AutoGrow:
                // Rust `clamp` (min first, then max)
                _rows = newRows < _minRows ? _minRows : (newRows > _maxRows ? _maxRows : newRows);
        }
    }

    /**
     * Grow the row count to fit the content.
     *
     * Callers gate this on the input being multi-line; a single-line field
     * keeps its one row. Only auto grow follows the content: in the other
     * modes `rows` is the configured height.
     */
    public function updateAutoGrow(displayMap:DisplayMap):Void {
        if (!isAutoGrow()) {
            return;
        }
        final wrappedLines = displayMap.wrapRowCount();
        setRows(wrappedLines);
    }

    /** At least 1 row is returned. */
    public function rows():Int {
        return _rows > 1 ? _rows : 1;
    }

    /** At least 1 row is returned. */
    public function minRows():Int {
        final rows = kind == AutoGrow ? _minRows : 1;
        return rows > 1 ? rows : 1;
    }

    /** `usize::MAX` outside auto grow: the largest Int here. */
    public function maxRows():Int {
        return kind == AutoGrow ? _maxRows : 0x7FFFFFFF;
    }

    /** Return false if the mode is not `CodeEditor`. */
    public inline function lineNumber():Bool {
        return kind == CodeEditor && _lineNumber;
    }

    /** Update the syntax highlighter with new text. */
    public function updateHighlighter(update:HighlighterUpdate, modeKind:InputModeKind, window:Window, cx:Context<InputBaseState>):Void {
        if (kind != CodeEditor) {
            return;
        }
        if (!update.force && _highlighter.value != null) {
            return;
        }
        if (!ensureHighlighter(_highlighter, highlighterFactory, language)) {
            return;
        }

        final edit = replacementInputEdit(update.oldText, update.newText, update.selectedRange, update.changeText);
        modeKind.driveHighlighter(_highlighter, edit, update.newText, folding, window, cx);
    }

    /**
     * Drive the highlighter once for several edits applied as one change,
     * each paired with the text right after it, in application order.
     */
    public function updateHighlighterBatch(edits:Array<EditedText>, modeKind:InputModeKind, window:Window, cx:Context<InputBaseState>):Void {
        if (kind != CodeEditor) {
            return;
        }
        if (!ensureHighlighter(_highlighter, highlighterFactory, language)) {
            return;
        }
        modeKind.driveHighlighterBatch(_highlighter, edits, folding, window, cx);
    }

    public function diagnostics():Null<DiagnosticSet> {
        return kind == CodeEditor ? _diagnostics : null;
    }

    public function diagnosticsMut():Null<DiagnosticSet> {
        return kind == CodeEditor ? _diagnostics : null;
    }

    /** Get the highlighter cell (if available). */
    public function highlighter():Null<HighlighterCell> {
        return kind == CodeEditor ? _highlighter : null;
    }

    public function setHighlighterFactory(factory:InputHighlighterFactory):Void {
        if (kind == CodeEditor) {
            highlighterFactory = factory;
            _highlighter.value = null;
        }
    }

    public function ensureHighlighterFactory(factory:InputHighlighterFactory):Void {
        if (kind == CodeEditor && highlighterFactory == null) {
            highlighterFactory = factory;
        }
    }

    // From editor/indent.rs

    /**
     * Whether this layout indents blocks. Callers gate this on the input
     * being multi-line: indenting a one-line text field has nothing to
     * indent.
     */
    public inline function isIndentable():Bool {
        return kind == PlainText || kind == CodeEditor;
    }

    public inline function hasIndentGuides():Bool {
        return kind == CodeEditor && indentGuides;
    }

    public function tabSize():TabSize {
        return kind == AutoGrow ? TabSize.defaultValue() : tab;
    }

    /** Builder support for `tab_size` (sets the tab of `PlainText` and `CodeEditor`). */
    public function setTabSize(tab:TabSize):Void {
        if (kind != AutoGrow) this.tab = tab;
    }

    /**
     * Create the highlighter from the factory if there is none yet. Returns
     * whether one is installed.
     */
    static function ensureHighlighter(highlighter:HighlighterCell, highlighterFactory:Null<InputHighlighterFactory>, language:EditorLanguage):Bool {
        if (highlighter.value == null && highlighterFactory != null) {
            highlighter.value = highlighterFactory(language.name());
        }
        return highlighter.value != null;
    }

    /**
     * Builds the tree-sitter edit for a text replacement.
     *
     * Byte offsets and positions for `start`/`oldEnd` come from `oldText`;
     * `newEnd` byte/position come from the post-edit `newText`.
     */
    public static function replacementInputEdit(oldText:Rope, newText:Rope, selectedRange:Range, changeText:String):InputEdit {
        final startByte = minInt(selectedRange.start, oldText.len());
        final oldEndByte = maxInt(minInt(selectedRange.end, oldText.len()), startByte);
        final newEndByte = minInt(startByte + glaze.util.Utf8.byteLength(changeText), newText.len());

        return new InputEdit(startByte, oldEndByte, newEndByte, oldText.offsetToPoint(startByte), oldText.offsetToPoint(oldEndByte),
            newText.offsetToPoint(newEndByte));
    }

    static inline function minInt(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    static inline function maxInt(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

}
