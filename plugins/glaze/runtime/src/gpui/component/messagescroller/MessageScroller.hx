// Ported from gpui-kit 0.8.1: crates/component/src/message_scroller.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.messagescroller;

import gpui.App;
import gpui.Context;
import gpui.DefiniteLength;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.FollowMode;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.Model;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ScrollBounce;
import gpui.base.motion.Motion;
import gpui.base.motion.Transition;
import gpui.base.motion.TransitionId;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.scroll.Scrollable;

/**
 * The entity-owned scrolling state for a `MessageScroller`.
 *
 * The state owns only GPUI's virtual-list bookkeeping. Message data remains
 * with the caller and is read by the row renderer passed to
 * `new MessageScroller(...)`.
 */
class MessageScrollerState extends Model {

    @:allow(gpui.component.messagescroller, tests)
    final listState:ListState;

    /**
     * Create a state for `itemCount` rows and enable tail following.
     *
     * The constructor receives the entity context so the list's scroll
     * handler can safely defer its entity update until GPUI has released the
     * list's internal borrow.
     */
    public function new(itemCount:Int, cx:Context<MessageScrollerState>) {
        super();
        listState = new ListState(itemCount, ListAlignment.Top, MessageScroller.LIST_OVERDRAW);
        listState.setFollowMode(FollowMode.Tail);

        final weakState = cx.weakEntity();
        listState.setScrollHandler((_, _, cx) -> {
            cx.defer(cx -> {
                weakState.update(cx, (_, cx) -> cx.notify());
            });
        });
    }

    /** Return the current number of rows known by the virtual list. */
    public function itemCount():Int {
        return listState.itemCount();
    }

    /** Return whether the user has scrolled away from the latest content. */
    public function isScrolledUp():Bool {
        final scrolledToEnd = listState.isScrolledToEnd();
        return listState.maxOffsetForScrollbar().y > 0.
            && !listState.isFollowingTail()
            && !(scrolledToEnd != null && scrolledToEnd);
    }

    /** Return whether the list is actively following its tail. */
    public function isFollowingTail():Bool {
        return listState.isFollowingTail();
    }

    /**
     * Return the row at the top of the viewport and how far into it the list
     * is scrolled.
     *
     * Wheel, trackpad, and scrollbar scrolls and `scrollToItem` update it at
     * once. `scrollToEnd` and tail following settle it when the list next
     * lays out; right after `scrollToEnd`, `itemIx` is `itemCount()` until
     * then.
     */
    public function logicalScrollTop():ListOffset {
        return listState.logicalScrollTop();
    }

    /** Reset the list to `itemCount` rows. */
    public function reset(itemCount:Int, cx:Context<MessageScrollerState>):Void {
        listState.reset(itemCount);
        listState.setFollowMode(FollowMode.Tail);
        cx.notify();
    }

    /**
     * Replace the rows `oldStart..oldEnd` with `count` new rows.
     *
     * Returns `false` when the range is outside the current list and leaves
     * the state unchanged.
     */
    public function splice(oldStart:Int, oldEnd:Int, count:Int, cx:Context<MessageScrollerState>):Bool {
        if (!validRange(oldStart, oldEnd)) {
            return false;
        }

        final neighbor:Null<Int> = oldStart >= 1 ? oldStart - 1 : null;
        final touchesStart = oldStart == 0;
        listState.splice(oldStart, oldEnd, count);

        // The default row wrapper pads every row except the last, so a row
        // whose "last" status may have flipped carries a stale measured
        // height. Remeasure the new last row and the survivor next to the
        // splice.
        if (listState.itemCount() >= 1) {
            final last = listState.itemCount() - 1;
            listState.remeasureItems(last, last + 1);
            if (neighbor != null && neighbor != last) {
                listState.remeasureItems(neighbor, neighbor + 1);
            }
        }

        // A surviving former first row may have lost its list inset, or a
        // surviving row may have become the first after a removal.
        if (touchesStart) {
            for (index in [0, count]) {
                if (index < listState.itemCount()) {
                    listState.remeasureItems(index, index + 1);
                }
            }
        }

        cx.notify();
        return true;
    }

