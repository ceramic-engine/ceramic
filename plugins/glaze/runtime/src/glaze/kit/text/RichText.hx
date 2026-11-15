// New code for the Haxe port of gpui-kit (no gpui-kit origin): the rich text component of the kit (G12), a
// public face of the paragraph engine the markdown view uses (`glaze.kit.base.text.InlineFlow`). See NOTICE.md.
package glaze.kit.text;

import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FontFeatures;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.Range;
import glaze.StrikethroughStyle;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.TextAlign;
import glaze.TextStyleRefinement;
import glaze.Transformation;
import glaze.UnderlineStyle;
import glaze.Window;
import glaze.kit.base.text.InlineElement;
import glaze.kit.base.text.InlineFlow;
import glaze.kit.base.text.InlineFlow.InlineFlowItem;
import glaze.kit.base.text.InlineHighlight;
import glaze.kit.base.text.InlineMotion;
import glaze.kit.base.text.InlineMotion.InlineAnimation;
import glaze.kit.base.text.InlineMotion.InlineTextTransform;
import glaze.kit.base.text.InlineNode.SharedFlag;
import glaze.kit.base.text.InlineState;
import glaze.kit.base.text.LinkMark;
import glaze.kit.base.text.RangedHighlight;
import glaze.kit.base.text.RangedLink;
import glaze.util.Utf8;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/** The font size of a span. */
enum RichFontSize {

    /** In pixels. */
    Absolute(size:Pixels);

    /** A part of the paragraph's font size (`1.2` for 120 %). */
    Relative(scale:Float);

}

/** A length that follows the text or not. */
enum RichLength {

    /** In pixels. */
    Absolute(length:Pixels);

    /** In em of the span's own font size. */
    Em(em:Float);

}

/** How the white space of the spans is treated. */
enum abstract RichWhiteSpace(Int) {

    /** Runs of spaces and newlines become one space; lines wrap between words. */
    var Normal = 0;

    /** Spaces and newlines are kept; lines wrap between words. */
    var PreWrap;

    /** Runs of spaces and newlines become one space; lines do not wrap. */
    var NoWrap;

}

/** The case a span is shown in: `None`, `Uppercase`, `Lowercase`, `Capitalize`. */
typedef TextTransform = InlineTextTransform;

/**
 * The animation of a span: keyframes of `MotionTransform` and a `Timing`
 * (`glaze.kit.base.motion`), for the whole span (`perRun()`, the default) or
 * for each of its characters (`perCharacter(stagger)`). See
 * `InlineAnimation`.
 */
typedef RichTextAnimation = InlineAnimation;

/**
 * The style of a span. Every field is optional: one left unset is
 * inherited from the paragraph (the text style around the `RichText`).
 * The setters change the style and return it; `merge` makes a new one.
 */
@:allow(glaze.kit.text)
class RichTextStyle {

    var fontFamilyValue:Null<String> = null;
    var fontWeightValue:Null<FontWeight> = null;
    var fontStyleValue:Null<FontStyle> = null;
    var fontFeaturesValue:Null<FontFeatures> = null;
    var fontSizeValue:Null<RichFontSize> = null;
    var colorValue:Null<Hsla> = null;
    var opacityValue:Null<Float> = null;
    var backgroundValue:Null<Hsla> = null;
    var underlineValue:Null<UnderlineStyle> = null;
    var strikethroughValue:Null<StrikethroughStyle> = null;
    var letterSpacingValue:Null<RichLength> = null;
    var textTransformValue:Null<TextTransform> = null;
    var boxValue:Null<StyleRefinement> = null;
    var linkValue:Null<String> = null;
    var transformationValue:Null<Transformation> = null;
    var animationValue:Null<RichTextAnimation> = null;

    public function new() {}

    public function fontFamily(family:String):RichTextStyle {
        fontFamilyValue = family;
        return this;
    }

