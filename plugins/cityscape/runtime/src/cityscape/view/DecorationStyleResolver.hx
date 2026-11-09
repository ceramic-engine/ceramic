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
/**
 * What a decoration paints outside the text runs (`DecorationStyleResolver.paintStylesOf`):
 * its styles (`combinedStyle`) with their resolved boxes and colors, for
 * the whole line, the boxes behind the text, the margin, the glyph margin,
 * the line decorations and the line number.
 */
class DecorationPaintStyles {

    /** `isWholeLine` class names and `lineStyle`. */
    public var lineStyles:Null<Array<IDecorationStyle>> = null;
    public var lineBoxes:Null<Array<Null<ResolvedBox>>> = null;

    /** `className` (not whole line) and `style`, with the colors of their squiggles. */
    public var boxStyles:Null<Array<IDecorationStyle>> = null;
    public var boxBoxes:Null<Array<Null<ResolvedBox>>> = null;
    public var boxUnderlineColors:Null<Array<Null<Hsla>>> = null;

    public var marginStyles:Null<Array<IDecorationStyle>> = null;
    public var marginBoxes:Null<Array<Null<ResolvedBox>>> = null;

    public var glyphStyles:Null<Array<IDecorationStyle>> = null;
    public var glyphBoxes:Null<Array<Null<ResolvedBox>>> = null;

    public var linesStyles:Null<Array<IDecorationStyle>> = null;
    public var linesBoxes:Null<Array<Null<ResolvedBox>>> = null;

    /** `lineNumberClassName` and `lineNumberStyle`: the colors of their styles. */
    public var lineNumberColors:Null<Array<Null<Hsla>>> = null;

    public function new() {}

}

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
            _paintStyles = new haxe.ds.ObjectMap();
            _paintStylesCount = 0;
        }
    }

    var _paintStyles:haxe.ds.ObjectMap<{}, DecorationPaintStyles> = new haxe.ds.ObjectMap();
    var _paintStylesCount:Int = 0;

    /**
     * What a decoration with these options paints outside the text runs
     * (`combinedStyle` and `resolveBox` / `resolveColor` of each style),
     * kept by options object while the theme and the registered styles stay
     * the same: the view paints its decorations without resolving them again
     * at each frame.
     */
    public function paintStylesOf(options:cityscape.common.Model.IModelDecorationOptions):DecorationPaintStyles {
        checkVersions();
        final cached = _paintStyles.get(options);
        if (cached != null) {
            return cached;
        }
        if (_paintStylesCount >= 8192) {
            // decorations made new options for a long time: start over
            _paintStyles = new haxe.ds.ObjectMap();
            _paintStylesCount = 0;
        }
        final result = new DecorationPaintStyles();
        final wholeLine = options.isWholeLine == true;
        result.lineStyles = combinedStyle(wholeLine ? options.className : null, options.lineStyle);
        result.lineBoxes = boxesOf(result.lineStyles);
        result.boxStyles = combinedStyle(wholeLine ? null : options.className, options.style);
        result.boxBoxes = boxesOf(result.boxStyles);
        if (result.boxStyles != null) {
            result.boxUnderlineColors = [for (st in result.boxStyles) {
                final underline = st.underline;
                underline != null && underline.color != null ? resolveColor(underline.color) : null;
            }];
        }
        result.marginStyles = combinedStyle(options.marginClassName, options.marginStyle);
        result.marginBoxes = boxesOf(result.marginStyles);
        result.glyphStyles = combinedStyle(options.glyphMarginClassName, options.glyphMarginStyle);
        result.glyphBoxes = boxesOf(result.glyphStyles);
        result.linesStyles = combinedStyle(options.linesDecorationsClassName, options.linesDecorationsStyle);
        result.linesBoxes = boxesOf(result.linesStyles);
        final lineNumberStyles = combinedStyle(options.lineNumberClassName, options.lineNumberStyle);
        if (lineNumberStyles != null) {
            result.lineNumberColors = [for (st in lineNumberStyles) resolveColor(st.color)];
        }
        _paintStyles.set(options, result);
        _paintStylesCount++;
        return result;
    }

    function boxesOf(styles:Null<Array<IDecorationStyle>>):Null<Array<Null<ResolvedBox>>> {
        return styles != null ? [for (st in styles) resolveBox(st)] : null;
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
        // Token classes first (Monaco's token style sheet), then the
        // decoration styles in cascade order
        final cascade:Array<CascadeEntry> = [];
        var position = 0;
        for (name in classNames.split(' ')) {
            if (name.length == 0) {
                continue;
            }
            if (StringTools.startsWith(name, 'mtk')) {
                applyTokenClass(result, name);
            } else if (StringTools.startsWith(name, TYPED_STYLE_PREFIX)) {
                final index = Std.parseInt(name.substr(TYPED_STYLE_PREFIX.length));
                if (index != null && index >= 0 && index < _typedStyles.length) {
                    cascade.push(new CascadeEntry(_typedStyles[index], TYPED_STYLE_ORDER, position++));
                }
            } else {
                // the theming participants (Monaco's theme CSS) first
                final participantColor = themeParticipantColor(name);
                if (participantColor != null) {
                    result.color = participantColor;
                }
                final style = registry.get(name);
                if (style != null) {
                    cascade.push(new CascadeEntry(style, registry.orderOf(name), position++));
                }
            }
        }
        sortCascade(cascade);
        for (entry in cascade) {
            applyStyle(result, entry.style);
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
        if (result != null && result.length > 1) {
            // several styles: in cascade order
            final cascade:Array<CascadeEntry> = [];
            var position = 0;
            for (name in classNames.split(' ')) {
                final s = registry.get(name);
                if (s != null) {
                    cascade.push(new CascadeEntry(s, registry.orderOf(name), position++));
                }
            }
            if (typed != null) {
                cascade.push(new CascadeEntry(typed, TYPED_STYLE_ORDER, position++));
            }
            sortCascade(cascade);
            for (i in 0...cascade.length) {
                result[i] = cascade[i].style;
            }
        }
        return result;
    }

    /**
     * The order of typed styles given to decorations: after every registered
     * class style.
     */
    static inline final TYPED_STYLE_ORDER:Int = 0x3fffffff;

    /**
     * Sorts styles from the weakest to the strongest (applied in this order,
     * so each property ends with the value of the strongest style setting
     * it, like the CSS cascade): not important before important, then by
     * `priority`, then by order (registration order of class styles, typed
     * styles last), then by position on the part.
     */
    static function sortCascade(cascade:Array<CascadeEntry>):Void {
        if (cascade.length < 2) {
            return;
        }
        haxe.ds.ArraySort.sort(cascade, (a, b) -> {
            if (a.important != b.important) {
                return a.important ? 1 : -1;
            }
            if (a.priority != b.priority) {
                return a.priority < b.priority ? -1 : 1;
            }
            if (a.order != b.order) {
                return a.order < b.order ? -1 : 1;
            }
            return a.position - b.position;
        });
    }

}

/**
 * A style of a part with its rank in the cascade.
 */
private class CascadeEntry {

    public final style:IDecorationStyle;
    public final important:Bool;
    public final priority:Float;
    public final order:Int;
    public final position:Int;

    public function new(style:IDecorationStyle, order:Int, position:Int) {
        this.style = style;
        this.important = style.important == true;
        final p:Null<Float> = style.priority;
        this.priority = p == null ? 0 : p;
        this.order = order;
        this.position = position;
    }

}
