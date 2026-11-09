// Ported from vscode src/vs/base/common/scrollable.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Event;

enum abstract ScrollbarVisibility(Int) from Int to Int {
    var Auto = 1;
    var Hidden = 2;
    var Visible = 3;
}

typedef IScrollPosition = {
    final scrollLeft:Float;
    final scrollTop:Float;
}

typedef IScrollDimensions = {
    final width:Float;
    final scrollWidth:Float;
    final height:Float;
    final scrollHeight:Float;
}

typedef INewScrollDimensions = {
    @:optional var width:Float;
    @:optional var scrollWidth:Float;
    @:optional var height:Float;
    @:optional var scrollHeight:Float;
}

typedef INewScrollPosition = {
    @:optional var scrollLeft:Float;
    @:optional var scrollTop:Float;
}

class ScrollEvent {
    public var inSmoothScrolling:Bool;

    public var oldWidth:Float;
    public var oldScrollWidth:Float;
    public var oldScrollLeft:Float;

    public var width:Float;
    public var scrollWidth:Float;
    public var scrollLeft:Float;

    public var oldHeight:Float;
    public var oldScrollHeight:Float;
    public var oldScrollTop:Float;

    public var height:Float;
    public var scrollHeight:Float;
    public var scrollTop:Float;

    public var widthChanged:Bool;
    public var scrollWidthChanged:Bool;
    public var scrollLeftChanged:Bool;

    public var heightChanged:Bool;
    public var scrollHeightChanged:Bool;
    public var scrollTopChanged:Bool;

    public function new() {}
}

class ScrollState {

    public final rawScrollLeft:Float;
    public final rawScrollTop:Float;

    public final width:Float;
    public final scrollWidth:Float;
    public final scrollLeft:Float;
    public final height:Float;
    public final scrollHeight:Float;
    public final scrollTop:Float;

    final _forceIntegerValues:Bool;

    public function new(_forceIntegerValues:Bool, width:Float, scrollWidth:Float, scrollLeft:Float, height:Float, scrollHeight:Float, scrollTop:Float) {
        this._forceIntegerValues = _forceIntegerValues;
        if (this._forceIntegerValues) {
            width = toInt32(width);
            scrollWidth = toInt32(scrollWidth);
            scrollLeft = toInt32(scrollLeft);
            height = toInt32(height);
            scrollHeight = toInt32(scrollHeight);
            scrollTop = toInt32(scrollTop);
        }

        this.rawScrollLeft = scrollLeft; // before validation
        this.rawScrollTop = scrollTop; // before validation

        if (width < 0) {
            width = 0;
        }
        if (scrollLeft + width > scrollWidth) {
            scrollLeft = scrollWidth - width;
        }
        if (scrollLeft < 0) {
            scrollLeft = 0;
        }

        if (height < 0) {
            height = 0;
        }
        if (scrollTop + height > scrollHeight) {
            scrollTop = scrollHeight - height;
        }
        if (scrollTop < 0) {
            scrollTop = 0;
        }

        this.width = width;
        this.scrollWidth = scrollWidth;
        this.scrollLeft = scrollLeft;
        this.height = height;
        this.scrollHeight = scrollHeight;
        this.scrollTop = scrollTop;
    }

    static inline function toInt32(value:Float):Float {
        return Math.isNaN(value) || !Math.isFinite(value) ? 0 : (Std.int(value) : Float);
    }

    public function equals(other:ScrollState):Bool {
        return (
            this.rawScrollLeft == other.rawScrollLeft
            && this.rawScrollTop == other.rawScrollTop
            && this.width == other.width
            && this.scrollWidth == other.scrollWidth
            && this.scrollLeft == other.scrollLeft
            && this.height == other.height
            && this.scrollHeight == other.scrollHeight
            && this.scrollTop == other.scrollTop
        );
    }

    public function withScrollDimensions(update:INewScrollDimensions, useRawScrollPositions:Bool):ScrollState {
        return new ScrollState(
            this._forceIntegerValues,
            (update.width != null ? update.width : this.width),
            (update.scrollWidth != null ? update.scrollWidth : this.scrollWidth),
            useRawScrollPositions ? this.rawScrollLeft : this.scrollLeft,
            (update.height != null ? update.height : this.height),
            (update.scrollHeight != null ? update.scrollHeight : this.scrollHeight),
            useRawScrollPositions ? this.rawScrollTop : this.scrollTop
        );
    }