    public function fontWeight(weight:FontWeight):RichTextStyle {
        fontWeightValue = weight;
        return this;
    }

    public function fontStyle(style:FontStyle):RichTextStyle {
        fontStyleValue = style;
        return this;
    }

    public function fontFeatures(features:FontFeatures):RichTextStyle {
        fontFeaturesValue = features;
        return this;
    }

    /** The font size, absolute or relative to the paragraph's. */
    public function fontSize(size:RichFontSize):RichTextStyle {
        fontSizeValue = size;
        return this;
    }

    public function color(color:Hsla):RichTextStyle {
        colorValue = color;
        return this;
    }

    /** The opacity of the text, of its decorations and of its box. */
    public function opacity(opacity:Float):RichTextStyle {
        opacityValue = opacity;
        return this;
    }

    /** A background behind the text, as tall as its line (the fill of the box when there is one). */
    public function background(color:Hsla):RichTextStyle {
        backgroundValue = color;
        return this;
    }

    public function underline(style:UnderlineStyle):RichTextStyle {
        underlineValue = style;
        return this;
    }

    public function strikethrough(style:StrikethroughStyle):RichTextStyle {
        strikethroughValue = style;
        return this;
    }

    /** Space added after each character. */
    public function letterSpacing(spacing:RichLength):RichTextStyle {
        letterSpacingValue = spacing;
        return this;
    }

    public function textTransform(transform:TextTransform):RichTextStyle {
        textTransformValue = transform;
        return this;
    }

    /**
     * A box around the span: the background, border, corner radii, paddings
     * and horizontal margins of `box` (`StyleBuilder.build(s -> s.px1().rounded(px(4)).border1())`).
     * A boxed span is never broken across lines.
     */
    public function box(box:StyleRefinement):RichTextStyle {
        boxValue = box;
        return this;
    }

    /** Makes the span a link to `url` (see `RichText.onLinkClick`). */
    public function link(url:String):RichTextStyle {
        linkValue = url;
        return this;
    }

    /** A fixed transformation of the span, which does not move the text around it. */
    public function transformation(transformation:Transformation):RichTextStyle {
        transformationValue = transformation;
        return this;
    }

    public function animation(animation:RichTextAnimation):RichTextStyle {
        animationValue = animation;
        return this;
    }

    public function clone():RichTextStyle {
        return new RichTextStyle().apply(this);
    }

    /** A new style: this one with the fields `other` sets laid over it. */
    public function merge(other:Null<RichTextStyle>):RichTextStyle {
        return clone().apply(other);
    }

    function apply(other:Null<RichTextStyle>):RichTextStyle {
        if (other == null) return this;
        if (other.fontFamilyValue != null) fontFamilyValue = other.fontFamilyValue;
        if (other.fontWeightValue != null) fontWeightValue = other.fontWeightValue;
        if (other.fontStyleValue != null) fontStyleValue = other.fontStyleValue;
        if (other.fontFeaturesValue != null) fontFeaturesValue = other.fontFeaturesValue;
        if (other.fontSizeValue != null) fontSizeValue = other.fontSizeValue;
        if (other.colorValue != null) colorValue = other.colorValue;
        if (other.opacityValue != null) opacityValue = other.opacityValue;
        if (other.backgroundValue != null) backgroundValue = other.backgroundValue;
        if (other.underlineValue != null) underlineValue = other.underlineValue;
        if (other.strikethroughValue != null) strikethroughValue = other.strikethroughValue;
        if (other.letterSpacingValue != null) letterSpacingValue = other.letterSpacingValue;
        if (other.textTransformValue != null) textTransformValue = other.textTransformValue;
        if (other.boxValue != null) boxValue = other.boxValue;
        if (other.linkValue != null) linkValue = other.linkValue;
        if (other.transformationValue != null) transformationValue = other.transformationValue;
        if (other.animationValue != null) animationValue = other.animationValue;
        return this;
    }

