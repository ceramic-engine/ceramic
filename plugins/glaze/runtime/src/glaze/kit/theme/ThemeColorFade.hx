// New code for the Haxe port of gpui-kit (no gpui-kit origin): the animated
// transition of the theme colors (Glaze addition KIT-027, see docs/DEVIATIONS.md). See NOTICE.md.
package glaze.kit.theme;

import glaze.Background;
import glaze.BackgroundTag;
import glaze.Hsla;
import glaze.LinearColorStop;
import glaze.kit.base.motion.MotionTime;
import glaze.kit.base.motion.Transition;

using glaze.kit.theme.Colorize;

/**
 * A running transition of the theme colors, from the colors shown when it
 * started to the colors of the theme it leads to (see `Theme.update`).
 *
 * The installed theme of every frame is a copy of `target` whose colors and
 * tokens are mixed in Oklab, alpha premultiplied (CSS
 * `color-mix(in oklab, ...)`, `Colorize.mixOklab`): a perceptual space, so a
 * dark to light fade has no muddy or overly bright midpoint. Every field that
 * is not a color comes from `target` from the first frame on.
 */
@:allow(glaze.kit.theme)
class ThemeColorFade {

    /**
     * The interval between two frames of the fade, in seconds.
     */
    static inline final TICK:Float = 1. / 60.;

    /** The colors the fade starts from (a theme that is never mutated). */
    final from:Theme;

    /** The theme the fade leads to, installed as is when it ends. */
    var target:Theme;

    /** When the fade started, in nanoseconds of the background executor clock. */
    final startedAt:Float;

    final policy:Transition;

    function new(from:Theme, target:Theme, startedAt:Float, policy:Transition) {

        this.from = from;
        this.target = target;
        this.startedAt = startedAt;
        this.policy = policy;

    }

    /**
     * The eased progress at `now` (nanoseconds), from 0 to 1.
     */
    function progress(now:Float):Float {

        final elapsed = now > startedAt ? now - startedAt : 0.;
        final linear = policy.progressValue(elapsed, policy.durationNanos);
        return linear >= 1. ? 1. : policy.sample(linear);

    }

    /**
     * Whether the fade has ended at `now` (nanoseconds).
     */
    function finished(now:Float):Bool {

        final elapsed = now > startedAt ? now - startedAt : 0.;
        return policy.progressValue(elapsed, policy.durationNanos) >= 1.;

    }

    /**
     * The theme to show at eased progress `t`: `target` with mixed colors,
     * carrying this fade.
     */
    function frame(t:Float):Theme {

        final theme = target.clone();
        mixColors(theme, from, target, t);
        mixTokens(theme.tokens, from.tokens, target.tokens, t);
        theme.transparent = mixColor(from.transparent, target.transparent, t);
        theme.colorFade = this;
        return theme;

    }

    /**
     * `from` and `to` mixed at `t` (0 gives `from`, 1 gives `to`, exactly).
     */
    static function mixColor(from:Hsla, to:Hsla, t:Float):Hsla {

        if (t <= 0.) return from;
        if (t >= 1. || from.equals(to)) return to;
        return to.mixOklab(from, t);

    }

    static function mixStop(from:LinearColorStop, to:LinearColorStop, t:Float):LinearColorStop {

        return new LinearColorStop(mixColor(from.color, to.color, t), from.percentage + (to.percentage - from.percentage) * t);

    }

    /**
     * Two tokens mixed at `t`. Solid tokens, and linear gradients in the same
     * color space, are mixed (stops, positions and angle); a token whose kind
     * changes (solid to gradient, pattern...) takes its new value at once.
     */
    static function mixToken(from:ThemeToken, to:ThemeToken, t:Float):ThemeToken {

        if (from == to || t >= 1.) return to;
        if (t <= 0.) return from;
        if (from.equals(to)) return to;
        final a = from.background;
        final b = to.background;
        final color = mixColor(from.color, to.color, t);
        if (a.tag == Solid && b.tag == Solid) {
            return new ThemeToken(color, new Background(Solid, b.colorSpace, mixColor(a.solid, b.solid, t)));
        }
        if (a.tag == LinearGradient && b.tag == LinearGradient && a.colorSpace == b.colorSpace) {
            return new ThemeToken(color, new Background(
                LinearGradient,
                b.colorSpace,
                mixColor(a.solid, b.solid, t),
                a.gradientAngleOrPatternHeight + (b.gradientAngleOrPatternHeight - a.gradientAngleOrPatternHeight) * t,
                mixStop(a.colors0, b.colors0, t),
                mixStop(a.colors1, b.colors1, t)
            ));
        }
        return to;

    }

