// Ported from gpui-kit 0.8.1: crates/component/src/theme/mod.rs, crates/component/src/theme/schema.rs (Theme::apply_config)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-020 (scrollbars shown on hover by default). See docs/DEVIATIONS.md.
package glaze.kit.theme;

import glaze.AppContext;
import glaze.Hsla;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.theme.ColorTokens;
import glaze.kit.base.theme.RadiusTokens;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.base.theme.ScrollbarTheme;
import glaze.kit.base.Scrollbar.ScrollbarEntrance;
import glaze.kit.base.Scrollbar.ScrollbarMotion;
import glaze.kit.base.Scrollbar.ScrollbarStyles;
import glaze.kit.base.theme.SemanticThemeTokens;
import glaze.kit.base.theme.ShadowTokens;
import glaze.kit.base.theme.SpacingTokens;
import glaze.kit.base.theme.TypographyTokens;
import glaze.kit.theme.SemanticThemeConfig;

using glaze.kit.theme.Colorize;

/**
 * The global theme configuration.
 *
 * Rust's `Theme` derefs to its `ThemeColor`, so components write
 * `cx.theme().primary`. Here `Theme` extends `ThemeColor` for the same
 * result, and `colors` returns the theme itself: `theme.colors.primary` and
 * `theme.primary` are the same field, and assigning `theme.colors = palette`
 * copies every color of `palette`.
 *
 * Reactivity: the theme installed in the global is never mutated.
 * `Theme.update` and `Theme.change` edit a copy and install it with
 * `cx.setGlobal`, so a view that reads `cx.theme()` (or `Theme.global(cx)`)
 * during render subscribes to the one observable value of the global cell,
 * and re-renders when a new theme is installed (no `observeGlobal` + `notify`).
 * `Theme.globalMut` still edits in place (like Rust) and invalidates the cell.
 *
 * Not ported yet (they come with their components): `list` and `cursorBlink`. The font probes of `Theme::change`
 * (`system_font.rs`, `mono_font.rs`), which ask the platform text system
 * which families are installed, are not run: the families stay as configured.
 */
class Theme extends ThemeColor {

    /**
     * The radius that rounds a shape as far as its own size allows, giving a
     * circle or a pill.
     */
    static inline final RADIUS_FULL:Pixels = 9999.;

    /** How long the scrollbar stays visible after the last scroll, drag, or hover. */
    static inline final SCROLLBAR_IDLE:Float = 2.;

    /** How long the scrollbar takes to appear. */
    static inline final SCROLLBAR_ENTER:Float = 0.3;

    /** How long the scrollbar takes to fade away once the idle hold expires. */
    static inline final SCROLLBAR_EXIT:Float = 0.5;

    /** How long the thumb takes to reach its hovered or resting width. */
    static inline final SCROLLBAR_EXPAND:Float = 0.3;

    /**
     * The resting thumb width on iOS and Android, matching the 3pt indicator
     * those platforms draw. Hover and drag keep Base's desktop widths, so a
     * grabbed thumb still grows under the finger.
     */
    static inline final MOBILE_SCROLLBAR_THUMB_WIDTH:Pixels = 3.;

    /**
     * How far the resting thumb sits from the edge on iOS and Android. Base's
     * desktop inset leaves a 3px thumb floating too far from the edge.
     */
    static inline final MOBILE_SCROLLBAR_THUMB_INSET:Pixels = 2.;

    /**
     * Base's resting thumb width, restated so the hovered thumb keeps it when
     * the mobile resting width would otherwise cascade into it.
     */
    static inline final SCROLLBAR_THUMB_HOVER_WIDTH:Pixels = 6.;

    /** Base's dragged thumb width, restated for the same reason. */
    static inline final SCROLLBAR_THUMB_ACTIVE_WIDTH:Pixels = 8.;

    /** Base's hovered and dragged thumb inset, restated for the same reason. */
    static inline final SCROLLBAR_THUMB_INSET:Pixels = 4.;

