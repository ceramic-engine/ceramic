// New code for Cityscape (not a port): resolves the class names of rendered
// parts (Monaco's `mtk*` token classes, decoration class names, typed styles)
// into what Glaze paints, replacing the CSS of Monaco's view.
package cityscape.view;

import cityscape.common.DecorationStyle;
import cityscape.common.Model.DecorationColor;
import glaze.FontWeight;
import glaze.Hsla;

/**
 * A box drawn behind text (decoration background, border, radius).
 */
class ResolvedBox {

    public var background:Null<Hsla> = null;
    public var borderColor:Null<Hsla> = null;
    public var borderWidth:Float = 0;
    public var borderRadius:Float = 0;
    public var paddingTop:Float = 0;
    public var paddingBottom:Float = 0;
    public var join:Bool = true;

    public function new() {}

    public function equals(other:Null<ResolvedBox>):Bool {
        if (other == null) {
            return false;
        }
        return colorEquals(background, other.background)
            && colorEquals(borderColor, other.borderColor)
            && borderWidth == other.borderWidth
            && borderRadius == other.borderRadius
            && paddingTop == other.paddingTop
            && paddingBottom == other.paddingBottom
            && join == other.join;
    }

    public static function colorEquals(a:Null<Hsla>, b:Null<Hsla>):Bool {
        if (a == null || b == null) {
            return a == b;
        }
        return a.h == b.h && a.s == b.s && a.l == b.l && a.a == b.a;
    }

}

/**
 * What a rendered part paints with.
 */
class ResolvedPartStyle {

    public var color:Hsla;
    public var italic:Bool = false;
    public var fontWeight:Null<FontWeight> = null;
    public var opacity:Float = 1;
    public var underlineColor:Null<Hsla> = null;
    public var underlineThickness:Float = 0;
    public var underlineWavy:Bool = false;
    public var strikethroughColor:Null<Hsla> = null;
    public var strikethroughThickness:Float = 0;
    public var letterSpacing:Float = 0;
    public var fontFeatures:Null<String> = null;
    public var box:Null<ResolvedBox> = null;

    /**
     * The font key of the part: parts with the same key are shaped with one
     * font run.
     */
    public var fontKey:String = '';

    public function new(color:Hsla) {
        this.color = color;
    }

}

/**
 * Resolves part class names, with a cache per class name string. One per
 * editor view (it reads the view's theme and the context's registered
 * decoration styles).
 */
class DecorationStyleResolver {

    public static inline final TYPED_STYLE_PREFIX = '__cs';

    final theme:ViewTheme;
    final registry:DecorationStyles;

    final _cache:Map<String, ResolvedPartStyle> = new Map();
    var _themeVersion:Int = -1;
    var _registryVersion:Int = -1;

    /**
     * Typed styles (`inlineStyle`) given synthetic class names, so that they
     * travel through Monaco's class name based line rendering.
     */
    var _typedStyleNames:haxe.ds.ObjectMap<{}, String> = new haxe.ds.ObjectMap();
    var _typedStyles:Array<IDecorationStyle> = [];

    public function new(theme:ViewTheme, registry:DecorationStyles) {
        this.theme = theme;
        this.registry = registry;
    }

    /**
     * The synthetic class name of a typed style.
     */
    public function classNameOfStyle(style:IDecorationStyle):String {
        final existing = _typedStyleNames.get(style);
        if (existing != null) {
            return existing;
        }
        if (_typedStyles.length >= 8192) {
            // decorations made new style objects for a long time: start over
            _typedStyleNames = new haxe.ds.ObjectMap();
            _typedStyles = [];
            _cache.clear();
        }
        final name = TYPED_STYLE_PREFIX + _typedStyles.length;
        _typedStyles.push(style);
        _typedStyleNames.set(style, name);
        return name;
    }

    function checkVersions():Void {
        if (_themeVersion != theme.version || _registryVersion != registry.version) {
            _themeVersion = theme.version;
            _registryVersion = registry.version;
            _cache.clear();
        }
    }

    public function resolveColor(color:Null<DecorationColor>):Null<Hsla> {
        return theme.resolveDecorationColor(color);
    }

    /**
     * The style of a part from its class names (space separated).
     */
    public function resolve(classNames:String):ResolvedPartStyle {
        checkVersions();
        final cached = _cache.get(classNames);
        if (cached != null) {
            return cached;
        }
        final defaultColor = theme.getTokenColor(1);
        final result = new ResolvedPartStyle(defaultColor);
        for (name in classNames.split(' ')) {
            if (name.length == 0) {
                continue;
            }
            if (StringTools.startsWith(name, 'mtk')) {
                applyTokenClass(result, name);
            } else if (StringTools.startsWith(name, TYPED_STYLE_PREFIX)) {
                final index = Std.parseInt(name.substr(TYPED_STYLE_PREFIX.length));
                if (index != null && index >= 0 && index < _typedStyles.length) {
                    applyStyle(result, _typedStyles[index]);
                }
            } else {
                final participantColor = themeParticipantColor(name);
                if (participantColor != null) {
                    result.color = participantColor;
                }
                final style = registry.get(name);
                if (style != null) {
                    applyStyle(result, style);
                }
            }
        }
        var key = (result.fontWeight == null ? '' : '' + result.fontWeight) + '|' + (result.italic ? 'i' : '') + '|' + (result.fontFeatures == null ? '' : result.fontFeatures);
        result.fontKey = key;
        _cache.set(classNames, result);
        return result;
    }

    var _bracketColorsVersion:Int = -1;
    var _bracketColors:Array<Hsla> = [];