    static function mixColors(into:ThemeColor, from:ThemeColor, to:ThemeColor, t:Float):Void {

        into.accent = mixColor(from.accent, to.accent, t);
        into.accentForeground = mixColor(from.accentForeground, to.accentForeground, t);
        into.accordion = mixColor(from.accordion, to.accordion, t);
        into.background = mixColor(from.background, to.background, t);
        into.border = mixColor(from.border, to.border, t);
        into.button = mixColor(from.button, to.button, t);
        into.buttonActive = mixColor(from.buttonActive, to.buttonActive, t);
        into.buttonForeground = mixColor(from.buttonForeground, to.buttonForeground, t);
        into.buttonHover = mixColor(from.buttonHover, to.buttonHover, t);
        into.buttonDanger = mixColor(from.buttonDanger, to.buttonDanger, t);
        into.buttonDangerActive = mixColor(from.buttonDangerActive, to.buttonDangerActive, t);
        into.buttonDangerForeground = mixColor(from.buttonDangerForeground, to.buttonDangerForeground, t);
        into.buttonDangerHover = mixColor(from.buttonDangerHover, to.buttonDangerHover, t);
        into.buttonInfo = mixColor(from.buttonInfo, to.buttonInfo, t);
        into.buttonInfoActive = mixColor(from.buttonInfoActive, to.buttonInfoActive, t);
        into.buttonInfoForeground = mixColor(from.buttonInfoForeground, to.buttonInfoForeground, t);
        into.buttonInfoHover = mixColor(from.buttonInfoHover, to.buttonInfoHover, t);
        into.buttonPrimary = mixColor(from.buttonPrimary, to.buttonPrimary, t);
        into.buttonPrimaryActive = mixColor(from.buttonPrimaryActive, to.buttonPrimaryActive, t);
        into.buttonPrimaryForeground = mixColor(from.buttonPrimaryForeground, to.buttonPrimaryForeground, t);
        into.buttonPrimaryHover = mixColor(from.buttonPrimaryHover, to.buttonPrimaryHover, t);
        into.buttonSecondary = mixColor(from.buttonSecondary, to.buttonSecondary, t);
        into.buttonSecondaryActive = mixColor(from.buttonSecondaryActive, to.buttonSecondaryActive, t);
        into.buttonSecondaryForeground = mixColor(from.buttonSecondaryForeground, to.buttonSecondaryForeground, t);
        into.buttonSecondaryHover = mixColor(from.buttonSecondaryHover, to.buttonSecondaryHover, t);
        into.buttonSuccess = mixColor(from.buttonSuccess, to.buttonSuccess, t);
        into.buttonSuccessActive = mixColor(from.buttonSuccessActive, to.buttonSuccessActive, t);
        into.buttonSuccessForeground = mixColor(from.buttonSuccessForeground, to.buttonSuccessForeground, t);
        into.buttonSuccessHover = mixColor(from.buttonSuccessHover, to.buttonSuccessHover, t);
        into.buttonWarning = mixColor(from.buttonWarning, to.buttonWarning, t);
        into.buttonWarningActive = mixColor(from.buttonWarningActive, to.buttonWarningActive, t);
        into.buttonWarningForeground = mixColor(from.buttonWarningForeground, to.buttonWarningForeground, t);
        into.buttonWarningHover = mixColor(from.buttonWarningHover, to.buttonWarningHover, t);
        into.groupBox = mixColor(from.groupBox, to.groupBox, t);
        into.groupBoxForeground = mixColor(from.groupBoxForeground, to.groupBoxForeground, t);
        into.caret = mixColor(from.caret, to.caret, t);
        into.chart1 = mixColor(from.chart1, to.chart1, t);
        into.chart2 = mixColor(from.chart2, to.chart2, t);
        into.chart3 = mixColor(from.chart3, to.chart3, t);
        into.chart4 = mixColor(from.chart4, to.chart4, t);
        into.chart5 = mixColor(from.chart5, to.chart5, t);
        into.chartBullish = mixColor(from.chartBullish, to.chartBullish, t);
        into.chartBearish = mixColor(from.chartBearish, to.chartBearish, t);
        into.chartGrid = mixColor(from.chartGrid, to.chartGrid, t);
        into.danger = mixColor(from.danger, to.danger, t);
        into.dangerActive = mixColor(from.dangerActive, to.dangerActive, t);
        into.dangerForeground = mixColor(from.dangerForeground, to.dangerForeground, t);
        into.dangerHover = mixColor(from.dangerHover, to.dangerHover, t);
        into.descriptionListLabel = mixColor(from.descriptionListLabel, to.descriptionListLabel, t);
        into.descriptionListLabelForeground = mixColor(from.descriptionListLabelForeground, to.descriptionListLabelForeground, t);
        into.dragBorder = mixColor(from.dragBorder, to.dragBorder, t);
        into.dropTarget = mixColor(from.dropTarget, to.dropTarget, t);
        into.foreground = mixColor(from.foreground, to.foreground, t);
        into.info = mixColor(from.info, to.info, t);
        into.infoActive = mixColor(from.infoActive, to.infoActive, t);
        into.infoForeground = mixColor(from.infoForeground, to.infoForeground, t);
        into.infoHover = mixColor(from.infoHover, to.infoHover, t);
        into.input = mixColor(from.input, to.input, t);
        into.link = mixColor(from.link, to.link, t);
        into.linkActive = mixColor(from.linkActive, to.linkActive, t);
        into.linkHover = mixColor(from.linkHover, to.linkHover, t);
        into.list = mixColor(from.list, to.list, t);
        into.listActive = mixColor(from.listActive, to.listActive, t);
        into.listActiveBorder = mixColor(from.listActiveBorder, to.listActiveBorder, t);
        into.listEven = mixColor(from.listEven, to.listEven, t);
        into.listHead = mixColor(from.listHead, to.listHead, t);
        into.listHover = mixColor(from.listHover, to.listHover, t);
        into.muted = mixColor(from.muted, to.muted, t);
        into.mutedForeground = mixColor(from.mutedForeground, to.mutedForeground, t);
        into.popover = mixColor(from.popover, to.popover, t);
        into.popoverForeground = mixColor(from.popoverForeground, to.popoverForeground, t);
        into.primary = mixColor(from.primary, to.primary, t);
        into.primaryActive = mixColor(from.primaryActive, to.primaryActive, t);
        into.primaryForeground = mixColor(from.primaryForeground, to.primaryForeground, t);
        into.primaryHover = mixColor(from.primaryHover, to.primaryHover, t);
        into.progressBar = mixColor(from.progressBar, to.progressBar, t);
        into.ring = mixColor(from.ring, to.ring, t);
        into.scrollbar = mixColor(from.scrollbar, to.scrollbar, t);
        into.scrollbarThumb = mixColor(from.scrollbarThumb, to.scrollbarThumb, t);
        into.scrollbarThumbHover = mixColor(from.scrollbarThumbHover, to.scrollbarThumbHover, t);
        into.secondary = mixColor(from.secondary, to.secondary, t);
        into.secondaryActive = mixColor(from.secondaryActive, to.secondaryActive, t);
        into.secondaryForeground = mixColor(from.secondaryForeground, to.secondaryForeground, t);
        into.secondaryHover = mixColor(from.secondaryHover, to.secondaryHover, t);
        into.selection = mixColor(from.selection, to.selection, t);
        into.sidebar = mixColor(from.sidebar, to.sidebar, t);
        into.sidebarAccent = mixColor(from.sidebarAccent, to.sidebarAccent, t);
        into.sidebarAccentForeground = mixColor(from.sidebarAccentForeground, to.sidebarAccentForeground, t);
        into.sidebarBorder = mixColor(from.sidebarBorder, to.sidebarBorder, t);
        into.sidebarForeground = mixColor(from.sidebarForeground, to.sidebarForeground, t);
        into.sidebarPrimary = mixColor(from.sidebarPrimary, to.sidebarPrimary, t);
        into.sidebarPrimaryForeground = mixColor(from.sidebarPrimaryForeground, to.sidebarPrimaryForeground, t);
        into.skeleton = mixColor(from.skeleton, to.skeleton, t);
        into.sliderBar = mixColor(from.sliderBar, to.sliderBar, t);
        into.sliderThumb = mixColor(from.sliderThumb, to.sliderThumb, t);
        into.success = mixColor(from.success, to.success, t);
        into.successForeground = mixColor(from.successForeground, to.successForeground, t);
        into.successHover = mixColor(from.successHover, to.successHover, t);
        into.successActive = mixColor(from.successActive, to.successActive, t);
        into.switch_ = mixColor(from.switch_, to.switch_, t);
        into.switchThumb = mixColor(from.switchThumb, to.switchThumb, t);
        into.tab = mixColor(from.tab, to.tab, t);
        into.tabActive = mixColor(from.tabActive, to.tabActive, t);
        into.tabActiveForeground = mixColor(from.tabActiveForeground, to.tabActiveForeground, t);
        into.tabBar = mixColor(from.tabBar, to.tabBar, t);
        into.tabBarSegmented = mixColor(from.tabBarSegmented, to.tabBarSegmented, t);
        into.tabForeground = mixColor(from.tabForeground, to.tabForeground, t);
        into.tabHover = mixColor(from.tabHover, to.tabHover, t);
        into.tabHoverForeground = mixColor(from.tabHoverForeground, to.tabHoverForeground, t);
        into.table = mixColor(from.table, to.table, t);
        into.tableActive = mixColor(from.tableActive, to.tableActive, t);
        into.tableActiveBorder = mixColor(from.tableActiveBorder, to.tableActiveBorder, t);
        into.tableEven = mixColor(from.tableEven, to.tableEven, t);
        into.tableHead = mixColor(from.tableHead, to.tableHead, t);
        into.tableHeadForeground = mixColor(from.tableHeadForeground, to.tableHeadForeground, t);
        into.tableFoot = mixColor(from.tableFoot, to.tableFoot, t);
        into.tableFootForeground = mixColor(from.tableFootForeground, to.tableFootForeground, t);
        into.tableHover = mixColor(from.tableHover, to.tableHover, t);
        into.tableRowBorder = mixColor(from.tableRowBorder, to.tableRowBorder, t);
        into.titleBar = mixColor(from.titleBar, to.titleBar, t);
        into.titleBarBorder = mixColor(from.titleBarBorder, to.titleBarBorder, t);
        into.statusBar = mixColor(from.statusBar, to.statusBar, t);
        into.statusBarBorder = mixColor(from.statusBarBorder, to.statusBarBorder, t);
        into.warning = mixColor(from.warning, to.warning, t);
        into.warningActive = mixColor(from.warningActive, to.warningActive, t);
        into.warningHover = mixColor(from.warningHover, to.warningHover, t);
        into.warningForeground = mixColor(from.warningForeground, to.warningForeground, t);
        into.overlay = mixColor(from.overlay, to.overlay, t);
        into.windowBorder = mixColor(from.windowBorder, to.windowBorder, t);
        into.red = mixColor(from.red, to.red, t);
        into.redLight = mixColor(from.redLight, to.redLight, t);
        into.green = mixColor(from.green, to.green, t);
        into.greenLight = mixColor(from.greenLight, to.greenLight, t);
        into.blue = mixColor(from.blue, to.blue, t);
        into.blueLight = mixColor(from.blueLight, to.blueLight, t);
        into.yellow = mixColor(from.yellow, to.yellow, t);
        into.yellowLight = mixColor(from.yellowLight, to.yellowLight, t);
        into.magenta = mixColor(from.magenta, to.magenta, t);
        into.magentaLight = mixColor(from.magentaLight, to.magentaLight, t);
        into.cyan = mixColor(from.cyan, to.cyan, t);
        into.cyanLight = mixColor(from.cyanLight, to.cyanLight, t);

    }

