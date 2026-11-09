// Ported from vscode src/vs/editor/contrib/snippet/browser/snippetSession.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.snippet.view;

import cityscape.base.common.CharCode;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.snippet.view.SnippetVariables;
import cityscape.contrib.suggest.view.SuggestOvertypingCapturer;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * The active choice of a snippet and its range.
 */
typedef ActiveChoice = {
    final choice:Choice;
    final range:Range;
}

/**
 * One inserted snippet (one per cursor) and the decorations tracking its
 * placeholders (Monaco's `OneSnippet`).
 */
class OneSnippet {

    var _placeholderDecorations:Null<Map<Placeholder, String>> = null;
    /** The placeholders of `_placeholderDecorations`, in insertion order (a JavaScript `Map` keeps it). */
    var _decoratedPlaceholders:Array<Placeholder> = [];
    var _placeholderGroups:Array<Array<Placeholder>>;
    var _offset:Int = -1;
    @:allow(cityscape.contrib.snippet.view)
    var _placeholderGroupsIdx:Int;
    @:allow(cityscape.contrib.snippet.view)
    var _nestingLevel:Float = 1;

    static var _decorActive:Null<ModelDecorationOptions> = null;
    static var _decorInactive:Null<ModelDecorationOptions> = null;
    static var _decorActiveFinal:Null<ModelDecorationOptions> = null;
    static var _decorInactiveFinal:Null<ModelDecorationOptions> = null;

    static function initDecor():Void {
        if (_decorActive == null) {
            _decorActive = ModelDecorationOptions.register({description: 'snippet-placeholder-1', stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, className: 'snippet-placeholder'});
            _decorInactive = ModelDecorationOptions.register({description: 'snippet-placeholder-2', stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'snippet-placeholder'});
            _decorActiveFinal = ModelDecorationOptions.register({description: 'snippet-placeholder-3', stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'finish-snippet-placeholder'});
            _decorInactiveFinal = ModelDecorationOptions.register({description: 'snippet-placeholder-4', stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'finish-snippet-placeholder'});
        }
    }

    final _editor:ICodeEditor;
    final _snippet:TextmateSnippet;
    final _snippetLineLeadingWhitespace:String;

    public function new(editor:ICodeEditor, snippet:TextmateSnippet, snippetLineLeadingWhitespace:String) {
        initDecor();
        this._editor = editor;
        this._snippet = snippet;
        this._snippetLineLeadingWhitespace = snippetLineLeadingWhitespace;
        this._placeholderGroups = SnippetSession.groupBy(snippet.placeholders, Placeholder.compareByIndex);
        this._placeholderGroupsIdx = -1;
    }

    public function initialize(textChange:TextChange):Void {
        this._offset = textChange.newPosition;
    }

    public function dispose():Void {
        if (this._placeholderDecorations != null) {
            this._editor.removeDecorations([for (p in _decoratedPlaceholders) this._placeholderDecorations.get(p)]);
        }
        this._placeholderGroups = [];
    }

    function _setDecoration(placeholder:Placeholder, id:String):Void {
        if (!this._placeholderDecorations.exists(placeholder)) {
            _decoratedPlaceholders.push(placeholder);
        }
        this._placeholderDecorations.set(placeholder, id);
    }

    function _deleteDecoration(placeholder:Placeholder):Void {
        this._placeholderDecorations.remove(placeholder);
        _decoratedPlaceholders.remove(placeholder);
    }

    function _initDecorations():Void {

        if (this._offset == -1) {
            throw 'Snippet not initialized!';
        }

        if (this._placeholderDecorations != null) {
            // already initialized
            return;
        }

        this._placeholderDecorations = new Map<Placeholder, String>();
        final model = this._editor.getModel();

        this._editor.changeDecorations(accessor -> {
            // create a decoration for each placeholder
            for (placeholder in this._snippet.placeholders) {
                final placeholderOffset = this._snippet.offset(placeholder);
                final placeholderLen = this._snippet.fullLen(placeholder);
                final range = Range.fromPositions(
                    model.getPositionAt(this._offset + placeholderOffset),
                    model.getPositionAt(this._offset + placeholderOffset + placeholderLen)
                );
                final options = placeholder.isFinalTabstop ? _decorInactiveFinal : _decorInactive;
                final handle = accessor.addDecoration(range, cast options);
                this._setDecoration(placeholder, handle);
            }
            return null;
        });
    }

