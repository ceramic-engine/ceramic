// Ported from vscode src/vs/editor/common/textModelEvents.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.Model.IModelDecoration;
import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.core.Range.IRange;
import cityscape.common.core.Selection;

/**
 * An event describing that the current language associated with a model has changed.
 */
typedef IModelLanguageChangedEvent = {
    /**
     * Previous language
     */
    final oldLanguage:String;
    /**
     * New language
     */
    final newLanguage:String;
    /**
     * Source of the call that caused the event.
     */
    final source:String;
}

/**
 * An event describing that the language configuration associated with a model has changed.
 */
typedef IModelLanguageConfigurationChangedEvent = {}

typedef IModelContentChange = {
    /**
     * The range that got replaced.
     */
    final range:IRange;
    /**
     * The offset of the range that got replaced.
     */
    final rangeOffset:Int;
    /**
     * The length of the range that got replaced.
     */
    final rangeLength:Int;
    /**
     * The new text for the range.
     */
    final text:String;
}

/**
 * An event describing a change in the text of a model.
 */
typedef IModelContentChangedEvent = {
    /**
     * The changes are ordered from the end of the document to the beginning, so they should be safe to apply in sequence.
     */
    final changes:Array<IModelContentChange>;
    /**
     * The (new) end-of-line character.
     */
    final eol:String;
    /**
     * The new version id the model has transitioned to.
     */
    final versionId:Int;
    /**
     * Flag that indicates that this event was generated while undoing.
     */
    final isUndoing:Bool;
    /**
     * Flag that indicates that this event was generated while redoing.
     */
    final isRedoing:Bool;
    /**
     * Flag that indicates that all decorations were lost with this edit.
     * The model has been reset to a new value.
     */
    final isFlush:Bool;
    /**
     * Flag that indicates that this event describes an eol change.
     */
    final isEolChange:Bool;
}

/**
 * An event describing that model decorations have changed.
 */
typedef IModelDecorationsChangedEvent = {
    final affectsMinimap:Bool;
    final affectsOverviewRuler:Bool;
    final affectsGlyphMargin:Bool;
    final affectsLineNumber:Bool;
}

typedef IModelTokensChangedEvent = {
    final semanticTokensApplied:Bool;
    final ranges:Array<{
        /**
         * The start of the range (inclusive)
         */
        final fromLineNumber:Int;
        /**
         * The end of the range (inclusive)
         */
        final toLineNumber:Int;
    }>;
}

typedef IModelOptionsChangedEvent = {
    final tabSize:Bool;
    final indentSize:Bool;
    final insertSpaces:Bool;
    final trimAutoWhitespace:Bool;
}

/**
 * @internal
 */
enum abstract RawContentChangedType(Int) from Int to Int {
    var Flush = 1;
    var LineChanged = 2;
    var LinesDeleted = 3;
    var LinesInserted = 4;
    var EOLChanged = 5;
}

/**
 * The base of Monaco's `ModelRawChange` union (`ModelRawFlush |
 * ModelRawLineChanged | ModelRawLinesDeleted | ModelRawLinesInserted |
 * ModelRawEOLChanged`): switch on `changeType` and cast, like Monaco.
 * @internal
 */
class ModelRawChange {

    public final changeType:RawContentChangedType;

    function new(changeType:RawContentChangedType) {
        this.changeType = changeType;
    }

}

/**
 * An event describing that a model has been reset to a new value.
 * @internal
 */
class ModelRawFlush extends ModelRawChange {

    public function new() {
        super(RawContentChangedType.Flush);
    }

}

/**
 * Represents text injected on a line
 * @internal
 */
class LineInjectedText {

    public static function applyInjectedText(lineText:String, injectedTexts:Null<Array<LineInjectedText>>):String {
        if (injectedTexts == null || injectedTexts.length == 0) {
            return lineText;
        }
        var result = '';
        var lastOriginalOffset = 0;
        for (injectedText in injectedTexts) {
            result += lineText.substring(lastOriginalOffset, injectedText.column - 1);
            lastOriginalOffset = injectedText.column - 1;
            result += injectedText.options.content;
        }
        result += lineText.substring(lastOriginalOffset);
        return result;
    }