    /** Append `count` rows to the end of the list. */
    public function append(count:Int, cx:Context<MessageScrollerState>):Bool {
        final itemCount = listState.itemCount();
        return splice(itemCount, itemCount, count, cx);
    }

    /** Prepend `count` rows while preserving the current scroll anchor. */
    public function prepend(count:Int, cx:Context<MessageScrollerState>):Bool {
        return splice(0, 0, count, cx);
    }

    /** Mark all rows for remeasurement while preserving a proportional anchor. */
    public function remeasure(cx:Context<MessageScrollerState>):Void {
        listState.remeasure();
        cx.notify();
    }

    /**
     * Mark the rows `start..end` for remeasurement while preserving an item
     * anchor.
     *
     * Returns `false` when the range is outside the current list.
     */
    public function remeasureItems(start:Int, end:Int, cx:Context<MessageScrollerState>):Bool {
        if (!validRange(start, end)) {
            return false;
        }

        listState.remeasureItems(start, end);
        cx.notify();
        return true;
    }

    /** Scroll to the row at `index`, if it exists. */
    public function scrollToItem(index:Int, cx:Context<MessageScrollerState>):Bool {
        if (index < 0 || index >= listState.itemCount()) {
            return false;
        }

        listState.scrollTo(new ListOffset(index, 0.));
        cx.notify();
        return true;
    }

    /** Resume tail following and scroll to the latest row. */
    public function scrollToEnd(cx:Context<MessageScrollerState>):Void {
        listState.setFollowMode(FollowMode.Tail);
        listState.scrollToEnd();
        cx.notify();
    }

    function validRange(start:Int, end:Int):Bool {
        return start >= 0 && start <= end && end <= listState.itemCount();
    }

}

/**
 * A virtualized message list with optional scrollbar and jump-to-latest UI.
 */
class MessageScroller implements RenderOnce implements Styled {

    @:allow(gpui.component.messagescroller)
    static inline final LIST_OVERDRAW:Pixels = 400.;

    /** Seconds (Rust `Duration::from_millis(200)`). */
    static inline final JUMP_BUTTON_TRANSITION:Float = 0.2;

    /** Seconds (Rust `Duration::from_millis(200)`). */
    static inline final BOTTOM_FADE_TRANSITION:Float = 0.2;

    final id:ElementId;

    final state:Entity<MessageScrollerState>;

    final renderer:(Int, Window, App) -> IntoElement;

    final scrollerStyle:StyleRefinement = new StyleRefinement();

    var contentStyle:StyleRefinement = new StyleRefinement();

    var listStyle:StyleRefinement = new StyleRefinement();

    var rowStyle:StyleRefinement = new StyleRefinement();

    var jumpButtonStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var jumpButtonRenderer:Null<(Button) -> Button> = null;

    /** Seconds. */
    @:allow(tests)
    var jumpButtonTransition:Float = JUMP_BUTTON_TRANSITION;

    @:allow(tests)
    var bottomFade:Null<Hsla> = null;

    @:allow(tests)
    var scrollbarValue:Bool = true;

    @:allow(tests)
    var jumpButtonValue:Bool = true;

    @:allow(tests)
    var jumpButtonLabel:String = 'Jump to latest';

    /** Create a message scroller with a renderer for each row. */
    public function new(id:ElementIdArg, state:Entity<MessageScrollerState>, renderer:(Int, Window, App) -> IntoElement) {
        this.id = id;
        this.state = state;
        this.renderer = renderer;
    }

    /** Enable or disable the virtual-list scrollbar. */
    public function scrollbar(scrollbar:Bool):MessageScroller {
        scrollbarValue = scrollbar;
        return this;
    }

    /** Enable or disable the built-in jump-to-latest button. */
    public function jumpButton(jumpButton:Bool):MessageScroller {
        jumpButtonValue = jumpButton;
        return this;
    }

