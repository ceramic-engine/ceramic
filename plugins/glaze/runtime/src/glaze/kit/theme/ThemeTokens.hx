// Ported from gpui-kit 0.8.1: crates/component/src/theme/theme_color.rs (define_theme_tokens!)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

/**
 * Legacy resolved tokens retained for compatibility with existing
 * `gpui-component` themes and components.
 *
 * This type intentionally includes component-specific fields such as
 * `buttonPrimary`, `tabActive`, and `tableHover`. New application-owned
 * components should use `glaze.kit.base.theme.SemanticThemeTokens` instead.
 *
 * The fields are the ones of `ThemeColor`, as `ThemeToken`s (a solid
 * representative color plus a renderable background that may be a gradient).
 * `switch` is a Haxe keyword: the switch token is the `switch_` field.
 */
class ThemeTokens {

    static final ZERO:ThemeToken = new ThemeToken();

    public var accent:ThemeToken = ZERO;
    public var accentForeground:ThemeToken = ZERO;
    public var accordion:ThemeToken = ZERO;
    public var background:ThemeToken = ZERO;
    public var border:ThemeToken = ZERO;
    public var button:ThemeToken = ZERO;
    public var buttonActive:ThemeToken = ZERO;
    public var buttonForeground:ThemeToken = ZERO;
    public var buttonHover:ThemeToken = ZERO;
    public var buttonDanger:ThemeToken = ZERO;
    public var buttonDangerActive:ThemeToken = ZERO;
    public var buttonDangerForeground:ThemeToken = ZERO;
    public var buttonDangerHover:ThemeToken = ZERO;
    public var buttonInfo:ThemeToken = ZERO;
    public var buttonInfoActive:ThemeToken = ZERO;
    public var buttonInfoForeground:ThemeToken = ZERO;
    public var buttonInfoHover:ThemeToken = ZERO;
    public var buttonPrimary:ThemeToken = ZERO;
    public var buttonPrimaryActive:ThemeToken = ZERO;
    public var buttonPrimaryForeground:ThemeToken = ZERO;
    public var buttonPrimaryHover:ThemeToken = ZERO;
    public var buttonSecondary:ThemeToken = ZERO;
    public var buttonSecondaryActive:ThemeToken = ZERO;
    public var buttonSecondaryForeground:ThemeToken = ZERO;
    public var buttonSecondaryHover:ThemeToken = ZERO;
    public var buttonSuccess:ThemeToken = ZERO;
    public var buttonSuccessActive:ThemeToken = ZERO;
    public var buttonSuccessForeground:ThemeToken = ZERO;
    public var buttonSuccessHover:ThemeToken = ZERO;
    public var buttonWarning:ThemeToken = ZERO;
    public var buttonWarningActive:ThemeToken = ZERO;
    public var buttonWarningForeground:ThemeToken = ZERO;
    public var buttonWarningHover:ThemeToken = ZERO;
    public var groupBox:ThemeToken = ZERO;
    public var groupBoxForeground:ThemeToken = ZERO;
    public var caret:ThemeToken = ZERO;
    public var chart1:ThemeToken = ZERO;
    public var chart2:ThemeToken = ZERO;
    public var chart3:ThemeToken = ZERO;
    public var chart4:ThemeToken = ZERO;
    public var chart5:ThemeToken = ZERO;
    public var chartBullish:ThemeToken = ZERO;
    public var chartBearish:ThemeToken = ZERO;
    public var chartGrid:ThemeToken = ZERO;
    public var danger:ThemeToken = ZERO;
    public var dangerActive:ThemeToken = ZERO;
    public var dangerForeground:ThemeToken = ZERO;
    public var dangerHover:ThemeToken = ZERO;
    public var descriptionListLabel:ThemeToken = ZERO;
    public var descriptionListLabelForeground:ThemeToken = ZERO;
    public var dragBorder:ThemeToken = ZERO;
    public var dropTarget:ThemeToken = ZERO;
    public var foreground:ThemeToken = ZERO;
    public var info:ThemeToken = ZERO;
    public var infoActive:ThemeToken = ZERO;
    public var infoForeground:ThemeToken = ZERO;
    public var infoHover:ThemeToken = ZERO;
    public var input:ThemeToken = ZERO;
    public var link:ThemeToken = ZERO;
    public var linkActive:ThemeToken = ZERO;
    public var linkHover:ThemeToken = ZERO;
    public var list:ThemeToken = ZERO;
    public var listActive:ThemeToken = ZERO;
    public var listActiveBorder:ThemeToken = ZERO;
    public var listEven:ThemeToken = ZERO;
    public var listHead:ThemeToken = ZERO;
    public var listHover:ThemeToken = ZERO;
    public var muted:ThemeToken = ZERO;
    public var mutedForeground:ThemeToken = ZERO;
    public var popover:ThemeToken = ZERO;
    public var popoverForeground:ThemeToken = ZERO;
    public var primary:ThemeToken = ZERO;
    public var primaryActive:ThemeToken = ZERO;
    public var primaryForeground:ThemeToken = ZERO;
    public var primaryHover:ThemeToken = ZERO;
    public var progressBar:ThemeToken = ZERO;
    public var ring:ThemeToken = ZERO;
    public var scrollbar:ThemeToken = ZERO;
    public var scrollbarThumb:ThemeToken = ZERO;
    public var scrollbarThumbHover:ThemeToken = ZERO;
    public var secondary:ThemeToken = ZERO;
    public var secondaryActive:ThemeToken = ZERO;
    public var secondaryForeground:ThemeToken = ZERO;
    public var secondaryHover:ThemeToken = ZERO;
    public var selection:ThemeToken = ZERO;
    public var sidebar:ThemeToken = ZERO;
    public var sidebarAccent:ThemeToken = ZERO;
    public var sidebarAccentForeground:ThemeToken = ZERO;
    public var sidebarBorder:ThemeToken = ZERO;
    public var sidebarForeground:ThemeToken = ZERO;
    public var sidebarPrimary:ThemeToken = ZERO;
    public var sidebarPrimaryForeground:ThemeToken = ZERO;
    public var skeleton:ThemeToken = ZERO;
    public var sliderBar:ThemeToken = ZERO;
    public var sliderThumb:ThemeToken = ZERO;
    public var success:ThemeToken = ZERO;
    public var successForeground:ThemeToken = ZERO;
    public var successHover:ThemeToken = ZERO;
    public var successActive:ThemeToken = ZERO;
    public var switch_:ThemeToken = ZERO;
    public var switchThumb:ThemeToken = ZERO;
    public var tab:ThemeToken = ZERO;
    public var tabActive:ThemeToken = ZERO;
    public var tabActiveForeground:ThemeToken = ZERO;
    public var tabBar:ThemeToken = ZERO;
    public var tabBarSegmented:ThemeToken = ZERO;
    public var tabForeground:ThemeToken = ZERO;
    public var table:ThemeToken = ZERO;
    public var tableActive:ThemeToken = ZERO;
    public var tableActiveBorder:ThemeToken = ZERO;
    public var tableEven:ThemeToken = ZERO;
    public var tableHead:ThemeToken = ZERO;
    public var tableHeadForeground:ThemeToken = ZERO;
    public var tableFoot:ThemeToken = ZERO;
    public var tableFootForeground:ThemeToken = ZERO;
    public var tableHover:ThemeToken = ZERO;
    public var tableRowBorder:ThemeToken = ZERO;
    public var titleBar:ThemeToken = ZERO;
    public var titleBarBorder:ThemeToken = ZERO;
    public var statusBar:ThemeToken = ZERO;
    public var statusBarBorder:ThemeToken = ZERO;
    public var warning:ThemeToken = ZERO;
    public var warningActive:ThemeToken = ZERO;
    public var warningHover:ThemeToken = ZERO;
    public var warningForeground:ThemeToken = ZERO;
    public var overlay:ThemeToken = ZERO;
    public var windowBorder:ThemeToken = ZERO;
    public var red:ThemeToken = ZERO;
    public var redLight:ThemeToken = ZERO;
    public var green:ThemeToken = ZERO;
    public var greenLight:ThemeToken = ZERO;
    public var blue:ThemeToken = ZERO;
    public var blueLight:ThemeToken = ZERO;
    public var yellow:ThemeToken = ZERO;
    public var yellowLight:ThemeToken = ZERO;
    public var magenta:ThemeToken = ZERO;
    public var magentaLight:ThemeToken = ZERO;
    public var cyan:ThemeToken = ZERO;
    public var cyanLight:ThemeToken = ZERO;

    public function new() {}