    public static function fromDecorations(decorations:Array<IModelDecoration>):Array<LineInjectedText> {
        final result:Array<LineInjectedText> = [];
        for (decoration in decorations) {
            final before = decoration.options.before;
            if (before != null && before.content.length > 0) {
                result.push(new LineInjectedText(
                    decoration.ownerId,
                    decoration.range.startLineNumber,
                    decoration.range.startColumn,
                    before,
                    0
                ));
            }
            final after = decoration.options.after;
            if (after != null && after.content.length > 0) {
                result.push(new LineInjectedText(
                    decoration.ownerId,
                    decoration.range.endLineNumber,
                    decoration.range.endColumn,
                    after,
                    1
                ));
            }
        }
        // Stable sort, like JavaScript's Array.prototype.sort
        haxe.ds.ArraySort.sort(result, (a, b) -> {
            if (a.lineNumber == b.lineNumber) {
                if (a.column == b.column) {
                    return a.order - b.order;
                }
                return a.column - b.column;
            }
            return a.lineNumber - b.lineNumber;
        });
        return result;
    }

    public final ownerId:Int;

    public final lineNumber:Int;

    public final column:Int;

    public final options:InjectedTextOptions;

    public final order:Int;

    public function new(ownerId:Int, lineNumber:Int, column:Int, options:InjectedTextOptions, order:Int) {
        this.ownerId = ownerId;
        this.lineNumber = lineNumber;
        this.column = column;
        this.options = options;
        this.order = order;
    }

    public function withText(text:String):LineInjectedText {
        // { ...this.options, content: text }: a shallow copy keeps every field
        final options:InjectedTextOptions = Reflect.copy(this.options);
        Reflect.setField(options, 'content', text);
        return new LineInjectedText(this.ownerId, this.lineNumber, this.column, options, this.order);
    }

}

/**
 * An event describing that a line has changed in a model.
 * @internal
 */
class ModelRawLineChanged extends ModelRawChange {

    /**
     * The line that has changed.
     */
    public final lineNumber:Int;

    /**
     * The new value of the line.
     */
    public final detail:String;

    /**
     * The injected text on the line.
     */
    public final injectedText:Null<Array<LineInjectedText>>;

    public function new(lineNumber:Int, detail:String, injectedText:Null<Array<LineInjectedText>>) {
        super(RawContentChangedType.LineChanged);
        this.lineNumber = lineNumber;
        this.detail = detail;
        this.injectedText = injectedText;
    }

}

/**
 * An event describing that line(s) have been deleted in a model.
 * @internal
 */
class ModelRawLinesDeleted extends ModelRawChange {

    /**
     * At what line the deletion began (inclusive).
     */
    public final fromLineNumber:Int;

    /**
     * At what line the deletion stopped (inclusive).
     */
    public final toLineNumber:Int;

    public function new(fromLineNumber:Int, toLineNumber:Int) {
        super(RawContentChangedType.LinesDeleted);
        this.fromLineNumber = fromLineNumber;
        this.toLineNumber = toLineNumber;
    }

}

/**
 * An event describing that line(s) have been inserted in a model.
 * @internal
 */
class ModelRawLinesInserted extends ModelRawChange {

    /**
     * Before what line did the insertion begin
     */
    public final fromLineNumber:Int;

    /**
     * `toLineNumber` - `fromLineNumber` + 1 denotes the number of lines that were inserted
     */
    public final toLineNumber:Int;

    /**
     * The text that was inserted
     */
    public final detail:Array<String>;

    /**
     * The injected texts for every inserted line.
     */
    public final injectedTexts:Array<Null<Array<LineInjectedText>>>;