    /** Set the label used by the built-in jump-to-latest button. */
    public function withJumpButtonLabel(label:String):MessageScroller {
        jumpButtonLabel = label;
        return this;
    }

    /** Refine the viewport that contains the list and scrollbar. */
    public function withContentStyle(style:StyleRefinement):MessageScroller {
        contentStyle = style;
        return this;
    }

    /** Refine the GPUI list element used to render rows. */
    public function withListStyle(style:StyleRefinement):MessageScroller {
        listStyle = style;
        return this;
    }

    /** Refine the full-width wrapper around every rendered row. */
    public function withRowStyle(style:StyleRefinement):MessageScroller {
        rowStyle = style;
        return this;
    }

    /** Refine the built-in jump-to-latest button after its defaults. */
    public function withJumpButtonStyle(style:StyleRefinement):MessageScroller {
        jumpButtonStyle = style;
        return this;
    }

    /**
     * Customize the built-in jump button without replacing its scroll action.
     *
     * The callback receives the fully configured Button, so its variant,
     * semantic size, icon, tooltip, or instance styling may be adjusted.
     */
    public function withJumpButtonRenderer(renderer:(Button) -> Button):MessageScroller {
        jumpButtonRenderer = renderer;
        return this;
    }

    /**
     * Set how long the built-in jump button takes to enter or leave, in
     * seconds.
     *
     * A zero duration disables its transition. Reduced-motion preferences
     * always adopt the final state immediately.
     */
    public function withJumpButtonTransition(duration:Float):MessageScroller {
        jumpButtonTransition = duration;
        return this;
    }

    /**
     * Fade the transcript's bottom edge into `color`.
     *
     * A partially visible row melts into the surface behind the scroller
     * instead of clipping mid-line. The fade shows only while the reader is
     * away from the live edge: at the bottom nothing is clipped. Pass the
     * color of that surface; the fade is off by default and sits under the
     * jump button.
     */
    public function withBottomFade(color:IntoHsla):MessageScroller {
        bottomFade = color;
        return this;
    }