    /**
     * Every token as the solid color of the same field (Rust: `From<ThemeColor>`).
     */
    public static function fromColors(colors:ThemeColor):ThemeTokens {

        final tokens = new ThemeTokens();
        tokens.accent = ThemeToken.fromHsla(colors.accent);
        tokens.accentForeground = ThemeToken.fromHsla(colors.accentForeground);
        tokens.accordion = ThemeToken.fromHsla(colors.accordion);
        tokens.background = ThemeToken.fromHsla(colors.background);
        tokens.border = ThemeToken.fromHsla(colors.border);
        tokens.button = ThemeToken.fromHsla(colors.button);
        tokens.buttonActive = ThemeToken.fromHsla(colors.buttonActive);
        tokens.buttonForeground = ThemeToken.fromHsla(colors.buttonForeground);
        tokens.buttonHover = ThemeToken.fromHsla(colors.buttonHover);
        tokens.buttonDanger = ThemeToken.fromHsla(colors.buttonDanger);
        tokens.buttonDangerActive = ThemeToken.fromHsla(colors.buttonDangerActive);
        tokens.buttonDangerForeground = ThemeToken.fromHsla(colors.buttonDangerForeground);
        tokens.buttonDangerHover = ThemeToken.fromHsla(colors.buttonDangerHover);
        tokens.buttonInfo = ThemeToken.fromHsla(colors.buttonInfo);
        tokens.buttonInfoActive = ThemeToken.fromHsla(colors.buttonInfoActive);
        tokens.buttonInfoForeground = ThemeToken.fromHsla(colors.buttonInfoForeground);
        tokens.buttonInfoHover = ThemeToken.fromHsla(colors.buttonInfoHover);
        tokens.buttonPrimary = ThemeToken.fromHsla(colors.buttonPrimary);
        tokens.buttonPrimaryActive = ThemeToken.fromHsla(colors.buttonPrimaryActive);
        tokens.buttonPrimaryForeground = ThemeToken.fromHsla(colors.buttonPrimaryForeground);
        tokens.buttonPrimaryHover = ThemeToken.fromHsla(colors.buttonPrimaryHover);
        tokens.buttonSecondary = ThemeToken.fromHsla(colors.buttonSecondary);
        tokens.buttonSecondaryActive = ThemeToken.fromHsla(colors.buttonSecondaryActive);
        tokens.buttonSecondaryForeground = ThemeToken.fromHsla(colors.buttonSecondaryForeground);
        tokens.buttonSecondaryHover = ThemeToken.fromHsla(colors.buttonSecondaryHover);
        tokens.buttonSuccess = ThemeToken.fromHsla(colors.buttonSuccess);
        tokens.buttonSuccessActive = ThemeToken.fromHsla(colors.buttonSuccessActive);
        tokens.buttonSuccessForeground = ThemeToken.fromHsla(colors.buttonSuccessForeground);
        tokens.buttonSuccessHover = ThemeToken.fromHsla(colors.buttonSuccessHover);
        tokens.buttonWarning = ThemeToken.fromHsla(colors.buttonWarning);
        tokens.buttonWarningActive = ThemeToken.fromHsla(colors.buttonWarningActive);
        tokens.buttonWarningForeground = ThemeToken.fromHsla(colors.buttonWarningForeground);
        tokens.buttonWarningHover = ThemeToken.fromHsla(colors.buttonWarningHover);
        tokens.groupBox = ThemeToken.fromHsla(colors.groupBox);
        tokens.groupBoxForeground = ThemeToken.fromHsla(colors.groupBoxForeground);
        tokens.caret = ThemeToken.fromHsla(colors.caret);
        tokens.chart1 = ThemeToken.fromHsla(colors.chart1);
        tokens.chart2 = ThemeToken.fromHsla(colors.chart2);
        tokens.chart3 = ThemeToken.fromHsla(colors.chart3);
        tokens.chart4 = ThemeToken.fromHsla(colors.chart4);
        tokens.chart5 = ThemeToken.fromHsla(colors.chart5);
        tokens.chartBullish = ThemeToken.fromHsla(colors.chartBullish);
        tokens.chartBearish = ThemeToken.fromHsla(colors.chartBearish);
        tokens.chartGrid = ThemeToken.fromHsla(colors.chartGrid);
        tokens.danger = ThemeToken.fromHsla(colors.danger);
        tokens.dangerActive = ThemeToken.fromHsla(colors.dangerActive);
        tokens.dangerForeground = ThemeToken.fromHsla(colors.dangerForeground);
        tokens.dangerHover = ThemeToken.fromHsla(colors.dangerHover);
        tokens.descriptionListLabel = ThemeToken.fromHsla(colors.descriptionListLabel);
        tokens.descriptionListLabelForeground = ThemeToken.fromHsla(colors.descriptionListLabelForeground);
        tokens.dragBorder = ThemeToken.fromHsla(colors.dragBorder);
        tokens.dropTarget = ThemeToken.fromHsla(colors.dropTarget);
        tokens.foreground = ThemeToken.fromHsla(colors.foreground);
        tokens.info = ThemeToken.fromHsla(colors.info);
        tokens.infoActive = ThemeToken.fromHsla(colors.infoActive);
        tokens.infoForeground = ThemeToken.fromHsla(colors.infoForeground);
        tokens.infoHover = ThemeToken.fromHsla(colors.infoHover);
        tokens.input = ThemeToken.fromHsla(colors.input);
        tokens.link = ThemeToken.fromHsla(colors.link);
        tokens.linkActive = ThemeToken.fromHsla(colors.linkActive);
        tokens.linkHover = ThemeToken.fromHsla(colors.linkHover);
        tokens.list = ThemeToken.fromHsla(colors.list);
        tokens.listActive = ThemeToken.fromHsla(colors.listActive);
        tokens.listActiveBorder = ThemeToken.fromHsla(colors.listActiveBorder);
        tokens.listEven = ThemeToken.fromHsla(colors.listEven);
        tokens.listHead = ThemeToken.fromHsla(colors.listHead);
        tokens.listHover = ThemeToken.fromHsla(colors.listHover);
        tokens.muted = ThemeToken.fromHsla(colors.muted);
        tokens.mutedForeground = ThemeToken.fromHsla(colors.mutedForeground);
        tokens.popover = ThemeToken.fromHsla(colors.popover);
        tokens.popoverForeground = ThemeToken.fromHsla(colors.popoverForeground);
        tokens.primary = ThemeToken.fromHsla(colors.primary);
        tokens.primaryActive = ThemeToken.fromHsla(colors.primaryActive);
        tokens.primaryForeground = ThemeToken.fromHsla(colors.primaryForeground);
        tokens.primaryHover = ThemeToken.fromHsla(colors.primaryHover);
        tokens.progressBar = ThemeToken.fromHsla(colors.progressBar);
        tokens.ring = ThemeToken.fromHsla(colors.ring);
        tokens.scrollbar = ThemeToken.fromHsla(colors.scrollbar);
        tokens.scrollbarThumb = ThemeToken.fromHsla(colors.scrollbarThumb);
        tokens.scrollbarThumbHover = ThemeToken.fromHsla(colors.scrollbarThumbHover);
        tokens.secondary = ThemeToken.fromHsla(colors.secondary);
        tokens.secondaryActive = ThemeToken.fromHsla(colors.secondaryActive);
        tokens.secondaryForeground = ThemeToken.fromHsla(colors.secondaryForeground);
        tokens.secondaryHover = ThemeToken.fromHsla(colors.secondaryHover);
        tokens.selection = ThemeToken.fromHsla(colors.selection);
        tokens.sidebar = ThemeToken.fromHsla(colors.sidebar);
        tokens.sidebarAccent = ThemeToken.fromHsla(colors.sidebarAccent);
        tokens.sidebarAccentForeground = ThemeToken.fromHsla(colors.sidebarAccentForeground);
        tokens.sidebarBorder = ThemeToken.fromHsla(colors.sidebarBorder);
        tokens.sidebarForeground = ThemeToken.fromHsla(colors.sidebarForeground);
        tokens.sidebarPrimary = ThemeToken.fromHsla(colors.sidebarPrimary);
        tokens.sidebarPrimaryForeground = ThemeToken.fromHsla(colors.sidebarPrimaryForeground);
        tokens.skeleton = ThemeToken.fromHsla(colors.skeleton);
        tokens.sliderBar = ThemeToken.fromHsla(colors.sliderBar);
        tokens.sliderThumb = ThemeToken.fromHsla(colors.sliderThumb);
        tokens.success = ThemeToken.fromHsla(colors.success);
        tokens.successForeground = ThemeToken.fromHsla(colors.successForeground);
        tokens.successHover = ThemeToken.fromHsla(colors.successHover);
        tokens.successActive = ThemeToken.fromHsla(colors.successActive);
        tokens.switch_ = ThemeToken.fromHsla(colors.switch_);
        tokens.switchThumb = ThemeToken.fromHsla(colors.switchThumb);
        tokens.tab = ThemeToken.fromHsla(colors.tab);
        tokens.tabActive = ThemeToken.fromHsla(colors.tabActive);
        tokens.tabActiveForeground = ThemeToken.fromHsla(colors.tabActiveForeground);
        tokens.tabBar = ThemeToken.fromHsla(colors.tabBar);
        tokens.tabBarSegmented = ThemeToken.fromHsla(colors.tabBarSegmented);
        tokens.tabForeground = ThemeToken.fromHsla(colors.tabForeground);
        tokens.table = ThemeToken.fromHsla(colors.table);
        tokens.tableActive = ThemeToken.fromHsla(colors.tableActive);
        tokens.tableActiveBorder = ThemeToken.fromHsla(colors.tableActiveBorder);
        tokens.tableEven = ThemeToken.fromHsla(colors.tableEven);
        tokens.tableHead = ThemeToken.fromHsla(colors.tableHead);
        tokens.tableHeadForeground = ThemeToken.fromHsla(colors.tableHeadForeground);
        tokens.tableFoot = ThemeToken.fromHsla(colors.tableFoot);
        tokens.tableFootForeground = ThemeToken.fromHsla(colors.tableFootForeground);
        tokens.tableHover = ThemeToken.fromHsla(colors.tableHover);
        tokens.tableRowBorder = ThemeToken.fromHsla(colors.tableRowBorder);
        tokens.titleBar = ThemeToken.fromHsla(colors.titleBar);
        tokens.titleBarBorder = ThemeToken.fromHsla(colors.titleBarBorder);
        tokens.statusBar = ThemeToken.fromHsla(colors.statusBar);
        tokens.statusBarBorder = ThemeToken.fromHsla(colors.statusBarBorder);
        tokens.warning = ThemeToken.fromHsla(colors.warning);
        tokens.warningActive = ThemeToken.fromHsla(colors.warningActive);
        tokens.warningHover = ThemeToken.fromHsla(colors.warningHover);
        tokens.warningForeground = ThemeToken.fromHsla(colors.warningForeground);
        tokens.overlay = ThemeToken.fromHsla(colors.overlay);
        tokens.windowBorder = ThemeToken.fromHsla(colors.windowBorder);
        tokens.red = ThemeToken.fromHsla(colors.red);
        tokens.redLight = ThemeToken.fromHsla(colors.redLight);
        tokens.green = ThemeToken.fromHsla(colors.green);
        tokens.greenLight = ThemeToken.fromHsla(colors.greenLight);
        tokens.blue = ThemeToken.fromHsla(colors.blue);
        tokens.blueLight = ThemeToken.fromHsla(colors.blueLight);
        tokens.yellow = ThemeToken.fromHsla(colors.yellow);
        tokens.yellowLight = ThemeToken.fromHsla(colors.yellowLight);
        tokens.magenta = ThemeToken.fromHsla(colors.magenta);
        tokens.magentaLight = ThemeToken.fromHsla(colors.magentaLight);
        tokens.cyan = ThemeToken.fromHsla(colors.cyan);
        tokens.cyanLight = ThemeToken.fromHsla(colors.cyanLight);
        return tokens;

    }

