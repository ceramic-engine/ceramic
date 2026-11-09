// Ported from vscode src/vs/editor/common/viewEvents.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Scrollable.ScrollEvent;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.TextModelEvents.IModelDecorationsChangedEvent;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

enum abstract ViewEventType(Int) from Int to Int {
    var ViewCompositionStart = 0;
    var ViewCompositionEnd = 1;
    var ViewConfigurationChanged = 2;
    var ViewCursorStateChanged = 3;
    var ViewDecorationsChanged = 4;
    var ViewFlushed = 5;
    var ViewFocusChanged = 6;
    var ViewLanguageConfigurationChanged = 7;
    var ViewLineMappingChanged = 8;
    var ViewLinesChanged = 9;
    var ViewLinesDeleted = 10;
    var ViewLinesInserted = 11;
    var ViewRevealRangeRequest = 12;
    var ViewScrollChanged = 13;
    var ViewThemeChanged = 14;
    var ViewTokensChanged = 15;
    var ViewTokensColorsChanged = 16;
    var ViewZonesChanged = 17;
}

/**
 * Monaco's `ViewEvent` union: every view event has its `type`.
 */
abstract class ViewEvent {

    public final type:ViewEventType;

    function new(type:ViewEventType) {
        this.type = type;
    }

}

class ViewCompositionStartEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewCompositionStart);
    }
}

class ViewCompositionEndEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewCompositionEnd);
    }
}

class ViewConfigurationChangedEvent extends ViewEvent {

    public final _source:ConfigurationChangedEvent;

    public function new(source:ConfigurationChangedEvent) {
        super(ViewEventType.ViewConfigurationChanged);
        this._source = source;
    }

    public function hasChanged<V>(id:EditorOption<V>):Bool {
        return this._source.hasChanged(id);
    }

}

class ViewCursorStateChangedEvent extends ViewEvent {

    public final selections:Array<Selection>;
    public final modelSelections:Array<Selection>;
    public final reason:CursorChangeReason;

    public function new(selections:Array<Selection>, modelSelections:Array<Selection>, reason:CursorChangeReason) {
        super(ViewEventType.ViewCursorStateChanged);
        this.selections = selections;
        this.modelSelections = modelSelections;
        this.reason = reason;
    }

}

class ViewDecorationsChangedEvent extends ViewEvent {

    public final affectsMinimap:Bool;
    public final affectsOverviewRuler:Bool;
    public final affectsGlyphMargin:Bool;
    public final affectsLineNumber:Bool;

    public function new(source:Null<IModelDecorationsChangedEvent>) {
        super(ViewEventType.ViewDecorationsChanged);
        if (source != null) {
            this.affectsMinimap = source.affectsMinimap;
            this.affectsOverviewRuler = source.affectsOverviewRuler;
            this.affectsGlyphMargin = source.affectsGlyphMargin;
            this.affectsLineNumber = source.affectsLineNumber;
        } else {
            this.affectsMinimap = true;
            this.affectsOverviewRuler = true;
            this.affectsGlyphMargin = true;
            this.affectsLineNumber = true;
        }
    }

}

class ViewFlushedEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewFlushed);
    }
}

class ViewFocusChangedEvent extends ViewEvent {

    public final isFocused:Bool;

    public function new(isFocused:Bool) {
        super(ViewEventType.ViewFocusChanged);
        this.isFocused = isFocused;
    }

}

class ViewLanguageConfigurationEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewLanguageConfigurationChanged);
    }
}

class ViewLineMappingChangedEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewLineMappingChanged);
    }
}

class ViewLinesChangedEvent extends ViewEvent {

    /**
     * The first line that has changed.
     */
    public final fromLineNumber:Int;
    /**
     * The number of lines that have changed.
     */
    public final count:Int;

    public function new(fromLineNumber:Int, count:Int) {
        super(ViewEventType.ViewLinesChanged);
        this.fromLineNumber = fromLineNumber;
        this.count = count;
    }

}

class ViewLinesDeletedEvent extends ViewEvent {

    /**
     * At what line the deletion began (inclusive).
     */
    public final fromLineNumber:Int;
    /**
     * At what line the deletion stopped (inclusive).
     */
    public final toLineNumber:Int;

