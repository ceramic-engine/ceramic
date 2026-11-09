// Ported from vscode src/vs/editor/contrib/find/browser/findState.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.Disposable;
import cityscape.common.core.Range;

/**
 * What changed in a `FindReplaceState` (Monaco's interface, a class here:
 * its fields are read by name on every target).
 */
class FindReplaceStateChangedEvent {

    public var moveCursor:Bool;
    public var updateHistory:Bool;

    public var searchString:Bool = false;
    public var replaceString:Bool = false;
    public var isRevealed:Bool = false;
    public var isReplaceRevealed:Bool = false;
    public var isRegex:Bool = false;
    public var wholeWord:Bool = false;
    public var matchCase:Bool = false;
    public var preserveCase:Bool = false;
    public var searchScope:Bool = false;
    public var matchesPosition:Bool = false;
    public var matchesCount:Bool = false;
    public var currentMatch:Bool = false;
    public var loop:Bool = false;
    public var isSearching:Bool = false;
    public var filters:Bool = false;

    public function new(moveCursor:Bool, updateHistory:Bool) {
        this.moveCursor = moveCursor;
        this.updateHistory = updateHistory;
    }

}

enum abstract FindOptionOverride(Int) from Int to Int {
    var NotSet = 0;
    var True = 1;
    var False = 2;
}

/**
 * The changes given to `FindReplaceState.change`: a field left out is
 * unchanged. `searchScope: null` clears the search scope (a field present
 * with a null value, tested with `Reflect.hasField` like Monaco tests
 * `undefined`).
 *
 * Monaco's generic `filters` (used by other find widgets than the editor's)
 * are not ported.
 */
typedef INewFindReplaceState = {
    @:optional var searchString:String;
    @:optional var replaceString:String;
    @:optional var isRevealed:Bool;
    @:optional var isReplaceRevealed:Bool;
    @:optional var isRegex:Bool;
    @:optional var isRegexOverride:FindOptionOverride;
    @:optional var wholeWord:Bool;
    @:optional var wholeWordOverride:FindOptionOverride;
    @:optional var matchCase:Bool;
    @:optional var matchCaseOverride:FindOptionOverride;
    @:optional var preserveCase:Bool;
    @:optional var preserveCaseOverride:FindOptionOverride;
    @:optional var searchScope:Null<Array<Range>>;
    @:optional var loop:Bool;
    @:optional var isSearching:Bool;
}

/**
 * The state of the find widget of one editor: search and replace strings,
 * options, the search scope and the match info (each editor has its own).
 */
class FindReplaceState extends Disposable {

    static function effectiveOptionValue(optionOverride:FindOptionOverride, value:Bool):Bool {
        if (optionOverride == FindOptionOverride.True) {
            return true;
        }
        if (optionOverride == FindOptionOverride.False) {
            return false;
        }
        return value;
    }

    var _searchString:String;
    var _replaceString:String;
    var _isRevealed:Bool;
    var _isReplaceRevealed:Bool;
    var _isRegex:Bool;
    var _isRegexOverride:FindOptionOverride;
    var _wholeWord:Bool;
    var _wholeWordOverride:FindOptionOverride;
    var _matchCase:Bool;
    var _matchCaseOverride:FindOptionOverride;
    var _preserveCase:Bool;
    var _preserveCaseOverride:FindOptionOverride;
    var _searchScope:Null<Array<Range>>;
    var _matchesPosition:Int;
    var _matchesCount:Int;
    var _currentMatch:Null<Range>;
    var _loop:Bool;
    var _isSearching:Bool;
    final _onFindReplaceStateChange:Emitter<FindReplaceStateChangedEvent>;

    public var searchString(get, never):String;
    inline function get_searchString():String { return this._searchString; }
    public var replaceString(get, never):String;
    inline function get_replaceString():String { return this._replaceString; }
    public var isRevealed(get, never):Bool;
    inline function get_isRevealed():Bool { return this._isRevealed; }
    public var isReplaceRevealed(get, never):Bool;
    inline function get_isReplaceRevealed():Bool { return this._isReplaceRevealed; }
    public var isRegex(get, never):Bool;
    function get_isRegex():Bool { return effectiveOptionValue(this._isRegexOverride, this._isRegex); }
    public var wholeWord(get, never):Bool;
    function get_wholeWord():Bool { return effectiveOptionValue(this._wholeWordOverride, this._wholeWord); }
    public var matchCase(get, never):Bool;
    function get_matchCase():Bool { return effectiveOptionValue(this._matchCaseOverride, this._matchCase); }
    public var preserveCase(get, never):Bool;
    function get_preserveCase():Bool { return effectiveOptionValue(this._preserveCaseOverride, this._preserveCase); }

