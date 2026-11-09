// Ported from vscode src/vs/editor/browser/widget/diffEditor/components/diffEditorDecorations.ts
// and the decoration options of src/vs/editor/browser/widget/diffEditor/registrations.contribution.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.Cityscape;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.Model;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.view.widget.codeEditor.CodeEditorWidget;

/**
 * The decoration options of the diff editor (registrations.contribution.ts),
 * created on first use. The class names keep Monaco's names; their look is
 * given by `DiffEditorStyles` (style.css).
 */
class DiffDecorationOptions {

    static var _diffLineAddDecorationBackgroundWithIndicator:Null<ModelDecorationOptions> = null;
    public static var diffLineAddDecorationBackgroundWithIndicator(get, never):IModelDecorationOptions;
    static function get_diffLineAddDecorationBackgroundWithIndicator():IModelDecorationOptions {
        if (_diffLineAddDecorationBackgroundWithIndicator == null) {
            _diffLineAddDecorationBackgroundWithIndicator = ModelDecorationOptions.register({
                className: 'line-insert',
                description: 'line-insert',
                isWholeLine: true,
                linesDecorationsClassName: 'insert-sign codicon codicon-diff-insert',
                marginClassName: 'gutter-insert',
            });
        }
        return cast _diffLineAddDecorationBackgroundWithIndicator;
    }

    static var _diffLineDeleteDecorationBackgroundWithIndicator:Null<ModelDecorationOptions> = null;
    public static var diffLineDeleteDecorationBackgroundWithIndicator(get, never):IModelDecorationOptions;
    static function get_diffLineDeleteDecorationBackgroundWithIndicator():IModelDecorationOptions {
        if (_diffLineDeleteDecorationBackgroundWithIndicator == null) {
            _diffLineDeleteDecorationBackgroundWithIndicator = ModelDecorationOptions.register({
                className: 'line-delete',
                description: 'line-delete',
                isWholeLine: true,
                linesDecorationsClassName: 'delete-sign codicon codicon-diff-remove',
                marginClassName: 'gutter-delete',
            });
        }
        return cast _diffLineDeleteDecorationBackgroundWithIndicator;
    }

    static var _diffLineAddDecorationBackground:Null<ModelDecorationOptions> = null;
    public static var diffLineAddDecorationBackground(get, never):IModelDecorationOptions;
    static function get_diffLineAddDecorationBackground():IModelDecorationOptions {
        if (_diffLineAddDecorationBackground == null) {
            _diffLineAddDecorationBackground = ModelDecorationOptions.register({
                className: 'line-insert',
                description: 'line-insert',
                isWholeLine: true,
                marginClassName: 'gutter-insert',
            });
        }
        return cast _diffLineAddDecorationBackground;
    }

    static var _diffLineDeleteDecorationBackground:Null<ModelDecorationOptions> = null;
    public static var diffLineDeleteDecorationBackground(get, never):IModelDecorationOptions;
    static function get_diffLineDeleteDecorationBackground():IModelDecorationOptions {
        if (_diffLineDeleteDecorationBackground == null) {
            _diffLineDeleteDecorationBackground = ModelDecorationOptions.register({
                className: 'line-delete',
                description: 'line-delete',
                isWholeLine: true,
                marginClassName: 'gutter-delete',
            });
        }
        return cast _diffLineDeleteDecorationBackground;
    }

    static var _diffAddDecoration:Null<ModelDecorationOptions> = null;
    public static var diffAddDecoration(get, never):IModelDecorationOptions;
    static function get_diffAddDecoration():IModelDecorationOptions {
        if (_diffAddDecoration == null) {
            _diffAddDecoration = ModelDecorationOptions.register({
                className: 'char-insert',
                description: 'char-insert',
                shouldFillLineOnLineBreak: true,
            });
        }
        return cast _diffAddDecoration;
    }

    static var _diffWholeLineAddDecoration:Null<ModelDecorationOptions> = null;
    public static var diffWholeLineAddDecoration(get, never):IModelDecorationOptions;
    static function get_diffWholeLineAddDecoration():IModelDecorationOptions {
        if (_diffWholeLineAddDecoration == null) {
            _diffWholeLineAddDecoration = ModelDecorationOptions.register({
                className: 'char-insert',
                description: 'char-insert',
                isWholeLine: true,
            });
        }
        return cast _diffWholeLineAddDecoration;
    }

