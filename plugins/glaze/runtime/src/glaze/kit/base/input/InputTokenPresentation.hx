// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Pixels;
import glaze.Range;

using glaze.kit.base.input.InputTokens;
using glaze.kit.base.input.RopeExt;

/**
 * A listener with the event to hand it (Rust `(Listener, Event)`).
 */
class TokenClickActivation {

    public final listener:InlineTokenClickListener;

    public final event:InlineTokenClickEvent;

    public inline function new(listener:InlineTokenClickListener, event:InlineTokenClickEvent) {
        this.listener = listener;
        this.event = event;
    }

}

/**
 * A hover listener with the event to hand it (Rust `(Listener, Event)`).
 */
class TokenHoverActivation {

    public final listener:InlineTokenHoverListener;

    public final event:InlineTokenHoverEvent;

    public inline function new(listener:InlineTokenHoverListener, event:InlineTokenHoverEvent) {
        this.listener = listener;
        this.event = event;
    }

}

/**
 * Token presentation of the input engine: the `impl InputBaseState` block
 * of token_presentation.rs, as static extensions
 * (`using glaze.kit.base.input.InputTokenPresentation;`). None of this enters
 * document history.
 */
class InputTokenPresentation {

    /** Inject presentation from a view without editing or notifying the document. */
    public static function setTokenPresentation(self:InputBaseState, presentation:InlineTokenPresentation):Void {
        self.tokenPresentation = presentation;
    }

    /**
     * Install a styled control's renderer, click listener and secrecy
     * without editing or notifying the document. Not part of the supported
     * API.
     */
    public static function installTokenPresentation(self:InputBaseState, renderer:Null<InlineTokenRenderer>, listener:Null<InlineTokenClickListener>,
            secret:Bool):Void {
        self.tokenPresentation = new InlineTokenPresentation(renderer, listener, self.tokenPresentation.hoverListener, secret);
    }

    /**
     * Install a styled control's token hover listener without editing or
     * notifying the document. Not part of the supported API.
     */
    public static function installTokenHoverPresentation(self:InputBaseState, hoverListener:Null<InlineTokenHoverListener>):Void {
        final presentation = self.tokenPresentation;
        self.tokenPresentation = new InlineTokenPresentation(presentation.renderer, presentation.listener, hoverListener, presentation.secret);
    }

    public static function tokensVisible(self:InputBaseState):Bool {
        return !self.masked && !self.tokenPresentation.secret && self.maskPattern.isNone() && self.tokenSpans().length > 0;
    }

    public static function tokenContext(self:InputBaseState, span:InlineTokenSpan, lineHeight:Pixels, width:Pixels):InlineTokenContext {
        final range = span.range();
        final selection = self.selectedRange();
        return new InlineTokenContext(span, selection.start < range.end && range.start < selection.end, self.disabled, self.readonly, lineHeight,
            width);
    }

    /** The token starting at `start`, paired with the listener that opens it. */
    public static function tokenActivation(self:InputBaseState, start:Int, bounds:Bounds, event:ClickEvent):Null<TokenClickActivation> {
        if (self.disabled || !tokensVisible(self)) {
            return null;
        }
        var span:Null<InlineTokenSpan> = null;
        for (s in self.tokenSpans()) {
            if (s.range().start == start) {
                span = s;
                break;
            }
        }
        if (span == null) return null;
        final listener = self.tokenPresentation.listener;
        if (listener == null) return null;
        return new TokenClickActivation(listener, new InlineTokenClickEvent(span, bounds, event));
    }

    /**
     * The token starting at `start`, paired with the hover listener.
     * Disabled tokens never enter; existing hover still receives its exit.
     * Readonly tokens report hover.
     *
     * Records and clears the retained hover snapshot used for exit
     * reconciliation. An exit only clears the snapshot when it belongs to the
     * exiting token: GPUI dispatches a newly entered token before the exit of
     * the token the pointer left, so an older exit must not drop the newer
     * token's snapshot.
     */
    public static function tokenHover(self:InputBaseState, start:Int, bounds:Bounds, hovered:Bool, expectedToken:Null<InlineToken>):Null<TokenHoverActivation> {
        final listener = self.tokenPresentation.hoverListener;
        if (listener == null) return null;
        inline function matches(snapshot:HoverSnapshot):Bool {
            return snapshot.span.range().start == start && (expectedToken == null || snapshot.span.token().equals(expectedToken));
        }
        var snapshot:HoverSnapshot;
        if (hovered) {
            if (self.disabled || !tokensVisible(self)) {
                return null;
            }
            var span:Null<InlineTokenSpan> = null;
            for (s in self.tokenSpans()) {
                if (s.range().start == start && (expectedToken == null || s.token().equals(expectedToken))) {
                    span = s;
                    break;
                }
            }
            if (span == null) return null;
            if (self.hoveredToken != null && self.hoveredToken.span.equals(span)) {
                return null;
            }
            final range = span.range();
            snapshot = new HoverSnapshot(span, bounds, new Range(self.text.offsetToOffsetUtf16(range.start), self.text.offsetToOffsetUtf16(range.end)));
            final previous = self.hoveredToken;
            self.hoveredToken = snapshot;
            if (previous != null) {
                self.pendingTokenHoverExits.push(previous);
            }
        }
        else if (self.hoveredToken != null && matches(self.hoveredToken)) {
            snapshot = self.hoveredToken;
            self.hoveredToken = null;
        }
        else {
            var index = -1;
            for (i in 0...self.pendingTokenHoverExits.length) {
                if (matches(self.pendingTokenHoverExits[i])) {
                    index = i;
                    break;
                }
            }
            if (index == -1) return null;
            snapshot = self.pendingTokenHoverExits.splice(index, 1)[0];
        }
        return new TokenHoverActivation(listener, new InlineTokenHoverEvent(snapshot.span, snapshot.bounds, hovered, snapshot.rangeUtf16));
    }

    /**
     * Deliver exits from entry snapshots, even after edits or callback
     * reentry remove the token. Keep predecessors until their mouse exit is
     * dispatched.
     */
    public static function reconcileTokenHover(self:InputBaseState):Null<TokenHoverActivation> {
        function isPlaced(snapshot:HoverSnapshot):Bool {
            if (self.disabled || !tokensVisible(self) || !self.tokenPresentation.hasHoverListener()
                || !self.tokenBounds.exists(snapshot.span.range().start)) {
                return false;
            }
            for (s in self.tokenSpans()) {
                if (s.equals(snapshot.span)) return true;
            }
            return false;
        }
        var snapshot:Null<HoverSnapshot> = null;
        var index = -1;
        for (i in 0...self.pendingTokenHoverExits.length) {
            if (!isPlaced(self.pendingTokenHoverExits[i])) {
                index = i;
                break;
            }
        }
        if (index != -1) {
            snapshot = self.pendingTokenHoverExits.splice(index, 1)[0];
        }
        else if (self.hoveredToken != null && !isPlaced(self.hoveredToken)) {
            snapshot = self.hoveredToken;
            self.hoveredToken = null;
        }
        else {
            return null;
        }
        final listener = self.tokenPresentation.hoverListener;
        if (listener == null) return null;
        return new TokenHoverActivation(listener, new InlineTokenHoverEvent(snapshot.span, snapshot.bounds, false, snapshot.rangeUtf16));
    }

    public static function tokenIsSecret(self:InputBaseState):Bool {
        return self.tokenPresentation.secret;
    }

}
