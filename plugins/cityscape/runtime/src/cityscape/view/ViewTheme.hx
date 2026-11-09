// New code for Cityscape (not a port): the colors the Glaze view paints with,
// read from the theme service and the token color map of the context.
package cityscape.view;

import cityscape.base.common.Color;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Themables.ThemeColor;
import cityscape.common.EditorTheme;
import cityscape.common.Languages.ITokenizationRegistry;
import cityscape.common.Languages.ITokenizationSupport;
import cityscape.common.Model.DecorationColor;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeService;
import glaze.Hsla;
import glaze.Rgba;

/**
 * The colors of a view: the editor colors of the current theme (Monaco's
 * color registry keys, `editor.background`, `editorLineNumber.foreground`...,
 * with the registry defaults) and the token color map
 * (`TokenizationRegistry.getColorMap()`), converted to Glaze colors and
 * cached until the theme or the color map changes.
 *
 * Monaco's view reads the colors through CSS rules built by the theme
 * service and the theming participants; the Glaze view asks for them here.
 */
class ViewTheme implements IDisposable {

    /**
     * Monaco's `EditorTheme` of the view model (theme type and colors).
     */
    public final editorTheme:EditorTheme;

    /**
     * Incremented at each change (resolved colors are cached by version).
     */
    public var version(default, null):Int = 0;

    final _themeService:IStandaloneThemeService;
    final _tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>;
    final _cache:Map<String, Null<Hsla>> = new Map();
    final _tokenColors:Array<Hsla> = [];
    final _listeners:Array<IDisposable> = [];

    public function new(themeService:IStandaloneThemeService, tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>) {
        this._themeService = themeService;
        this._tokenizationRegistry = tokenizationRegistry;
        this.editorTheme = new EditorTheme(themeService.getColorTheme());
        _listeners.push(themeService.onDidColorThemeChange(theme -> {
            editorTheme.update(theme);
            _invalidate();
        }));
        _listeners.push(tokenizationRegistry.onDidChange(e -> {
            if (e.changedColorMap) {
                _invalidate();
            }
        }));
    }

    public function dispose():Void {
        for (l in _listeners) {
            l.dispose();
        }
        _listeners.resize(0);
    }

    function _invalidate():Void {
        _cache.clear();
        _tokenColors.resize(0);
        version++;
    }

    static function toHsla(color:Null<Color>):Null<Hsla> {
        if (color == null) {
            return null;
        }
        final rgba = color.rgba;
        return new Rgba(rgba.r / 255, rgba.g / 255, rgba.b / 255, rgba.a).toHsla();
    }

    final _remap:Map<String, String> = new Map();

    /**
     * Paints this view's `key` with the theme color `to` instead (what the
     * CSS of Monaco's widgets does to the editors they embed, like the
     * `peekViewEditor.background` of the peek view's editor).
     */
    public function remapColor(key:String, to:String):Void {
        _remap.set(key, to);
        _invalidate();
    }

    /**
     * The color of a theme key (with the registry default), or null when
     * there is none.
     */
    public function getColor(key:String):Null<Hsla> {
        if (_cache.exists(key)) {
            return _cache.get(key);
        }
        final mapped = _remap.get(key);
        final color = toHsla(editorTheme.getColor(mapped != null ? mapped : key));
        _cache.set(key, color);
        return color;
    }

    /**
     * The color of a token color id (`ColorId`), the default foreground
     * (color id 1) when the color map has none.
     */
    public function getTokenColor(colorId:Int):Hsla {
        if (colorId >= 0 && colorId < _tokenColors.length && _tokenColors[colorId] != null) {
            return _tokenColors[colorId];
        }
        final colorMap = _tokenizationRegistry.getColorMap();
        var color:Null<Hsla> = null;
        if (colorMap != null) {
            if (colorId >= 0 && colorId < colorMap.length) {
                color = toHsla(colorMap[colorId]);
            }
            if (color == null && colorMap.length > 1) {
                color = toHsla(colorMap[1]);
            }
        }
        if (color == null) {
            color = getColor('editor.foreground');
        }
        if (color == null) {
            color = new Hsla(0, 0, 0, 1);
        }
        if (colorId >= 0) {
            _tokenColors[colorId] = color;
        }
        return color;
    }

    /**
     * A decoration color: a CSS-like color string or a theme color
     * (`ThemeColor`, or its id given as a string).
     */
    public function resolveDecorationColor(color:Null<DecorationColor>):Null<Hsla> {
        if (color == null) {
            return null;
        }
        if (Std.isOfType(color, String)) {
            final value:String = cast color;
            final parsed = parseColor(value);
            if (parsed != null) {
                return parsed;
            }
            // A theme key given as a string
            return getColor(value);
        }
        final themeColor:ThemeColor = cast color;
        return getColor(themeColor.id);
    }

    /**
     * Parses a CSS color: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`,
     * `rgb(r, g, b)`, `rgba(r, g, b, a)`, `transparent`. Null when invalid.
     */
    public static function parseColor(value:String):Null<Hsla> {
        if (value == null) {
            return null;
        }
        final v = StringTools.trim(value).toLowerCase();
        if (v == 'transparent') {
            return new Hsla(0, 0, 0, 0);
        }
        if (StringTools.startsWith(v, '#')) {
            final rgba = Rgba.tryParse(v);
            return rgba == null ? null : rgba.toHsla();
        }
        if (StringTools.startsWith(v, 'rgb')) {
            final open = v.indexOf('(');
            final close = v.lastIndexOf(')');
            if (open == -1 || close <= open) {
                return null;
            }
            final parts = v.substring(open + 1, close).split(',').map(StringTools.trim);
            if (parts.length < 3) {
                return null;
            }
            inline function channel(s:String):Float {
                if (StringTools.endsWith(s, '%')) {
                    return Std.parseFloat(s.substr(0, s.length - 1)) / 100;
                }
                return Std.parseFloat(s) / 255;
            }
            final a = parts.length > 3 ? Std.parseFloat(parts[3]) : 1.0;
            return new Rgba(channel(parts[0]), channel(parts[1]), channel(parts[2]), Math.isNaN(a) ? 1.0 : a).toHsla();
        }
        return null;
    }

}