    public function move(fwd:Null<Bool>):Array<Selection> {
        if (!this._editor.hasModel()) {
            return [];
        }

        this._initDecorations();

        // Transform placeholder text if necessary
        if (this._placeholderGroupsIdx >= 0) {
            final operations:Array<IIdentifiedSingleEditOperation> = [];

            for (placeholder in this._placeholderGroups[this._placeholderGroupsIdx]) {
                // Check if the placeholder has a transformation
                if (placeholder.transform != null) {
                    final id = this._placeholderDecorations.get(placeholder);
                    final range = this._editor.getModel().getDecorationRange(id);
                    final currentValue = this._editor.getModel().getValueInRange(range);
                    final transformedValueLines = Strings.splitLines(placeholder.transform.resolve(currentValue));
                    // fix indentation for transformed lines
                    for (i in 1...transformedValueLines.length) {
                        transformedValueLines[i] = this._editor.getModel().normalizeIndentation(this._snippetLineLeadingWhitespace + transformedValueLines[i]);
                    }
                    operations.push(EditOperation.replace(range, transformedValueLines.join(this._editor.getModel().getEOL())));
                }
            }
            if (operations.length > 0) {
                this._editor.executeEdits('snippet.placeholderTransform', operations);
            }
        }

        var couldSkipThisPlaceholder = false;
        if (fwd == true && this._placeholderGroupsIdx < this._placeholderGroups.length - 1) {
            this._placeholderGroupsIdx += 1;
            couldSkipThisPlaceholder = true;

        }
        else if (fwd == false && this._placeholderGroupsIdx > 0) {
            this._placeholderGroupsIdx -= 1;
            couldSkipThisPlaceholder = true;

        }
        else {
            // the selection of the current placeholder might
            // not acurate any more -> simply restore it
        }

        final newSelections = this._editor.getModel().changeDecorations(accessor -> {

            final activePlaceholders:Array<Placeholder> = [];

            // change stickiness to always grow when typing at its edges
            // because these decorations represent the currently active
            // tabstop.
            // Special case #1: reaching the final tabstop
            // Special case #2: placeholders enclosing active placeholders
            final selections:Array<Selection> = [];
            for (placeholder in this._placeholderGroups[this._placeholderGroupsIdx]) {
                final id = this._placeholderDecorations.get(placeholder);
                final range = this._editor.getModel().getDecorationRange(id);
                selections.push(new Selection(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn));

                // consider to skip this placeholder index when the decoration
                // range is empty but when the placeholder wasn't. that's a strong
                // hint that the placeholder has been deleted. (all placeholder must match this)
                couldSkipThisPlaceholder = couldSkipThisPlaceholder && this._hasPlaceholderBeenCollapsed(placeholder);

                accessor.changeDecorationOptions(id, cast (placeholder.isFinalTabstop ? _decorActiveFinal : _decorActive));
                if (activePlaceholders.indexOf(placeholder) < 0) {
                    activePlaceholders.push(placeholder);
                }

                for (enclosingPlaceholder in this._snippet.enclosingPlaceholders(placeholder)) {
                    final id = this._placeholderDecorations.get(enclosingPlaceholder);
                    accessor.changeDecorationOptions(id, cast (enclosingPlaceholder.isFinalTabstop ? _decorActiveFinal : _decorActive));
                    if (activePlaceholders.indexOf(enclosingPlaceholder) < 0) {
                        activePlaceholders.push(enclosingPlaceholder);
                    }
                }
            }

            // change stickness to never grow when typing at its edges
            // so that in-active tabstops never grow
            for (placeholder in _decoratedPlaceholders) {
                if (activePlaceholders.indexOf(placeholder) < 0) {
                    accessor.changeDecorationOptions(this._placeholderDecorations.get(placeholder), cast (placeholder.isFinalTabstop ? _decorInactiveFinal : _decorInactive));
                }
            }

            return selections;
        }, null);

        return !couldSkipThisPlaceholder ? (newSelections != null ? newSelections : []) : this.move(fwd);
    }

    function _hasPlaceholderBeenCollapsed(placeholder:Placeholder):Bool {
        // A placeholder is empty when it wasn't empty when authored but
        // when its tracking decoration is empty. This also applies to all
        // potential parent placeholders
        var marker:Null<Marker> = placeholder;
        while (marker != null) {
            if (Std.isOfType(marker, Placeholder)) {
                final id = this._placeholderDecorations.get(cast marker);
                final range = this._editor.getModel().getDecorationRange(id);
                if (range.isEmpty() && marker.toString().length > 0) {
                    return true;
                }
            }
            marker = marker.parent;
        }
        return false;
    }

