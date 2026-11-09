// Ported from vscode src/vs/editor/common/viewModelEventDispatcher.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Event;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.TextModelEvents;
import cityscape.common.ViewEvents.ViewEvent;
import cityscape.common.core.Selection;

class ViewModelEventDispatcher {

    final _onEvent:Emitter<OutgoingViewModelEvent> = new Emitter<OutgoingViewModelEvent>();
    public final onEvent:Event<OutgoingViewModelEvent>;

    final _eventHandlers:Array<ViewEventHandler>;
    var _viewEventQueue:Null<Array<ViewEvent>>;
    var _isConsumingViewEventQueue:Bool;
    var _collector:Null<ViewModelEventsCollector>;
    var _collectorCnt:Int;
    final _outgoingEvents:Array<OutgoingViewModelEvent>;

    public function new() {
        this.onEvent = _onEvent.event;
        this._eventHandlers = [];
        this._viewEventQueue = null;
        this._isConsumingViewEventQueue = false;
        this._collector = null;
        this._collectorCnt = 0;
        this._outgoingEvents = [];
    }

    public function dispose():Void {
        _onEvent.dispose();
    }

    public function emitOutgoingEvent(e:OutgoingViewModelEvent):Void {
        this._addOutgoingEvent(e);
        this._emitOutgoingEvents();
    }

    function _addOutgoingEvent(e:OutgoingViewModelEvent):Void {
        for (i in 0...this._outgoingEvents.length) {
            final mergeResult = (this._outgoingEvents[i].kind == e.kind ? this._outgoingEvents[i].attemptToMerge(e) : null);
            if (mergeResult != null) {
                this._outgoingEvents[i] = mergeResult;
                return;
            }
        }
        // not merged
        this._outgoingEvents.push(e);
    }

    function _emitOutgoingEvents():Void {
        while (this._outgoingEvents.length > 0) {
            if (this._collector != null || this._isConsumingViewEventQueue) {
                // right now collecting or emitting view events, so let's postpone emitting
                return;
            }
            final event = this._outgoingEvents.shift();
            if (event.isNoOp()) {
                continue;
            }
            this._onEvent.fire(event);
        }
    }

    public function addViewEventHandler(eventHandler:ViewEventHandler):Void {
        this._eventHandlers.push(eventHandler);
    }

    public function removeViewEventHandler(eventHandler:ViewEventHandler):Void {
        for (i in 0...this._eventHandlers.length) {
            if (this._eventHandlers[i] == eventHandler) {
                this._eventHandlers.splice(i, 1);
                break;
            }
        }
    }

    public function beginEmitViewEvents():ViewModelEventsCollector {
        this._collectorCnt++;
        if (this._collectorCnt == 1) {
            this._collector = new ViewModelEventsCollector();
        }
        return this._collector;
    }

    public function endEmitViewEvents():Void {
        this._collectorCnt--;
        if (this._collectorCnt == 0) {
            final outgoingEvents = this._collector.outgoingEvents;
            final viewEvents = this._collector.viewEvents;
            this._collector = null;

            for (outgoingEvent in outgoingEvents) {
                this._addOutgoingEvent(outgoingEvent);
            }

            if (viewEvents.length > 0) {
                this._emitMany(viewEvents);
            }
        }
        this._emitOutgoingEvents();
    }

    public function emitSingleViewEvent(event:ViewEvent):Void {
        try {
            final eventsCollector = this.beginEmitViewEvents();
            eventsCollector.emitViewEvent(event);
        } catch (e:haxe.Exception) {
            this.endEmitViewEvents();
            throw e;
        }
        this.endEmitViewEvents();
    }

    function _emitMany(events:Array<ViewEvent>):Void {
        if (this._viewEventQueue != null) {
            this._viewEventQueue = this._viewEventQueue.concat(events);
        } else {
            this._viewEventQueue = events;
        }

        if (!this._isConsumingViewEventQueue) {
            this._consumeViewEventQueue();
        }
    }

    function _consumeViewEventQueue():Void {
        this._isConsumingViewEventQueue = true;
        try {
            this._doConsumeQueue();
        } catch (e:haxe.Exception) {
            this._isConsumingViewEventQueue = false;
            throw e;
        }
        this._isConsumingViewEventQueue = false;
    }

    function _doConsumeQueue():Void {
        while (this._viewEventQueue != null) {
            // Empty event queue, as events might come in while sending these off
            final events = this._viewEventQueue;
            this._viewEventQueue = null;

            // Use a clone of the event handlers list, as they might remove themselves
            final eventHandlers = this._eventHandlers.copy();
            for (eventHandler in eventHandlers) {
                eventHandler.handleEvents(events);
            }
        }
    }

}

class ViewModelEventsCollector {