    static function mixTokens(into:ThemeTokens, from:ThemeTokens, to:ThemeTokens, t:Float):Void {

        into.accent = mixToken(from.accent, to.accent, t);
        into.accentForeground = mixToken(from.accentForeground, to.accentForeground, t);
        into.accordion = mixToken(from.accordion, to.accordion, t);
        into.background = mixToken(from.background, to.background, t);
        into.border = mixToken(from.border, to.border, t);
        into.button = mixToken(from.button, to.button, t);
        into.buttonActive = mixToken(from.buttonActive, to.buttonActive, t);
        into.buttonForeground = mixToken(from.buttonForeground, to.buttonForeground, t);
        into.buttonHover = mixToken(from.buttonHover, to.buttonHover, t);
        into.buttonDanger = mixToken(from.buttonDanger, to.buttonDanger, t);
        into.buttonDangerActive = mixToken(from.buttonDangerActive, to.buttonDangerActive, t);
        into.buttonDangerForeground = mixToken(from.buttonDangerForeground, to.buttonDangerForeground, t);
        into.buttonDangerHover = mixToken(from.buttonDangerHover, to.buttonDangerHover, t);
        into.buttonInfo = mixToken(from.buttonInfo, to.buttonInfo, t);
        into.buttonInfoActive = mixToken(from.buttonInfoActive, to.buttonInfoActive, t);
        into.buttonInfoForeground = mixToken(from.buttonInfoForeground, to.buttonInfoForeground, t);
        into.buttonInfoHover = mixToken(from.buttonInfoHover, to.buttonInfoHover, t);
        into.buttonPrimary = mixToken(from.buttonPrimary, to.buttonPrimary, t);
        into.buttonPrimaryActive = mixToken(from.buttonPrimaryActive, to.buttonPrimaryActive, t);
        into.buttonPrimaryForeground = mixToken(from.buttonPrimaryForeground, to.buttonPrimaryForeground, t);
        into.buttonPrimaryHover = mixToken(from.buttonPrimaryHover, to.buttonPrimaryHover, t);
        into.buttonSecondary = mixToken(from.buttonSecondary, to.buttonSecondary, t);
        into.buttonSecondaryActive = mixToken(from.buttonSecondaryActive, to.buttonSecondaryActive, t);
        into.buttonSecondaryForeground = mixToken(from.buttonSecondaryForeground, to.buttonSecondaryForeground, t);
        into.buttonSecondaryHover = mixToken(from.buttonSecondaryHover, to.buttonSecondaryHover, t);
        into.buttonSuccess = mixToken(from.buttonSuccess, to.buttonSuccess, t);
        into.buttonSuccessActive = mixToken(from.buttonSuccessActive, to.buttonSuccessActive, t);
        into.buttonSuccessForeground = mixToken(from.buttonSuccessForeground, to.buttonSuccessForeground, t);
        into.buttonSuccessHover = mixToken(from.buttonSuccessHover, to.buttonSuccessHover, t);
        into.buttonWarning = mixToken(from.buttonWarning, to.buttonWarning, t);
        into.buttonWarningActive = mixToken(from.buttonWarningActive, to.buttonWarningActive, t);
        into.buttonWarningForeground = mixToken(from.buttonWarningForeground, to.buttonWarningForeground, t);
        into.buttonWarningHover = mixToken(from.buttonWarningHover, to.buttonWarningHover, t);
        into.groupBox = mixToken(from.groupBox, to.groupBox, t);
        into.groupBoxForeground = mixToken(from.groupBoxForeground, to.groupBoxForeground, t);
        into.caret = mixToken(from.caret, to.caret, t);
        into.chart1 = mixToken(from.chart1, to.chart1, t);
        into.chart2 = mixToken(from.chart2, to.chart2, t);
        into.chart3 = mixToken(from.chart3, to.chart3, t);
        into.chart4 = mixToken(from.chart4, to.chart4, t);
        into.chart5 = mixToken(from.chart5, to.chart5, t);
        into.chartBullish = mixToken(from.chartBullish, to.chartBullish, t);
        into.chartBearish = mixToken(from.chartBearish, to.chartBearish, t);
        into.chartGrid = mixToken(from.chartGrid, to.chartGrid, t);
        into.danger = mixToken(from.danger, to.danger, t);
        into.dangerActive = mixToken(from.dangerActive, to.dangerActive, t);
        into.dangerForeground = mixToken(from.dangerForeground, to.dangerForeground, t);
        into.dangerHover = mixToken(from.dangerHover, to.dangerHover, t);
        into.descriptionListLabel = mixToken(from.descriptionListLabel, to.descriptionListLabel, t);
        into.descriptionListLabelForeground = mixToken(from.descriptionListLabelForeground, to.descriptionListLabelForeground, t);
        into.dragBorder = mixToken(from.dragBorder, to.dragBorder, t);
        into.dropTarget = mixToken(from.dropTarget, to.dropTarget, t);
        into.foreground = mixToken(from.foreground, to.foreground, t);
        into.info = mixToken(from.info, to.info, t);
        into.infoActive = mixToken(from.infoActive, to.infoActive, t);
        into.infoForeground = mixToken(from.infoForeground, to.infoForeground, t);
        into.infoHover = mixToken(from.infoHover, to.infoHover, t);
        into.input = mixToken(from.input, to.input, t);
        into.link = mixToken(from.link, to.link, t);
        into.linkActive = mixToken(from.linkActive, to.linkActive, t);
        into.linkHover = mixToken(from.linkHover, to.linkHover, t);
        into.list = mixToken(from.list, to.list, t);
        into.listActive = mixToken(from.listActive, to.listActive, t);
        into.listActiveBorder = mixToken(from.listActiveBorder, to.listActiveBorder, t);
        into.listEven = mixToken(from.listEven, to.listEven, t);
        into.listHead = mixToken(from.listHead, to.listHead, t);
        into.listHover = mixToken(from.listHover, to.listHover, t);
        into.muted = mixToken(from.muted, to.muted, t);
        into.mutedForeground = mixToken(from.mutedForeground, to.mutedForeground, t);
        into.popover = mixToken(from.popover, to.popover, t);
        into.popoverForeground = mixToken(from.popoverForeground, to.popoverForeground, t);
        into.primary = mixToken(from.primary, to.primary, t);
        into.primaryActive = mixToken(from.primaryActive, to.primaryActive, t);
        into.primaryForeground = mixToken(from.primaryForeground, to.primaryForeground, t);
        into.primaryHover = mixToken(from.primaryHover, to.primaryHover, t);
        into.progressBar = mixToken(from.progressBar, to.progressBar, t);
        into.ring = mixToken(from.ring, to.ring, t);
        into.scrollbar = mixToken(from.scrollbar, to.scrollbar, t);
        into.scrollbarThumb = mixToken(from.scrollbarThumb, to.scrollbarThumb, t);
        into.scrollbarThumbHover = mixToken(from.scrollbarThumbHover, to.scrollbarThumbHover, t);
        into.secondary = mixToken(from.secondary, to.secondary, t);
        into.secondaryActive = mixToken(from.secondaryActive, to.secondaryActive, t);
        into.secondaryForeground = mixToken(from.secondaryForeground, to.secondaryForeground, t);
        into.secondaryHover = mixToken(from.secondaryHover, to.secondaryHover, t);
        into.selection = mixToken(from.selection, to.selection, t);
        into.sidebar = mixToken(from.sidebar, to.sidebar, t);
        into.sidebarAccent = mixToken(from.sidebarAccent, to.sidebarAccent, t);
        into.sidebarAccentForeground = mixToken(from.sidebarAccentForeground, to.sidebarAccentForeground, t);
        into.sidebarBorder = mixToken(from.sidebarBorder, to.sidebarBorder, t);
        into.sidebarForeground = mixToken(from.sidebarForeground, to.sidebarForeground, t);
        into.sidebarPrimary = mixToken(from.sidebarPrimary, to.sidebarPrimary, t);
        into.sidebarPrimaryForeground = mixToken(from.sidebarPrimaryForeground, to.sidebarPrimaryForeground, t);
        into.skeleton = mixToken(from.skeleton, to.skeleton, t);
        into.sliderBar = mixToken(from.sliderBar, to.sliderBar, t);
        into.sliderThumb = mixToken(from.sliderThumb, to.sliderThumb, t);
        into.success = mixToken(from.success, to.success, t);
        into.successForeground = mixToken(from.successForeground, to.successForeground, t);
        into.successHover = mixToken(from.successHover, to.successHover, t);
        into.successActive = mixToken(from.successActive, to.successActive, t);
        into.switch_ = mixToken(from.switch_, to.switch_, t);
        into.switchThumb = mixToken(from.switchThumb, to.switchThumb, t);
        into.tab = mixToken(from.tab, to.tab, t);
        into.tabActive = mixToken(from.tabActive, to.tabActive, t);
        into.tabActiveForeground = mixToken(from.tabActiveForeground, to.tabActiveForeground, t);
        into.tabBar = mixToken(from.tabBar, to.tabBar, t);
        into.tabBarSegmented = mixToken(from.tabBarSegmented, to.tabBarSegmented, t);
        into.tabForeground = mixToken(from.tabForeground, to.tabForeground, t);
        into.tabHover = mixToken(from.tabHover, to.tabHover, t);
        into.tabHoverForeground = mixToken(from.tabHoverForeground, to.tabHoverForeground, t);
        into.table = mixToken(from.table, to.table, t);
        into.tableActive = mixToken(from.tableActive, to.tableActive, t);
        into.tableActiveBorder = mixToken(from.tableActiveBorder, to.tableActiveBorder, t);
        into.tableEven = mixToken(from.tableEven, to.tableEven, t);
        into.tableHead = mixToken(from.tableHead, to.tableHead, t);
        into.tableHeadForeground = mixToken(from.tableHeadForeground, to.tableHeadForeground, t);
        into.tableFoot = mixToken(from.tableFoot, to.tableFoot, t);
        into.tableFootForeground = mixToken(from.tableFootForeground, to.tableFootForeground, t);
        into.tableHover = mixToken(from.tableHover, to.tableHover, t);
        into.tableRowBorder = mixToken(from.tableRowBorder, to.tableRowBorder, t);
        into.titleBar = mixToken(from.titleBar, to.titleBar, t);
        into.titleBarBorder = mixToken(from.titleBarBorder, to.titleBarBorder, t);
        into.statusBar = mixToken(from.statusBar, to.statusBar, t);
        into.statusBarBorder = mixToken(from.statusBarBorder, to.statusBarBorder, t);
        into.warning = mixToken(from.warning, to.warning, t);
        into.warningActive = mixToken(from.warningActive, to.warningActive, t);
        into.warningHover = mixToken(from.warningHover, to.warningHover, t);
        into.warningForeground = mixToken(from.warningForeground, to.warningForeground, t);
        into.overlay = mixToken(from.overlay, to.overlay, t);
        into.windowBorder = mixToken(from.windowBorder, to.windowBorder, t);
        into.red = mixToken(from.red, to.red, t);
        into.redLight = mixToken(from.redLight, to.redLight, t);
        into.green = mixToken(from.green, to.green, t);
        into.greenLight = mixToken(from.greenLight, to.greenLight, t);
        into.blue = mixToken(from.blue, to.blue, t);
        into.blueLight = mixToken(from.blueLight, to.blueLight, t);
        into.yellow = mixToken(from.yellow, to.yellow, t);
        into.yellowLight = mixToken(from.yellowLight, to.yellowLight, t);
        into.magenta = mixToken(from.magenta, to.magenta, t);
        into.magentaLight = mixToken(from.magentaLight, to.magentaLight, t);
        into.cyan = mixToken(from.cyan, to.cyan, t);
        into.cyanLight = mixToken(from.cyanLight, to.cyanLight, t);

    }

}