    /**
     * How long a chart's data takes to draw in the first time it is painted,
     * in seconds (the mainstream chart libraries agree on about a second).
     */
    static inline final PLOT_APPEAR:Float = 1.;

    /**
     * The curve a chart's data draws in on: Chart.js' default
     * `easeOutQuart`, in `f32` like the original.
     */
    static function plotAppearEasing(t:Float):Float {
        final b = glaze.SpringMath.f32(1. - t);
        final b2 = glaze.SpringMath.f32(b * b);
        return glaze.SpringMath.f32(1. - glaze.SpringMath.f32(b2 * b2));
    }

    /**
     * The plot hover motion this design system projects onto Base: the
     * pointer follows on the fast tier as a critically damped spring with a
     * sub-pixel tolerance, the hover fades on the same tier, and the data
     * draws in over `PLOT_APPEAR` on `plotAppearEasing`.
     */
    static function plotMotion(motion:MotionTokens):glaze.kit.base.plot.PlotMotion {
        return new glaze.kit.base.plot.PlotMotion()
            .withPointer(new glaze.kit.base.motion.Spring(motion.durationFast).withEpsilon(0.1))
            .withEnter(new glaze.kit.base.motion.Transition(motion.durationFast).easing(motion.easingEnter))
            .withExit(new glaze.kit.base.motion.Transition(motion.durationFast).easing(motion.easingExit))
            .withAppear(new glaze.kit.base.motion.Transition(PLOT_APPEAR).ease(plotAppearEasing));
    }

    /**
     * The scrollbar motion this design system projects onto Base.
     *
     * Scrolling and track hover reveal a scrollbar by fading it in place. In hover
     * mode, pointing at the thumb slides it in from the nearest edge as it fades.
     */
    static function scrollbarMotion(mode:ScrollbarMode):ScrollbarMotion {
        return new ScrollbarMotion()
            .withIdle(SCROLLBAR_IDLE)
            .withEnter(SCROLLBAR_ENTER)
            .withExit(SCROLLBAR_EXIT)
            .withExpand(SCROLLBAR_EXPAND)
            .withEntrance(ScrollbarEntrance.Fade)
            .withThumbHoverEntrance(switch mode {
                case Scrolling | Always: ScrollbarEntrance.Fade;
                case Hover: ScrollbarEntrance.SlideAndFade;
            });
    }

    /**
     * The colors (Rust: the `colors` field the theme derefs to). Reading it
     * returns this theme; assigning it copies every color.
     */
    public var colors(get, set):ThemeColor;
    inline function get_colors():ThemeColor return this;
    function set_colors(colors:ThemeColor):ThemeColor {
        if (colors != this) copyColorsFrom(colors);
        return this;
    }

    /**
     * Component-specific resolved tokens retained for legacy compatibility.
     *
     * New application-owned presentation should use `semanticTokens()`
     * rather than extending this legacy surface.
     */
    public var tokens:ThemeTokens;

    /**
     * The `highlight` section of the active config (raw JSON), kept for the
     * code that read it before `highlightTheme` existed.
     */
    public var highlight:Null<Dynamic> = null;

    /**
     * The highlight theme: editor colors, status colors and syntax styles
     * (Rust `highlight_theme`). Default: `HighlightTheme.defaultLight()`.
     */
    public var highlightTheme:glaze.kit.highlighter.HighlightTheme = glaze.kit.highlighter.HighlightTheme.defaultLight();

    public var lightTheme:ThemeConfig = new ThemeConfig();

    public var darkTheme:ThemeConfig = new ThemeConfig();

    public var mode:ThemeMode = Light;

    /**
     * The font family for the application, default is `.SystemUIFont`.
     */
    public var fontFamily:String = '.SystemUIFont';

    /**
     * The base font size for the application, default is 16px.
     */
    public var fontSize:Pixels = 16.;

