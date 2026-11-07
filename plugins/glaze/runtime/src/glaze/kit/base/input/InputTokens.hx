// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Context;
import gpui.Range;
import gpui.Window;
import gpui.util.Utf8;

/**
 * Document annotations for atomic inline objects: the `impl InputBaseState`
 * blocks of inline_tokens.rs, as static extensions
 * (`using gpui.base.input.InputTokens;`). Coordinates are always source
 * bytes.
 *
 * The public token API (Rust `token_api!`, on `InputState` and
 * `TextareaState` only) is `replaceWithToken`, `replaceRangeWithToken`,
 * `tokens` and `content`: the state subclasses forward to them. Where Rust
 * returns `Result<(), InlineTokenError>`, these return the error or null.
 */
class InputTokens {

    public static function tokenSpans(self:InputBaseState):Array<InlineTokenSpan> {
        final store = self.inlineTokens;
        return store != null ? store.spans : [];
    }

    public static function tokenBoundary(self:InputBaseState, offset:Int, bias:Bias):Int {
        final spans = tokenSpans(self);
        var ix = 0;
        while (ix < spans.length && spans[ix]._range.end <= offset) ix++;
        if (ix < spans.length && spans[ix]._range.start < offset) {
            final span = spans[ix];
            return bias == Bias.Left ? span._range.start : span._range.end;
        }
        else {
            return offset;
        }
    }

    public static function normalizeTokenRange(self:InputBaseState, range:Range):Range {
        if (self.replayingHistory) {
            return range;
        }
        if (range.isEmpty()) {
            final offset = tokenBoundary(self, range.start, Bias.Right);
            return new Range(offset, offset);
        }
        else {
            return new Range(tokenBoundary(self, range.start, Bias.Left), tokenBoundary(self, range.end, Bias.Right));
        }
    }

    public static function editTokens(self:InputBaseState, range:Range, newLen:Int):Null<TokenDelta> {
        if (self.replayingHistory) {
            return null;
        }
        final token = self.pendingToken;
        self.pendingToken = null;
        final inserted = token != null ? [new InlineTokenSpan(new Range(0, newLen), token)] : [];
        if (inserted.length > 0 && self.inlineTokens == null) {
            self.inlineTokens = new InlineTokenStore();
        }
        final store = self.inlineTokens;
        if (store == null) {
            return null;
        }
        return store.replace(range, newLen, inserted);
    }

    public static function replayTokens(self:InputBaseState, range:Range, newLen:Int, delta:Null<TokenDelta>, undo:Bool):Void {
        final inserted = delta != null ? (undo ? delta.removed : delta.inserted) : [];
        if (inserted.length > 0 && self.inlineTokens == null) {
            self.inlineTokens = new InlineTokenStore();
        }
        final store = self.inlineTokens;
        if (store != null) {
            store.replace(range, newLen, inserted);
        }
    }

    static function checkTokenMode(self:InputBaseState):Null<InlineTokenError> {
        if (self.imeMarkedRange != null) {
            return InlineTokenError.CompositionActive;
        }
        if (self.modeKind.codeEditor() || self.masked || InputTokenPresentation.tokenIsSecret(self) || !self.maskPattern.isNone()) {
            return InlineTokenError.UnsupportedMode;
        }
        return null;
    }

    static function replaceToken(self:InputBaseState, range:Range, token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        var error = checkTokenMode(self);
        if (error != null) return error;
        error = token.validate();
        if (error != null) return error;
        final text = self.text.toString();
        error = InputContent.validateRange(text, range);
        if (error != null) return error;
        final range = normalizeTokenRange(self, range);
        // `String::replace_range`
        final next = Utf8.substring(text, 0, range.start) + token.text() + Utf8.substringFrom(text, range.end);
        error = InputContent.validateRange(next, new Range(range.start, range.start + Utf8.byteLength(token.text())));
        if (error != null) return error;
        if (self.normalizeInput(next) != next) {
            return InlineTokenError.TextMismatch;
        }
        if (!self.isValidInput(next, cx)) {
            return InlineTokenError.ValidationRejected;
        }
        for (s in tokenSpans(self)) {
            if (s._range.equals(range) && s._token.equals(token)) {
                return null;
            }
        }
        final newText = token.text();
        self.pendingToken = token;
        self.undoManager.breakTransactionCoalescing();
        self.undoManager.setPendingIntent(EditIntent.Atomic);
        final rangeUtf16 = self.rangeToUtf16(range);
        self.validatedTokenEdit = true;
        self.withEditsAllowed(state -> state.replaceTextInRange(rangeUtf16, newText, window, cx));
        self.validatedTokenEdit = false;
        self.pendingToken = null;
        return null;
    }

    /**
     * Adopt the tokens of content whose text was just installed by
     * `setValue`. Tokens are dropped when this mode cannot show them or when
     * normalization changed the text, since their ranges would no longer
     * describe it.
     */
    public static function installTokens(self:InputBaseState, content:InputContent):Void {
        final supported = !self.modeKind.codeEditor() && self.maskPattern.isNone();
        final textKept = self.text.equalsStr(content._text);
        self.inlineTokens = (supported && textKept && content._tokens.length > 0) ? new InlineTokenStore(content._tokens.copy()) : null;
    }

    // Rust `token_api!` (InputState and TextareaState)

    /** Replace the selection with an atomic token; no delimiter is added. */
    public static function replaceWithToken(self:InputBaseState, token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        return replaceToken(self, self.selectedRange(), token, window, cx);
    }

    /** Replace a UTF-8 byte range, expanding overlaps to whole tokens. */
    public static function replaceRangeWithToken(self:InputBaseState, range:Range, token:InlineToken, window:Window,
            cx:Context<InputBaseState>):Null<InlineTokenError> {
        return replaceToken(self, range, token, window, cx);
    }

    public static function tokens(self:InputBaseState):Array<InlineTokenSpan> {
        return tokenSpans(self);
    }

    /** The text with its tokens, as `setValue` accepts it. */
    public static function content(self:InputBaseState):InputContent {
        return InputContent.withSpans(self.value(), tokenSpans(self));
    }

}