    static var _diffAddDecorationEmpty:Null<ModelDecorationOptions> = null;
    public static var diffAddDecorationEmpty(get, never):IModelDecorationOptions;
    static function get_diffAddDecorationEmpty():IModelDecorationOptions {
        if (_diffAddDecorationEmpty == null) {
            _diffAddDecorationEmpty = ModelDecorationOptions.register({
                className: 'char-insert diff-range-empty',
                description: 'char-insert diff-range-empty',
            });
        }
        return cast _diffAddDecorationEmpty;
    }

    static var _diffDeleteDecoration:Null<ModelDecorationOptions> = null;
    public static var diffDeleteDecoration(get, never):IModelDecorationOptions;
    static function get_diffDeleteDecoration():IModelDecorationOptions {
        if (_diffDeleteDecoration == null) {
            _diffDeleteDecoration = ModelDecorationOptions.register({
                className: 'char-delete',
                description: 'char-delete',
                shouldFillLineOnLineBreak: true,
            });
        }
        return cast _diffDeleteDecoration;
    }

    static var _diffWholeLineDeleteDecoration:Null<ModelDecorationOptions> = null;
    public static var diffWholeLineDeleteDecoration(get, never):IModelDecorationOptions;
    static function get_diffWholeLineDeleteDecoration():IModelDecorationOptions {
        if (_diffWholeLineDeleteDecoration == null) {
            _diffWholeLineDeleteDecoration = ModelDecorationOptions.register({
                className: 'char-delete',
                description: 'char-delete',
                isWholeLine: true,
            });
        }
        return cast _diffWholeLineDeleteDecoration;
    }

    static var _diffDeleteDecorationEmpty:Null<ModelDecorationOptions> = null;
    public static var diffDeleteDecorationEmpty(get, never):IModelDecorationOptions;
    static function get_diffDeleteDecorationEmpty():IModelDecorationOptions {
        if (_diffDeleteDecorationEmpty == null) {
            _diffDeleteDecorationEmpty = ModelDecorationOptions.register({
                className: 'char-delete diff-range-empty',
                description: 'char-delete diff-range-empty',
            });
        }
        return cast _diffDeleteDecorationEmpty;
    }

}

/**
 * The look of the diff editor's class names (style.css), registered as
 * decoration styles of the context unless the host registered its own
 * (like the find decorations). The gutter colors fall back to the line
 * colors when the theme has none, like the CSS variables of style.css:
 * `update` registers them again for the current theme.
 */
class DiffEditorStyles {

    static final OWN_STYLES = ['line-insert', 'char-insert', 'line-delete', 'char-delete', 'gutter-insert', 'gutter-delete', 'diff-unchanged-lines'];

    public static function update(context:Cityscape, theme:Null<cityscape.view.ViewTheme>, registered:Map<String, Bool>):Void {
        final styles = context.decorationStyles;
        function register(className:String, style:cityscape.common.DecorationStyle.IDecorationStyle):Void {
            // A host style of the same class name wins
            if (styles.get(className) != null && !registered.exists(className)) {
                return;
            }
            context.registerDecorationStyle(className, style);
            registered.set(className, true);
        }
        function hasColor(id:String):Bool {
            return theme != null && theme.getColor(id) != null;
        }
        function border(id:String):Null<cityscape.common.DecorationStyle.IDecorationBorder> {
            return hasColor(id) ? {color: {id: id}, width: 1} : null;
        }
        register('line-insert', {background: {id: hasColor('diffEditor.insertedLineBackground') ? 'diffEditor.insertedLineBackground' : 'diffEditor.insertedTextBackground'}, border: border('diffEditor.insertedTextBorder'), join: false});
        register('char-insert', {background: {id: 'diffEditor.insertedTextBackground'}, border: border('diffEditor.insertedTextBorder'), join: false});
        register('line-delete', {background: {id: hasColor('diffEditor.removedLineBackground') ? 'diffEditor.removedLineBackground' : 'diffEditor.removedTextBackground'}, border: border('diffEditor.removedTextBorder'), join: false});
        register('char-delete', {background: {id: 'diffEditor.removedTextBackground'}, border: border('diffEditor.removedTextBorder'), join: false});
        register('gutter-insert', {background: {id: hasColor('diffEditorGutter.insertedLineBackground') ? 'diffEditorGutter.insertedLineBackground' : (hasColor('diffEditor.insertedLineBackground') ? 'diffEditor.insertedLineBackground' : 'diffEditor.insertedTextBackground')}});
        register('gutter-delete', {background: {id: hasColor('diffEditorGutter.removedLineBackground') ? 'diffEditorGutter.removedLineBackground' : (hasColor('diffEditor.removedLineBackground') ? 'diffEditor.removedLineBackground' : 'diffEditor.removedTextBackground')}});
        register('diff-unchanged-lines', {background: {id: 'diffEditor.unchangedCodeBackground'}});
    }

}

