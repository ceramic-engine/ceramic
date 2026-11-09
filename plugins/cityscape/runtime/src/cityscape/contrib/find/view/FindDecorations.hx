// Ported from vscode src/vs/editor/contrib/find/browser/findDecorations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.platform.theme.common.ThemeService;

/**
 * The decorations of the find matches of an editor: every match, the
 * current one, the line of the current match (range highlight), the find
 * scopes and the overview ruler marks (approximate above 1000 matches).
 */
class FindDecorations implements IDisposable {

    final _editor:ICodeEditor;
    var _decorations:Array<String>;
    var _overviewRulerApproximateDecorations:Array<String>;
    var _findScopeDecorationIds:Array<String>;
    var _rangeHighlightDecorationId:Null<String>;
    var _highlightedDecorationId:Null<String>;
    var _startPosition:Position;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._decorations = [];
        this._overviewRulerApproximateDecorations = [];
        this._findScopeDecorationIds = [];
        this._rangeHighlightDecorationId = null;
        this._highlightedDecorationId = null;
        this._startPosition = this._editor.getPosition();
    }

    public function dispose():Void {
        this._editor.removeDecorations(this._allDecorations());

        this._decorations = [];
        this._overviewRulerApproximateDecorations = [];
        this._findScopeDecorationIds = [];
        this._rangeHighlightDecorationId = null;
        this._highlightedDecorationId = null;
    }

    public function reset():Void {
        this._decorations = [];
        this._overviewRulerApproximateDecorations = [];
        this._findScopeDecorationIds = [];
        this._rangeHighlightDecorationId = null;
        this._highlightedDecorationId = null;
    }

    public function getCount():Int {
        return this._decorations.length;
    }

    /** @deprecated use getFindScopes to support multiple selections */
    public function getFindScope():Null<Range> {
        if (this._findScopeDecorationIds.length > 0 && this._findScopeDecorationIds[0] != null) {
            return this._editor.getModel().getDecorationRange(this._findScopeDecorationIds[0]);
        }
        return null;
    }

    public function getFindScopes():Null<Array<Range>> {
        if (this._findScopeDecorationIds.length > 0) {
            final scopes:Array<Range> = [];
            for (findScopeDecorationId in this._findScopeDecorationIds) {
                final range = this._editor.getModel().getDecorationRange(findScopeDecorationId);
                if (range != null) {
                    scopes.push(range);
                }
            }
            if (scopes.length > 0) {
                return scopes;
            }
        }
        return null;
    }

    public function getStartPosition():Position {
        return this._startPosition;
    }

    public function setStartPosition(newStartPosition:Position):Void {
        this._startPosition = newStartPosition;
        this.setCurrentFindMatch(null);
    }

    function _getDecorationIndex(decorationId:String):Int {
        final index = this._decorations.indexOf(decorationId);
        if (index >= 0) {
            return index + 1;
        }
        return 1;
    }

    public function getDecorationRangeAt(index:Int):Null<Range> {
        final decorationId = index >= 0 && index < this._decorations.length ? this._decorations[index] : null;
        if (decorationId != null) {
            return this._editor.getModel().getDecorationRange(decorationId);
        }
        return null;
    }

    public function getCurrentMatchesPosition(desiredRange:Range):Int {
        final candidates = this._editor.getModel().getDecorationsInRange(desiredRange);
        for (candidate in candidates) {
            final candidateOpts:Null<ModelDecorationOptions> = Std.isOfType(candidate.options, ModelDecorationOptions) ? cast candidate.options : null;
            if (candidateOpts == FindDecorations._FIND_MATCH_DECORATION || candidateOpts == FindDecorations._CURRENT_FIND_MATCH_DECORATION) {
                return this._getDecorationIndex(candidate.id);
            }
        }
        // We don't know the current match position, so returns zero to show '?' in find widget
        return 0;
    }

    public function setCurrentFindMatch(nextMatch:Null<Range>):Int {
        var newCurrentDecorationId:Null<String> = null;
        var matchPosition = 0;
        if (nextMatch != null) {
            for (i in 0...this._decorations.length) {
                final range = this._editor.getModel().getDecorationRange(this._decorations[i]);
                if (nextMatch.equalsRange(range)) {
                    newCurrentDecorationId = this._decorations[i];
                    matchPosition = (i + 1);
                    break;
                }
            }
        }

        if (this._highlightedDecorationId != null || newCurrentDecorationId != null) {
            this._editor.changeDecorations((changeAccessor:IModelDecorationsChangeAccessor) -> {
                if (this._highlightedDecorationId != null) {
                    changeAccessor.changeDecorationOptions(this._highlightedDecorationId, cast FindDecorations._FIND_MATCH_DECORATION);
                    this._highlightedDecorationId = null;
                }
                if (newCurrentDecorationId != null) {
                    this._highlightedDecorationId = newCurrentDecorationId;
                    changeAccessor.changeDecorationOptions(this._highlightedDecorationId, cast FindDecorations._CURRENT_FIND_MATCH_DECORATION);
                }
                if (this._rangeHighlightDecorationId != null) {
                    changeAccessor.removeDecoration(this._rangeHighlightDecorationId);
                    this._rangeHighlightDecorationId = null;
                }
                if (newCurrentDecorationId != null) {
                    var rng = this._editor.getModel().getDecorationRange(newCurrentDecorationId);
                    if (rng.startLineNumber != rng.endLineNumber && rng.endColumn == 1) {
                        final lineBeforeEnd = rng.endLineNumber - 1;
                        final lineBeforeEndMaxColumn = this._editor.getModel().getLineMaxColumn(lineBeforeEnd);
                        rng = new Range(rng.startLineNumber, rng.startColumn, lineBeforeEnd, lineBeforeEndMaxColumn);
                    }
                    this._rangeHighlightDecorationId = changeAccessor.addDecoration(rng, cast FindDecorations._RANGE_HIGHLIGHT_DECORATION);
                }
                return null;
            });
        }

        return matchPosition;
    }

    public function set(findMatches:Array<FindMatch>, findScopes:Null<Array<Range>>):Void {
        this._editor.changeDecorations((accessor) -> {

            var findMatchesOptions:ModelDecorationOptions = FindDecorations._FIND_MATCH_DECORATION;
            final newOverviewRulerApproximateDecorations:Array<IModelDeltaDecoration> = [];

            if (findMatches.length > 1000) {
                // we go into a mode where the overview ruler gets "approximate" decorations
                // the reason is that the overview ruler paints all the decorations in the file and we don't want to cause freezes
                findMatchesOptions = FindDecorations._FIND_MATCH_NO_OVERVIEW_DECORATION;

                // approximate a distance in lines where matches should be merged
                final lineCount = this._editor.getModel().getLineCount();
                final height = this._editor.getOption(EditorOption.layoutInfo).height;
                final approxPixelsPerLine = height / lineCount;
                final mergeLinesDelta = Std.int(Math.max(2, Math.ceil(3 / approxPixelsPerLine)));

                // merge decorations as much as possible
                var prevStartLineNumber = findMatches[0].range.startLineNumber;
                var prevEndLineNumber = findMatches[0].range.endLineNumber;
                for (i in 1...findMatches.length) {
                    final range = findMatches[i].range;
                    if (prevEndLineNumber + mergeLinesDelta >= range.startLineNumber) {
                        if (range.endLineNumber > prevEndLineNumber) {
                            prevEndLineNumber = range.endLineNumber;
                        }
                    } else {
                        newOverviewRulerApproximateDecorations.push({
                            range: new Range(prevStartLineNumber, 1, prevEndLineNumber, 1),
                            options: cast FindDecorations._FIND_MATCH_ONLY_OVERVIEW_DECORATION
                        });
                        prevStartLineNumber = range.startLineNumber;
                        prevEndLineNumber = range.endLineNumber;
                    }
                }

                newOverviewRulerApproximateDecorations.push({
                    range: new Range(prevStartLineNumber, 1, prevEndLineNumber, 1),
                    options: cast FindDecorations._FIND_MATCH_ONLY_OVERVIEW_DECORATION
                });
            }

            // Find matches
            final newFindMatchesDecorations:Array<IModelDeltaDecoration> = [];
            for (i in 0...findMatches.length) {
                newFindMatchesDecorations[i] = {
                    range: findMatches[i].range,
                    options: cast findMatchesOptions
                };
            }
            this._decorations = accessor.deltaDecorations(this._decorations, newFindMatchesDecorations);

            // Overview ruler approximate decorations
            this._overviewRulerApproximateDecorations = accessor.deltaDecorations(this._overviewRulerApproximateDecorations, newOverviewRulerApproximateDecorations);

            // Range highlight
            if (this._rangeHighlightDecorationId != null) {
                accessor.removeDecoration(this._rangeHighlightDecorationId);
                this._rangeHighlightDecorationId = null;
            }

            // Find scope
            if (this._findScopeDecorationIds.length > 0) {
                for (findScopeDecorationId in this._findScopeDecorationIds) {
                    accessor.removeDecoration(findScopeDecorationId);
                }
                this._findScopeDecorationIds = [];
            }
            if (findScopes != null && findScopes.length > 0) {
                this._findScopeDecorationIds = [for (findScope in findScopes) accessor.addDecoration(findScope, cast FindDecorations._FIND_SCOPE_DECORATION)];
            }
            return null;
        });
    }

    public function matchBeforePosition(position:Position):Null<Range> {
        if (this._decorations.length == 0) {
            return null;
        }
        var i = this._decorations.length - 1;
        while (i >= 0) {
            final decorationId = this._decorations[i];
            final r = this._editor.getModel().getDecorationRange(decorationId);
            i--;
            if (r == null || r.endLineNumber > position.lineNumber) {
                continue;
            }
            if (r.endLineNumber < position.lineNumber) {
                return r;
            }
            if (r.endColumn > position.column) {
                continue;
            }
            return r;
        }

        return this._editor.getModel().getDecorationRange(this._decorations[this._decorations.length - 1]);
    }

    public function matchAfterPosition(position:Position):Null<Range> {
        if (this._decorations.length == 0) {
            return null;
        }
        for (i in 0...this._decorations.length) {
            final decorationId = this._decorations[i];
            final r = this._editor.getModel().getDecorationRange(decorationId);
            if (r == null || r.startLineNumber < position.lineNumber) {
                continue;
            }
            if (r.startLineNumber > position.lineNumber) {
                return r;
            }
            if (r.startColumn < position.column) {
                continue;
            }
            return r;
        }

        return this._editor.getModel().getDecorationRange(this._decorations[0]);
    }

    function _allDecorations():Array<String> {
        var result:Array<String> = [];
        result = result.concat(this._decorations);
        result = result.concat(this._overviewRulerApproximateDecorations);
        if (this._findScopeDecorationIds.length > 0) {
            for (id in this._findScopeDecorationIds) {
                result.push(id);
            }
        }
        if (this._rangeHighlightDecorationId != null) {
            result.push(this._rangeHighlightDecorationId);
        }
        return result;
    }

    public static final _CURRENT_FIND_MATCH_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'current-find-match',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        zIndex: 13,
        className: 'currentFindMatch',
        inlineClassName: 'currentFindMatchInline',
        showIfCollapsed: true,
        overviewRuler: {
            color: ThemeService.themeColorFromId('editorOverviewRuler.findMatchForeground'),
            position: OverviewRulerLane.Center
        },
        minimap: {
            color: ThemeService.themeColorFromId('minimap.findMatchHighlight'),
            position: MinimapPosition.Inline
        }
    });

    public static final _FIND_MATCH_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'find-match',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        zIndex: 10,
        className: 'findMatch',
        inlineClassName: 'findMatchInline',
        showIfCollapsed: true,
        overviewRuler: {
            color: ThemeService.themeColorFromId('editorOverviewRuler.findMatchForeground'),
            position: OverviewRulerLane.Center
        },
        minimap: {
            color: ThemeService.themeColorFromId('minimap.findMatchHighlight'),
            position: MinimapPosition.Inline
        }
    });

    public static final _FIND_MATCH_NO_OVERVIEW_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'find-match-no-overview',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        className: 'findMatch',
        showIfCollapsed: true
    });

    static final _FIND_MATCH_ONLY_OVERVIEW_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'find-match-only-overview',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        overviewRuler: {
            color: ThemeService.themeColorFromId('editorOverviewRuler.findMatchForeground'),
            position: OverviewRulerLane.Center
        }
    });

    static final _RANGE_HIGHLIGHT_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'find-range-highlight',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        className: 'rangeHighlight',
        isWholeLine: true
    });

    static final _FIND_SCOPE_DECORATION:ModelDecorationOptions = ModelDecorationOptions.register({
        description: 'find-scope',
        className: 'findScope',
        isWholeLine: true
    });

}