    public function withScrollPosition(update:INewScrollPosition):ScrollState {
        return new ScrollState(
            this._forceIntegerValues,
            this.width,
            this.scrollWidth,
            (update.scrollLeft != null ? update.scrollLeft : this.rawScrollLeft),
            this.height,
            this.scrollHeight,
            (update.scrollTop != null ? update.scrollTop : this.rawScrollTop)
        );
    }

    public function createScrollEvent(previous:ScrollState, inSmoothScrolling:Bool):ScrollEvent {
        final e = new ScrollEvent();
        e.inSmoothScrolling = inSmoothScrolling;
        e.oldWidth = previous.width;
        e.oldScrollWidth = previous.scrollWidth;
        e.oldScrollLeft = previous.scrollLeft;
        e.width = this.width;
        e.scrollWidth = this.scrollWidth;
        e.scrollLeft = this.scrollLeft;
        e.oldHeight = previous.height;
        e.oldScrollHeight = previous.scrollHeight;
        e.oldScrollTop = previous.scrollTop;
        e.height = this.height;
        e.scrollHeight = this.scrollHeight;
        e.scrollTop = this.scrollTop;
        e.widthChanged = (this.width != previous.width);
        e.scrollWidthChanged = (this.scrollWidth != previous.scrollWidth);
        e.scrollLeftChanged = (this.scrollLeft != previous.scrollLeft);
        e.heightChanged = (this.height != previous.height);
        e.scrollHeightChanged = (this.scrollHeight != previous.scrollHeight);
        e.scrollTopChanged = (this.scrollTop != previous.scrollTop);
        return e;
    }

}

typedef IScrollableOptions = {
    /**
     * Define if the scroll values should always be integers.
     */
    final forceIntegerValues:Bool;
    /**
     * Set the duration (ms) used for smooth scroll animations.
     */
    final smoothScrollDuration:Float;
}

/**
 * Monaco's scroll state (dimensions, position) and its scroll event.
 *
 * Cityscape scrolls with Glaze and the kit (see the plan, "Intégration au
 * kit"): the kit's scroll physics (wheel, bounce, scrollbar drag) drives the
 * position, so `setScrollPositionSmooth` moves immediately, like
 * `setScrollPositionNow` (docs/DEVIATIONS.md, "Chrome from the Glaze kit").
 */
class Scrollable implements Lifecycle.IDisposable {

    var _smoothScrollDuration:Float;

    var _state:ScrollState;

    final _onScroll:Emitter<ScrollEvent> = new Emitter<ScrollEvent>();
    public final onScroll:Event<ScrollEvent>;

    public function new(options:IScrollableOptions) {
        this._smoothScrollDuration = options.smoothScrollDuration;
        this._state = new ScrollState(options.forceIntegerValues, 0, 0, 0, 0, 0, 0);
        this.onScroll = _onScroll.event;
    }

    public function dispose():Void {
        _onScroll.dispose();
    }

    public function setSmoothScrollDuration(smoothScrollDuration:Float):Void {
        this._smoothScrollDuration = smoothScrollDuration;
    }

    public function validateScrollPosition(scrollPosition:INewScrollPosition):IScrollPosition {
        final s = this._state.withScrollPosition(scrollPosition);
        return {scrollLeft: s.scrollLeft, scrollTop: s.scrollTop};
    }

    public function getScrollDimensions():ScrollState {
        return this._state;
    }

    public function setScrollDimensions(dimensions:INewScrollDimensions, useRawScrollPositions:Bool):Void {
        final newState = this._state.withScrollDimensions(dimensions, useRawScrollPositions);
        this._setState(newState, false);
    }

    /**
     * Returns the final scroll position that the instance will have once the smooth scroll animation concludes.
     * If no scroll animation is occurring, it will return the current scroll position instead.
     */
    public function getFutureScrollPosition():ScrollState {
        return this._state;
    }

    /**
     * Returns the current scroll position.
     * Note: This result might be an intermediate scroll position, as there might be an ongoing smooth scroll animation.
     */
    public function getCurrentScrollPosition():ScrollState {
        return this._state;
    }

    public function setScrollPositionNow(update:INewScrollPosition):Void {
        final newState = this._state.withScrollPosition(update);
        this._setState(newState, false);
    }

    public function setScrollPositionSmooth(update:INewScrollPosition, ?reuseAnimation:Bool):Void {
        this.setScrollPositionNow(update);
    }

    public function hasPendingScrollAnimation():Bool {
        return false;
    }

    function _setState(newState:ScrollState, inSmoothScrolling:Bool):Void {
        final oldState = this._state;
        if (oldState.equals(newState)) {
            // no change
            return;
        }
        this._state = newState;
        this._onScroll.fire(this._state.createScrollEvent(oldState, inSmoothScrolling));
    }

}