    /**
     * The color the theming participant of the bracket pair colorization
     * (bracketPairColorization in Monaco's editor CSS) gives a class:
     * `unexpected-closing-bracket` takes
     * `editorBracketHighlight.unexpectedBracket.foreground`, and
     * `bracket-highlighting-N` the N-th of the non transparent colors among
     * `editorBracketHighlight.foreground1..6`, cycling. Null for other
     * classes.
     */
    function themeParticipantColor(name:String):Null<Hsla> {
        if (name == 'unexpected-closing-bracket') {
            return theme.getColor('editorBracketHighlight.unexpectedBracket.foreground');
        }
        if (!StringTools.startsWith(name, 'bracket-highlighting-')) {
            return null;
        }
        if (_bracketColorsVersion != theme.version) {
            _bracketColorsVersion = theme.version;
            _bracketColors = [];
            for (i in 1...7) {
                final c = theme.getColor('editorBracketHighlight.foreground' + i);
                if (c != null && c.a > 0) {
                    _bracketColors.push(c);
                }
            }
        }
        if (_bracketColors.length == 0) {
            return null;
        }
        final level = Std.parseInt(name.substr('bracket-highlighting-'.length));
        if (level == null || level < 0) {
            return null;
        }
        return _bracketColors[level % _bracketColors.length];
    }

    function applyTokenClass(result:ResolvedPartStyle, name:String):Void {
        switch name {
            case 'mtki':
                result.italic = true;
            case 'mtkb':
                result.fontWeight = FontWeight.BOLD;
            case 'mtku':
                result.underlineThickness = 1;
            case 'mtks':
                result.strikethroughThickness = 1;
            case 'mtkw' | 'mtkz':
                final c = theme.getColor('editorWhitespace.foreground');
                if (c != null) {
                    result.color = c;
                }
            case 'mtkcontrol':
                // Monaco: `.mtkcontrol { color: rgb(255, 255, 255); background: rgb(150, 0, 0); }`
                result.color = new Hsla(0, 0, 1, 1);
                final box = new ResolvedBox();
                box.background = ViewTheme.parseColor('rgb(150, 0, 0)');
                box.join = false;
                result.box = box;
            case 'mtkoverflow':
            case _:
                final id = Std.parseInt(name.substr(3));
                if (id != null) {
                    result.color = theme.getTokenColor(id);
                }
        }
    }

    public function applyStyle(result:ResolvedPartStyle, style:IDecorationStyle):Void {
        final color = resolveColor(style.color);
        if (color != null) {
            result.color = color;
        }
        if (style.fontStyle != null) {
            result.italic = (style.fontStyle == 'italic' || style.fontStyle == 'oblique');
        }
        if (style.fontWeight != null) {
            result.fontWeight = EditorFontMeasurements.parseFontWeight(style.fontWeight);
        }
        if (style.opacity != null) {
            result.opacity *= style.opacity;
        }
        if (style.underline != null) {
            final thickness:Null<Float> = style.underline.thickness;
            result.underlineThickness = thickness == null ? 1 : thickness;
            result.underlineColor = resolveColor(style.underline.color);
            result.underlineWavy = style.underline.wavy == true;
        }
        if (style.strikethrough != null) {
            final thickness:Null<Float> = style.strikethrough.thickness;
            result.strikethroughThickness = thickness == null ? 1 : thickness;
            result.strikethroughColor = resolveColor(style.strikethrough.color);
        }
        if (style.letterSpacing != null) {
            result.letterSpacing = style.letterSpacing;
        }
        if (style.fontFeatures != null) {
            result.fontFeatures = style.fontFeatures;
        }
        final box = resolveBox(style, result.box);
        if (box != null) {
            result.box = box;
        }
    }

    /**
     * The box of a style (background, border, radius, padding), merged over
     * `base`, or `base` when the style has none.
     */
    public function resolveBox(style:IDecorationStyle, ?base:ResolvedBox):Null<ResolvedBox> {
        if (style.background == null && style.border == null && style.borderRadius == null && style.paddingTop == null && style.paddingBottom == null) {
            return base;
        }
        final box = new ResolvedBox();
        if (base != null) {
            box.background = base.background;
            box.borderColor = base.borderColor;
            box.borderWidth = base.borderWidth;
            box.borderRadius = base.borderRadius;
            box.paddingTop = base.paddingTop;
            box.paddingBottom = base.paddingBottom;
            box.join = base.join;
        }
        final background = resolveColor(style.background);
        if (background != null) {
            box.background = background;
        }
        if (style.border != null) {
            box.borderColor = resolveColor(style.border.color);
            final width:Null<Float> = style.border.width;
            box.borderWidth = width == null ? 1 : width;
        }
        if (style.borderRadius != null) {
            box.borderRadius = style.borderRadius;
        }
        if (style.paddingTop != null) {
            box.paddingTop = style.paddingTop;
        }
        if (style.paddingBottom != null) {
            box.paddingBottom = style.paddingBottom;
        }
        if (style.join != null) {
            box.join = style.join;
        }
        return box;
    }

    /**
     * The typed style of a decoration's class names and typed style merged
     * (registered class styles first, then `typed`), or null when neither
     * gives anything.
     */
    public function combinedStyle(classNames:Null<String>, typed:Null<IDecorationStyle>):Null<Array<IDecorationStyle>> {
        var result:Null<Array<IDecorationStyle>> = null;
        if (classNames != null && classNames.length > 0) {
            for (name in classNames.split(' ')) {
                final s = registry.get(name);
                if (s != null) {
                    if (result == null) {
                        result = [];
                    }
                    result.push(s);
                }
            }
        }
        if (typed != null) {
            if (result == null) {
                result = [];
            }
            result.push(typed);
        }
        return result;
    }

}