    /**
     * A copy of the tokens (Rust: `ThemeTokens` is `Copy`; tokens are immutable).
     */
    public function copy():ThemeTokens {

        final tokens = new ThemeTokens();
        tokens.accent = accent;
        tokens.accentForeground = accentForeground;
        tokens.accordion = accordion;
        tokens.background = background;
        tokens.border = border;
        tokens.button = button;
        tokens.buttonActive = buttonActive;
        tokens.buttonForeground = buttonForeground;
        tokens.buttonHover = buttonHover;
        tokens.buttonDanger = buttonDanger;
        tokens.buttonDangerActive = buttonDangerActive;
        tokens.buttonDangerForeground = buttonDangerForeground;
        tokens.buttonDangerHover = buttonDangerHover;
        tokens.buttonInfo = buttonInfo;
        tokens.buttonInfoActive = buttonInfoActive;
        tokens.buttonInfoForeground = buttonInfoForeground;
        tokens.buttonInfoHover = buttonInfoHover;
        tokens.buttonPrimary = buttonPrimary;
        tokens.buttonPrimaryActive = buttonPrimaryActive;
        tokens.buttonPrimaryForeground = buttonPrimaryForeground;
        tokens.buttonPrimaryHover = buttonPrimaryHover;
        tokens.buttonSecondary = buttonSecondary;
        tokens.buttonSecondaryActive = buttonSecondaryActive;
        tokens.buttonSecondaryForeground = buttonSecondaryForeground;
        tokens.buttonSecondaryHover = buttonSecondaryHover;
        tokens.buttonSuccess = buttonSuccess;
        tokens.buttonSuccessActive = buttonSuccessActive;
        tokens.buttonSuccessForeground = buttonSuccessForeground;
        tokens.buttonSuccessHover = buttonSuccessHover;
        tokens.buttonWarning = buttonWarning;
        tokens.buttonWarningActive = buttonWarningActive;
        tokens.buttonWarningForeground = buttonWarningForeground;
        tokens.buttonWarningHover = buttonWarningHover;
        tokens.groupBox = groupBox;
        tokens.groupBoxForeground = groupBoxForeground;
        tokens.caret = caret;
        tokens.chart1 = chart1;
        tokens.chart2 = chart2;
        tokens.chart3 = chart3;
        tokens.chart4 = chart4;
        tokens.chart5 = chart5;
        tokens.chartBullish = chartBullish;
        tokens.chartBearish = chartBearish;
        tokens.chartGrid = chartGrid;
        tokens.danger = danger;
        tokens.dangerActive = dangerActive;
        tokens.dangerForeground = dangerForeground;
        tokens.dangerHover = dangerHover;
        tokens.descriptionListLabel = descriptionListLabel;
        tokens.descriptionListLabelForeground = descriptionListLabelForeground;
        tokens.dragBorder = dragBorder;
        tokens.dropTarget = dropTarget;
        tokens.foreground = foreground;
        tokens.info = info;
        tokens.infoActive = infoActive;
        tokens.infoForeground = infoForeground;
        tokens.infoHover = infoHover;
        tokens.input = input;
        tokens.link = link;
        tokens.linkActive = linkActive;
        tokens.linkHover = linkHover;
        tokens.list = list;
        tokens.listActive = listActive;
        tokens.listActiveBorder = listActiveBorder;
        tokens.listEven = listEven;
        tokens.listHead = listHead;
        tokens.listHover = listHover;
        tokens.muted = muted;
        tokens.mutedForeground = mutedForeground;
        tokens.popover = popover;
        tokens.popoverForeground = popoverForeground;
        tokens.primary = primary;
        tokens.primaryActive = primaryActive;
        tokens.primaryForeground = primaryForeground;
        tokens.primaryHover = primaryHover;
        tokens.progressBar = progressBar;
        tokens.ring = ring;
        tokens.scrollbar = scrollbar;
        tokens.scrollbarThumb = scrollbarThumb;
        tokens.scrollbarThumbHover = scrollbarThumbHover;
        tokens.secondary = secondary;
        tokens.secondaryActive = secondaryActive;
        tokens.secondaryForeground = secondaryForeground;
        tokens.secondaryHover = secondaryHover;
        tokens.selection = selection;
        tokens.sidebar = sidebar;
        tokens.sidebarAccent = sidebarAccent;
        tokens.sidebarAccentForeground = sidebarAccentForeground;
        tokens.sidebarBorder = sidebarBorder;
        tokens.sidebarForeground = sidebarForeground;
        tokens.sidebarPrimary = sidebarPrimary;
        tokens.sidebarPrimaryForeground = sidebarPrimaryForeground;
        tokens.skeleton = skeleton;
        tokens.sliderBar = sliderBar;
        tokens.sliderThumb = sliderThumb;
        tokens.success = success;
        tokens.successForeground = successForeground;
        tokens.successHover = successHover;
        tokens.successActive = successActive;
        tokens.switch_ = switch_;
        tokens.switchThumb = switchThumb;
        tokens.tab = tab;
        tokens.tabActive = tabActive;
        tokens.tabActiveForeground = tabActiveForeground;
        tokens.tabBar = tabBar;
        tokens.tabBarSegmented = tabBarSegmented;
        tokens.tabForeground = tabForeground;
        tokens.table = table;
        tokens.tableActive = tableActive;
        tokens.tableActiveBorder = tableActiveBorder;
        tokens.tableEven = tableEven;
        tokens.tableHead = tableHead;
        tokens.tableHeadForeground = tableHeadForeground;
        tokens.tableFoot = tableFoot;
        tokens.tableFootForeground = tableFootForeground;
        tokens.tableHover = tableHover;
        tokens.tableRowBorder = tableRowBorder;
        tokens.titleBar = titleBar;
        tokens.titleBarBorder = titleBarBorder;
        tokens.statusBar = statusBar;
        tokens.statusBarBorder = statusBarBorder;
        tokens.warning = warning;
        tokens.warningActive = warningActive;
        tokens.warningHover = warningHover;
        tokens.warningForeground = warningForeground;
        tokens.overlay = overlay;
        tokens.windowBorder = windowBorder;
        tokens.red = red;
        tokens.redLight = redLight;
        tokens.green = green;
        tokens.greenLight = greenLight;
        tokens.blue = blue;
        tokens.blueLight = blueLight;
        tokens.yellow = yellow;
        tokens.yellowLight = yellowLight;
        tokens.magenta = magenta;
        tokens.magentaLight = magentaLight;
        tokens.cyan = cyan;
        tokens.cyanLight = cyanLight;
        return tokens;

    }

    /**
     * Structural equality (Rust: `PartialEq`).
     */
    public function equals(other:ThemeTokens):Bool {

        return other != null
            && accent.equals(other.accent)
            && accentForeground.equals(other.accentForeground)
            && accordion.equals(other.accordion)
            && background.equals(other.background)
            && border.equals(other.border)
            && button.equals(other.button)
            && buttonActive.equals(other.buttonActive)
            && buttonForeground.equals(other.buttonForeground)
            && buttonHover.equals(other.buttonHover)
            && buttonDanger.equals(other.buttonDanger)
            && buttonDangerActive.equals(other.buttonDangerActive)
            && buttonDangerForeground.equals(other.buttonDangerForeground)
            && buttonDangerHover.equals(other.buttonDangerHover)
            && buttonInfo.equals(other.buttonInfo)
            && buttonInfoActive.equals(other.buttonInfoActive)
            && buttonInfoForeground.equals(other.buttonInfoForeground)
            && buttonInfoHover.equals(other.buttonInfoHover)
            && buttonPrimary.equals(other.buttonPrimary)
            && buttonPrimaryActive.equals(other.buttonPrimaryActive)
            && buttonPrimaryForeground.equals(other.buttonPrimaryForeground)
            && buttonPrimaryHover.equals(other.buttonPrimaryHover)
            && buttonSecondary.equals(other.buttonSecondary)
            && buttonSecondaryActive.equals(other.buttonSecondaryActive)
            && buttonSecondaryForeground.equals(other.buttonSecondaryForeground)
            && buttonSecondaryHover.equals(other.buttonSecondaryHover)
            && buttonSuccess.equals(other.buttonSuccess)
            && buttonSuccessActive.equals(other.buttonSuccessActive)
            && buttonSuccessForeground.equals(other.buttonSuccessForeground)
            && buttonSuccessHover.equals(other.buttonSuccessHover)
            && buttonWarning.equals(other.buttonWarning)
            && buttonWarningActive.equals(other.buttonWarningActive)
            && buttonWarningForeground.equals(other.buttonWarningForeground)
            && buttonWarningHover.equals(other.buttonWarningHover)
            && groupBox.equals(other.groupBox)
            && groupBoxForeground.equals(other.groupBoxForeground)
            && caret.equals(other.caret)
            && chart1.equals(other.chart1)
            && chart2.equals(other.chart2)
            && chart3.equals(other.chart3)
            && chart4.equals(other.chart4)
            && chart5.equals(other.chart5)
            && chartBullish.equals(other.chartBullish)
            && chartBearish.equals(other.chartBearish)
            && chartGrid.equals(other.chartGrid)
            && danger.equals(other.danger)
            && dangerActive.equals(other.dangerActive)
            && dangerForeground.equals(other.dangerForeground)
            && dangerHover.equals(other.dangerHover)
            && descriptionListLabel.equals(other.descriptionListLabel)
            && descriptionListLabelForeground.equals(other.descriptionListLabelForeground)
            && dragBorder.equals(other.dragBorder)
            && dropTarget.equals(other.dropTarget)
            && foreground.equals(other.foreground)
            && info.equals(other.info)
            && infoActive.equals(other.infoActive)
            && infoForeground.equals(other.infoForeground)
            && infoHover.equals(other.infoHover)
            && input.equals(other.input)
            && link.equals(other.link)
            && linkActive.equals(other.linkActive)
            && linkHover.equals(other.linkHover)
            && list.equals(other.list)
            && listActive.equals(other.listActive)
            && listActiveBorder.equals(other.listActiveBorder)
            && listEven.equals(other.listEven)
            && listHead.equals(other.listHead)
            && listHover.equals(other.listHover)
            && muted.equals(other.muted)
            && mutedForeground.equals(other.mutedForeground)
            && popover.equals(other.popover)
            && popoverForeground.equals(other.popoverForeground)
            && primary.equals(other.primary)
            && primaryActive.equals(other.primaryActive)
            && primaryForeground.equals(other.primaryForeground)
            && primaryHover.equals(other.primaryHover)
            && progressBar.equals(other.progressBar)
            && ring.equals(other.ring)
            && scrollbar.equals(other.scrollbar)
            && scrollbarThumb.equals(other.scrollbarThumb)
            && scrollbarThumbHover.equals(other.scrollbarThumbHover)
            && secondary.equals(other.secondary)
            && secondaryActive.equals(other.secondaryActive)
            && secondaryForeground.equals(other.secondaryForeground)
            && secondaryHover.equals(other.secondaryHover)
            && selection.equals(other.selection)
            && sidebar.equals(other.sidebar)
            && sidebarAccent.equals(other.sidebarAccent)
            && sidebarAccentForeground.equals(other.sidebarAccentForeground)
            && sidebarBorder.equals(other.sidebarBorder)
            && sidebarForeground.equals(other.sidebarForeground)
            && sidebarPrimary.equals(other.sidebarPrimary)
            && sidebarPrimaryForeground.equals(other.sidebarPrimaryForeground)
            && skeleton.equals(other.skeleton)
            && sliderBar.equals(other.sliderBar)
            && sliderThumb.equals(other.sliderThumb)
            && success.equals(other.success)
            && successForeground.equals(other.successForeground)
            && successHover.equals(other.successHover)
            && successActive.equals(other.successActive)
            && switch_.equals(other.switch_)
            && switchThumb.equals(other.switchThumb)
            && tab.equals(other.tab)
            && tabActive.equals(other.tabActive)
            && tabActiveForeground.equals(other.tabActiveForeground)
            && tabBar.equals(other.tabBar)
            && tabBarSegmented.equals(other.tabBarSegmented)
            && tabForeground.equals(other.tabForeground)
            && table.equals(other.table)
            && tableActive.equals(other.tableActive)
            && tableActiveBorder.equals(other.tableActiveBorder)
            && tableEven.equals(other.tableEven)
            && tableHead.equals(other.tableHead)
            && tableHeadForeground.equals(other.tableHeadForeground)
            && tableFoot.equals(other.tableFoot)
            && tableFootForeground.equals(other.tableFootForeground)
            && tableHover.equals(other.tableHover)
            && tableRowBorder.equals(other.tableRowBorder)
            && titleBar.equals(other.titleBar)
            && titleBarBorder.equals(other.titleBarBorder)
            && statusBar.equals(other.statusBar)
            && statusBarBorder.equals(other.statusBarBorder)
            && warning.equals(other.warning)
            && warningActive.equals(other.warningActive)
            && warningHover.equals(other.warningHover)
            && warningForeground.equals(other.warningForeground)
            && overlay.equals(other.overlay)
            && windowBorder.equals(other.windowBorder)
            && red.equals(other.red)
            && redLight.equals(other.redLight)
            && green.equals(other.green)
            && greenLight.equals(other.greenLight)
            && blue.equals(other.blue)
            && blueLight.equals(other.blueLight)
            && yellow.equals(other.yellow)
            && yellowLight.equals(other.yellowLight)
            && magenta.equals(other.magenta)
            && magentaLight.equals(other.magentaLight)
            && cyan.equals(other.cyan)
            && cyanLight.equals(other.cyanLight)
        ;

    }

