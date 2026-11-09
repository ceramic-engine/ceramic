// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/ghostText.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.base.common.Strings;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit;
import cityscape.contrib.inlineCompletions.view.Utils.ColumnRange;

/**
 * Monaco's `GhostTextOrReplacement` (`GhostText | GhostTextReplacement`):
 * the common base of the two classes.
 */
class GhostTextOrReplacement {

    public final lineNumber:Int;

    function new(lineNumber:Int) {
        this.lineNumber = lineNumber;
    }

    public var parts(get, never):Array<GhostTextPart>;
    function get_parts():Array<GhostTextPart> {
        throw 'abstract';
    }

    public var lineCount(get, never):Int;
    function get_lineCount():Int {
        throw 'abstract';
    }

    public function isEmpty():Bool {
        for (p in this.parts) {
            if (p.lines.length != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * Only used for testing/debugging.
     */
    public function render(documentText:String, debug:Bool = false):String {
        throw 'abstract';
    }

    public function renderForScreenReader(lineText:String):String {
        throw 'abstract';
    }

    public static function ghostTextsOrReplacementsEqual(a:Null<Array<GhostTextOrReplacement>>, b:Null<Array<GhostTextOrReplacement>>):Bool {
        // equals(a, b, ghostTextOrReplacementEquals) of arrays.ts
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!ghostTextOrReplacementEquals(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

    public static function ghostTextOrReplacementEquals(a:Null<GhostTextOrReplacement>, b:Null<GhostTextOrReplacement>):Bool {
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        if (Std.isOfType(a, GhostText) && Std.isOfType(b, GhostText)) {
            return (cast a : GhostText).equals(cast b);
        }
        if (Std.isOfType(a, GhostTextReplacement) && Std.isOfType(b, GhostTextReplacement)) {
            return (cast a : GhostTextReplacement).equals(cast b);
        }
        return false;
    }

}

class GhostText extends GhostTextOrReplacement {

    final _parts:Array<GhostTextPart>;

    public function new(lineNumber:Int, parts:Array<GhostTextPart>) {
        super(lineNumber);
        this._parts = parts;
    }

    override function get_parts():Array<GhostTextPart> {
        return _parts;
    }

    public function equals(other:GhostText):Bool {
        if (this.lineNumber != other.lineNumber || this._parts.length != other._parts.length) {
            return false;
        }
        for (index in 0...this._parts.length) {
            if (!this._parts[index].equals(other._parts[index])) {
                return false;
            }
        }
        return true;
    }

    /**
     * Only used for testing/debugging.
     */
    override public function render(documentText:String, debug:Bool = false):String {
        return new TextEdit([
            for (p in this._parts) new SingleTextEdit(
                Range.fromPositions(new Position(this.lineNumber, p.column)),
                debug ? '[' + p.lines.join('\n') + ']' : p.lines.join('\n')
            )
        ]).applyToString(documentText);
    }

    override public function renderForScreenReader(lineText:String):String {
        if (this._parts.length == 0) {
            return '';
        }
        final lastPart = this._parts[this._parts.length - 1];

        final cappedLineText = lineText.substr(0, lastPart.column - 1);
        final text = new TextEdit([
            for (p in this._parts) new SingleTextEdit(
                Range.fromPositions(new Position(1, p.column)),
                p.lines.join('\n')
            )
        ]).applyToString(cappedLineText);

        return text.substring(this._parts[0].column - 1);
    }

    override function get_lineCount():Int {
        var r = 1;
        for (p in this._parts) {
            r += p.lines.length - 1;
        }
        return r;
    }

}

class GhostTextPart {

    public final column:Int;
    public final text:String;
    /**
     * Indicates if this part is a preview of an inline suggestion when a suggestion is previewed.
     */
    public final preview:Bool;

    public final lines:Array<String>;

    public function new(column:Int, text:String, preview:Bool) {
        this.column = column;
        this.text = text;
        this.preview = preview;
        this.lines = Strings.splitLines(text);
    }

    public function equals(other:GhostTextPart):Bool {
        if (this.column != other.column || this.lines.length != other.lines.length) {
            return false;
        }
        for (index in 0...this.lines.length) {
            if (this.lines[index] != other.lines[index]) {
                return false;
            }
        }
        return true;
    }

}

class GhostTextReplacement extends GhostTextOrReplacement {

    final _parts:Array<GhostTextPart>;

    public final columnRange:ColumnRange;
    public final text:String;
    public final additionalReservedLineCount:Int;
    public final newLines:Array<String>;

    public function new(lineNumber:Int, columnRange:ColumnRange, text:String, additionalReservedLineCount:Int = 0) {
        super(lineNumber);
        this.columnRange = columnRange;
        this.text = text;
        this.additionalReservedLineCount = additionalReservedLineCount;
        this._parts = [new GhostTextPart(columnRange.endColumnExclusive, text, false)];
        this.newLines = Strings.splitLines(text);
    }

    override function get_parts():Array<GhostTextPart> {
        return _parts;
    }

    override public function renderForScreenReader(_lineText:String):String {
        return this.newLines.join('\n');
    }

    override public function render(documentText:String, debug:Bool = false):String {
        final replaceRange = this.columnRange.toRange(this.lineNumber);

        if (debug) {
            return new TextEdit([
                new SingleTextEdit(Range.fromPositions(replaceRange.getStartPosition()), '('),
                new SingleTextEdit(Range.fromPositions(replaceRange.getEndPosition()), ')[' + this.newLines.join('\n') + ']'),
            ]).applyToString(documentText);
        }
        else {
            return new TextEdit([
                new SingleTextEdit(replaceRange, this.newLines.join('\n')),
            ]).applyToString(documentText);
        }
    }

    override function get_lineCount():Int {
        return this.newLines.length;
    }

    public function equals(other:GhostTextReplacement):Bool {
        if (this.lineNumber != other.lineNumber
            || !this.columnRange.equals(other.columnRange)
            || this.newLines.length != other.newLines.length
            || this.additionalReservedLineCount != other.additionalReservedLineCount) {
            return false;
        }
        for (index in 0...this.newLines.length) {
            if (this.newLines[index] != other.newLines[index]) {
                return false;
            }
        }
        return true;
    }

}