/**
 * Monaco's `DiffEditorDecorations`: the decorations of the changes in the
 * two editors, set again when the diff or the options change (`update`).
 */
class DiffEditorDecorations {

    final _original:CodeEditorWidget;
    final _modified:CodeEditorWidget;
    final _originalDecorations:IEditorDecorationsCollection;
    final _modifiedDecorations:IEditorDecorationsCollection;

    public function new(original:CodeEditorWidget, modified:CodeEditorWidget) {
        this._original = original;
        this._modified = modified;
        this._originalDecorations = original.createDecorationsCollection();
        this._modifiedDecorations = modified.createDecorationsCollection();
    }

    public function dispose():Void {
        this._originalDecorations.clear();
        this._modifiedDecorations.clear();
    }

    public function update(diffModel:Null<DiffEditorViewModel>, options:DiffEditorOptions):Void {
        final decorations = computeDecorations(diffModel, options);
        this._originalDecorations.set(decorations != null ? decorations.originalDecorations : []);
        this._modifiedDecorations.set(decorations != null ? decorations.modifiedDecorations : []);
    }

    /**
     * Monaco's `_decorations` derived value.
     */
    public static function computeDecorations(diffModel:Null<DiffEditorViewModel>, options:DiffEditorOptions):Null<{originalDecorations:Array<IModelDeltaDecoration>, modifiedDecorations:Array<IModelDeltaDecoration>}> {
        final diff = diffModel != null ? diffModel.diff : null;
        if (diff == null) {
            return null;
        }

        final movedTextToCompare = diffModel.movedTextToCompare;
        final renderIndicators = options.renderIndicators;
        final showEmptyDecorations = options.showEmptyDecorations;

        final originalDecorations:Array<IModelDeltaDecoration> = [];
        final modifiedDecorations:Array<IModelDeltaDecoration> = [];
        if (movedTextToCompare == null) {
            for (m in diff.mappings) {
                if (!m.lineRangeMapping.original.isEmpty) {
                    originalDecorations.push({range: m.lineRangeMapping.original.toInclusiveRange(), options: renderIndicators ? DiffDecorationOptions.diffLineDeleteDecorationBackgroundWithIndicator : DiffDecorationOptions.diffLineDeleteDecorationBackground});
                }
                if (!m.lineRangeMapping.modified.isEmpty) {
                    modifiedDecorations.push({range: m.lineRangeMapping.modified.toInclusiveRange(), options: renderIndicators ? DiffDecorationOptions.diffLineAddDecorationBackgroundWithIndicator : DiffDecorationOptions.diffLineAddDecorationBackground});
                }

                if (m.lineRangeMapping.modified.isEmpty || m.lineRangeMapping.original.isEmpty) {
                    if (!m.lineRangeMapping.original.isEmpty) {
                        originalDecorations.push({range: m.lineRangeMapping.original.toInclusiveRange(), options: DiffDecorationOptions.diffWholeLineDeleteDecoration});
                    }
                    if (!m.lineRangeMapping.modified.isEmpty) {
                        modifiedDecorations.push({range: m.lineRangeMapping.modified.toInclusiveRange(), options: DiffDecorationOptions.diffWholeLineAddDecoration});
                    }
                }
                else {
                    final useInlineDiff = options.useTrueInlineDiffRendering && DiffEditorViewZones.allowsTrueInlineDiffRendering(m.lineRangeMapping);
                    final innerChanges = m.lineRangeMapping.innerChanges != null ? m.lineRangeMapping.innerChanges : [];
                    for (i in innerChanges) {
                        // Don't show empty markers outside the line range
                        if (m.lineRangeMapping.original.contains(i.originalRange.startLineNumber)) {
                            originalDecorations.push({range: i.originalRange, options: (i.originalRange.isEmpty() && showEmptyDecorations) ? DiffDecorationOptions.diffDeleteDecorationEmpty : DiffDecorationOptions.diffDeleteDecoration});
                        }
                        if (m.lineRangeMapping.modified.contains(i.modifiedRange.startLineNumber)) {
                            modifiedDecorations.push({range: i.modifiedRange, options: (i.modifiedRange.isEmpty() && showEmptyDecorations && !useInlineDiff) ? DiffDecorationOptions.diffAddDecorationEmpty : DiffDecorationOptions.diffAddDecoration});
                        }
                        if (useInlineDiff) {
                            final deletedText = diffModel.model.original.getValueInRange(i.originalRange);
                            modifiedDecorations.push({
                                range: i.modifiedRange,
                                options: {
                                    description: 'deleted-text',
                                    before: {
                                        content: deletedText,
                                        inlineClassName: 'inline-deleted-text',
                                    },
                                    zIndex: 100000,
                                    showIfCollapsed: true,
                                }
                            });
                        }
                    }
                }
            }
        }

        if (movedTextToCompare != null) {
            for (m in movedTextToCompare.changes) {
                final fullRangeOriginal = m.original.toInclusiveRange();
                if (fullRangeOriginal != null) {
                    originalDecorations.push({range: fullRangeOriginal, options: renderIndicators ? DiffDecorationOptions.diffLineDeleteDecorationBackgroundWithIndicator : DiffDecorationOptions.diffLineDeleteDecorationBackground});
                }
                final fullRangeModified = m.modified.toInclusiveRange();
                if (fullRangeModified != null) {
                    modifiedDecorations.push({range: fullRangeModified, options: renderIndicators ? DiffDecorationOptions.diffLineAddDecorationBackgroundWithIndicator : DiffDecorationOptions.diffLineAddDecorationBackground});
                }

                if (m.innerChanges != null) {
                    for (i in m.innerChanges) {
                        originalDecorations.push({range: i.originalRange, options: DiffDecorationOptions.diffDeleteDecoration});
                        modifiedDecorations.push({range: i.modifiedRange, options: DiffDecorationOptions.diffAddDecoration});
                    }
                }
            }
        }
        final activeMovedText = diffModel.activeMovedText;

        for (m in diff.movedTexts) {
            originalDecorations.push({
                range: m.lineRangeMapping.original.toInclusiveRange(), options: {
                    description: 'moved',
                    blockClassName: 'movedOriginal' + (m == activeMovedText ? ' currentMove' : ''),
                    blockPadding: [MovedBlocksLinesFeature.movedCodeBlockPadding, 0, MovedBlocksLinesFeature.movedCodeBlockPadding, MovedBlocksLinesFeature.movedCodeBlockPadding],
                }
            });

            modifiedDecorations.push({
                range: m.lineRangeMapping.modified.toInclusiveRange(), options: {
                    description: 'moved',
                    blockClassName: 'movedModified' + (m == activeMovedText ? ' currentMove' : ''),
                    blockPadding: [4, 0, 4, 4],
                }
            });
        }

        return {originalDecorations: originalDecorations, modifiedDecorations: modifiedDecorations};
    }

}

/**
 * The constants of Monaco's `MovedBlocksLinesFeature` (the lines between
 * the moved blocks are not drawn yet).
 */
class MovedBlocksLinesFeature {
    public static inline final movedCodeBlockPadding = 4;
}