    /**
     * The monospace font family for the application: `Menlo` on macOS,
     * `Consolas` on Windows, `DejaVu Sans Mono` on Linux.
     */
    public var monoFontFamily:String = TypographyTokens.defaultMonoFontFamily();

    /**
     * The monospace font size for the application, default is 13px.
     */
    public var monoFontSize:Pixels = 13.;

    /**
     * Radius for the general elements.
     */
    public var radius:Pixels = 6.;

    /**
     * Radius for the large elements, e.g.: Dialog, Notification border radius.
     */
    public var radiusLg:Pixels = 8.;

    public var shadow:Bool = true;

    /**
     * Whether focused controls draw a ring outside their border, default true.
     */
    public var focusRing:Bool = true;

    public var transparent:Hsla = Hsla.transparentBlack();

    /**
     * Show the scrollbar mode, default: Scrolling.
     */
    public var scrollbarMode:ScrollbarMode = Scrolling;

    /**
     * The styled layer's semantic motion policy (see `motionTokens()`).
     */
    public var motion:MotionTokens = new MotionTokens();

    /**
     * The notification settings.
     */
    public var notification:glaze.kit.notification.Notification.NotificationSettings = new glaze.kit.notification.Notification.NotificationSettings();

    /**
     * The list settings (Rust `Theme::list`; renamed: `list` is the
     * inherited list color of `ThemeColor`).
     */
    public var listSettings:glaze.kit.base.ListSettings = new glaze.kit.base.ListSettings();

    /**
     * The sheet settings.
     */
    public var sheet:glaze.kit.sheet.Sheet.SheetSettings = new glaze.kit.sheet.Sheet.SheetSettings();

    /**
     * A theme with the given colors (Rust: `From<&ThemeColor> for Theme`);
     * without argument, all-zero colors (Rust: `Theme::default()`).
     */
    public function new(?colors:ThemeColor) {

        super();
        if (colors != null) copyColorsFrom(colors);
        tokens = ThemeTokens.fromColors(this);

    }

    /**
     * A copy of this theme: colors and tokens are copied, configs are shared
     * (Rust: `Clone`).
     */
    public function clone():Theme {

        final theme = new Theme(this);
        theme.tokens = tokens.copy();
        theme.highlight = highlight;
        theme.highlightTheme = highlightTheme;
        theme.lightTheme = lightTheme;
        theme.darkTheme = darkTheme;
        theme.mode = mode;
        theme.fontFamily = fontFamily;
        theme.fontSize = fontSize;
        theme.monoFontFamily = monoFontFamily;
        theme.monoFontSize = monoFontSize;
        theme.radius = radius;
        theme.radiusLg = radiusLg;
        theme.shadow = shadow;
        theme.focusRing = focusRing;
        theme.transparent = transparent;
        theme.scrollbarMode = scrollbarMode;
        theme.motion = motion.copy();
        theme.notification = notification.copy();
        theme.listSettings = listSettings.copy();
        theme.sheet = sheet.copy();
        return theme;

    }

    /**
     * Initializes the theme system: the registry, the default light theme,
     * then the `Hover` scrollbar mode (Rust: `theme::init`).
     *
     * Initial port deviation DEV-020: gpui-kit syncs the scrollbar mode with
     * the platform here; the port uses `Hover` on every platform (the bars
     * show on hover and for a moment after any scroll). An app that wants
     * the system setting calls `syncScrollbarAppearance` after `init`
     * (read once, like gpui-kit: a later change of the setting is not
     * followed).
     */
    public static function init(cx:AppContext):Void {

        // The theme is initialized with the rest of the kit, once
        Kit.ensureInit(cx);

    }

