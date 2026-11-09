// Ported from vscode src/vs/editor/common/viewEventHandler.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.ViewEvents;

/**
 * A view part that receives view events.
 */
class ViewEventHandler {

    var _shouldRender:Bool;

    public function new() {
        this._shouldRender = true;
    }

    public function dispose():Void {}

    public function shouldRender():Bool {
        return this._shouldRender;
    }

    public function forceShouldRender():Void {
        this._shouldRender = true;
    }

    function setShouldRender():Void {
        this._shouldRender = true;
    }

    public function onDidRender():Void {
        this._shouldRender = false;
    }

    // --- begin event handlers

    public function onCompositionStart(e:ViewCompositionStartEvent):Bool {
        return false;
    }

    public function onCompositionEnd(e:ViewCompositionEndEvent):Bool {
        return false;
    }

    public function onConfigurationChanged(e:ViewConfigurationChangedEvent):Bool {
        return false;
    }

    public function onCursorStateChanged(e:ViewCursorStateChangedEvent):Bool {
        return false;
    }

    public function onDecorationsChanged(e:ViewDecorationsChangedEvent):Bool {
        return false;
    }

    public function onFlushed(e:ViewFlushedEvent):Bool {
        return false;
    }

    public function onFocusChanged(e:ViewFocusChangedEvent):Bool {
        return false;
    }

    public function onLanguageConfigurationChanged(e:ViewLanguageConfigurationEvent):Bool {
        return false;
    }

    public function onLineMappingChanged(e:ViewLineMappingChangedEvent):Bool {
        return false;
    }

    public function onLinesChanged(e:ViewLinesChangedEvent):Bool {
        return false;
    }

    public function onLinesDeleted(e:ViewLinesDeletedEvent):Bool {
        return false;
    }

    public function onLinesInserted(e:ViewLinesInsertedEvent):Bool {
        return false;
    }

    public function onRevealRangeRequest(e:ViewRevealRangeRequestEvent):Bool {
        return false;
    }

    public function onScrollChanged(e:ViewScrollChangedEvent):Bool {
        return false;
    }

    public function onTokensChanged(e:ViewTokensChangedEvent):Bool {
        return false;
    }

    public function onThemeChanged(e:ViewThemeChangedEvent):Bool {
        return false;
    }

    public function onTokensColorsChanged(e:ViewTokensColorsChangedEvent):Bool {
        return false;
    }

    public function onZonesChanged(e:ViewZonesChangedEvent):Bool {
        return false;
    }

    // --- end event handlers

    public function handleEvents(events:Array<ViewEvent>):Void {

        var shouldRender = false;

        for (i in 0...events.length) {
            final e = events[i];

            switch (e.type) {
                case ViewEventType.ViewCompositionStart:
                    if (this.onCompositionStart(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewCompositionEnd:
                    if (this.onCompositionEnd(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewConfigurationChanged:
                    if (this.onConfigurationChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewCursorStateChanged:
                    if (this.onCursorStateChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewDecorationsChanged:
                    if (this.onDecorationsChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewFlushed:
                    if (this.onFlushed(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewFocusChanged:
                    if (this.onFocusChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewLanguageConfigurationChanged:
                    if (this.onLanguageConfigurationChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewLineMappingChanged:
                    if (this.onLineMappingChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewLinesChanged:
                    if (this.onLinesChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewLinesDeleted:
                    if (this.onLinesDeleted(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewLinesInserted:
                    if (this.onLinesInserted(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewRevealRangeRequest:
                    if (this.onRevealRangeRequest(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewScrollChanged:
                    if (this.onScrollChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewTokensChanged:
                    if (this.onTokensChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewThemeChanged:
                    if (this.onThemeChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewTokensColorsChanged:
                    if (this.onTokensColorsChanged(cast e)) {
                        shouldRender = true;
                    }
                case ViewEventType.ViewZonesChanged:
                    if (this.onZonesChanged(cast e)) {
                        shouldRender = true;
                    }
            }
        }

        if (shouldRender) {
            this._shouldRender = true;
        }
    }

}