    public var actualIsRegex(get, never):Bool;
    inline function get_actualIsRegex():Bool { return this._isRegex; }
    public var actualWholeWord(get, never):Bool;
    inline function get_actualWholeWord():Bool { return this._wholeWord; }
    public var actualMatchCase(get, never):Bool;
    inline function get_actualMatchCase():Bool { return this._matchCase; }
    public var actualPreserveCase(get, never):Bool;
    inline function get_actualPreserveCase():Bool { return this._preserveCase; }

    public var searchScope(get, never):Null<Array<Range>>;
    inline function get_searchScope():Null<Array<Range>> { return this._searchScope; }
    public var matchesPosition(get, never):Int;
    inline function get_matchesPosition():Int { return this._matchesPosition; }
    public var matchesCount(get, never):Int;
    inline function get_matchesCount():Int { return this._matchesCount; }
    public var currentMatch(get, never):Null<Range>;
    inline function get_currentMatch():Null<Range> { return this._currentMatch; }
    public var isSearching(get, never):Bool;
    inline function get_isSearching():Bool { return this._isSearching; }
    public var loop(get, never):Bool;
    inline function get_loop():Bool { return this._loop; }

    public final onFindReplaceStateChange:Event<FindReplaceStateChangedEvent>;

    public function new() {
        super();
        this._onFindReplaceStateChange = this._register(new Emitter<FindReplaceStateChangedEvent>());
        this.onFindReplaceStateChange = this._onFindReplaceStateChange.event;
        this._searchString = '';
        this._replaceString = '';
        this._isRevealed = false;
        this._isReplaceRevealed = false;
        this._isRegex = false;
        this._isRegexOverride = FindOptionOverride.NotSet;
        this._wholeWord = false;
        this._wholeWordOverride = FindOptionOverride.NotSet;
        this._matchCase = false;
        this._matchCaseOverride = FindOptionOverride.NotSet;
        this._preserveCase = false;
        this._preserveCaseOverride = FindOptionOverride.NotSet;
        this._searchScope = null;
        this._matchesPosition = 0;
        this._matchesCount = 0;
        this._currentMatch = null;
        this._loop = true;
        this._isSearching = false;
    }

    /**
     * `currentMatch` is Monaco's optional argument: `hasCurrentMatch` false
     * is `undefined` (the current match is left as is).
     */
    public function changeMatchInfo(matchesPosition:Int, matchesCount:Int, currentMatch:Null<Range>, hasCurrentMatch:Bool = true):Void {
        final changeEvent = new FindReplaceStateChangedEvent(false, false);
        var somethingChanged = false;

        if (matchesCount == 0) {
            matchesPosition = 0;
        }
        if (matchesPosition > matchesCount) {
            matchesPosition = matchesCount;
        }

        if (this._matchesPosition != matchesPosition) {
            this._matchesPosition = matchesPosition;
            changeEvent.matchesPosition = true;
            somethingChanged = true;
        }
        if (this._matchesCount != matchesCount) {
            this._matchesCount = matchesCount;
            changeEvent.matchesCount = true;
            somethingChanged = true;
        }

        if (hasCurrentMatch) {
            if (!Range.equalsRangeStatic(this._currentMatch, currentMatch)) {
                this._currentMatch = currentMatch;
                changeEvent.currentMatch = true;
                somethingChanged = true;
            }
        }

        if (somethingChanged) {
            this._onFindReplaceStateChange.fire(changeEvent);
        }
    }