    public function new(fromLineNumber:Int, toLineNumber:Int, detail:Array<String>, injectedTexts:Array<Null<Array<LineInjectedText>>>) {
        super(RawContentChangedType.LinesInserted);
        this.injectedTexts = injectedTexts;
        this.fromLineNumber = fromLineNumber;
        this.toLineNumber = toLineNumber;
        this.detail = detail;
    }

}

/**
 * An event describing that a model has had its EOL changed.
 * @internal
 */
class ModelRawEOLChanged extends ModelRawChange {

    public function new() {
        super(RawContentChangedType.EOLChanged);
    }

}

/**
 * An event describing a change in the text of a model.
 * @internal
 */
class ModelRawContentChangedEvent {

    public final changes:Array<ModelRawChange>;

    /**
     * The new version id the model has transitioned to.
     */
    public final versionId:Int;

    /**
     * Flag that indicates that this event was generated while undoing.
     */
    public final isUndoing:Bool;

    /**
     * Flag that indicates that this event was generated while redoing.
     */
    public final isRedoing:Bool;

    public var resultingSelection:Null<Array<Selection>>;

    public function new(changes:Array<ModelRawChange>, versionId:Int, isUndoing:Bool, isRedoing:Bool) {
        this.changes = changes;
        this.versionId = versionId;
        this.isUndoing = isUndoing;
        this.isRedoing = isRedoing;
        this.resultingSelection = null;
    }

    public function containsEvent(type:RawContentChangedType):Bool {
        for (i in 0...this.changes.length) {
            final change = this.changes[i];
            if (change.changeType == type) {
                return true;
            }
        }
        return false;
    }

    public static function merge(a:ModelRawContentChangedEvent, b:ModelRawContentChangedEvent):ModelRawContentChangedEvent {
        final changes = a.changes.concat(b.changes);
        final versionId = b.versionId;
        final isUndoing = (a.isUndoing || b.isUndoing);
        final isRedoing = (a.isRedoing || b.isRedoing);
        return new ModelRawContentChangedEvent(changes, versionId, isUndoing, isRedoing);
    }

}

/**
 * An event describing a change in injected text.
 * @internal
 */
class ModelInjectedTextChangedEvent {

    public final changes:Array<ModelRawLineChanged>;

    public function new(changes:Array<ModelRawLineChanged>) {
        this.changes = changes;
    }

}

/**
 * @internal
 */
class InternalModelContentChangeEvent {

    public final rawContentChangedEvent:ModelRawContentChangedEvent;

    public final contentChangedEvent:IModelContentChangedEvent;

    public function new(rawContentChangedEvent:ModelRawContentChangedEvent, contentChangedEvent:IModelContentChangedEvent) {
        this.rawContentChangedEvent = rawContentChangedEvent;
        this.contentChangedEvent = contentChangedEvent;
    }

    public function merge(other:InternalModelContentChangeEvent):InternalModelContentChangeEvent {
        final rawContentChangedEvent = ModelRawContentChangedEvent.merge(this.rawContentChangedEvent, other.rawContentChangedEvent);
        final contentChangedEvent = InternalModelContentChangeEvent._mergeChangeEvents(this.contentChangedEvent, other.contentChangedEvent);
        return new InternalModelContentChangeEvent(rawContentChangedEvent, contentChangedEvent);
    }

    static function _mergeChangeEvents(a:IModelContentChangedEvent, b:IModelContentChangedEvent):IModelContentChangedEvent {
        final changes = a.changes.concat(b.changes);
        final eol = b.eol;
        final versionId = b.versionId;
        final isUndoing = (a.isUndoing || b.isUndoing);
        final isRedoing = (a.isRedoing || b.isRedoing);
        final isFlush = (a.isFlush || b.isFlush);
        final isEolChange = a.isEolChange && b.isEolChange; // both must be true to not confuse listeners who skip such edits
        return {
            changes: changes,
            eol: eol,
            isEolChange: isEolChange,
            versionId: versionId,
            isUndoing: isUndoing,
            isRedoing: isRedoing,
            isFlush: isFlush,
        };
    }

}