    public final viewEvents:Array<ViewEvent>;
    public final outgoingEvents:Array<OutgoingViewModelEvent>;

    public function new() {
        this.viewEvents = [];
        this.outgoingEvents = [];
    }

    public function emitViewEvent(event:ViewEvent):Void {
        this.viewEvents.push(event);
    }

    public function emitOutgoingEvent(e:OutgoingViewModelEvent):Void {
        this.outgoingEvents.push(e);
    }

}

enum abstract OutgoingViewModelEventKind(Int) from Int to Int {
    var ContentSizeChanged = 0;
    var FocusChanged = 1;
    var ScrollChanged = 2;
    var ViewZonesChanged = 3;
    var HiddenAreasChanged = 4;
    var ReadOnlyEditAttempt = 5;
    var CursorStateChanged = 6;
    var ModelDecorationsChanged = 7;
    var ModelLanguageChanged = 8;
    var ModelLanguageConfigurationChanged = 9;
    var ModelContentChanged = 10;
    var ModelOptionsChanged = 11;
    var ModelTokensChanged = 12;
}

/**
 * Monaco's `OutgoingViewModelEvent` union.
 */
abstract class OutgoingViewModelEvent {

    public final kind:OutgoingViewModelEventKind;

    function new(kind:OutgoingViewModelEventKind) {
        this.kind = kind;
    }

    public abstract function isNoOp():Bool;

    public abstract function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent>;

}

class ContentSizeChangedEvent extends OutgoingViewModelEvent {

    final _oldContentWidth:Float;
    final _oldContentHeight:Float;

    public final contentWidth:Float;
    public final contentHeight:Float;
    public final contentWidthChanged:Bool;
    public final contentHeightChanged:Bool;

    public function new(oldContentWidth:Float, oldContentHeight:Float, contentWidth:Float, contentHeight:Float) {
        super(OutgoingViewModelEventKind.ContentSizeChanged);
        this._oldContentWidth = oldContentWidth;
        this._oldContentHeight = oldContentHeight;
        this.contentWidth = contentWidth;
        this.contentHeight = contentHeight;
        this.contentWidthChanged = (this._oldContentWidth != this.contentWidth);
        this.contentHeightChanged = (this._oldContentHeight != this.contentHeight);
    }

    public function isNoOp():Bool {
        return (!this.contentWidthChanged && !this.contentHeightChanged);
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        final other:ContentSizeChangedEvent = cast other;
        return new ContentSizeChangedEvent(this._oldContentWidth, this._oldContentHeight, other.contentWidth, other.contentHeight);
    }

}

class FocusChangedEvent extends OutgoingViewModelEvent {

    public final oldHasFocus:Bool;
    public final hasFocus:Bool;

    public function new(oldHasFocus:Bool, hasFocus:Bool) {
        super(OutgoingViewModelEventKind.FocusChanged);
        this.oldHasFocus = oldHasFocus;
        this.hasFocus = hasFocus;
    }

    public function isNoOp():Bool {
        return (this.oldHasFocus == this.hasFocus);
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        final other:FocusChangedEvent = cast other;
        return new FocusChangedEvent(this.oldHasFocus, other.hasFocus);
    }

}

class ScrollChangedEvent extends OutgoingViewModelEvent {

    final _oldScrollWidth:Float;
    final _oldScrollLeft:Float;
    final _oldScrollHeight:Float;
    final _oldScrollTop:Float;

    public final scrollWidth:Float;
    public final scrollLeft:Float;
    public final scrollHeight:Float;
    public final scrollTop:Float;

    public final scrollWidthChanged:Bool;
    public final scrollLeftChanged:Bool;
    public final scrollHeightChanged:Bool;
    public final scrollTopChanged:Bool;

    public function new(oldScrollWidth:Float, oldScrollLeft:Float, oldScrollHeight:Float, oldScrollTop:Float, scrollWidth:Float, scrollLeft:Float, scrollHeight:Float, scrollTop:Float) {
        super(OutgoingViewModelEventKind.ScrollChanged);
        this._oldScrollWidth = oldScrollWidth;
        this._oldScrollLeft = oldScrollLeft;
        this._oldScrollHeight = oldScrollHeight;
        this._oldScrollTop = oldScrollTop;

        this.scrollWidth = scrollWidth;
        this.scrollLeft = scrollLeft;
        this.scrollHeight = scrollHeight;
        this.scrollTop = scrollTop;

        this.scrollWidthChanged = (this._oldScrollWidth != this.scrollWidth);
        this.scrollLeftChanged = (this._oldScrollLeft != this.scrollLeft);
        this.scrollHeightChanged = (this._oldScrollHeight != this.scrollHeight);
        this.scrollTopChanged = (this._oldScrollTop != this.scrollTop);
    }