    public function change(newState:INewFindReplaceState, moveCursor:Bool, updateHistory:Bool = true):Void {
        final changeEvent = new FindReplaceStateChangedEvent(moveCursor, updateHistory);
        var somethingChanged = false;

        final oldEffectiveIsRegex = this.isRegex;
        final oldEffectiveWholeWords = this.wholeWord;
        final oldEffectiveMatchCase = this.matchCase;
        final oldEffectivePreserveCase = this.preserveCase;

        final searchString:Null<String> = newState.searchString;
        if (searchString != null) {
            if (this._searchString != searchString) {
                this._searchString = searchString;
                changeEvent.searchString = true;
                somethingChanged = true;
            }
        }
        final replaceString:Null<String> = newState.replaceString;
        if (replaceString != null) {
            if (this._replaceString != replaceString) {
                this._replaceString = replaceString;
                changeEvent.replaceString = true;
                somethingChanged = true;
            }
        }
        final isRevealed:Null<Bool> = newState.isRevealed;
        if (isRevealed != null) {
            if (this._isRevealed != isRevealed) {
                this._isRevealed = isRevealed;
                changeEvent.isRevealed = true;
                somethingChanged = true;
            }
        }
        final isReplaceRevealed:Null<Bool> = newState.isReplaceRevealed;
        if (isReplaceRevealed != null) {
            if (this._isReplaceRevealed != isReplaceRevealed) {
                this._isReplaceRevealed = isReplaceRevealed;
                changeEvent.isReplaceRevealed = true;
                somethingChanged = true;
            }
        }
        final isRegex:Null<Bool> = newState.isRegex;
        if (isRegex != null) {
            this._isRegex = isRegex;
        }
        final wholeWord:Null<Bool> = newState.wholeWord;
        if (wholeWord != null) {
            this._wholeWord = wholeWord;
        }
        final matchCase:Null<Bool> = newState.matchCase;
        if (matchCase != null) {
            this._matchCase = matchCase;
        }
        final preserveCase:Null<Bool> = newState.preserveCase;
        if (preserveCase != null) {
            this._preserveCase = preserveCase;
        }
        if (Reflect.hasField(newState, 'searchScope')) {
            final newSearchScope:Null<Array<Range>> = newState.searchScope;
            // `!newState.searchScope?.every(n => this._searchScope?.some(e => !Range.equalsRange(e, n)))`
            var every = false;
            if (newSearchScope != null) {
                every = true;
                for (n in newSearchScope) {
                    var some = false;
                    final existing = this._searchScope;
                    if (existing != null) {
                        for (e in existing) {
                            if (!Range.equalsRangeStatic(e, n)) {
                                some = true;
                                break;
                            }
                        }
                    }
                    if (!some) {
                        every = false;
                        break;
                    }
                }
            }
            if (!every) {
                this._searchScope = newSearchScope;
                changeEvent.searchScope = true;
                somethingChanged = true;
            }
        }
        final loop:Null<Bool> = newState.loop;
        if (loop != null) {
            if (this._loop != loop) {
                this._loop = loop;
                changeEvent.loop = true;
                somethingChanged = true;
            }
        }

        final isSearching:Null<Bool> = newState.isSearching;
        if (isSearching != null) {
            if (this._isSearching != isSearching) {
                this._isSearching = isSearching;
                changeEvent.isSearching = true;
                somethingChanged = true;
            }
        }

        // Overrides get set when they explicitly come in and get reset anytime something else changes
        final isRegexOverride:Null<FindOptionOverride> = newState.isRegexOverride;
        final wholeWordOverride:Null<FindOptionOverride> = newState.wholeWordOverride;
        final matchCaseOverride:Null<FindOptionOverride> = newState.matchCaseOverride;
        final preserveCaseOverride:Null<FindOptionOverride> = newState.preserveCaseOverride;
        this._isRegexOverride = (isRegexOverride != null ? isRegexOverride : FindOptionOverride.NotSet);
        this._wholeWordOverride = (wholeWordOverride != null ? wholeWordOverride : FindOptionOverride.NotSet);
        this._matchCaseOverride = (matchCaseOverride != null ? matchCaseOverride : FindOptionOverride.NotSet);
        this._preserveCaseOverride = (preserveCaseOverride != null ? preserveCaseOverride : FindOptionOverride.NotSet);

        if (oldEffectiveIsRegex != this.isRegex) {
            somethingChanged = true;
            changeEvent.isRegex = true;
        }
        if (oldEffectiveWholeWords != this.wholeWord) {
            somethingChanged = true;
            changeEvent.wholeWord = true;
        }
        if (oldEffectiveMatchCase != this.matchCase) {
            somethingChanged = true;
            changeEvent.matchCase = true;
        }

        if (oldEffectivePreserveCase != this.preserveCase) {
            somethingChanged = true;
            changeEvent.preserveCase = true;
        }

        if (somethingChanged) {
            this._onFindReplaceStateChange.fire(changeEvent);
        }
    }

    public function canNavigateBack():Bool {
        return this.canNavigateInLoop() || (this.matchesPosition != 1);
    }

    public function canNavigateForward():Bool {
        return this.canNavigateInLoop() || (this.matchesPosition < this.matchesCount);
    }

    function canNavigateInLoop():Bool {
        return this._loop || (this.matchesCount >= FindModel.MATCHES_LIMIT);
    }

}