    public var isAtFirstPlaceholder(get, never):Bool;
    function get_isAtFirstPlaceholder():Bool {
        return this._placeholderGroupsIdx <= 0 || this._placeholderGroups.length == 0;
    }

    public var isAtLastPlaceholder(get, never):Bool;
    function get_isAtLastPlaceholder():Bool {
        return this._placeholderGroupsIdx == this._placeholderGroups.length - 1;
    }

    public var hasPlaceholder(get, never):Bool;
    function get_hasPlaceholder():Bool {
        return this._snippet.placeholders.length > 0;
    }

    /**
     * A snippet is trivial when it has no placeholder or only a final placeholder at
     * its very end
     */
    public var isTrivialSnippet(get, never):Bool;
    function get_isTrivialSnippet():Bool {
        if (this._snippet.placeholders.length == 0) {
            return true;
        }
        if (this._snippet.placeholders.length == 1) {
            final placeholder = this._snippet.placeholders[0];
            if (placeholder.isFinalTabstop) {
                if (this._snippet.rightMostDescendant == placeholder) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * The ranges of the placeholders by index (Monaco's `Map<number,
     * Range[]>`); `indexes` keeps the insertion order of the map.
     */
    public function computePossibleSelections():{indexes:Array<Float>, ranges:Map<String, Array<Range>>} {
        final indexes:Array<Float> = [];
        final result = new Map<String, Array<Range>>();
        for (placeholdersWithEqualIndex in this._placeholderGroups) {
            var ranges:Null<Array<Range>> = null;

            for (placeholder in placeholdersWithEqualIndex) {
                if (placeholder.isFinalTabstop) {
                    // ignore those
                    break;
                }

                final key = SnippetSession.indexKey(placeholder.index);
                if (ranges == null) {
                    ranges = [];
                    result.set(key, ranges);
                    indexes.push(placeholder.index);
                }

                final id = this._placeholderDecorations.get(placeholder);
                final range = this._editor.getModel().getDecorationRange(id);
                if (range == null) {
                    // one of the placeholder lost its decoration and
                    // therefore we bail out and pretend the placeholder
                    // (with its mirrors) doesn't exist anymore.
                    result.remove(key);
                    indexes.remove(placeholder.index);
                    break;
                }

                ranges.push(range);
            }
        }
        return {indexes: indexes, ranges: result};
    }

    public var activeChoice(get, never):Null<ActiveChoice>;
    function get_activeChoice():Null<ActiveChoice> {
        if (this._placeholderDecorations == null) {
            return null;
        }
        if (this._placeholderGroupsIdx < 0 || this._placeholderGroupsIdx >= this._placeholderGroups.length) {
            return null;
        }
        final placeholder = this._placeholderGroups[this._placeholderGroupsIdx][0];
        if (placeholder == null || placeholder.choice == null) {
            return null;
        }
        final id = this._placeholderDecorations.get(placeholder);
        if (id == null) {
            return null;
        }
        final range = this._editor.getModel().getDecorationRange(id);
        if (range == null) {
            return null;
        }
        return {range: range, choice: placeholder.choice};
    }

    public var hasChoice(get, never):Bool;
    function get_hasChoice():Bool {
        var result = false;
        this._snippet.walk(marker -> {
            result = Std.isOfType(marker, Choice);
            return !result;
        });
        return result;
    }

    public function merge(others:Array<OneSnippet>):Void {

        final model = this._editor.getModel();
        this._nestingLevel *= 10;

        this._editor.changeDecorations(accessor -> {

            // For each active placeholder take one snippet and merge it
            // in that the placeholder (can be many for `$1foo$1foo`). Because
            // everything is sorted by editor selection we can simply remove
            // elements from the beginning of the array
            for (placeholder in this._placeholderGroups[this._placeholderGroupsIdx]) {
                final nested = others.shift();

                // Massage placeholder-indicies of the nested snippet to be
                // sorted right after the insertion point. This ensures we move
                // through the placeholders in the correct order
                final indexLastPlaceholder = nested._snippet.placeholderInfo.last.index;

                for (nestedPlaceholder in nested._snippet.placeholderInfo.all) {
                    if (nestedPlaceholder.isFinalTabstop) {
                        nestedPlaceholder.index = placeholder.index + ((indexLastPlaceholder + 1) / this._nestingLevel);
                    }
                    else {
                        nestedPlaceholder.index = placeholder.index + (nestedPlaceholder.index / this._nestingLevel);
                    }
                }
                this._snippet.replace(placeholder, nested._snippet.children);

                // Remove the placeholder at which position are inserting
                // the snippet and also remove its decoration.
                final id = this._placeholderDecorations.get(placeholder);
                accessor.removeDecoration(id);
                this._deleteDecoration(placeholder);

                // For each *new* placeholder we create decoration to monitor
                // how and if it grows/shrinks.
                for (placeholder in nested._snippet.placeholders) {
                    final placeholderOffset = nested._snippet.offset(placeholder);
                    final placeholderLen = nested._snippet.fullLen(placeholder);
                    final range = Range.fromPositions(
                        model.getPositionAt(nested._offset + placeholderOffset),
                        model.getPositionAt(nested._offset + placeholderOffset + placeholderLen)
                    );
                    final handle = accessor.addDecoration(range, cast _decorInactive);
                    this._setDecoration(placeholder, handle);
                }
            }

            // Last, re-create the placeholder groups by sorting placeholders by their index.
            this._placeholderGroups = SnippetSession.groupBy(this._snippet.placeholders, Placeholder.compareByIndex);
            return null;
        });
    }

    public function getEnclosingRange():Null<Range> {
        var result:Null<Range> = null;
        final model = this._editor.getModel();
        for (placeholder in _decoratedPlaceholders) {
            final placeholderRange = model.getDecorationRange(this._placeholderDecorations.get(placeholder));
            if (result == null) {
                result = placeholderRange;
            }
            else {
                result = result.plusRange(placeholderRange);
            }
        }
        return result;
    }

}

typedef ISnippetSessionInsertOptions = {
    var overwriteBefore:Int;
    var overwriteAfter:Int;
    var adjustWhitespace:Bool;
    var clipboardText:Null<String>;
    var overtypingCapturer:Null<OvertypingCapturer>;
}

typedef ISnippetEdit = {
    var range:Range;
    var template:String;
}

/**
 * A snippet inserted at every cursor and the moves between its
 * placeholders (Monaco's `SnippetSession`).
 */
class SnippetSession {

    /**
     * Monaco's `groupBy` (arrays.ts): the items sorted with `compare`, in
     * runs of equal items.
     */
    public static function groupBy<T>(data:Array<T>, compare:(a:T, b:T) -> Int):Array<Array<T>> {
        final result:Array<Array<T>> = [];
        var currentGroup:Null<Array<T>> = null;
        final sorted = data.copy();
        haxe.ds.ArraySort.sort(sorted, compare);
        for (element in sorted) {
            if (currentGroup == null || compare(currentGroup[0], element) != 0) {
                currentGroup = [element];
                result.push(currentGroup);
            }
            else {
                currentGroup.push(element);
            }
        }
        return result;
    }

    /**
     * The key of a placeholder index in a map (Haxe maps have no float keys).
     */
    public static inline function indexKey(index:Float):String {
        return cityscape.base.common.JsValues.numberToString(index);
    }

    static final _defaultOptions:ISnippetSessionInsertOptions = {
        overwriteBefore: 0,
        overwriteAfter: 0,
        adjustWhitespace: true,
        clipboardText: null,
        overtypingCapturer: null
    };

    public static function adjustWhitespace(model:ITextModel, position:IPosition, adjustIndentation:Bool, snippet:TextmateSnippet, ?filter:Array<Marker>):String {
        final line = model.getLineContent(position.lineNumber);
        final lineLeadingWhitespace = Strings.getLeadingWhitespace(line, 0, position.column - 1);

        // the snippet as inserted
        var snippetTextString:Null<String> = null;

        snippet.walk(marker -> {
            // all text elements that are not inside choice
            if (!Std.isOfType(marker, Text) || Std.isOfType(marker.parent, Choice)) {
                return true;
            }

            // check with filter (iff provided)
            if (filter != null && filter.indexOf(marker) < 0) {
                return true;
            }

            final text:Text = cast marker;
            final lines = Strings.splitLines(text.value);

            if (adjustIndentation) {
                // adjust indentation of snippet test
                // -the snippet-start doesn't get extra-indented (lineLeadingWhitespace), only normalized
                // -all N+1 lines get extra-indented and normalized
                // -the text start get extra-indented and normalized when following a linebreak
                final offset = snippet.offset(marker);
                if (offset == 0) {
                    // snippet start
                    lines[0] = model.normalizeIndentation(lines[0]);

                }
                else {
                    // check if text start is after a linebreak
                    if (snippetTextString == null) {
                        snippetTextString = snippet.toString();
                    }
                    final prevChar = StringTools.fastCodeAt(snippetTextString, offset - 1);
                    if (prevChar == CharCode.LineFeed || prevChar == CharCode.CarriageReturn) {
                        lines[0] = model.normalizeIndentation(lineLeadingWhitespace + lines[0]);
                    }
                }
                for (i in 1...lines.length) {
                    lines[i] = model.normalizeIndentation(lineLeadingWhitespace + lines[i]);
                }
            }

            final newValue = lines.join(model.getEOL());
            if (newValue != text.value) {
                marker.parent.replace(marker, [new Text(newValue)]);
                snippetTextString = null;
            }
            return true;
        });

        return lineLeadingWhitespace;
    }

    public static function adjustSelection(model:ITextModel, selection:Selection, overwriteBefore:Int, overwriteAfter:Int):Selection {
        if (overwriteBefore != 0 || overwriteAfter != 0) {
            // overwrite[Before|After] is compute using the position, not the whole
            // selection. therefore we adjust the selection around that position
            final positionLineNumber = selection.positionLineNumber;
            final positionColumn = selection.positionColumn;
            final positionColumnBefore = positionColumn - overwriteBefore;
            final positionColumnAfter = positionColumn + overwriteAfter;

            final range = model.validateRange({
                startLineNumber: positionLineNumber,
                startColumn: positionColumnBefore,
                endLineNumber: positionLineNumber,
                endColumn: positionColumnAfter
            });

            selection = Selection.createWithDirection(
                range.startLineNumber, range.startColumn,
                range.endLineNumber, range.endColumn,
                selection.getDirection()
            );
        }
        return selection;
    }

    static function variableResolver(editor:ICodeEditor, model:ITextModel, selection:Selection, idx:Int, selectionCount:Int, clipboardText:Null<String>, overtypingCapturer:Null<OvertypingCapturer>, languageConfigurationService:ILanguageConfigurationService):VariableResolver {
        return new CompositeSnippetVariableResolver([
            new ModelBasedVariableResolver(model),
            new ClipboardBasedVariableResolver(() -> clipboardText, idx, selectionCount, editor.getOption(EditorOption.multiCursorPaste) == 'spread'),
            new SelectionBasedVariableResolver(model, selection, idx, overtypingCapturer),
            new CommentBasedVariableResolver(model, selection, languageConfigurationService),
            new TimeBasedVariableResolver(),
            new RandomBasedVariableResolver(),
        ]);
    }

    public static function createEditsAndSnippetsFromSelections(editor:ICodeEditor, template:String, overwriteBefore:Int, overwriteAfter:Int, enforceFinalTabstop:Bool, adjustWhitespace:Bool, clipboardText:Null<String>, overtypingCapturer:Null<OvertypingCapturer>, languageConfigurationService:ILanguageConfigurationService):{edits:Array<IIdentifiedSingleEditOperation>, snippets:Array<OneSnippet>} {
        final edits:Array<IIdentifiedSingleEditOperation> = [];
        final snippets:Array<OneSnippet> = [];

        if (!editor.hasModel()) {
            return {edits: edits, snippets: snippets};
        }
        final model = editor.getModel();

        // know what text the overwrite[Before|After] extensions
        // of the primary curser have selected because only when
        // secondary selections extend to the same text we can grow them
        final firstBeforeText = model.getValueInRange(SnippetSession.adjustSelection(model, editor.getSelection(), overwriteBefore, 0));
        final firstAfterText = model.getValueInRange(SnippetSession.adjustSelection(model, editor.getSelection(), 0, overwriteAfter));

        // remember the first non-whitespace column to decide if
        // `keepWhitespace` should be overruled for secondary selections
        final firstLineFirstNonWhitespace = model.getLineFirstNonWhitespaceColumn(editor.getSelection().positionLineNumber);

        // sort selections by their start position but remeber
        // the original index. that allows you to create correct
        // offset-based selection logic without changing the
        // primary selection
        final selections = editor.getSelections();
        final indexedSelections = [for (idx in 0...selections.length) {selection: selections[idx], idx: idx}];
        haxe.ds.ArraySort.sort(indexedSelections, (a, b) -> Range.compareRangesUsingStarts(a.selection, b.selection));

        for (entry in indexedSelections) {
            final selection = entry.selection;
            final idx = entry.idx;

            // extend selection with the `overwriteBefore` and `overwriteAfter` and then
            // compare if this matches the extensions of the primary selection
            var extensionBefore = SnippetSession.adjustSelection(model, selection, overwriteBefore, 0);
            var extensionAfter = SnippetSession.adjustSelection(model, selection, 0, overwriteAfter);
            if (firstBeforeText != model.getValueInRange(extensionBefore)) {
                extensionBefore = selection;
            }
            if (firstAfterText != model.getValueInRange(extensionAfter)) {
                extensionAfter = selection;
            }

            // merge the before and after selection into one
            final snippetSelection = selection
                .setStartPosition(extensionBefore.startLineNumber, extensionBefore.startColumn)
                .setEndPosition(extensionAfter.endLineNumber, extensionAfter.endColumn);

            final snippet = new SnippetParser().parse(template, true, enforceFinalTabstop);

            // adjust the template string to match the indentation and
            // whitespace rules of this insert location (can be different for each cursor)
            // happens when being asked for (default) or when this is a secondary
            // cursor and the leading whitespace is different
            final start = snippetSelection.getStartPosition();
            final snippetLineLeadingWhitespace = SnippetSession.adjustWhitespace(
                model, start,
                adjustWhitespace || (idx > 0 && firstLineFirstNonWhitespace != model.getLineFirstNonWhitespaceColumn(selection.positionLineNumber)),
                snippet
            );

            snippet.resolveVariables(variableResolver(editor, model, selection, idx, indexedSelections.length, clipboardText, overtypingCapturer, languageConfigurationService));

            // store snippets with the index of their originating selection.
            // that ensures the primiary cursor stays primary despite not being
            // the one with lowest start position
            final edit = EditOperation.replace(snippetSelection, snippet.toString());
            edit.identifier = {major: idx, minor: 0}; // mark the edit so only our undo edits will be used to generate end cursors
            edit._isTracked = true;
            edits[idx] = edit;
            snippets[idx] = new OneSnippet(editor, snippet, snippetLineLeadingWhitespace);
        }

        return {edits: edits, snippets: snippets};
    }

    public static function createEditsAndSnippetsFromEdits(editor:ICodeEditor, snippetEdits:Array<ISnippetEdit>, enforceFinalTabstop:Bool, adjustWhitespace:Bool, clipboardText:Null<String>, overtypingCapturer:Null<OvertypingCapturer>, languageConfigurationService:ILanguageConfigurationService):{edits:Array<IIdentifiedSingleEditOperation>, snippets:Array<OneSnippet>} {

        if (!editor.hasModel() || snippetEdits.length == 0) {
            return {edits: [], snippets: []};
        }

        final edits:Array<IIdentifiedSingleEditOperation> = [];
        final model = editor.getModel();

        final parser = new SnippetParser();
        final snippet = new TextmateSnippet();

        // snippet variables resolver
        final resolver = variableResolver(editor, model, editor.getSelection(), 0, editor.getSelections().length, clipboardText, overtypingCapturer, languageConfigurationService);

        //
        snippetEdits = snippetEdits.copy();
        haxe.ds.ArraySort.sort(snippetEdits, (a, b) -> Range.compareRangesUsingStarts(a.range, b.range));
        var offset = 0;
        for (i in 0...snippetEdits.length) {

            final range = snippetEdits[i].range;
            final template = snippetEdits[i].template;

            // gaps between snippet edits are appended as text nodes. this
            // ensures placeholder-offsets are later correct
            if (i > 0) {
                final lastRange = snippetEdits[i - 1].range;
                final textRange = Range.fromPositions(lastRange.getEndPosition(), range.getStartPosition());
                final textNode = new Text(model.getValueInRange(textRange));
                snippet.appendChild(textNode);
                offset += textNode.value.length;
            }

            final newNodes = parser.parseFragment(template, snippet);
            SnippetSession.adjustWhitespace(model, range.getStartPosition(), true, snippet, newNodes);
            snippet.resolveVariables(resolver);

            final snippetText = snippet.toString();
            final snippetFragmentText = snippetText.substr(offset);
            offset = snippetText.length;

            // make edit
            final edit = EditOperation.replace(range, snippetFragmentText);
            edit.identifier = {major: i, minor: 0}; // mark the edit so only our undo edits will be used to generate end cursors
            edit._isTracked = true;
            edits.push(edit);
        }

        //
        parser.ensureFinalTabstop(snippet, enforceFinalTabstop, true);

        return {
            edits: edits,
            snippets: [new OneSnippet(editor, snippet, '')]
        };
    }

    final _templateMerges:Array<String> = [];
    var _snippets:Array<OneSnippet> = [];

    final _editor:ICodeEditor;
    final _template:Null<String>;
    final _templateEdits:Null<Array<ISnippetEdit>>;
    final _options:ISnippetSessionInsertOptions;
    final _languageConfigurationService:ILanguageConfigurationService;

    /**
     * `template` is a snippet string or an array of `ISnippetEdit`s.
     */
    public function new(editor:ICodeEditor, template:haxe.extern.EitherType<String, Array<ISnippetEdit>>, ?options:ISnippetSessionInsertOptions, ?languageConfigurationService:ILanguageConfigurationService) {
        this._editor = editor;
        if (cityscape.base.common.JsValues.isString(template)) {
            this._template = cast template;
            this._templateEdits = null;
        }
        else {
            this._template = null;
            this._templateEdits = cast template;
        }
        this._options = options != null ? options : _defaultOptions;
        this._languageConfigurationService = languageConfigurationService != null ? languageConfigurationService : editor.context.languageConfigurationService;
    }

    public function dispose():Void {
        for (s in this._snippets) {
            s.dispose();
        }
    }

    public function _logInfo():String {
        return 'template="' + this._template + '", merged_templates="' + this._templateMerges.join(' -> ') + '"';
    }

    public function insert():Void {
        if (!this._editor.hasModel()) {
            return;
        }

        // make insert edit and start with first selections
        final result = this._template != null
            ? SnippetSession.createEditsAndSnippetsFromSelections(this._editor, this._template, this._options.overwriteBefore, this._options.overwriteAfter, false, this._options.adjustWhitespace, this._options.clipboardText, this._options.overtypingCapturer, this._languageConfigurationService)
            : SnippetSession.createEditsAndSnippetsFromEdits(this._editor, this._templateEdits, false, this._options.adjustWhitespace, this._options.clipboardText, this._options.overtypingCapturer, this._languageConfigurationService);
        final edits = result.edits;
        final snippets = result.snippets;

        this._snippets = snippets;

        final computer:ICursorStateComputer = _undoEdits -> {
            // Sometimes, the text buffer will remove automatic whitespace when doing any edits,
            // so we need to look only at the undo edits relevant for us.
            // Our edits have an identifier set so that's how we can distinguish them
            final undoEdits = [for (edit in _undoEdits) if (edit.identifier != null) edit];
            for (idx in 0...snippets.length) {
                snippets[idx].initialize(undoEdits[idx].textChange);
            }

            if (this._snippets[0].hasPlaceholder) {
                return this._move(true);
            }
            else {
                return [for (edit in undoEdits) Selection.fromPositions(edit.range.getEndPosition())];
            }
        };
        this._editor.executeEdits('snippet', edits, computer);
        this._editor.revealRange(this._editor.getSelections()[0]);
    }

    public function merge(template:String, ?options:ISnippetSessionInsertOptions):Void {
        if (!this._editor.hasModel()) {
            return;
        }
        if (options == null) {
            options = _defaultOptions;
        }
        this._templateMerges.push(this._snippets[0]._nestingLevel + ',' + this._snippets[0]._placeholderGroupsIdx + ',' + template);
        final result = SnippetSession.createEditsAndSnippetsFromSelections(this._editor, template, options.overwriteBefore, options.overwriteAfter, true, options.adjustWhitespace, options.clipboardText, options.overtypingCapturer, this._languageConfigurationService);
        final edits = result.edits;
        final snippets = result.snippets;

        final computer:ICursorStateComputer = _undoEdits -> {
            // Sometimes, the text buffer will remove automatic whitespace when doing any edits,
            // so we need to look only at the undo edits relevant for us.
            // Our edits have an identifier set so that's how we can distinguish them
            final undoEdits = [for (edit in _undoEdits) if (edit.identifier != null) edit];
            for (idx in 0...snippets.length) {
                snippets[idx].initialize(undoEdits[idx].textChange);
            }

            // Trivial snippets have no placeholder or are just the final placeholder. That means they
            // are just text insertions and we don't need to merge the nested snippet into the existing
            // snippet
            final isTrivialSnippet = snippets[0].isTrivialSnippet;
            if (!isTrivialSnippet) {
                for (snippet in this._snippets) {
                    snippet.merge(snippets);
                }
            }

            if (this._snippets[0].hasPlaceholder && !isTrivialSnippet) {
                return this._move(null);
            }
            else {
                return [for (edit in undoEdits) Selection.fromPositions(edit.range.getEndPosition())];
            }
        };
        this._editor.executeEdits('snippet', edits, computer);
    }

    public function next():Void {
        final newSelections = this._move(true);
        this._editor.setSelections(cast newSelections);
        this._editor.revealPositionInCenterIfOutsideViewport(newSelections[0].getPosition());
    }

    public function prev():Void {
        final newSelections = this._move(false);
        this._editor.setSelections(cast newSelections);
        this._editor.revealPositionInCenterIfOutsideViewport(newSelections[0].getPosition());
    }

    function _move(fwd:Null<Bool>):Array<Selection> {
        final selections:Array<Selection> = [];
        for (snippet in this._snippets) {
            final oneSelection = snippet.move(fwd);
            for (s in oneSelection) {
                selections.push(s);
            }
        }
        return selections;
    }

    public var isAtFirstPlaceholder(get, never):Bool;
    function get_isAtFirstPlaceholder():Bool {
        return this._snippets[0].isAtFirstPlaceholder;
    }

    public var isAtLastPlaceholder(get, never):Bool;
    function get_isAtLastPlaceholder():Bool {
        return this._snippets[0].isAtLastPlaceholder;
    }

    public var hasPlaceholder(get, never):Bool;
    function get_hasPlaceholder():Bool {
        return this._snippets[0].hasPlaceholder;
    }

    public var hasChoice(get, never):Bool;
    function get_hasChoice():Bool {
        return this._snippets[0].hasChoice;
    }

    public var activeChoice(get, never):Null<ActiveChoice>;
    function get_activeChoice():Null<ActiveChoice> {
        return this._snippets[0].activeChoice;
    }

    public function isSelectionWithinPlaceholders():Bool {

        if (!this.hasPlaceholder) {
            return false;
        }

        final selections = this._editor.getSelections();
        if (selections.length < this._snippets.length) {
            // this means we started snippet mode with N
            // selections and have M (N > M) selections.
            // So one snippet is without selection -> cancel
            return false;
        }

        final allIndexes:Array<String> = [];
        final allPossibleSelections = new Map<String, Array<Range>>();
        for (snippet in this._snippets) {

            final possibleSelections = snippet.computePossibleSelections();

            // for the first snippet find the placeholder (and its ranges)
            // that contain at least one selection. for all remaining snippets
            // the same placeholder (and their ranges) must be used.
            if (allIndexes.length == 0) {
                for (index in possibleSelections.indexes) {
                    final key = indexKey(index);
                    final ranges = possibleSelections.ranges.get(key);
                    haxe.ds.ArraySort.sort(ranges, Range.compareRangesUsingStarts);
                    for (selection in selections) {
                        if (ranges[0].containsRange(selection)) {
                            allPossibleSelections.set(key, []);
                            allIndexes.push(key);
                            break;
                        }
                    }
                }
            }

            if (allIndexes.length == 0) {
                // return false if we couldn't associate a selection to
                // this (the first) snippet
                return false;
            }

            // add selections from 'this' snippet so that we know all
            // selections for this placeholder
            for (key in allIndexes) {
                final array = allPossibleSelections.get(key);
                final more = possibleSelections.ranges.get(key);
                if (more != null) {
                    for (r in more) {
                        array.push(r);
                    }
                }
            }
        }

        // sort selections (and later placeholder-ranges). then walk both
        // arrays and make sure the placeholder-ranges contain the corresponding
        // selection
        final sortedSelections = selections.copy();
        haxe.ds.ArraySort.sort(sortedSelections, Range.compareRangesUsingStarts);

        for (key in allIndexes.copy()) {
            final ranges = allPossibleSelections.get(key);
            if (ranges.length != sortedSelections.length) {
                allIndexes.remove(key);
                continue;
            }

            haxe.ds.ArraySort.sort(ranges, Range.compareRangesUsingStarts);

            for (i in 0...ranges.length) {
                if (!ranges[i].containsRange(sortedSelections[i])) {
                    allIndexes.remove(key);
                    continue;
                }
            }
        }

        // from all possible selections we have deleted those
        // that don't match with the current selection. if we don't
        // have any left, we don't have a selection anymore
        return allIndexes.length > 0;
    }

    public function getEnclosingRange():Null<Range> {
        var result:Null<Range> = null;
        for (snippet in this._snippets) {
            final snippetRange = snippet.getEnclosingRange();
            if (result == null) {
                result = snippetRange;
            }
            else {
                result = result.plusRange(snippetRange);
            }
        }
        return result;
    }

}
