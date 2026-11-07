// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import glaze.util.Utf8;

using unicode_segmentation.UnicodeSegmentation;

/**
 * An owned, coherent text-and-token snapshot: what `content()` returns and
 * what `setValue` accepts. Plain text converts into content without tokens
 * (`InputContent.fromText`, or implicitly through `IntoInputContent`), and
 * every token is validated against the text as it is attached, so a content
 * value is always consistent.
 */
class InputContent {

    @:allow(glaze.kit.base.input)
    final _text:String;

    @:allow(glaze.kit.base.input)
    final _tokens:Array<InlineTokenSpan>;

    public function new(text:String) {
        this._text = text;
        this._tokens = [];
    }

    @:allow(glaze.kit.base.input)
    static function withSpans(text:String, tokens:Array<InlineTokenSpan>):InputContent {
        final content = new InputContent(text);
        for (span in tokens) content._tokens.push(span);
        return content;
    }

    /**
     * Attach a token to a half-open UTF-8 byte range of the text. The range
     * must be nonempty, sit on grapheme boundaries, contain exactly the
     * token's text and not overlap another token. Returns a new content;
     * throws an `InlineTokenException` where Rust returns an `Err`.
     */
    public function withToken(range:Range, token:InlineToken):InputContent {
        var error = token.validate();
        if (error == null) error = validateRange(_text, range);
        if (error == null && range.isEmpty()) error = InlineTokenError.InvalidRange;
        if (error == null && Utf8.substring(_text, range.start, range.end) != token.text()) error = InlineTokenError.TextMismatch;
        if (error != null) {
            throw new InlineTokenException(error);
        }
        var ix = 0;
        while (ix < _tokens.length && _tokens[ix]._range.end <= range.start) ix++;
        if (ix < _tokens.length && _tokens[ix]._range.start < range.end) {
            throw new InlineTokenException(InlineTokenError.OverlappingTokens);
        }
        final next = withSpans(_text, _tokens);
        next._tokens.insert(ix, new InlineTokenSpan(range, token));
        return next;
    }

    public inline function text():String {
        return _text;
    }

    public inline function tokens():Array<InlineTokenSpan> {
        return _tokens;
    }

    /** Rust `From<&str>` (and the other text types) for `InputContent`. */
    public static inline function fromText(text:String):InputContent {
        return new InputContent(text);
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<InputContent>):Bool {
        return other != null && other._text == _text && InlineTokenSpan.sameAll(other._tokens, _tokens);
    }

    /** The validation error of a range of `text`, or null when it is valid. */
    @:allow(glaze.kit.base.input)
    static function validateRange(text:String, range:Range):Null<InlineTokenError> {
        final len = Utf8.byteLength(text);
        if (range.start > range.end || range.end > len) {
            return InlineTokenError.InvalidRange;
        }
        inline function boundary(offset:Int):Bool {
            var found = offset == len;
            if (!found) {
                final iter = text.graphemeIndices(true);
                while (iter.nextRange()) {
                    if (iter.index == offset) {
                        found = true;
                        break;
                    }
                }
            }
            return found;
        }
        if (!boundary(range.start) || !boundary(range.end)) {
            return InlineTokenError.InvalidBoundary;
        }
        return null;
    }

}

/**
 * Rust `impl Into<InputContent>`: an `InputContent`, or any text.
 */
@:forward
abstract IntoInputContent(InputContent) from InputContent to InputContent {

    @:from static inline function fromString(text:String):IntoInputContent {
        return new InputContent(text);
    }

}
