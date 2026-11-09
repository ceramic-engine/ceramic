// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mode.rs, crates/base/src/input/editor/indent.rs (the `impl LayoutMode` block)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The variants of `LayoutMode`.
 *
 * gpui-kit's third variant, `CodeEditor` (line numbers, language, indent
 * guides, folding, highlighter, diagnostics, automatic pairs), belongs to its
 * code editor, which is not part of Glaze: its code editor is Cityscape
 * (plugin `cityscape`).
 */
enum abstract LayoutModeKind(Int) {
    /** A plain text input mode. */
    var PlainText = 0;
    /** An auto grow input mode. */
    var AutoGrow = 1;
}

/**
 * How the input lays its text out: rows and growth.
 *
 * This does not say what *kind* of input this is: that is the state's
 * `InputModeKind`. Rust's enum variants are `kind`; the fields of the other
 * variant are unused (`tab` and `rows` exist in every variant here, `tab`
 * is only read for `PlainText`).
 */
class LayoutMode {

    public var kind(default, null):LayoutModeKind;

    var tab:TabSize;

    var _rows:Int;

    // AutoGrow
    var _minRows:Int = 1;
    var _maxRows:Int = 1;

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

    /** `LayoutMode::default()`: a plain text mode. */
    public static inline function defaultValue():LayoutMode {
        return plainText();
    }

    /** Create a plain input mode with default settings. */
    public static function plainText():LayoutMode {
        return plainTextWith(TabSize.defaultValue(), 1);
    }

    /** Create an auto grow input mode with given min and max rows. */
    public static function autoGrow(minRows:Int, maxRows:Int):LayoutMode {
        return autoGrowWith(minRows, minRows, maxRows);
    }

    /** A copy (Rust `Clone`). */
    public function clone():LayoutMode {
        final mode = new LayoutMode(kind, tab.copy(), _rows);
        mode._minRows = _minRows;
        mode._maxRows = _maxRows;
        return mode;
    }

    public inline function isAutoGrow():Bool {
        return kind == AutoGrow;
    }

    public function setRows(newRows:Int):Void {
        switch kind {
            case PlainText:
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
     * mode `rows` is the configured height.
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

    // From editor/indent.rs

    /**
     * Whether this layout indents blocks. Callers gate this on the input
     * being multi-line: indenting a one-line text field has nothing to
     * indent.
     */
    public inline function isIndentable():Bool {
        return kind == PlainText;
    }

    public function tabSize():TabSize {
        return kind == AutoGrow ? TabSize.defaultValue() : tab;
    }

    /** Builder support for `tab_size` (sets the tab of `PlainText`). */
    public function setTabSize(tab:TabSize):Void {
        if (kind != AutoGrow) this.tab = tab;
    }

}