    public function new(fromLineNumber:Int, toLineNumber:Int) {
        super(ViewEventType.ViewLinesDeleted);
        this.fromLineNumber = fromLineNumber;
        this.toLineNumber = toLineNumber;
    }

}

class ViewLinesInsertedEvent extends ViewEvent {

    /**
     * Before what line did the insertion begin
     */
    public final fromLineNumber:Int;
    /**
     * `toLineNumber` - `fromLineNumber` + 1 denotes the number of lines that were inserted
     */
    public final toLineNumber:Int;

    public function new(fromLineNumber:Int, toLineNumber:Int) {
        super(ViewEventType.ViewLinesInserted);
        this.fromLineNumber = fromLineNumber;
        this.toLineNumber = toLineNumber;
    }

}

enum abstract VerticalRevealType(Int) from Int to Int {
    var Simple = 0;
    var Center = 1;
    var CenterIfOutsideViewport = 2;
    var Top = 3;
    var Bottom = 4;
    var NearTop = 5;
    var NearTopIfOutsideViewport = 6;
}

class ViewRevealRangeRequestEvent extends ViewEvent {

    /**
     * Source of the call that caused the event.
     */
    public final source:Null<String>;
    /**
     * Reduce the revealing to a minimum (e.g. avoid scrolling if the bounding box is visible and near the viewport edge).
     */
    public final minimalReveal:Bool;
    /**
     * Range to be reavealed.
     */
    public final range:Null<Range>;
    /**
     * Selections to be revealed.
     */
    public final selections:Null<Array<Selection>>;
    /**
     * The vertical reveal strategy.
     */
    public final verticalType:VerticalRevealType;
    /**
     * If true: there should be a horizontal & vertical revealing.
     * If false: there should be just a vertical revealing.
     */
    public final revealHorizontal:Bool;
    /**
     * The scroll type.
     */
    public final scrollType:ScrollType;

    public function new(source:Null<String>, minimalReveal:Bool, range:Null<Range>, selections:Null<Array<Selection>>, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType) {
        super(ViewEventType.ViewRevealRangeRequest);
        this.source = source;
        this.minimalReveal = minimalReveal;
        this.range = range;
        this.selections = selections;
        this.verticalType = verticalType;
        this.revealHorizontal = revealHorizontal;
        this.scrollType = scrollType;
    }

}

class ViewScrollChangedEvent extends ViewEvent {

    public final scrollWidth:Float;
    public final scrollLeft:Float;
    public final scrollHeight:Float;
    public final scrollTop:Float;

    public final scrollWidthChanged:Bool;
    public final scrollLeftChanged:Bool;
    public final scrollHeightChanged:Bool;
    public final scrollTopChanged:Bool;

    public function new(source:ScrollEvent) {
        super(ViewEventType.ViewScrollChanged);
        this.scrollWidth = source.scrollWidth;
        this.scrollLeft = source.scrollLeft;
        this.scrollHeight = source.scrollHeight;
        this.scrollTop = source.scrollTop;

        this.scrollWidthChanged = source.scrollWidthChanged;
        this.scrollLeftChanged = source.scrollLeftChanged;
        this.scrollHeightChanged = source.scrollHeightChanged;
        this.scrollTopChanged = source.scrollTopChanged;
    }

}

/**
 * The theme changed. Monaco passes an `IColorTheme`; the view reads the
 * colors from its own theme (TODO(step 1, themes): the theme object).
 */
class ViewThemeChangedEvent extends ViewEvent {

    public final theme:Any;

    public function new(theme:Any) {
        super(ViewEventType.ViewThemeChanged);
        this.theme = theme;
    }

}

class ViewTokensChangedEvent extends ViewEvent {

    public final ranges:Array<{fromLineNumber:Int, toLineNumber:Int}>;

    public function new(ranges:Array<{fromLineNumber:Int, toLineNumber:Int}>) {
        super(ViewEventType.ViewTokensChanged);
        this.ranges = ranges;
    }

}

class ViewTokensColorsChangedEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewTokensColorsChanged);
    }
}

class ViewZonesChangedEvent extends ViewEvent {
    public function new() {
        super(ViewEventType.ViewZonesChanged);
    }
}
