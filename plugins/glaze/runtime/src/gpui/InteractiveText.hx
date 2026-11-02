// Ported from gpui-pre 0.3.10: src/elements/text.rs (InteractiveText, InteractiveTextState)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.Interactivity.ActiveTooltipCell;
import gpui.util.Ref;

/**
 * A text element that can be interacted with: clicks on byte ranges,
 * hover of characters, and tooltips per character.
 */
@:access(gpui.Interactivity)
class InteractiveText extends Element {

    final id:ElementId;

    final styledText:StyledText;

    var clickListener:Null<(Array<TextRange>, Int, Int, Window, App) -> Void> = null;

    var hoverListener:Null<(Null<Int>, MouseMoveEvent, Window, App) -> Void> = null;

    var tooltipBuilder:Null<(Int, Window, App) -> Null<AnyView>> = null;

    var tooltipId:Int = -1;

    var clickableRanges:Array<TextRange> = [];

    var hitbox:Null<Hitbox> = null;

    /**
     * Creates a new InteractiveText from the given text.
     */
    public function new(id:ElementIdArg, text:StyledText) {
        this.id = id;
        this.styledText = text;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    /** The styled text of this element. */
    public inline function text():StyledText {
        return styledText;
    }

    /**
     * `onClick` is called when the user clicks on one of the given ranges (byte
     * ranges `[start, end)`), passing the index of the clicked range.
     */
    public function onClick(ranges:Array<TextRange>, listener:(Int, Window, App) -> Void):InteractiveText {
        clickListener = (ranges, mouseDownIndex, mouseUpIndex, window, cx) -> {
            for (rangeIx in 0...ranges.length) {
                final range = ranges[rangeIx];
                if (range.contains(mouseDownIndex) && range.contains(mouseUpIndex)) {
                    listener(rangeIx, window, cx);
                }
            }
        };
        clickableRanges = ranges;
        return this;
    }

    /**
     * `onHover` is called when the mouse moves over a character within the text, passing the
     * index of the hovered character, or `null` if the mouse leaves the text.
     */
    public function onHover(listener:(Null<Int>, MouseMoveEvent, Window, App) -> Void):InteractiveText {
        hoverListener = listener;
        return this;
    }

    /**
     * `tooltip` lets you specify a tooltip for a given character index in the string.
     */
    public function tooltip(builder:(Int, Window, App) -> Null<AnyView>):InteractiveText {
        tooltipBuilder = builder;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return styledText.requestLayout(null, window, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = window.withOptionalElementState(globalId, InteractiveTextState, (box, window) -> {
            if (box != null) {
                if (box.value == null)
                    box.value = new InteractiveTextState();
                final interactiveState = box.value;
                if (tooltipBuilder != null) {
                    tooltipId = Interactivity.setTooltipOnWindow(interactiveState.activeTooltip, window);
                }
                else {
                    // If there is no longer a tooltip builder, remove the active tooltip.
                    interactiveState.longPressTooltipActive.value = false;
                    interactiveState.activeTooltip.take();
                }
            }

            styledText.prepaint(null, bounds, window, cx);
            return window.insertHitbox(bounds, Normal);
        });
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final currentView = window.currentView();
        final textLayout = styledText.layout();
        final hitbox = this.hitbox;
        this.hitbox = null;
        window.withElementState(globalId, InteractiveTextState, (box, window) -> {
            if (box.value == null)
                box.value = new InteractiveTextState();
            final interactiveState = box.value;
            final clickListener = this.clickListener;
            this.clickListener = null;
            if (clickListener != null) {
                final mousePosition = window.mousePosition();
                switch textLayout.indexForPosition(mousePosition) {
                    case Ok(ix):
                        for (range in clickableRanges) {
                            if (range.contains(ix)) {
                                window.setCursorStyle(PointingHand, hitbox);
                                break;
                            }
                        }
                    case Err(_):
                }

                final mouseDown = interactiveState.mouseDownIndex;
                final mouseDownIndex = mouseDown.value;
                if (mouseDownIndex != null) {
                    final clickableRanges = this.clickableRanges;
                    this.clickableRanges = [];
                    window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
                        if (phase == Bubble && hitbox.isHovered(window)) {
                            final up:MouseUpEvent = cast event;
                            switch textLayout.indexForPosition(up.position) {
                                case Ok(mouseUpIndex):
                                    clickListener(clickableRanges, mouseDownIndex, mouseUpIndex, window, cx);
                                case Err(_):
                            }
                            mouseDown.value = null;
                            window.refresh();
                        }
                    });
                }
                else {
                    window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
                        if (phase == Bubble && hitbox.isHovered(window)) {
                            final down:MouseDownEvent = cast event;
                            switch textLayout.indexForPosition(down.position) {
                                case Ok(index):
                                    mouseDown.value = index;
                                    window.refresh();
                                case Err(_):
                            }
                        }
                    });
                }
            }

            final hoverListener = this.hoverListener;
            this.hoverListener = null;
            final hoveredIndex = interactiveState.hoveredIndex;
            window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
                if (phase == Bubble && hitbox.isHovered(window)) {
                    final move:MouseMoveEvent = cast event;
                    final current = hoveredIndex.value;
                    final updated:Null<Int> = switch textLayout.indexForPosition(move.position) {
                        case Ok(ix): ix;
                        case Err(_): null;
                    };
                    if (current != updated) {
                        hoveredIndex.value = updated;
                        if (hoverListener != null) {
                            hoverListener(updated, move, window, cx);
                        }
                        cx.notify(currentView);
                    }
                }
            });

            final tooltipBuilder = this.tooltipBuilder;
            if (tooltipBuilder != null) {
                final activeTooltip = interactiveState.activeTooltip;
                final pendingMouseDown = interactiveState.mouseDownIndex;
                final buildTooltip = (window:Window, cx:App) -> {
                    return switch textLayout.indexForPosition(window.mousePosition()) {
                        case Ok(position):
                            final view = tooltipBuilder(position, window, cx);
                            view != null ? {view: view, hoverable: false} : null;
                        case Err(_): null;
                    }
                };

                // Use bounds instead of testing hitbox since this is called during prepaint.
                final sourceBounds = hitbox.bounds;
                final checkIsHoveredDuringPrepaint = (window:Window) -> {
                    return textLayout.indexForPosition(window.mousePosition()).match(Ok(_))
                        && sourceBounds.contains(window.mousePosition())
                        && pendingMouseDown.value == null;
                };

                final checkIsHovered = (window:Window) -> {
                    return textLayout.indexForPosition(window.mousePosition()).match(Ok(_))
                        && hitbox.isHovered(window)
                        && pendingMouseDown.value == null;
                };

                Interactivity.registerTooltipMouseHandlers(activeTooltip, tooltipId, buildTooltip, checkIsHovered, checkIsHoveredDuringPrepaint, interactiveState.longPressTooltipActive, null, window);
            }

            styledText.paint(null, bounds, window, cx);
            return null;
        });
    }

}

/**
 * The state of an `InteractiveText` kept across frames.
 */
class InteractiveTextState {

    public final mouseDownIndex:Ref<Null<Int>> = new Ref(null);

    public final hoveredIndex:Ref<Null<Int>> = new Ref(null);

    public final activeTooltip:ActiveTooltipCell = new ActiveTooltipCell();

    public final longPressTooltipActive:Ref<Bool> = new Ref(false);

    public function new() {}

}

/**
 * A UTF-8 byte range `[start, end)` (Rust `Range<usize>`).
 */
class TextRange {

    public final start:Int;

    public final end:Int;

    public inline function new(start:Int, end:Int) {
        this.start = start;
        this.end = end;
    }

    public inline function contains(index:Int):Bool {
        return index >= start && index < end;
    }

}