    /**
     * Rust `theme::init`, run by the kit's initialization (`Kit`).
     */
    @:allow(glaze.kit)
    static function initTheme(cx:AppContext):Void {

        ThemeRegistry.init(cx);

        // Ensure theme is loaded directly on startup
        change(Light, null, cx);
        // Modified for Glaze (DEV-020): Hover on every platform
        // instead of syncScrollbarAppearance(cx)
        setScrollbarMode(Hover, cx);

    }

    /**
     * Sync the theme with the system appearance: the appearance of `window`
     * when given (Rust prefers it, to avoid an error on Linux), else the
     * appearance of the application's windows.
     */
    public static function syncSystemAppearance(window:Null<Window>, cx:AppContext):Void {

        Kit.ensureInit(cx);
        final appearance = window != null ? window.appearance() : cx.windowAppearance();
        change(ThemeMode.fromAppearance(appearance), window, cx);

    }

    /**
     * Sync the scrollbar showing behavior with the system: `Scrolling` when
     * the platform auto-hides scrollbars, `Hover` otherwise.
     *
     * Not called by `init` in the port (DEV-020): call it after `init` to
     * follow the system setting (macOS "Show scroll bars", Windows "Automatically
     * hide scroll bars", `Scrolling` in a browser, `Hover` on Linux).
     */
    public static function syncScrollbarAppearance(cx:AppContext):Void {

        Kit.ensureInit(cx);
        final mode:ScrollbarMode = cx.shouldAutoHideScrollbars() ? Scrolling : Hover;
        setScrollbarMode(mode, cx);

    }

    /**
     * Returns the global theme. Read in render, it subscribes the view to
     * theme changes.
     */
    public static inline function global(cx:AppContext):Theme {

        Kit.ensureInit(cx);
        return cx.global(Theme);

    }

    /**
     * Returns the global theme for an edit in place.
     *
     * An edit made through this reference reaches nothing but the field it
     * touches: `tokens` keeps the colors it had, and so does the Base
     * projection until `syncBase` rebuilds it. Prefer `update`.
     */
    public static inline function globalMut(cx:AppContext):Theme {

        Kit.ensureInit(cx);
        return cx.globalMut(Theme);

    }

    /**
     * Edits the global theme and keeps every copy of it in step.
     *
     * After `edit` returns, a color edited on `colors` replaces its token
     * (dropping any gradient), a token edited on its own writes its solid
     * color back to `colors`, an untouched field keeps the gradient a theme
     * file gave it, the Base projection is rebuilt, and every window is
     * refreshed.
     *
     * Setting `mode` loads that mode's registered theme, the same as
     * `change`. `applyConfig` installs a theme file and switches to its mode
     * in one step, and the closure may go on editing after it.
     *
     * The edit is made on a copy, installed when the closure returns.
     */
    public static function update<R>(cx:AppContext, edit:(Theme) -> R):R {

        return Theme.edit(cx, false, edit);

    }

    /**
     * The write path behind `update` and `change`.
     *
     * `reloadMode` loads the current mode's registered theme even when the
     * mode did not change, which is what `change` promises.
     */
    @:allow(glaze.kit.theme)
    static function edit<R>(cx:AppContext, reloadMode:Bool, edit:(Theme) -> R):R {

        Kit.ensureInit(cx);
        tracker.Autorun.unobserve();
        final before = cx.global(Theme);
        tracker.Autorun.reobserve();

        final theme = before.clone();
        final result = edit(theme);

        theme.tokens.reconcile(theme, before, before.tokens);
        final modeChanged = theme.mode != before.mode;
        final config = theme.mode.isDark() ? theme.darkTheme : theme.lightTheme;
        final configBefore = theme.mode.isDark() ? before.darkTheme : before.lightTheme;
        // `applyConfig` registers the file it applies and switches to its
        // mode, so a mode change that arrives with a newly registered config
        // has already loaded it. Loading it again would put the file's radius,
        // fonts and colors back over whatever the closure edited after it.
        final installedByEdit = modeChanged && config != configBefore;
        if ((modeChanged || reloadMode) && !installedByEdit) {
            theme.applyConfig(config);
        }
        // Rust resolves the default font families against the installed fonts
        // here (`resolve_default_font`, `resolve_default_mono_font`): not ported.

        cx.setGlobal(theme, Theme);
        syncBase(cx);
        cx.refreshWindows();
        return result;

    }

