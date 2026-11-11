// Ported from vscode src/vs/editor/browser/widget/diffEditor/features/gutterFeature.ts
// and src/vs/editor/browser/widget/diffEditor/utils/editorGutter.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.common.core.LineRange;
import cityscape.common.core.Range;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;
import glaze.kit.base.Scrollbar.ScalarTransition;
import glaze.kit.base.animation.Easings;

/**
 * An item of the gutter menu: a change of the diff, or the changes the
 * selections of the modified editor touch (Monaco's `DiffGutterItem`).
 */
class DiffGutterItem {

    public final mapping:DetailedLineRangeMapping;

    /** Shown without hovering the gutter (the change of the cursor, a selection). */
    public final showAlways:Bool;

    /** The toolbar of a selection (`MenuId.DiffEditorSelectionToolbar`), else of a change. */
    public final isSelection:Bool;

    public function new(mapping:DetailedLineRangeMapping, showAlways:Bool, isSelection:Bool) {
        this.mapping = mapping;
        this.showAlways = showAlways;
        this.isSelection = isSelection;
    }

    public var id(get, never):String;
    function get_id():String {
        return this.mapping.modified.toString();
    }

    public var range(get, never):LineRange;
    function get_range():LineRange {
        return this.mapping.modified;
    }

}

/**
 * The place of a gutter item, relative to the top of the gutter: its top
 * and height (the lines of its range in the modified editor), and the top
 * of its buttons.
 */
class DiffGutterItemLayout {

    public final item:DiffGutterItem;
    public final top:Float;
    public final height:Float;
    public final buttonsTop:Float;

    public function new(item:DiffGutterItem, top:Float, height:Float, buttonsTop:Float) {
        this.item = item;
        this.top = top;
        this.height = height;
        this.buttonsTop = buttonsTop;
    }

}

/**
 * The gutter menu between the two editors of the diff editor (Monaco's
 * `DiffEditorGutter`, `renderGutterMenu`): 35 pixels wide, with a toolbar per
 * change (`MenuId.DiffEditorHunkToolbar`) whose only action in standalone
 * Monaco is "Revert Block" (`diffEditor.revert`, the `arrow-right` codicon
 * side by side, `discard` in the inline view), shown when the modified text
 * can be edited (`diffEditorModifiedWritable`). With selections in the
 * modified editor, one toolbar for the changes they touch ("Revert
 * Selection").
 *
 * This class holds the logic; `CityscapeDiffEditor` draws the gutter.
 */
class DiffEditorGutter {

    /** The width of the gutter (gutterFeature.ts `width`). */
    public static inline final WIDTH:Float = 35;

    /** The size of a `.gutterItem`. */
    public static inline final ITEM_WIDTH:Float = 34;
    public static inline final ITEM_HEIGHT:Float = 20;

    /**
     * The height of the buttons: a 16 pixel codicon in an action label with
     * a vertical padding of 1 pixel (style.css `.action-label { padding: 1px
     * 2px }`), 20 by 18 pixels.
     */
    public static inline final BUTTON_WIDTH:Float = 20;
    public static inline final BUTTON_HEIGHT:Float = 18;

    final widget:DiffEditorWidget;

    public function new(widget:DiffEditorWidget) {
        this.widget = widget;
    }

    /**
     * Whether the gutter has actions (`_hasActions`): the gutter menu is on
     * (`shouldRenderGutterMenu`) and the diff editor is not read only (the
     * `when` of the revert actions, `diffEditorModifiedWritable`:
     * `!readOnly`).
     */
    public function hasActions():Bool {
        final options = this.widget.getOptions();
        return options.shouldRenderGutterMenu && !options.readOnly;
    }

    /**
     * The width the gutter takes in the layout (0 without actions).
     */
    public function width():Float {
        return this.hasActions() ? WIDTH : 0;
    }

    /**
     * The codicon of the revert action: `arrow-right` side by side, `discard`
     * in the inline view (diffEditor.contribution.ts).
     */
    public function iconOf(item:DiffGutterItem):String {
        return this.widget.renderSideBySide ? 'arrow-right' : 'discard';
    }

    /**
     * The title of the revert action.
     */
    public function titleOf(item:DiffGutterItem):String {
        final nls = this.widget.modified.context.nls;
        return item.isSelection ? nls.localize('revertSelection', "Revert Selection") : nls.localize('revertHunk', "Revert Block");
    }

    /**
     * Runs the revert action of an item (`RevertHunkOrSelection`).
     */
    public function run(item:DiffGutterItem):Void {
        final inner = item.mapping.innerChanges;
        this.widget.revertRangeMappings(inner != null ? inner : []);
    }