    /** Whether the style changes nothing. */
    function isPlain():Bool {
        return fontFamilyValue == null && fontWeightValue == null && fontStyleValue == null && fontFeaturesValue == null && fontSizeValue == null
            && colorValue == null && opacityValue == null && backgroundValue == null && underlineValue == null && strikethroughValue == null
            && letterSpacingValue == null && boxValue == null && transformationValue == null && animationValue == null;
    }

    /** The style as the paragraph engine takes it. */
    function toHighlight(boxed:Bool):InlineHighlight {
        final highlight = new InlineHighlight(new HighlightStyle(colorValue, fontWeightValue, fontStyleValue, backgroundValue, underlineValue, strikethroughValue),
            fontFamilyValue);
        if (fontFeaturesValue != null) {
            // The engine reads the font features of a span from this refinement.
            final refinement = new StyleRefinement();
            refinement.text = new TextStyleRefinement();
            refinement.text.fontFeatures = fontFeaturesValue;
            @:privateAccess highlight.codeStyle = refinement;
        }
        switch fontSizeValue {
            case null:
            case Absolute(size): highlight.fontSizeAbsolute = size;
            case Relative(scale): highlight.fontSizeRelative = scale;
        }
        switch letterSpacingValue {
            case null:
            case Absolute(length): highlight.letterSpacingPx = length;
            case Em(em): highlight.letterSpacingEm = em;
        }
        highlight.textTransform = textTransformValue;
        highlight.opacity = opacityValue;
        highlight.box = boxValue != null ? boxValue.clone() : (boxed ? new StyleRefinement() : null);
        highlight.transformation = transformationValue;
        highlight.animation = animationValue;
        return highlight;
    }

}

private enum RichSpanKind {
    Text(text:String, style:Null<RichTextStyle>, boxed:Bool);
    Element(element:IntoElement, baseline:Null<Pixels>);
    LineBreak;
}

/** One span of a `RichText`. */
@:allow(glaze.kit.text)
class RichSpan {

    final kind:RichSpanKind;

    function new(kind:RichSpanKind) {
        this.kind = kind;
    }

    /** Text in `style` (the paragraph's own style when omitted). */
    public static function text(text:String, ?style:RichTextStyle):RichSpan {
        return new RichSpan(Text(text, style, false));
    }

    /** A pill: text in the box of `style`, never broken across lines. */
    public static function box(text:String, style:RichTextStyle):RichSpan {
        return new RichSpan(Text(text, style, true));
    }

    /**
     * Any element placed in the line like a character. Its bottom sits on
     * the baseline unless `baseline` says how far below its top the
     * baseline is.
     */
    public static function element(element:IntoElement, ?baseline:Pixels):RichSpan {
        return new RichSpan(Element(element, baseline));
    }

    /** A forced line break. */
    public static function lineBreak():RichSpan {
        return new RichSpan(LineBreak);
    }

}

/**
 * A paragraph of text in mixed styles: families, weights, sizes on one
 * baseline, colors, decorations, letter spacing, case, boxes (pills),
 * inline elements, links, and spans animated as a whole or character by
 * character. It takes typed spans and styles; it knows no markup (markdown
 * is `TextView`).
 *
 * The paragraph inherits the text style around it, and the styles set on
 * the component itself (`.textSize(...)`, `.textColor(...)`,
 * `.fontFamily(...)`, `.lineHeight(...)`, a width).
 *
 * An animated span costs a frame only while it is on screen, never lays the
 * paragraph out again, and stands still under reduced motion.
 */
class RichText extends Component implements Styled {

    final id:ElementId;

    final richStyle:StyleRefinement = new StyleRefinement();

    var spanList:Array<RichSpan> = [];

    /** Sets how white space is treated, `Normal` by default. */
    @prop var whiteSpace:RichWhiteSpace = Normal;

    /** Aligns the lines, `Left` by default. */
    @prop var textAlign:TextAlign = TextAlign.Left;

