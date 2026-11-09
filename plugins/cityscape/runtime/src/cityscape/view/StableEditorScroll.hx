// Ported from vscode src/vs/editor/browser/stableEditorScroll.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The part of Monaco's `ICodeEditor` that `StableEditorScrollState` uses.
 */
interface IScrollStateEditor {
    function getScrollTop():Float;
    function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void;
    function hasPendingScrollAnimation():Bool;
    function getContentHeight():Float;
    function getVisibleRanges():Array<Range>;
    function getTopForLineNumber(lineNumber:Int):Float;
    function getTopForPosition(lineNumber:Int, column:Int):Float;
    function getPosition():Null<Position>;
}

class StableEditorScrollState {

    public static function capture(editor:IScrollStateEditor):StableEditorScrollState {
        if (editor.getScrollTop() == 0 || editor.hasPendingScrollAnimation()) {
            // Never mess with the scroll top if the editor is at the top of the file or if there is a pending scroll animation
            return new StableEditorScrollState(editor.getScrollTop(), editor.getContentHeight(), null, 0, null);
        }

        var visiblePosition:Null<Position> = null;
        var visiblePositionScrollDelta:Float = 0;
        final visibleRanges = editor.getVisibleRanges();
        if (visibleRanges.length > 0) {
            visiblePosition = visibleRanges[0].getStartPosition();
            final visiblePositionScrollTop = editor.getTopForPosition(visiblePosition.lineNumber, visiblePosition.column);
            visiblePositionScrollDelta = editor.getScrollTop() - visiblePositionScrollTop;
        }
        return new StableEditorScrollState(editor.getScrollTop(), editor.getContentHeight(), visiblePosition, visiblePositionScrollDelta, editor.getPosition());
    }

    final _initialScrollTop:Float;
    final _initialContentHeight:Float;
    final _visiblePosition:Null<Position>;
    final _visiblePositionScrollDelta:Float;
    final _cursorPosition:Null<Position>;

    public function new(initialScrollTop:Float, initialContentHeight:Float, visiblePosition:Null<Position>, visiblePositionScrollDelta:Float, cursorPosition:Null<Position>) {
        _initialScrollTop = initialScrollTop;
        _initialContentHeight = initialContentHeight;
        _visiblePosition = visiblePosition;
        _visiblePositionScrollDelta = visiblePositionScrollDelta;
        _cursorPosition = cursorPosition;
    }

    public function restore(editor:IScrollStateEditor):Void {
        if (_initialContentHeight == editor.getContentHeight() && _initialScrollTop == editor.getScrollTop()) {
            // The editor's content height and scroll top haven't changed, so we don't need to do anything
            return;
        }

        if (_visiblePosition != null) {
            final visiblePositionScrollTop = editor.getTopForPosition(_visiblePosition.lineNumber, _visiblePosition.column);
            editor.setScrollTop(visiblePositionScrollTop + _visiblePositionScrollDelta);
        }
    }

    public function restoreRelativeVerticalPositionOfCursor(editor:IScrollStateEditor):Void {
        if (_initialContentHeight == editor.getContentHeight() && _initialScrollTop == editor.getScrollTop()) {
            // The editor's content height and scroll top haven't changed, so we don't need to do anything
            return;
        }

        final currentCursorPosition = editor.getPosition();

        if (_cursorPosition == null || currentCursorPosition == null) {
            return;
        }

        final offset = editor.getTopForLineNumber(currentCursorPosition.lineNumber) - editor.getTopForLineNumber(_cursorPosition.lineNumber);
        editor.setScrollTop(editor.getScrollTop() + offset, ScrollType.Immediate);
    }
}