    function _currentDiff(mappings:Array<DiffMapping>):Null<DiffMapping> {
        final cursorPosition = this.widget.modified.getPosition();
        if (cursorPosition == null) {
            return null;
        }
        for (m in mappings) {
            if (m.lineRangeMapping.modified.contains(cursorPosition.lineNumber)) {
                return m;
            }
        }
        return null;
    }

    function _selectedDiffs(mappings:Array<DiffMapping>):Array<{mapping:DiffMapping, rangeMappings:Array<RangeMapping>}> {
        final result:Array<{mapping:DiffMapping, rangeMappings:Array<RangeMapping>}> = [];
        final selections = this.widget.modified.getSelections();
        if (selections == null) {
            return result;
        }
        var allEmpty = true;
        for (s in selections) {
            if (!s.isEmpty()) {
                allEmpty = false;
                break;
            }
        }
        if (allEmpty) {
            return result;
        }
        final selectedLineNumbers = new LineRangeSet([for (s in selections) LineRange.fromRangeInclusive(s)]);
        for (m in mappings) {
            final inner = m.lineRangeMapping.innerChanges;
            if (inner == null || !selectedLineNumbers.intersects(m.lineRangeMapping.modified)) {
                continue;
            }
            result.push({mapping: m, rangeMappings: [for (c in inner) if (Lambda.exists(selections, s -> Range.areIntersecting(c.modifiedRange, s))) c]});
        }
        var none = true;
        for (r in result) {
            if (r.rangeMappings.length > 0) {
                none = false;
                break;
            }
        }
        return none ? [] : result;
    }

    /**
     * The items (`getIntersectingGutterItems`): the toolbar of the selected
     * changes when the selections touch some, else one per change.
     */
    public function items():Array<DiffGutterItem> {
        final model = this.widget.getViewModel();
        final diff = model != null ? model.diff : null;
        if (diff == null) {
            return [];
        }
        final mappings = diff.mappings;
        final selection = this._selectedDiffs(mappings);
        if (selection.length > 0) {
            final all:Array<RangeMapping> = [];
            for (s in selection) {
                for (r in s.rangeMappings) {
                    all.push(r);
                }
            }
            return [new DiffGutterItem(DetailedLineRangeMapping.fromRangeMappings(all), true, true)];
        }
        final currentDiff = this._currentDiff(mappings);
        return [for (m in mappings) new DiffGutterItem(m.lineRangeMapping.withInnerChangesFromLineRanges(), currentDiff != null && m.lineRangeMapping == currentDiff.lineRangeMapping, false)];
    }

    /**
     * The visible items and their places in a gutter `viewHeight` pixels
     * high (`EditorGutter.render` and `DiffToolBar.layout`).
     */
    public function layout(viewHeight:Float):Array<DiffGutterItemLayout> {
        final result:Array<DiffGutterItemLayout> = [];
        final editor:CodeEditorWidget = this.widget.modified;
        final model = editor.getModel();
        if (model == null || viewHeight <= 0 || !this.hasActions()) {
            return result;
        }
        final scrollTop = editor.getScrollTop();
        final items = this.items();
        final done = new Map<String, Bool>();
        for (visibleRange in editor.getVisibleRanges()) {
            final visibleRange2 = new LineRange(visibleRange.startLineNumber, visibleRange.endLineNumber + 1);
            for (gutterItem in items) {
                if (gutterItem.range.intersect(visibleRange2) == null || done.exists(gutterItem.id)) {
                    continue;
                }
                done.set(gutterItem.id, true);
                final range = gutterItem.range;
                final top = range.startLineNumber <= model.getLineCount()
                    ? editor.getTopForLineNumber(range.startLineNumber, true) - scrollTop
                    : editor.getBottomForLineNumber(range.startLineNumber - 1, false) - scrollTop;
                final bottom = range.endLineNumberExclusive == 1
                    ? Math.max(top, editor.getTopForLineNumber(range.startLineNumber, false) - scrollTop)
                    : Math.max(top, editor.getBottomForLineNumber(range.endLineNumberExclusive - 1, true) - scrollTop);
                final height = bottom - top;
                result.push(new DiffGutterItemLayout(gutterItem, top, height, buttonsTop(top, height, viewHeight)));
            }
        }
        return result;
    }

