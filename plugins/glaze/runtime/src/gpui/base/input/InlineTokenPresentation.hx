// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.AnyElement;
import gpui.App;
import gpui.Font;
import gpui.IntoElement;
import gpui.Pixels;
import gpui.Range;
import gpui.Window;

import gpui.Prelude.*;

/**
 * Presentation shared by Base and styled controls. It owns no content.
 * The builders return a new value (Rust takes `self` by value).
 */
class InlineTokenPresentation {

    @:allow(gpui.base.input)
    final renderer:Null<InlineTokenRenderer>;

    @:allow(gpui.base.input)
    final listener:Null<InlineTokenClickListener>;

    @:allow(gpui.base.input)
    final hoverListener:Null<InlineTokenHoverListener>;

    @:allow(gpui.base.input)
    final secret:Bool;

    public function new(?renderer:InlineTokenRenderer, ?listener:InlineTokenClickListener, ?hoverListener:InlineTokenHoverListener,
            secret:Bool = false) {
        this.renderer = renderer;
        this.listener = listener;
        this.hoverListener = hoverListener;
        this.secret = secret;
    }

    public function token(render:(InlineTokenContext, Window, App) -> IntoElement):InlineTokenPresentation {
        return new InlineTokenPresentation((token, window, cx) -> render(token, window, cx).intoAnyElement(), listener, hoverListener, secret);
    }

    public function onTokenClick(listener:InlineTokenClickListener):InlineTokenPresentation {
        return new InlineTokenPresentation(renderer, listener, hoverListener, secret);
    }

    public function onTokenHover(listener:InlineTokenHoverListener):InlineTokenPresentation {
        return new InlineTokenPresentation(renderer, this.listener, listener, secret);
    }

    public inline function hasHoverListener():Bool {
        return hoverListener != null;
    }

    public inline function hasListener():Bool {
        return listener != null;
    }

    public function render(token:InlineTokenContext, window:Window, cx:App):AnyElement {
        if (renderer != null) {
            return renderer(token, window, cx);
        }
        else {
            return (div().child(token.token().label()) : IntoElement).intoAnyElement();
        }
    }

}

/**
 * The measured widths of the tokens of the visible text, kept between
 * frames.
 */
class TokenLayoutCache {

    /** Rust `Option<(Font, Pixels, Pixels, Pixels, bool)>`. */
    public var key:Null<TokenLayoutKey> = null;

    public var revision:Int = 0;

    public var unwrappedWidth:Pixels = 0.;

    /** Rust `Rc<[(Range<usize>, Pixels)]>`. */
    public var metrics:Array<TokenMetric> = [];

    /** Rust `HashMap<InlineToken, Pixels>`, keyed by `InlineToken.hashKey()`. */
    public var widths:Map<String, Pixels> = new Map();

    public function new() {}

}

/**
 * What the measured token widths depend on: the font, its size, the row
 * width, the line height, and whether rows never wrap (the single line or
 * no soft wrap flag). Rust builds it as a tuple in the element.
 */
class TokenLayoutKey {

    public final font:Font;
    public final fontSize:Pixels;
    public final width:Pixels;
    public final lineHeight:Pixels;
    public final unwrapped:Bool;

    public function new(font:Font, fontSize:Pixels, width:Pixels, lineHeight:Pixels, unwrapped:Bool) {
        this.font = font;
        this.fontSize = fontSize;
        this.width = width;
        this.lineHeight = lineHeight;
        this.unwrapped = unwrapped;
    }

    public function equals(other:Null<TokenLayoutKey>):Bool {
        return other != null && other.font.equals(font) && (other.fontSize:Float) == (fontSize:Float) && (other.width:Float) == (width:Float)
            && (other.lineHeight:Float) == (lineHeight:Float) && other.unwrapped == unwrapped;
    }

}

/** One measured token: its range and width (Rust `(Range<usize>, Pixels)`). */
class TokenMetric {

    public final range:Range;

    public final width:Pixels;

    public function new(range:Range, width:Pixels) {
        this.range = range;
        this.width = width;
    }

}