    /**
     * Whether the text can be selected, `false` by default. Selection is
     * the markdown view's: it works for a `RichText` placed inside a
     * selectable `TextView` scope only.
     */
    @prop var selectable:Bool = false;

    var linkHandler:Null<(String, Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    /** Sets the spans of the paragraph. */
    public function spans(spans:Array<RichSpan>):RichText {
        spanList = [for (span in spans) if (span != null) span];
        return this;
    }

    /** Called with the url of a clicked link; without it the url is opened by the system. */
    public function onLinkClick(handler:(url:String, window:Window, cx:App) -> Void):RichText {
        linkHandler = handler;
        return this;
    }

    public inline function style():StyleRefinement {
        return richStyle;
    }

    /** The text of the spans as it is shown (white space rule and case applied), elements left out. */
    public function plainText():String {
        final built = build();
        final out = new StringBuf();
        for (item in built) {
            switch item {
                case Text(_, text, _, _, _, _): out.add(text);
                case _:
            }
        }
        return out.toString();
    }

    function build():Array<InlineFlowItem> {
        final collapse = whiteSpace != PreWrap;
        final items:Array<InlineFlowItem> = [];
        var text = new StringBuf();
        var length = 0;
        var links:Array<RangedLink> = [];
        var highlights:Array<RangedHighlight> = [];
        // Whether the next space is dropped: at the start of a line, and after a space.
        var pendingSpace = true;
        var objectId = 0;

        function flush():Void {
            if (length > 0) {
                items.push(InlineFlowItem.Text(new InlineState(), text.toString(), links, highlights, [], null));
            }
            text = new StringBuf();
            length = 0;
            links = [];
            highlights = [];
        }

        for (span in spanList) {
            switch span.kind {
                case Text(source, style, boxed):
                    var shown = source;
                    if (collapse) {
                        final out = new StringBuf();
                        for (c in new haxe.iterators.StringIteratorUnicode(source)) {
                            if (c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code) {
                                if (!pendingSpace) out.add(' ');
                                pendingSpace = true;
                            } else {
                                out.addChar(c);
                                pendingSpace = false;
                            }
                        }
                        shown = out.toString();
                    }
                    if (style != null) shown = InlineMotion.transformText(shown, style.textTransformValue);
                    final bytes = Utf8.byteLength(shown);
                    if (bytes == 0) continue;
                    final range = new Range(length, length + bytes);
                    if (style != null && (boxed || !style.isPlain())) {
                        highlights.push(new RangedHighlight(range, style.toHighlight(boxed)));
                    }
                    if (style != null && style.linkValue != null) {
                        links.push(new RangedLink(range, new LinkMark(style.linkValue)));
                    }
                    text.add(shown);
                    length += bytes;
                case Element(element, baseline):
                    flush();
                    var taken = false;
                    final id = objectId++;
                    items.push(InlineFlowItem.Object('￼', id, (_, _, _) -> {
                        // An element is laid out once: a second request falls back to the placeholder text.
                        if (taken) return null;
                        taken = true;
                        final placed = new InlineElement(element);
                        return baseline != null ? placed.withBaseline(baseline) : placed;
                    }, '', new SharedFlag(), new HighlightStyle(), null));
                    pendingSpace = false;
                case LineBreak:
                    text.add('\n');
                    length += 1;
                    pendingSpace = true;
            }
        }
        flush();
        return items;
    }

    public function render(window:Window, cx:App):IntoElement {
        final handler = linkHandler;
        final flow = new InlineFlow(id, build(), handler != null ? (url, _, window, cx) -> handler(url, window, cx) : null)
            .textAlign(textAlign)
            .preWrap(whiteSpace == PreWrap);
        final container = div().minW0();
        if (whiteSpace == NoWrap) container.whitespaceNowrap();
        return container.refineStyle(richStyle).child(flow);
    }

}