    /**
     * `DiffToolBar.layout`: the top of the buttons relative to the item,
     * centered on its range, kept a button's height away from the edges of
     * the view and of the range when there is room.
     */
    public static function buttonsTop(itemStart:Float, itemLength:Float, viewHeight:Float):Float {
        final itemHeight = BUTTON_HEIGHT;
        final middleHeight = itemLength / 2 - itemHeight / 2;
        final margin = itemHeight;
        var effectiveCheckboxTop = itemStart + middleHeight;
        // OffsetRange.tryCreate: null when the end is before the start
        final viewportStart = margin;
        final viewportEnd = viewHeight - margin - itemHeight;
        final parentStart = itemStart + margin;
        final parentEnd = itemStart + itemLength - itemHeight - margin;
        if (viewportStart <= viewportEnd && parentStart < parentEnd) {
            // OffsetRange.clip: within [start, endExclusive - 1] (Monaco
            // throws on an empty viewport range; the start is kept here)
            effectiveCheckboxTop = Math.max(viewportStart, Math.min(viewportEnd - 1, effectiveCheckboxTop));
            effectiveCheckboxTop = Math.max(parentStart, Math.min(parentEnd - 1, effectiveCheckboxTop));
        }
        return effectiveCheckboxTop - itemStart;
    }

}

/**
 * The opacity of a gutter item over time, Monaco's CSS transitions of
 * style.css: `.gutterItem { opacity: 0; transition: opacity 0.7s }` (the
 * `ease` timing function of CSS), `.gutter:hover .gutterItem { opacity: 1;
 * transition: opacity 0.1s ease-in-out }`, `.showAlways { opacity: 1;
 * transition: none }`, and `noTransition` while `showAlways` changes
 * (`DiffToolBar`, gutterFeature.ts). Measured on the real Monaco 0.52.2
 * (glaze-golden scratchpad cs-cursor probe, s7-cursor.js): 0.52 at 52 ms
 * and 1 at 100 ms after the mouse enters the gutter, 0.70 at 144 ms, 0.45
 * at 243 ms, 0.21 at 355 ms, 0.09 at 467 ms and 0 at 714 ms after it
 * leaves.
 *
 * The transition is the kit scrollbars' (`ScalarTransition` of
 * `glaze.kit.base.Scrollbar`, times from `cx.backgroundExecutor().now()`),
 * with CSS's curves. Like a CSS transition reversed midway, a fade that
 * changes direction starts from its current opacity and takes the duration
 * of the distance left. An item created visible or hidden shows so at once
 * (a new DOM node has no transition), and so does one whose `showAlways`
 * changes (`noTransition`) or one under reduced motion.
 */
class GutterItemFade {

    /** The durations of style.css, in seconds. */
    public static inline final FADE_IN_DURATION:Float = 0.1;
    public static inline final FADE_OUT_DURATION:Float = 0.7;

    /** CSS `ease-in-out` (the fade in) and `ease` (the fade out). */
    static final EASE_IN_OUT = Easings.cubicBezier(0.42, 0, 0.58, 1);
    static final EASE = Easings.cubicBezier(0.25, 0.1, 0.25, 1);

    final transition:ScalarTransition;

    var showAlways:Bool;

    /** The render that last used this fade (`CityscapeDiffEditor`). */
    public var renderStamp:Int = 0;

    /** The opacity of the last render. */
    public var rendered:Float = 0;

    public function new(visible:Bool, showAlways:Bool, now:Float) {
        this.transition = @:privateAccess ScalarTransition.settled(visible ? 1 : 0, now);
        this.showAlways = showAlways;
    }

    /**
     * Moves toward `visible` (the gutter hovered, or `showAlways`).
     */
    public function setVisible(visible:Bool, showAlways:Bool, reduceMotion:Bool, now:Float):Void {
        final target = visible ? 1.0 : 0.0;
        if (showAlways != this.showAlways || reduceMotion) {
            this.showAlways = showAlways;
            @:privateAccess transition.settle(target, now);
            return;
        }
        if (@:privateAccess transition.target == target) {
            return;
        }
        final current = opacity(now);
        final duration = (visible ? FADE_IN_DURATION : FADE_OUT_DURATION) * Math.abs(target - current);
        @:privateAccess transition.start(current, target, duration, now);
    }

    public function opacity(now:Float):Float {
        return @:privateAccess transition.sample(now, interpolate).value;
    }

    public function running(now:Float):Bool {
        return @:privateAccess transition.sample(now, interpolate).running;
    }

    static function interpolate(from:Float, target:Float, linear:Float):Float {
        final curve = target > from ? EASE_IN_OUT : EASE;
        return from + (target - from) * curve(linear);
    }

}