    /**
     * Returns true if the theme is dark.
     */
    public inline function isDark():Bool {

        return mode.isDark();

    }

    /**
     * Returns the current theme name.
     */
    public function themeName():String {

        return isDark() ? darkTheme.name : lightTheme.name;

    }

    /**
     * Changes the scrollbar display mode through `update`, which projects it
     * onto the Base scrollbar and refreshes every window.
     */
    public static function setScrollbarMode(mode:ScrollbarMode, cx:AppContext):Void {

        update(cx, theme -> {
            theme.scrollbarMode = mode;
            return null;
        });

    }

    /**
     * Change the theme mode.
     *
     * Loads the registered theme for `mode` (even when `mode` is already
     * current, so a caller that swapped `lightTheme` or `darkTheme` sees the
     * new theme) through `update`. `window` is accepted for compatibility;
     * every window is refreshed either way, so it is not read.
     */
    public static function change(mode:ThemeMode, window:Null<Window>, cx:AppContext):Void {

        Kit.ensureInit(cx);
        if (!cx.hasGlobal(Theme)) {
            final theme = new Theme();
            final registry = ThemeRegistry.global(cx);
            theme.lightTheme = registry.defaultLightTheme();
            theme.darkTheme = registry.defaultDarkTheme();
            cx.setGlobal(theme, Theme);
        }

        Theme.edit(cx, true, theme -> {
            theme.mode = mode;
            return null;
        });

    }

    /**
     * This theme projected onto the Base layer, which owns the scrollbar and
     * resize handles and reads the semantic tokens.
     *
     * Only the parts of the Base theme that are ported are projected: the
     * plot motion and the caret blink come with their modules.
     */
    @:allow(glaze.kit.theme)
    function baseTheme():glaze.kit.base.theme.Theme {

        final theme = new glaze.kit.base.theme.Theme();
        theme.appearance = mode.isDark() ? Dark : Light;
        theme.tokens = semanticTokens();
        final thumb = tokens.scrollbarThumb.background;
        final thumbHover = tokens.scrollbarThumbHover.background;
        final isMobile = glaze.kit.base.Prelude.isMobile();
        theme.scrollbar = new ScrollbarTheme()
            .withMode(scrollbarMode)
            .withMotion(scrollbarMotion(scrollbarMode))
            .withStyles(
                new ScrollbarStyles()
                    .track(style -> style.bg(scrollbar))
                    .trackHover(style -> style.bg(scrollbar))
                    .trackActive(style -> style.bg(scrollbar).borderColor(border))
                    .thumb(style -> style
                        .bg(thumb)
                        .radius(radius)
                        .when(isMobile, style -> style
                            .width(MOBILE_SCROLLBAR_THUMB_WIDTH)
                            .inset(MOBILE_SCROLLBAR_THUMB_INSET)
                            .radius(RADIUS_FULL)))
                    .thumbHover(style -> style
                        .bg(thumbHover)
                        .radius(radius)
                        .when(isMobile, style -> style
                            .width(SCROLLBAR_THUMB_HOVER_WIDTH)
                            .inset(SCROLLBAR_THUMB_INSET)))
                    .thumbActive(style -> style
                        .bg(thumbHover)
                        .radius(radius)
                        .when(isMobile, style -> style
                            .width(SCROLLBAR_THUMB_ACTIVE_WIDTH)
                            .inset(SCROLLBAR_THUMB_INSET)))
            );
        theme.resizable.handle = border;
        theme.resizable.activeHandle = dragBorder;
        theme.plot = new glaze.kit.base.theme.PlotTheme().withMotion(plotMotion(motion));
        return theme;

    }