    public function isNoOp():Bool {
        return (!this.scrollWidthChanged && !this.scrollLeftChanged && !this.scrollHeightChanged && !this.scrollTopChanged);
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        final other:ScrollChangedEvent = cast other;
        return new ScrollChangedEvent(
            this._oldScrollWidth, this._oldScrollLeft, this._oldScrollHeight, this._oldScrollTop,
            other.scrollWidth, other.scrollLeft, other.scrollHeight, other.scrollTop
        );
    }

}

/**
 * Monaco's outgoing `ViewZonesChangedEvent` (viewModelEventDispatcher.ts),
 * renamed: Haxe forbids two types of one package with the same name, and
 * viewEvents.ts has a `ViewZonesChangedEvent` too.
 */
class ViewZonesChangedOutgoingEvent extends OutgoingViewModelEvent {

    public function new() {
        super(OutgoingViewModelEventKind.ViewZonesChanged);
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        return this;
    }

}

class HiddenAreasChangedEvent extends OutgoingViewModelEvent {

    public function new() {
        super(OutgoingViewModelEventKind.HiddenAreasChanged);
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        return this;
    }

}

class CursorStateChangedEvent extends OutgoingViewModelEvent {

    public final oldSelections:Null<Array<Selection>>;
    public final selections:Array<Selection>;
    public final oldModelVersionId:Int;
    public final modelVersionId:Int;
    public final source:String;
    public final reason:CursorChangeReason;
    public final reachedMaxCursorCount:Bool;

    public function new(oldSelections:Null<Array<Selection>>, selections:Array<Selection>, oldModelVersionId:Int, modelVersionId:Int, source:String, reason:CursorChangeReason, reachedMaxCursorCount:Bool) {
        super(OutgoingViewModelEventKind.CursorStateChanged);
        this.oldSelections = oldSelections;
        this.selections = selections;
        this.oldModelVersionId = oldModelVersionId;
        this.modelVersionId = modelVersionId;
        this.source = source;
        this.reason = reason;
        this.reachedMaxCursorCount = reachedMaxCursorCount;
    }

    static function _selectionsAreEqual(a:Null<Array<Selection>>, b:Null<Array<Selection>>):Bool {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        final aLen = a.length;
        final bLen = b.length;
        if (aLen != bLen) {
            return false;
        }
        for (i in 0...aLen) {
            if (!a[i].equalsSelection(b[i])) {
                return false;
            }
        }
        return true;
    }

    public function isNoOp():Bool {
        return (
            CursorStateChangedEvent._selectionsAreEqual(this.oldSelections, this.selections)
            && this.oldModelVersionId == this.modelVersionId
        );
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        final other:CursorStateChangedEvent = cast other;
        return new CursorStateChangedEvent(
            this.oldSelections, other.selections, this.oldModelVersionId, other.modelVersionId, other.source, other.reason, this.reachedMaxCursorCount || other.reachedMaxCursorCount
        );
    }

}

class ReadOnlyEditAttemptEvent extends OutgoingViewModelEvent {

    public function new() {
        super(OutgoingViewModelEventKind.ReadOnlyEditAttempt);
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        if (other.kind != this.kind) {
            return null;
        }
        return this;
    }

}

class ModelDecorationsChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelDecorationsChangedEvent;

    public function new(event:IModelDecorationsChangedEvent) {
        super(OutgoingViewModelEventKind.ModelDecorationsChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}

class ModelLanguageChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelLanguageChangedEvent;

    public function new(event:IModelLanguageChangedEvent) {
        super(OutgoingViewModelEventKind.ModelLanguageChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}

class ModelLanguageConfigurationChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelLanguageConfigurationChangedEvent;

    public function new(event:IModelLanguageConfigurationChangedEvent) {
        super(OutgoingViewModelEventKind.ModelLanguageConfigurationChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}

class ModelContentChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelContentChangedEvent;

    public function new(event:IModelContentChangedEvent) {
        super(OutgoingViewModelEventKind.ModelContentChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}

class ModelOptionsChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelOptionsChangedEvent;

    public function new(event:IModelOptionsChangedEvent) {
        super(OutgoingViewModelEventKind.ModelOptionsChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}

class ModelTokensChangedEvent extends OutgoingViewModelEvent {

    public final event:IModelTokensChangedEvent;

    public function new(event:IModelTokensChangedEvent) {
        super(OutgoingViewModelEventKind.ModelTokensChanged);
        this.event = event;
    }

    public function isNoOp():Bool {
        return false;
    }

    public function attemptToMerge(other:OutgoingViewModelEvent):Null<OutgoingViewModelEvent> {
        return null;
    }

}