    /**
     * Brings the tokens and `colors` back to one value per field after an
     * edit, given the two as they were before it.
     *
     * A field edited on `colors` wins: when its token no longer names that
     * color, the token becomes that solid color, dropping any gradient it
     * carried. A field edited only on the tokens writes its solid color back
     * to `colors`. A field the edit set on both sides to one color, as
     * applying a theme config does, keeps its token, so a gradient from a
     * theme file survives; so does an untouched field.
     */
    @:allow(glaze.kit.theme)
    function reconcile(colors:ThemeColor, colorsBefore:ThemeColor, tokensBefore:ThemeTokens):Void {

        if (!colors.accent.equals(colorsBefore.accent)) {
            if (!accent.color.equals(colors.accent)) {
                accent = ThemeToken.fromHsla(colors.accent);
            }
        }
        else if (!accent.equals(tokensBefore.accent)) {
            colors.accent = accent.color;
        }
        if (!colors.accentForeground.equals(colorsBefore.accentForeground)) {
            if (!accentForeground.color.equals(colors.accentForeground)) {
                accentForeground = ThemeToken.fromHsla(colors.accentForeground);
            }
        }
        else if (!accentForeground.equals(tokensBefore.accentForeground)) {
            colors.accentForeground = accentForeground.color;
        }
        if (!colors.accordion.equals(colorsBefore.accordion)) {
            if (!accordion.color.equals(colors.accordion)) {
                accordion = ThemeToken.fromHsla(colors.accordion);
            }
        }
        else if (!accordion.equals(tokensBefore.accordion)) {
            colors.accordion = accordion.color;
        }
        if (!colors.background.equals(colorsBefore.background)) {
            if (!background.color.equals(colors.background)) {
                background = ThemeToken.fromHsla(colors.background);
            }
        }
        else if (!background.equals(tokensBefore.background)) {
            colors.background = background.color;
        }
        if (!colors.border.equals(colorsBefore.border)) {
            if (!border.color.equals(colors.border)) {
                border = ThemeToken.fromHsla(colors.border);
            }
        }
        else if (!border.equals(tokensBefore.border)) {
            colors.border = border.color;
        }
        if (!colors.button.equals(colorsBefore.button)) {
            if (!button.color.equals(colors.button)) {
                button = ThemeToken.fromHsla(colors.button);
            }
        }
        else if (!button.equals(tokensBefore.button)) {
            colors.button = button.color;
        }
        if (!colors.buttonActive.equals(colorsBefore.buttonActive)) {
            if (!buttonActive.color.equals(colors.buttonActive)) {
                buttonActive = ThemeToken.fromHsla(colors.buttonActive);
            }
        }
        else if (!buttonActive.equals(tokensBefore.buttonActive)) {
            colors.buttonActive = buttonActive.color;
        }
        if (!colors.buttonForeground.equals(colorsBefore.buttonForeground)) {
            if (!buttonForeground.color.equals(colors.buttonForeground)) {
                buttonForeground = ThemeToken.fromHsla(colors.buttonForeground);
            }
        }
        else if (!buttonForeground.equals(tokensBefore.buttonForeground)) {
            colors.buttonForeground = buttonForeground.color;
        }
        if (!colors.buttonHover.equals(colorsBefore.buttonHover)) {
            if (!buttonHover.color.equals(colors.buttonHover)) {
                buttonHover = ThemeToken.fromHsla(colors.buttonHover);
            }
        }
        else if (!buttonHover.equals(tokensBefore.buttonHover)) {
            colors.buttonHover = buttonHover.color;
        }
        if (!colors.buttonDanger.equals(colorsBefore.buttonDanger)) {
            if (!buttonDanger.color.equals(colors.buttonDanger)) {
                buttonDanger = ThemeToken.fromHsla(colors.buttonDanger);
            }
        }
        else if (!buttonDanger.equals(tokensBefore.buttonDanger)) {
            colors.buttonDanger = buttonDanger.color;
        }
        if (!colors.buttonDangerActive.equals(colorsBefore.buttonDangerActive)) {
            if (!buttonDangerActive.color.equals(colors.buttonDangerActive)) {
                buttonDangerActive = ThemeToken.fromHsla(colors.buttonDangerActive);
            }
        }
        else if (!buttonDangerActive.equals(tokensBefore.buttonDangerActive)) {
            colors.buttonDangerActive = buttonDangerActive.color;
        }
        if (!colors.buttonDangerForeground.equals(colorsBefore.buttonDangerForeground)) {
            if (!buttonDangerForeground.color.equals(colors.buttonDangerForeground)) {
                buttonDangerForeground = ThemeToken.fromHsla(colors.buttonDangerForeground);
            }
        }
        else if (!buttonDangerForeground.equals(tokensBefore.buttonDangerForeground)) {
            colors.buttonDangerForeground = buttonDangerForeground.color;
        }
        if (!colors.buttonDangerHover.equals(colorsBefore.buttonDangerHover)) {
            if (!buttonDangerHover.color.equals(colors.buttonDangerHover)) {
                buttonDangerHover = ThemeToken.fromHsla(colors.buttonDangerHover);
            }
        }
        else if (!buttonDangerHover.equals(tokensBefore.buttonDangerHover)) {
            colors.buttonDangerHover = buttonDangerHover.color;
        }
        if (!colors.buttonInfo.equals(colorsBefore.buttonInfo)) {
            if (!buttonInfo.color.equals(colors.buttonInfo)) {
                buttonInfo = ThemeToken.fromHsla(colors.buttonInfo);
            }
        }
        else if (!buttonInfo.equals(tokensBefore.buttonInfo)) {
            colors.buttonInfo = buttonInfo.color;
        }
        if (!colors.buttonInfoActive.equals(colorsBefore.buttonInfoActive)) {
            if (!buttonInfoActive.color.equals(colors.buttonInfoActive)) {
                buttonInfoActive = ThemeToken.fromHsla(colors.buttonInfoActive);
            }
        }
        else if (!buttonInfoActive.equals(tokensBefore.buttonInfoActive)) {
            colors.buttonInfoActive = buttonInfoActive.color;
        }
        if (!colors.buttonInfoForeground.equals(colorsBefore.buttonInfoForeground)) {
            if (!buttonInfoForeground.color.equals(colors.buttonInfoForeground)) {
                buttonInfoForeground = ThemeToken.fromHsla(colors.buttonInfoForeground);
            }
        }
        else if (!buttonInfoForeground.equals(tokensBefore.buttonInfoForeground)) {
            colors.buttonInfoForeground = buttonInfoForeground.color;
        }
        if (!colors.buttonInfoHover.equals(colorsBefore.buttonInfoHover)) {
            if (!buttonInfoHover.color.equals(colors.buttonInfoHover)) {
                buttonInfoHover = ThemeToken.fromHsla(colors.buttonInfoHover);
            }
        }
        else if (!buttonInfoHover.equals(tokensBefore.buttonInfoHover)) {
            colors.buttonInfoHover = buttonInfoHover.color;
        }
        if (!colors.buttonPrimary.equals(colorsBefore.buttonPrimary)) {
            if (!buttonPrimary.color.equals(colors.buttonPrimary)) {
                buttonPrimary = ThemeToken.fromHsla(colors.buttonPrimary);
            }
        }
        else if (!buttonPrimary.equals(tokensBefore.buttonPrimary)) {
            colors.buttonPrimary = buttonPrimary.color;
        }
        if (!colors.buttonPrimaryActive.equals(colorsBefore.buttonPrimaryActive)) {
            if (!buttonPrimaryActive.color.equals(colors.buttonPrimaryActive)) {
                buttonPrimaryActive = ThemeToken.fromHsla(colors.buttonPrimaryActive);
            }
        }
        else if (!buttonPrimaryActive.equals(tokensBefore.buttonPrimaryActive)) {
            colors.buttonPrimaryActive = buttonPrimaryActive.color;
        }
        if (!colors.buttonPrimaryForeground.equals(colorsBefore.buttonPrimaryForeground)) {
            if (!buttonPrimaryForeground.color.equals(colors.buttonPrimaryForeground)) {
                buttonPrimaryForeground = ThemeToken.fromHsla(colors.buttonPrimaryForeground);
            }
        }
        else if (!buttonPrimaryForeground.equals(tokensBefore.buttonPrimaryForeground)) {
            colors.buttonPrimaryForeground = buttonPrimaryForeground.color;
        }
        if (!colors.buttonPrimaryHover.equals(colorsBefore.buttonPrimaryHover)) {
            if (!buttonPrimaryHover.color.equals(colors.buttonPrimaryHover)) {
                buttonPrimaryHover = ThemeToken.fromHsla(colors.buttonPrimaryHover);
            }
        }
        else if (!buttonPrimaryHover.equals(tokensBefore.buttonPrimaryHover)) {
            colors.buttonPrimaryHover = buttonPrimaryHover.color;
        }
        if (!colors.buttonSecondary.equals(colorsBefore.buttonSecondary)) {
            if (!buttonSecondary.color.equals(colors.buttonSecondary)) {
                buttonSecondary = ThemeToken.fromHsla(colors.buttonSecondary);
            }
        }
        else if (!buttonSecondary.equals(tokensBefore.buttonSecondary)) {
            colors.buttonSecondary = buttonSecondary.color;
        }
        if (!colors.buttonSecondaryActive.equals(colorsBefore.buttonSecondaryActive)) {
            if (!buttonSecondaryActive.color.equals(colors.buttonSecondaryActive)) {
                buttonSecondaryActive = ThemeToken.fromHsla(colors.buttonSecondaryActive);
            }
        }
        else if (!buttonSecondaryActive.equals(tokensBefore.buttonSecondaryActive)) {
            colors.buttonSecondaryActive = buttonSecondaryActive.color;
        }
        if (!colors.buttonSecondaryForeground.equals(colorsBefore.buttonSecondaryForeground)) {
            if (!buttonSecondaryForeground.color.equals(colors.buttonSecondaryForeground)) {
                buttonSecondaryForeground = ThemeToken.fromHsla(colors.buttonSecondaryForeground);
            }
        }
        else if (!buttonSecondaryForeground.equals(tokensBefore.buttonSecondaryForeground)) {
            colors.buttonSecondaryForeground = buttonSecondaryForeground.color;
        }
        if (!colors.buttonSecondaryHover.equals(colorsBefore.buttonSecondaryHover)) {
            if (!buttonSecondaryHover.color.equals(colors.buttonSecondaryHover)) {
                buttonSecondaryHover = ThemeToken.fromHsla(colors.buttonSecondaryHover);
            }
        }
        else if (!buttonSecondaryHover.equals(tokensBefore.buttonSecondaryHover)) {
            colors.buttonSecondaryHover = buttonSecondaryHover.color;
        }
        if (!colors.buttonSuccess.equals(colorsBefore.buttonSuccess)) {
            if (!buttonSuccess.color.equals(colors.buttonSuccess)) {
                buttonSuccess = ThemeToken.fromHsla(colors.buttonSuccess);
            }
        }
        else if (!buttonSuccess.equals(tokensBefore.buttonSuccess)) {
            colors.buttonSuccess = buttonSuccess.color;
        }
        if (!colors.buttonSuccessActive.equals(colorsBefore.buttonSuccessActive)) {
            if (!buttonSuccessActive.color.equals(colors.buttonSuccessActive)) {
                buttonSuccessActive = ThemeToken.fromHsla(colors.buttonSuccessActive);
            }
        }
        else if (!buttonSuccessActive.equals(tokensBefore.buttonSuccessActive)) {
            colors.buttonSuccessActive = buttonSuccessActive.color;
        }
        if (!colors.buttonSuccessForeground.equals(colorsBefore.buttonSuccessForeground)) {
            if (!buttonSuccessForeground.color.equals(colors.buttonSuccessForeground)) {
                buttonSuccessForeground = ThemeToken.fromHsla(colors.buttonSuccessForeground);
            }
        }
        else if (!buttonSuccessForeground.equals(tokensBefore.buttonSuccessForeground)) {
            colors.buttonSuccessForeground = buttonSuccessForeground.color;
        }
        if (!colors.buttonSuccessHover.equals(colorsBefore.buttonSuccessHover)) {
            if (!buttonSuccessHover.color.equals(colors.buttonSuccessHover)) {
                buttonSuccessHover = ThemeToken.fromHsla(colors.buttonSuccessHover);
            }
        }
        else if (!buttonSuccessHover.equals(tokensBefore.buttonSuccessHover)) {
            colors.buttonSuccessHover = buttonSuccessHover.color;
        }
        if (!colors.buttonWarning.equals(colorsBefore.buttonWarning)) {
            if (!buttonWarning.color.equals(colors.buttonWarning)) {
                buttonWarning = ThemeToken.fromHsla(colors.buttonWarning);
            }
        }
        else if (!buttonWarning.equals(tokensBefore.buttonWarning)) {
            colors.buttonWarning = buttonWarning.color;
        }
        if (!colors.buttonWarningActive.equals(colorsBefore.buttonWarningActive)) {
            if (!buttonWarningActive.color.equals(colors.buttonWarningActive)) {
                buttonWarningActive = ThemeToken.fromHsla(colors.buttonWarningActive);
            }
        }
        else if (!buttonWarningActive.equals(tokensBefore.buttonWarningActive)) {
            colors.buttonWarningActive = buttonWarningActive.color;
        }
        if (!colors.buttonWarningForeground.equals(colorsBefore.buttonWarningForeground)) {
            if (!buttonWarningForeground.color.equals(colors.buttonWarningForeground)) {
                buttonWarningForeground = ThemeToken.fromHsla(colors.buttonWarningForeground);
            }
        }
        else if (!buttonWarningForeground.equals(tokensBefore.buttonWarningForeground)) {
            colors.buttonWarningForeground = buttonWarningForeground.color;
        }
        if (!colors.buttonWarningHover.equals(colorsBefore.buttonWarningHover)) {
            if (!buttonWarningHover.color.equals(colors.buttonWarningHover)) {
                buttonWarningHover = ThemeToken.fromHsla(colors.buttonWarningHover);
            }
        }
        else if (!buttonWarningHover.equals(tokensBefore.buttonWarningHover)) {
            colors.buttonWarningHover = buttonWarningHover.color;
        }
        if (!colors.groupBox.equals(colorsBefore.groupBox)) {
            if (!groupBox.color.equals(colors.groupBox)) {
                groupBox = ThemeToken.fromHsla(colors.groupBox);
            }
        }
        else if (!groupBox.equals(tokensBefore.groupBox)) {
            colors.groupBox = groupBox.color;
        }
        if (!colors.groupBoxForeground.equals(colorsBefore.groupBoxForeground)) {
            if (!groupBoxForeground.color.equals(colors.groupBoxForeground)) {
                groupBoxForeground = ThemeToken.fromHsla(colors.groupBoxForeground);
            }
        }
        else if (!groupBoxForeground.equals(tokensBefore.groupBoxForeground)) {
            colors.groupBoxForeground = groupBoxForeground.color;
        }
        if (!colors.caret.equals(colorsBefore.caret)) {
            if (!caret.color.equals(colors.caret)) {
                caret = ThemeToken.fromHsla(colors.caret);
            }
        }
        else if (!caret.equals(tokensBefore.caret)) {
            colors.caret = caret.color;
        }
        if (!colors.chart1.equals(colorsBefore.chart1)) {
            if (!chart1.color.equals(colors.chart1)) {
                chart1 = ThemeToken.fromHsla(colors.chart1);
            }
        }
        else if (!chart1.equals(tokensBefore.chart1)) {
            colors.chart1 = chart1.color;
        }
        if (!colors.chart2.equals(colorsBefore.chart2)) {
            if (!chart2.color.equals(colors.chart2)) {
                chart2 = ThemeToken.fromHsla(colors.chart2);
            }
        }
        else if (!chart2.equals(tokensBefore.chart2)) {
            colors.chart2 = chart2.color;
        }
        if (!colors.chart3.equals(colorsBefore.chart3)) {
            if (!chart3.color.equals(colors.chart3)) {
                chart3 = ThemeToken.fromHsla(colors.chart3);
            }
        }
        else if (!chart3.equals(tokensBefore.chart3)) {
            colors.chart3 = chart3.color;
        }
        if (!colors.chart4.equals(colorsBefore.chart4)) {
            if (!chart4.color.equals(colors.chart4)) {
                chart4 = ThemeToken.fromHsla(colors.chart4);
            }
        }
        else if (!chart4.equals(tokensBefore.chart4)) {
            colors.chart4 = chart4.color;
        }
        if (!colors.chart5.equals(colorsBefore.chart5)) {
            if (!chart5.color.equals(colors.chart5)) {
                chart5 = ThemeToken.fromHsla(colors.chart5);
            }
        }
        else if (!chart5.equals(tokensBefore.chart5)) {
            colors.chart5 = chart5.color;
        }
        if (!colors.chartBullish.equals(colorsBefore.chartBullish)) {
            if (!chartBullish.color.equals(colors.chartBullish)) {
                chartBullish = ThemeToken.fromHsla(colors.chartBullish);
            }
        }
        else if (!chartBullish.equals(tokensBefore.chartBullish)) {
            colors.chartBullish = chartBullish.color;
        }
        if (!colors.chartBearish.equals(colorsBefore.chartBearish)) {
            if (!chartBearish.color.equals(colors.chartBearish)) {
                chartBearish = ThemeToken.fromHsla(colors.chartBearish);
            }
        }
        else if (!chartBearish.equals(tokensBefore.chartBearish)) {
            colors.chartBearish = chartBearish.color;
        }
        if (!colors.chartGrid.equals(colorsBefore.chartGrid)) {
            if (!chartGrid.color.equals(colors.chartGrid)) {
                chartGrid = ThemeToken.fromHsla(colors.chartGrid);
            }
        }
        else if (!chartGrid.equals(tokensBefore.chartGrid)) {
            colors.chartGrid = chartGrid.color;
        }
        if (!colors.danger.equals(colorsBefore.danger)) {
            if (!danger.color.equals(colors.danger)) {
                danger = ThemeToken.fromHsla(colors.danger);
            }
        }
        else if (!danger.equals(tokensBefore.danger)) {
            colors.danger = danger.color;
        }
        if (!colors.dangerActive.equals(colorsBefore.dangerActive)) {
            if (!dangerActive.color.equals(colors.dangerActive)) {
                dangerActive = ThemeToken.fromHsla(colors.dangerActive);
            }
        }
        else if (!dangerActive.equals(tokensBefore.dangerActive)) {
            colors.dangerActive = dangerActive.color;
        }
        if (!colors.dangerForeground.equals(colorsBefore.dangerForeground)) {
            if (!dangerForeground.color.equals(colors.dangerForeground)) {
                dangerForeground = ThemeToken.fromHsla(colors.dangerForeground);
            }
        }
        else if (!dangerForeground.equals(tokensBefore.dangerForeground)) {
            colors.dangerForeground = dangerForeground.color;
        }
        if (!colors.dangerHover.equals(colorsBefore.dangerHover)) {
            if (!dangerHover.color.equals(colors.dangerHover)) {
                dangerHover = ThemeToken.fromHsla(colors.dangerHover);
            }
        }
        else if (!dangerHover.equals(tokensBefore.dangerHover)) {
            colors.dangerHover = dangerHover.color;
        }
        if (!colors.descriptionListLabel.equals(colorsBefore.descriptionListLabel)) {
            if (!descriptionListLabel.color.equals(colors.descriptionListLabel)) {
                descriptionListLabel = ThemeToken.fromHsla(colors.descriptionListLabel);
            }
        }
        else if (!descriptionListLabel.equals(tokensBefore.descriptionListLabel)) {
            colors.descriptionListLabel = descriptionListLabel.color;
        }
        if (!colors.descriptionListLabelForeground.equals(colorsBefore.descriptionListLabelForeground)) {
            if (!descriptionListLabelForeground.color.equals(colors.descriptionListLabelForeground)) {
                descriptionListLabelForeground = ThemeToken.fromHsla(colors.descriptionListLabelForeground);
            }
        }
        else if (!descriptionListLabelForeground.equals(tokensBefore.descriptionListLabelForeground)) {
            colors.descriptionListLabelForeground = descriptionListLabelForeground.color;
        }
        if (!colors.dragBorder.equals(colorsBefore.dragBorder)) {
            if (!dragBorder.color.equals(colors.dragBorder)) {
                dragBorder = ThemeToken.fromHsla(colors.dragBorder);
            }
        }
        else if (!dragBorder.equals(tokensBefore.dragBorder)) {
            colors.dragBorder = dragBorder.color;
        }
        if (!colors.dropTarget.equals(colorsBefore.dropTarget)) {
            if (!dropTarget.color.equals(colors.dropTarget)) {
                dropTarget = ThemeToken.fromHsla(colors.dropTarget);
            }
        }
        else if (!dropTarget.equals(tokensBefore.dropTarget)) {
            colors.dropTarget = dropTarget.color;
        }
        if (!colors.foreground.equals(colorsBefore.foreground)) {
            if (!foreground.color.equals(colors.foreground)) {
                foreground = ThemeToken.fromHsla(colors.foreground);
            }
        }
        else if (!foreground.equals(tokensBefore.foreground)) {
            colors.foreground = foreground.color;
        }
        if (!colors.info.equals(colorsBefore.info)) {
            if (!info.color.equals(colors.info)) {
                info = ThemeToken.fromHsla(colors.info);
            }
        }
        else if (!info.equals(tokensBefore.info)) {
            colors.info = info.color;
        }
        if (!colors.infoActive.equals(colorsBefore.infoActive)) {
            if (!infoActive.color.equals(colors.infoActive)) {
                infoActive = ThemeToken.fromHsla(colors.infoActive);
            }
        }
        else if (!infoActive.equals(tokensBefore.infoActive)) {
            colors.infoActive = infoActive.color;
        }
        if (!colors.infoForeground.equals(colorsBefore.infoForeground)) {
            if (!infoForeground.color.equals(colors.infoForeground)) {
                infoForeground = ThemeToken.fromHsla(colors.infoForeground);
            }
        }
        else if (!infoForeground.equals(tokensBefore.infoForeground)) {
            colors.infoForeground = infoForeground.color;
        }
        if (!colors.infoHover.equals(colorsBefore.infoHover)) {
            if (!infoHover.color.equals(colors.infoHover)) {
                infoHover = ThemeToken.fromHsla(colors.infoHover);
            }
        }
        else if (!infoHover.equals(tokensBefore.infoHover)) {
            colors.infoHover = infoHover.color;
        }
        if (!colors.input.equals(colorsBefore.input)) {
            if (!input.color.equals(colors.input)) {
                input = ThemeToken.fromHsla(colors.input);
            }
        }
        else if (!input.equals(tokensBefore.input)) {
            colors.input = input.color;
        }
        if (!colors.link.equals(colorsBefore.link)) {
            if (!link.color.equals(colors.link)) {
                link = ThemeToken.fromHsla(colors.link);
            }
        }
        else if (!link.equals(tokensBefore.link)) {
            colors.link = link.color;
        }
        if (!colors.linkActive.equals(colorsBefore.linkActive)) {
            if (!linkActive.color.equals(colors.linkActive)) {
                linkActive = ThemeToken.fromHsla(colors.linkActive);
            }
        }
        else if (!linkActive.equals(tokensBefore.linkActive)) {
            colors.linkActive = linkActive.color;
        }
        if (!colors.linkHover.equals(colorsBefore.linkHover)) {
            if (!linkHover.color.equals(colors.linkHover)) {
                linkHover = ThemeToken.fromHsla(colors.linkHover);
            }
        }
        else if (!linkHover.equals(tokensBefore.linkHover)) {
            colors.linkHover = linkHover.color;
        }
        if (!colors.list.equals(colorsBefore.list)) {
            if (!list.color.equals(colors.list)) {
                list = ThemeToken.fromHsla(colors.list);
            }
        }
        else if (!list.equals(tokensBefore.list)) {
            colors.list = list.color;
        }
        if (!colors.listActive.equals(colorsBefore.listActive)) {
            if (!listActive.color.equals(colors.listActive)) {
                listActive = ThemeToken.fromHsla(colors.listActive);
            }
        }
        else if (!listActive.equals(tokensBefore.listActive)) {
            colors.listActive = listActive.color;
        }
        if (!colors.listActiveBorder.equals(colorsBefore.listActiveBorder)) {
            if (!listActiveBorder.color.equals(colors.listActiveBorder)) {
                listActiveBorder = ThemeToken.fromHsla(colors.listActiveBorder);
            }
        }
        else if (!listActiveBorder.equals(tokensBefore.listActiveBorder)) {
            colors.listActiveBorder = listActiveBorder.color;
        }
        if (!colors.listEven.equals(colorsBefore.listEven)) {
            if (!listEven.color.equals(colors.listEven)) {
                listEven = ThemeToken.fromHsla(colors.listEven);
            }
        }
        else if (!listEven.equals(tokensBefore.listEven)) {
            colors.listEven = listEven.color;
        }
        if (!colors.listHead.equals(colorsBefore.listHead)) {
            if (!listHead.color.equals(colors.listHead)) {
                listHead = ThemeToken.fromHsla(colors.listHead);
            }
        }
        else if (!listHead.equals(tokensBefore.listHead)) {
            colors.listHead = listHead.color;
        }
        if (!colors.listHover.equals(colorsBefore.listHover)) {
            if (!listHover.color.equals(colors.listHover)) {
                listHover = ThemeToken.fromHsla(colors.listHover);
            }
        }
        else if (!listHover.equals(tokensBefore.listHover)) {
            colors.listHover = listHover.color;
        }
        if (!colors.muted.equals(colorsBefore.muted)) {
            if (!muted.color.equals(colors.muted)) {
                muted = ThemeToken.fromHsla(colors.muted);
            }
        }
        else if (!muted.equals(tokensBefore.muted)) {
            colors.muted = muted.color;
        }
        if (!colors.mutedForeground.equals(colorsBefore.mutedForeground)) {
            if (!mutedForeground.color.equals(colors.mutedForeground)) {
                mutedForeground = ThemeToken.fromHsla(colors.mutedForeground);
            }
        }
        else if (!mutedForeground.equals(tokensBefore.mutedForeground)) {
            colors.mutedForeground = mutedForeground.color;
        }
        if (!colors.popover.equals(colorsBefore.popover)) {
            if (!popover.color.equals(colors.popover)) {
                popover = ThemeToken.fromHsla(colors.popover);
            }
        }
        else if (!popover.equals(tokensBefore.popover)) {
            colors.popover = popover.color;
        }
        if (!colors.popoverForeground.equals(colorsBefore.popoverForeground)) {
            if (!popoverForeground.color.equals(colors.popoverForeground)) {
                popoverForeground = ThemeToken.fromHsla(colors.popoverForeground);
            }
        }
        else if (!popoverForeground.equals(tokensBefore.popoverForeground)) {
            colors.popoverForeground = popoverForeground.color;
        }
        if (!colors.primary.equals(colorsBefore.primary)) {
            if (!primary.color.equals(colors.primary)) {
                primary = ThemeToken.fromHsla(colors.primary);
            }
        }
        else if (!primary.equals(tokensBefore.primary)) {
            colors.primary = primary.color;
        }
        if (!colors.primaryActive.equals(colorsBefore.primaryActive)) {
            if (!primaryActive.color.equals(colors.primaryActive)) {
                primaryActive = ThemeToken.fromHsla(colors.primaryActive);
            }
        }
        else if (!primaryActive.equals(tokensBefore.primaryActive)) {
            colors.primaryActive = primaryActive.color;
        }
        if (!colors.primaryForeground.equals(colorsBefore.primaryForeground)) {
            if (!primaryForeground.color.equals(colors.primaryForeground)) {
                primaryForeground = ThemeToken.fromHsla(colors.primaryForeground);
            }
        }
        else if (!primaryForeground.equals(tokensBefore.primaryForeground)) {
            colors.primaryForeground = primaryForeground.color;
        }
        if (!colors.primaryHover.equals(colorsBefore.primaryHover)) {
            if (!primaryHover.color.equals(colors.primaryHover)) {
                primaryHover = ThemeToken.fromHsla(colors.primaryHover);
            }
        }
        else if (!primaryHover.equals(tokensBefore.primaryHover)) {
            colors.primaryHover = primaryHover.color;
        }
        if (!colors.progressBar.equals(colorsBefore.progressBar)) {
            if (!progressBar.color.equals(colors.progressBar)) {
                progressBar = ThemeToken.fromHsla(colors.progressBar);
            }
        }
        else if (!progressBar.equals(tokensBefore.progressBar)) {
            colors.progressBar = progressBar.color;
        }
        if (!colors.ring.equals(colorsBefore.ring)) {
            if (!ring.color.equals(colors.ring)) {
                ring = ThemeToken.fromHsla(colors.ring);
            }
        }
        else if (!ring.equals(tokensBefore.ring)) {
            colors.ring = ring.color;
        }
        if (!colors.scrollbar.equals(colorsBefore.scrollbar)) {
            if (!scrollbar.color.equals(colors.scrollbar)) {
                scrollbar = ThemeToken.fromHsla(colors.scrollbar);
            }
        }
        else if (!scrollbar.equals(tokensBefore.scrollbar)) {
            colors.scrollbar = scrollbar.color;
        }
        if (!colors.scrollbarThumb.equals(colorsBefore.scrollbarThumb)) {
            if (!scrollbarThumb.color.equals(colors.scrollbarThumb)) {
                scrollbarThumb = ThemeToken.fromHsla(colors.scrollbarThumb);
            }
        }
        else if (!scrollbarThumb.equals(tokensBefore.scrollbarThumb)) {
            colors.scrollbarThumb = scrollbarThumb.color;
        }
        if (!colors.scrollbarThumbHover.equals(colorsBefore.scrollbarThumbHover)) {
            if (!scrollbarThumbHover.color.equals(colors.scrollbarThumbHover)) {
                scrollbarThumbHover = ThemeToken.fromHsla(colors.scrollbarThumbHover);
            }
        }
        else if (!scrollbarThumbHover.equals(tokensBefore.scrollbarThumbHover)) {
            colors.scrollbarThumbHover = scrollbarThumbHover.color;
        }
        if (!colors.secondary.equals(colorsBefore.secondary)) {
            if (!secondary.color.equals(colors.secondary)) {
                secondary = ThemeToken.fromHsla(colors.secondary);
            }
        }
        else if (!secondary.equals(tokensBefore.secondary)) {
            colors.secondary = secondary.color;
        }
        if (!colors.secondaryActive.equals(colorsBefore.secondaryActive)) {
            if (!secondaryActive.color.equals(colors.secondaryActive)) {
                secondaryActive = ThemeToken.fromHsla(colors.secondaryActive);
            }
        }
        else if (!secondaryActive.equals(tokensBefore.secondaryActive)) {
            colors.secondaryActive = secondaryActive.color;
        }
        if (!colors.secondaryForeground.equals(colorsBefore.secondaryForeground)) {
            if (!secondaryForeground.color.equals(colors.secondaryForeground)) {
                secondaryForeground = ThemeToken.fromHsla(colors.secondaryForeground);
            }
        }
        else if (!secondaryForeground.equals(tokensBefore.secondaryForeground)) {
            colors.secondaryForeground = secondaryForeground.color;
        }
        if (!colors.secondaryHover.equals(colorsBefore.secondaryHover)) {
            if (!secondaryHover.color.equals(colors.secondaryHover)) {
                secondaryHover = ThemeToken.fromHsla(colors.secondaryHover);
            }
        }
        else if (!secondaryHover.equals(tokensBefore.secondaryHover)) {
            colors.secondaryHover = secondaryHover.color;
        }
        if (!colors.selection.equals(colorsBefore.selection)) {
            if (!selection.color.equals(colors.selection)) {
                selection = ThemeToken.fromHsla(colors.selection);
            }
        }
        else if (!selection.equals(tokensBefore.selection)) {
            colors.selection = selection.color;
        }
        if (!colors.sidebar.equals(colorsBefore.sidebar)) {
            if (!sidebar.color.equals(colors.sidebar)) {
                sidebar = ThemeToken.fromHsla(colors.sidebar);
            }
        }
        else if (!sidebar.equals(tokensBefore.sidebar)) {
            colors.sidebar = sidebar.color;
        }
        if (!colors.sidebarAccent.equals(colorsBefore.sidebarAccent)) {
            if (!sidebarAccent.color.equals(colors.sidebarAccent)) {
                sidebarAccent = ThemeToken.fromHsla(colors.sidebarAccent);
            }
        }
        else if (!sidebarAccent.equals(tokensBefore.sidebarAccent)) {
            colors.sidebarAccent = sidebarAccent.color;
        }
        if (!colors.sidebarAccentForeground.equals(colorsBefore.sidebarAccentForeground)) {
            if (!sidebarAccentForeground.color.equals(colors.sidebarAccentForeground)) {
                sidebarAccentForeground = ThemeToken.fromHsla(colors.sidebarAccentForeground);
            }
        }
        else if (!sidebarAccentForeground.equals(tokensBefore.sidebarAccentForeground)) {
            colors.sidebarAccentForeground = sidebarAccentForeground.color;
        }
        if (!colors.sidebarBorder.equals(colorsBefore.sidebarBorder)) {
            if (!sidebarBorder.color.equals(colors.sidebarBorder)) {
                sidebarBorder = ThemeToken.fromHsla(colors.sidebarBorder);
            }
        }
        else if (!sidebarBorder.equals(tokensBefore.sidebarBorder)) {
            colors.sidebarBorder = sidebarBorder.color;
        }
        if (!colors.sidebarForeground.equals(colorsBefore.sidebarForeground)) {
            if (!sidebarForeground.color.equals(colors.sidebarForeground)) {
                sidebarForeground = ThemeToken.fromHsla(colors.sidebarForeground);
            }
        }
        else if (!sidebarForeground.equals(tokensBefore.sidebarForeground)) {
            colors.sidebarForeground = sidebarForeground.color;
        }
        if (!colors.sidebarPrimary.equals(colorsBefore.sidebarPrimary)) {
            if (!sidebarPrimary.color.equals(colors.sidebarPrimary)) {
                sidebarPrimary = ThemeToken.fromHsla(colors.sidebarPrimary);
            }
        }
        else if (!sidebarPrimary.equals(tokensBefore.sidebarPrimary)) {
            colors.sidebarPrimary = sidebarPrimary.color;
        }
        if (!colors.sidebarPrimaryForeground.equals(colorsBefore.sidebarPrimaryForeground)) {
            if (!sidebarPrimaryForeground.color.equals(colors.sidebarPrimaryForeground)) {
                sidebarPrimaryForeground = ThemeToken.fromHsla(colors.sidebarPrimaryForeground);
            }
        }
        else if (!sidebarPrimaryForeground.equals(tokensBefore.sidebarPrimaryForeground)) {
            colors.sidebarPrimaryForeground = sidebarPrimaryForeground.color;
        }
        if (!colors.skeleton.equals(colorsBefore.skeleton)) {
            if (!skeleton.color.equals(colors.skeleton)) {
                skeleton = ThemeToken.fromHsla(colors.skeleton);
            }
        }
        else if (!skeleton.equals(tokensBefore.skeleton)) {
            colors.skeleton = skeleton.color;
        }
        if (!colors.sliderBar.equals(colorsBefore.sliderBar)) {
            if (!sliderBar.color.equals(colors.sliderBar)) {
                sliderBar = ThemeToken.fromHsla(colors.sliderBar);
            }
        }
        else if (!sliderBar.equals(tokensBefore.sliderBar)) {
            colors.sliderBar = sliderBar.color;
        }
        if (!colors.sliderThumb.equals(colorsBefore.sliderThumb)) {
            if (!sliderThumb.color.equals(colors.sliderThumb)) {
                sliderThumb = ThemeToken.fromHsla(colors.sliderThumb);
            }
        }
        else if (!sliderThumb.equals(tokensBefore.sliderThumb)) {
            colors.sliderThumb = sliderThumb.color;
        }
        if (!colors.success.equals(colorsBefore.success)) {
            if (!success.color.equals(colors.success)) {
                success = ThemeToken.fromHsla(colors.success);
            }
        }
        else if (!success.equals(tokensBefore.success)) {
            colors.success = success.color;
        }
        if (!colors.successForeground.equals(colorsBefore.successForeground)) {
            if (!successForeground.color.equals(colors.successForeground)) {
                successForeground = ThemeToken.fromHsla(colors.successForeground);
            }
        }
        else if (!successForeground.equals(tokensBefore.successForeground)) {
            colors.successForeground = successForeground.color;
        }
        if (!colors.successHover.equals(colorsBefore.successHover)) {
            if (!successHover.color.equals(colors.successHover)) {
                successHover = ThemeToken.fromHsla(colors.successHover);
            }
        }
        else if (!successHover.equals(tokensBefore.successHover)) {
            colors.successHover = successHover.color;
        }
        if (!colors.successActive.equals(colorsBefore.successActive)) {
            if (!successActive.color.equals(colors.successActive)) {
                successActive = ThemeToken.fromHsla(colors.successActive);
            }
        }
        else if (!successActive.equals(tokensBefore.successActive)) {
            colors.successActive = successActive.color;
        }
        if (!colors.switch_.equals(colorsBefore.switch_)) {
            if (!switch_.color.equals(colors.switch_)) {
                switch_ = ThemeToken.fromHsla(colors.switch_);
            }
        }
        else if (!switch_.equals(tokensBefore.switch_)) {
            colors.switch_ = switch_.color;
        }
        if (!colors.switchThumb.equals(colorsBefore.switchThumb)) {
            if (!switchThumb.color.equals(colors.switchThumb)) {
                switchThumb = ThemeToken.fromHsla(colors.switchThumb);
            }
        }
        else if (!switchThumb.equals(tokensBefore.switchThumb)) {
            colors.switchThumb = switchThumb.color;
        }
        if (!colors.tab.equals(colorsBefore.tab)) {
            if (!tab.color.equals(colors.tab)) {
                tab = ThemeToken.fromHsla(colors.tab);
            }
        }
        else if (!tab.equals(tokensBefore.tab)) {
            colors.tab = tab.color;
        }
        if (!colors.tabActive.equals(colorsBefore.tabActive)) {
            if (!tabActive.color.equals(colors.tabActive)) {
                tabActive = ThemeToken.fromHsla(colors.tabActive);
            }
        }
        else if (!tabActive.equals(tokensBefore.tabActive)) {
            colors.tabActive = tabActive.color;
        }
        if (!colors.tabActiveForeground.equals(colorsBefore.tabActiveForeground)) {
            if (!tabActiveForeground.color.equals(colors.tabActiveForeground)) {
                tabActiveForeground = ThemeToken.fromHsla(colors.tabActiveForeground);
            }
        }
        else if (!tabActiveForeground.equals(tokensBefore.tabActiveForeground)) {
            colors.tabActiveForeground = tabActiveForeground.color;
        }
        if (!colors.tabBar.equals(colorsBefore.tabBar)) {
            if (!tabBar.color.equals(colors.tabBar)) {
                tabBar = ThemeToken.fromHsla(colors.tabBar);
            }
        }
        else if (!tabBar.equals(tokensBefore.tabBar)) {
            colors.tabBar = tabBar.color;
        }
        if (!colors.tabBarSegmented.equals(colorsBefore.tabBarSegmented)) {
            if (!tabBarSegmented.color.equals(colors.tabBarSegmented)) {
                tabBarSegmented = ThemeToken.fromHsla(colors.tabBarSegmented);
            }
        }
        else if (!tabBarSegmented.equals(tokensBefore.tabBarSegmented)) {
            colors.tabBarSegmented = tabBarSegmented.color;
        }
        if (!colors.tabForeground.equals(colorsBefore.tabForeground)) {
            if (!tabForeground.color.equals(colors.tabForeground)) {
                tabForeground = ThemeToken.fromHsla(colors.tabForeground);
            }
        }
        else if (!tabForeground.equals(tokensBefore.tabForeground)) {
            colors.tabForeground = tabForeground.color;
        }
        if (!colors.table.equals(colorsBefore.table)) {
            if (!table.color.equals(colors.table)) {
                table = ThemeToken.fromHsla(colors.table);
            }
        }
        else if (!table.equals(tokensBefore.table)) {
            colors.table = table.color;
        }
        if (!colors.tableActive.equals(colorsBefore.tableActive)) {
            if (!tableActive.color.equals(colors.tableActive)) {
                tableActive = ThemeToken.fromHsla(colors.tableActive);
            }
        }
        else if (!tableActive.equals(tokensBefore.tableActive)) {
            colors.tableActive = tableActive.color;
        }
        if (!colors.tableActiveBorder.equals(colorsBefore.tableActiveBorder)) {
            if (!tableActiveBorder.color.equals(colors.tableActiveBorder)) {
                tableActiveBorder = ThemeToken.fromHsla(colors.tableActiveBorder);
            }
        }
        else if (!tableActiveBorder.equals(tokensBefore.tableActiveBorder)) {
            colors.tableActiveBorder = tableActiveBorder.color;
        }
        if (!colors.tableEven.equals(colorsBefore.tableEven)) {
            if (!tableEven.color.equals(colors.tableEven)) {
                tableEven = ThemeToken.fromHsla(colors.tableEven);
            }
        }
        else if (!tableEven.equals(tokensBefore.tableEven)) {
            colors.tableEven = tableEven.color;
        }
        if (!colors.tableHead.equals(colorsBefore.tableHead)) {
            if (!tableHead.color.equals(colors.tableHead)) {
                tableHead = ThemeToken.fromHsla(colors.tableHead);
            }
        }
        else if (!tableHead.equals(tokensBefore.tableHead)) {
            colors.tableHead = tableHead.color;
        }
        if (!colors.tableHeadForeground.equals(colorsBefore.tableHeadForeground)) {
            if (!tableHeadForeground.color.equals(colors.tableHeadForeground)) {
                tableHeadForeground = ThemeToken.fromHsla(colors.tableHeadForeground);
            }
        }
        else if (!tableHeadForeground.equals(tokensBefore.tableHeadForeground)) {
            colors.tableHeadForeground = tableHeadForeground.color;
        }
        if (!colors.tableFoot.equals(colorsBefore.tableFoot)) {
            if (!tableFoot.color.equals(colors.tableFoot)) {
                tableFoot = ThemeToken.fromHsla(colors.tableFoot);
            }
        }
        else if (!tableFoot.equals(tokensBefore.tableFoot)) {
            colors.tableFoot = tableFoot.color;
        }
        if (!colors.tableFootForeground.equals(colorsBefore.tableFootForeground)) {
            if (!tableFootForeground.color.equals(colors.tableFootForeground)) {
                tableFootForeground = ThemeToken.fromHsla(colors.tableFootForeground);
            }
        }
        else if (!tableFootForeground.equals(tokensBefore.tableFootForeground)) {
            colors.tableFootForeground = tableFootForeground.color;
        }
        if (!colors.tableHover.equals(colorsBefore.tableHover)) {
            if (!tableHover.color.equals(colors.tableHover)) {
                tableHover = ThemeToken.fromHsla(colors.tableHover);
            }
        }
        else if (!tableHover.equals(tokensBefore.tableHover)) {
            colors.tableHover = tableHover.color;
        }
        if (!colors.tableRowBorder.equals(colorsBefore.tableRowBorder)) {
            if (!tableRowBorder.color.equals(colors.tableRowBorder)) {
                tableRowBorder = ThemeToken.fromHsla(colors.tableRowBorder);
            }
        }
        else if (!tableRowBorder.equals(tokensBefore.tableRowBorder)) {
            colors.tableRowBorder = tableRowBorder.color;
        }
        if (!colors.titleBar.equals(colorsBefore.titleBar)) {
            if (!titleBar.color.equals(colors.titleBar)) {
                titleBar = ThemeToken.fromHsla(colors.titleBar);
            }
        }
        else if (!titleBar.equals(tokensBefore.titleBar)) {
            colors.titleBar = titleBar.color;
        }
        if (!colors.titleBarBorder.equals(colorsBefore.titleBarBorder)) {
            if (!titleBarBorder.color.equals(colors.titleBarBorder)) {
                titleBarBorder = ThemeToken.fromHsla(colors.titleBarBorder);
            }
        }
        else if (!titleBarBorder.equals(tokensBefore.titleBarBorder)) {
            colors.titleBarBorder = titleBarBorder.color;
        }
        if (!colors.statusBar.equals(colorsBefore.statusBar)) {
            if (!statusBar.color.equals(colors.statusBar)) {
                statusBar = ThemeToken.fromHsla(colors.statusBar);
            }
        }
        else if (!statusBar.equals(tokensBefore.statusBar)) {
            colors.statusBar = statusBar.color;
        }
        if (!colors.statusBarBorder.equals(colorsBefore.statusBarBorder)) {
            if (!statusBarBorder.color.equals(colors.statusBarBorder)) {
                statusBarBorder = ThemeToken.fromHsla(colors.statusBarBorder);
            }
        }
        else if (!statusBarBorder.equals(tokensBefore.statusBarBorder)) {
            colors.statusBarBorder = statusBarBorder.color;
        }
        if (!colors.warning.equals(colorsBefore.warning)) {
            if (!warning.color.equals(colors.warning)) {
                warning = ThemeToken.fromHsla(colors.warning);
            }
        }
        else if (!warning.equals(tokensBefore.warning)) {
            colors.warning = warning.color;
        }
        if (!colors.warningActive.equals(colorsBefore.warningActive)) {
            if (!warningActive.color.equals(colors.warningActive)) {
                warningActive = ThemeToken.fromHsla(colors.warningActive);
            }
        }
        else if (!warningActive.equals(tokensBefore.warningActive)) {
            colors.warningActive = warningActive.color;
        }
        if (!colors.warningHover.equals(colorsBefore.warningHover)) {
            if (!warningHover.color.equals(colors.warningHover)) {
                warningHover = ThemeToken.fromHsla(colors.warningHover);
            }
        }
        else if (!warningHover.equals(tokensBefore.warningHover)) {
            colors.warningHover = warningHover.color;
        }
        if (!colors.warningForeground.equals(colorsBefore.warningForeground)) {
            if (!warningForeground.color.equals(colors.warningForeground)) {
                warningForeground = ThemeToken.fromHsla(colors.warningForeground);
            }
        }
        else if (!warningForeground.equals(tokensBefore.warningForeground)) {
            colors.warningForeground = warningForeground.color;
        }
        if (!colors.overlay.equals(colorsBefore.overlay)) {
            if (!overlay.color.equals(colors.overlay)) {
                overlay = ThemeToken.fromHsla(colors.overlay);
            }
        }
        else if (!overlay.equals(tokensBefore.overlay)) {
            colors.overlay = overlay.color;
        }
        if (!colors.windowBorder.equals(colorsBefore.windowBorder)) {
            if (!windowBorder.color.equals(colors.windowBorder)) {
                windowBorder = ThemeToken.fromHsla(colors.windowBorder);
            }
        }
        else if (!windowBorder.equals(tokensBefore.windowBorder)) {
            colors.windowBorder = windowBorder.color;
        }
        if (!colors.red.equals(colorsBefore.red)) {
            if (!red.color.equals(colors.red)) {
                red = ThemeToken.fromHsla(colors.red);
            }
        }
        else if (!red.equals(tokensBefore.red)) {
            colors.red = red.color;
        }
        if (!colors.redLight.equals(colorsBefore.redLight)) {
            if (!redLight.color.equals(colors.redLight)) {
                redLight = ThemeToken.fromHsla(colors.redLight);
            }
        }
        else if (!redLight.equals(tokensBefore.redLight)) {
            colors.redLight = redLight.color;
        }
        if (!colors.green.equals(colorsBefore.green)) {
            if (!green.color.equals(colors.green)) {
                green = ThemeToken.fromHsla(colors.green);
            }
        }
        else if (!green.equals(tokensBefore.green)) {
            colors.green = green.color;
        }
        if (!colors.greenLight.equals(colorsBefore.greenLight)) {
            if (!greenLight.color.equals(colors.greenLight)) {
                greenLight = ThemeToken.fromHsla(colors.greenLight);
            }
        }
        else if (!greenLight.equals(tokensBefore.greenLight)) {
            colors.greenLight = greenLight.color;
        }
        if (!colors.blue.equals(colorsBefore.blue)) {
            if (!blue.color.equals(colors.blue)) {
                blue = ThemeToken.fromHsla(colors.blue);
            }
        }
        else if (!blue.equals(tokensBefore.blue)) {
            colors.blue = blue.color;
        }
        if (!colors.blueLight.equals(colorsBefore.blueLight)) {
            if (!blueLight.color.equals(colors.blueLight)) {
                blueLight = ThemeToken.fromHsla(colors.blueLight);
            }
        }
        else if (!blueLight.equals(tokensBefore.blueLight)) {
            colors.blueLight = blueLight.color;
        }
        if (!colors.yellow.equals(colorsBefore.yellow)) {
            if (!yellow.color.equals(colors.yellow)) {
                yellow = ThemeToken.fromHsla(colors.yellow);
            }
        }
        else if (!yellow.equals(tokensBefore.yellow)) {
            colors.yellow = yellow.color;
        }
        if (!colors.yellowLight.equals(colorsBefore.yellowLight)) {
            if (!yellowLight.color.equals(colors.yellowLight)) {
                yellowLight = ThemeToken.fromHsla(colors.yellowLight);
            }
        }
        else if (!yellowLight.equals(tokensBefore.yellowLight)) {
            colors.yellowLight = yellowLight.color;
        }
        if (!colors.magenta.equals(colorsBefore.magenta)) {
            if (!magenta.color.equals(colors.magenta)) {
                magenta = ThemeToken.fromHsla(colors.magenta);
            }
        }
        else if (!magenta.equals(tokensBefore.magenta)) {
            colors.magenta = magenta.color;
        }
        if (!colors.magentaLight.equals(colorsBefore.magentaLight)) {
            if (!magentaLight.color.equals(colors.magentaLight)) {
                magentaLight = ThemeToken.fromHsla(colors.magentaLight);
            }
        }
        else if (!magentaLight.equals(tokensBefore.magentaLight)) {
            colors.magentaLight = magentaLight.color;
        }
        if (!colors.cyan.equals(colorsBefore.cyan)) {
            if (!cyan.color.equals(colors.cyan)) {
                cyan = ThemeToken.fromHsla(colors.cyan);
            }
        }
        else if (!cyan.equals(tokensBefore.cyan)) {
            colors.cyan = cyan.color;
        }
        if (!colors.cyanLight.equals(colorsBefore.cyanLight)) {
            if (!cyanLight.color.equals(colors.cyanLight)) {
                cyanLight = ThemeToken.fromHsla(colors.cyanLight);
            }
        }
        else if (!cyanLight.equals(tokensBefore.cyanLight)) {
            colors.cyanLight = cyanLight.color;
        }

    }

}