    /**
     * Push the current theme down to the Base layer.
     *
     * `update` and `change` call this after their edits. After editing
     * through `globalMut`, call it yourself, then refresh the windows.
     */
    public static function syncBase(cx:AppContext):Void {

        tracker.Autorun.unobserve();
        final theme = cx.global(Theme);
        tracker.Autorun.reobserve();
        cx.setGlobal(theme.baseTheme(), glaze.kit.base.theme.Theme);
        glaze.kit.text.TextView.installTextViewDefaults(theme, cx);

    }

    /**
     * Get the input background color.
     *
     * For dark, use a transparent color mixed with the input border,
     * otherwise use the background color.
     */
    /**
     * Returns the styled layer's semantic motion policy.
     */
    public function motionTokens():MotionTokens {
        return motion;
    }

    public function inputBackground():Hsla {

        return isDark() ? input.mixOklab(transparent, 0.3) : background;

    }

    /**
     * Returns a snapshot of the semantic design tokens represented by this
     * theme, computed from the legacy public fields.
     */
    public function semanticTokens():SemanticThemeTokens {

        final tokens = new SemanticThemeTokens();
        tokens.colors = colorTokens();
        tokens.radius = radiusTokens();
        tokens.spacing = spacingTokens();
        tokens.typography = typographyTokens();
        tokens.shadow = shadowTokens();
        return tokens;

    }

    public function colorTokens():ColorTokens {

        final colors = ColorTokens.defaultValue();
        colors.background = background;
        colors.foreground = foreground;
        colors.surface = popover;
        colors.surfaceForeground = popoverForeground;
        colors.primary = primary;
        colors.primaryForeground = primaryForeground;
        colors.secondary = secondary;
        colors.secondaryForeground = secondaryForeground;
        colors.muted = muted;
        colors.mutedForeground = mutedForeground;
        colors.accent = accent;
        colors.accentForeground = accentForeground;
        colors.destructive = danger;
        colors.destructiveForeground = dangerForeground;
        colors.border = border;
        colors.input = input;
        colors.ring = ring;
        colors.selection = selection;
        return colors;

    }

    /**
     * The radius of a shape that reads as a circle or a pill. A theme whose
     * `radius` is zero squares these off too.
     */
    public function radiusFull():Pixels {

        return radius == 0. ? 0. : RADIUS_FULL;

    }

    /**
     * Returns the next surface radius above the existing `xl` theme tier.
     */
    public function radius2xl():Pixels {

        return radius * 2.5;

    }

    /**
     * Returns the surface radius above `radius2xl`.
     */
    public function radius3xl():Pixels {

        return radius * 3.;

    }

    /**
     * Returns the surface radius above `radius3xl`.
     */
    public function radius4xl():Pixels {

        return radius * 3.5;

    }

    public function radiusTokens():RadiusTokens {

        final tokens = new RadiusTokens();
        tokens.none = 0.;
        tokens.sm = radius / 2.;
        tokens.md = radius;
        tokens.lg = radiusLg;
        tokens.xl = radius * 2.;
        tokens.full = radiusFull();
        return tokens;

    }

    public function spacingTokens():SpacingTokens {

        return new SpacingTokens();

    }

    public function typographyTokens():TypographyTokens {

        final tokens = new TypographyTokens();
        tokens.sans = fontFamily;
        tokens.mono = monoFontFamily;
        tokens.md.size = fontSize;
        tokens.monoMd.size = monoFontSize;
        return tokens;

    }

    public function shadowTokens():ShadowTokens {

        return shadow ? ShadowTokens.elevations(transparent.alpha(0.18)) : new ShadowTokens();

    }