    public inline function style():StyleRefinement {
        return scrollerStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final rootId = id;
        final scrollerState = state.read(cx);
        final listState = scrollerState.listState;
        final scrolledUp = scrollerState.isScrolledUp();
        final showJumpButton = jumpButtonValue && scrolledUp;
        final jumpButtonVisibility = if (jumpButtonValue) {
            Motion.transition(
                TransitionId.named(rootId, 'jump-button-visibility'),
                showJumpButton ? 1. : 0.,
                new Transition(jumpButtonTransition),
                window,
                cx
            );
        } else {
            0.;
        }
        // At the live edge nothing is clipped below, so a visible fade would
        // suggest more content than there is.
        final bottomFadeVisibility = if (bottomFade != null) {
            Motion.transition(
                TransitionId.named(rootId, 'bottom-fade-visibility'),
                scrolledUp ? 1. : 0.,
                new Transition(BOTTOM_FADE_TRANSITION),
                window,
                cx
            );
        } else {
            0.;
        }
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        final rowStyle = this.rowStyle;
        final renderer = this.renderer;

        // GPUI's `list` lays rows out at the full list width and offsets them
        // only by vertical padding, so the horizontal component of the list
        // style must be carried by every row wrapper instead.
        //
        // The vertical padding rides on the rows as well. A list measures its
        // scroll extent from its items alone, so a list that carries padding
        // of its own reports a scroll range that stops short of its end: the
        // scrollbar thumb can never reach the last row, the tail never
        // resumes, and the list never reports itself as scrolled to the end.
        // Padding on the rows is part of the content, so the extent covers
        // it.
        //
        // Rust takes the padding out of its own (moved) refinement: the port
        // works on a copy, so the caller's refinement is left as it was.
        final listStyle = this.listStyle.clone();
        final rowInsetLeft:Null<DefiniteLength> = listStyle.paddingLeft;
        listStyle.paddingLeft = null;
        final rowInsetRight:Null<DefiniteLength> = listStyle.paddingRight;
        listStyle.paddingRight = null;
        final rowInsetTop:Null<DefiniteLength> = listStyle.paddingTop;
        listStyle.paddingTop = null;
        final rowInsetBottom:Null<DefiniteLength> = listStyle.paddingBottom;
        listStyle.paddingBottom = null;

        // Read the count outside the row closure: the count is stable within
        // one render pass.
        final itemCount = listState.itemCount();
        final listElement = list(listState, (index, window, cx) -> {
            final row = div().wFull();
            if (index == 0) {
                if (rowInsetTop != null) row.pt(rowInsetTop) else row.pt2();
            }
            if (index + 1 == itemCount) {
                if (rowInsetBottom != null) row.pb(rowInsetBottom) else row.pb2();
            }
            final inner = div()
                .wFull()
                .minW0()
                .px3();
            if (index + 1 < itemCount) inner.pb8();
            if (rowInsetLeft != null) inner.pl(rowInsetLeft);
            if (rowInsetRight != null) inner.pr(rowInsetRight);
            inner.refineStyle(rowStyle).child(renderer(index, window, cx));
            return row.child(inner);
        })
            .sizeFull()
            .minH0()
            .refineStyle(listStyle);

        final stateEntity = state;
        final viewport = div()
            .id(ElementId.NamedChild(rootId, 'viewport'))
            // Rust announces appended rows as a log region (`.role(Role::Log)`,
            // like shadcn's `role="log"` transcript content); the port has no
            // accessibility tree.
            .sizeFull()
            .minH0()
            .minW0()
            .child(
                // The bounce scrolls the list itself, past the list's own
                // scroll handler; tell the state, as that handler would.
                new ScrollBounce(ElementId.NamedChild(rootId, 'bounce'), listState, listElement)
                    .onScroll((_, cx) -> {
                        stateEntity.update(cx, (_, cx) -> cx.notify());
                    })
            );
        // The fade sits above the rows but below the scrollbar and the jump
        // button, so neither control is washed out by it.
        if (bottomFade != null && bottomFadeVisibility > 0.) {
            final color:Hsla = bottomFade;
            viewport.child(
                div()
                    .absolute()
                    .left0()
                    .right0()
                    .bottom0()
                    .h(rems(3.))
                    .opacity(bottomFadeVisibility)
                    .bg(linearGradient(
                        180.,
                        linearColorStop(color.opacity(0.), 0.),
                        linearColorStop(color, 1.)
                    ))
            );
        }
        if (scrollbarValue) viewport.verticalScrollbar(listState);
        viewport.refineStyle(contentStyle);

        final root = div()
            .id(rootId)
            .relative()
            .sizeFull()
            .minH0()
            .overflowHidden()
            .child(viewport);
        if (jumpButtonValue && jumpButtonVisibility > 0.) {
            // No explicit width or height: Button sizes an icon-only button
            // as a square on its own, and a renderer that adds a label or
            // another semantic size must be able to change the layout.
            var button = new Button(ElementId.NamedChild(rootId, 'jump-to-latest'))
                .secondary()
                .icon(IconName.ArrowDown)
                .tooltip(jumpButtonLabel)
                .rounded(theme.radiusFull())
                .border1()
                .borderColor(tokens.colors.border)
                .bg(tokens.colors.background)
                .textColor(tokens.colors.foreground)
                .refineStyle(jumpButtonStyle)
                .onClick((_, _, cx) -> {
                    stateEntity.update(cx, (state, cx) -> state.scrollToEnd(cx));
                });
            if (jumpButtonRenderer != null) button = jumpButtonRenderer(button);
            if (!showJumpButton) button = button.disabled(true);
            root.child(
                div()
                    .absolute()
                    .left0()
                    .right0()
                    .bottom(rems(0.5 + jumpButtonVisibility * 0.5))
                    .flex()
                    .justifyCenter()
                    .opacity(jumpButtonVisibility)
                    .child(button)
            );
        }
        root.refineStyle(scrollerStyle);
        return root;
    }

}