    /**
     * Applies the subset of semantic tokens representable by the legacy
     * theme. Scale-only spacing and elevation details have no legacy storage.
     */
    public function applySemanticTokens(tokens:SemanticThemeTokens):Void {

        final colors = tokens.colors;
        background = colors.background;
        foreground = colors.foreground;
        popover = colors.surface;
        popoverForeground = colors.surfaceForeground;
        primary = colors.primary;
        primaryForeground = colors.primaryForeground;
        secondary = colors.secondary;
        secondaryForeground = colors.secondaryForeground;
        muted = colors.muted;
        mutedForeground = colors.mutedForeground;
        accent = colors.accent;
        accentForeground = colors.accentForeground;
        danger = colors.destructive;
        dangerForeground = colors.destructiveForeground;
        border = colors.border;
        input = colors.input;
        ring = colors.ring;

        this.tokens.background = ThemeToken.fromHsla(colors.background);
        this.tokens.popover = ThemeToken.fromHsla(colors.surface);
        this.tokens.primary = ThemeToken.fromHsla(colors.primary);
        this.tokens.secondary = ThemeToken.fromHsla(colors.secondary);
        this.tokens.muted = ThemeToken.fromHsla(colors.muted);
        this.tokens.accent = ThemeToken.fromHsla(colors.accent);
        this.tokens.danger = ThemeToken.fromHsla(colors.destructive);

        radius = tokens.radius.md;
        radiusLg = tokens.radius.lg;
        fontFamily = tokens.typography.sans;
        monoFontFamily = tokens.typography.mono;
        fontSize = tokens.typography.md.size;
        monoFontSize = tokens.typography.monoMd.size;
        shadow = tokens.shadow.sm.length > 0 || tokens.shadow.md.length > 0 || tokens.shadow.lg.length > 0;

    }

    /**
     * Resolves a standalone semantic configuration over the current legacy
     * theme without mutating either value.
     */
    public function resolveSemanticConfig(config:SemanticThemeConfig):SemanticThemeTokens {

        final tokens = semanticTokens();
        config.applyTo(tokens);
        return tokens;

    }

    /**
     * Applies the legacy-representable part of a standalone semantic config
     * and returns the complete resolved snapshot for application-owned UI.
     */
    public function applySemanticConfig(config:SemanticThemeConfig):SemanticThemeTokens {

        final tokens = resolveSemanticConfig(config);
        applySemanticTokens(tokens);
        return tokens;

    }

    /**
     * Parses and applies a standalone `{ "tokens": ... }` semantic theme
     * file. Throws when the content is invalid.
     */
    public function applySemanticConfigStr(content:String):SemanticThemeTokens {

        final config = SemanticThemeConfigFile.parse(content);
        return applySemanticConfig(config.tokens);

    }

    /**
     * Apply the given theme configuration to the current theme.
     */
    public function applyConfig(config:ThemeConfig):Void {

        if (config.mode.isDark()) {
            darkTheme = config;
        }
        else {
            lightTheme = config;
        }
        if (config.highlight != null) {
            highlight = config.highlight;
            highlightTheme = new glaze.kit.highlighter.HighlightTheme(config.name, config.mode,
                glaze.kit.highlighter.HighlightTheme.HighlightThemeStyle.fromJson(config.highlight));
        }

        final defaultColors = config.mode.isDark() ? ThemeColor.dark() : ThemeColor.light();

        if (config.fontSize != null) {
            fontSize = config.fontSize;
        }
        if (config.fontFamily != null) {
            fontFamily = config.fontFamily;
        }
        if (config.monoFontFamily != null) {
            monoFontFamily = config.monoFontFamily;
        }
        if (config.monoFontSize != null) {
            monoFontSize = config.monoFontSize;
        }
        if (config.radius != null) {
            radius = config.radius;
        }
        if (config.radiusLg != null) {
            radiusLg = config.radiusLg;
        }
        if (config.shadow != null) {
            shadow = config.shadow;
        }

        tokens = applyConfigColors(config, defaultColors);
        mode = config.mode;

    }

}
