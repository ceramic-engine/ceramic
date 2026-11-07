// Ported from gpui-kit 0.8.1: crates/component/src/theme/theme_color.rs, crates/component/src/theme/schema.rs (ThemeColor::apply_config)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

import glaze.Background;
import glaze.Hsla;

using glaze.kit.theme.Colorize;

/**
 * Theme colors used throughout the UI components.
 *
 * Fields are mutable like the Rust struct, but a `ThemeColor` installed in the
 * global `Theme` is treated as immutable: `Theme.update` edits a copy and
 * installs it, so a view reading the theme re-renders through one observable
 * (the global cell), not through 139 fields.
 *
 * `switch` is a Haxe keyword: the switch color is the `switch_` field.
 */
class ThemeColor {

    /** The default color of every field (`Hsla::default()`, transparent black), shared. */
    static final ZERO:Hsla = new Hsla();

    /**
     * Used for accents such as hover background on MenuItem, ListItem, etc.
     */
    public var accent:Hsla = ZERO;

    /**
     * Used for accent text color.
     */
    public var accentForeground:Hsla = ZERO;

    /**
     * Accordion background color.
     */
    public var accordion:Hsla = ZERO;

    /**
     * Default background color.
     */
    public var background:Hsla = ZERO;

    /**
     * Default border color
     */
    public var border:Hsla = ZERO;

    /**
     * Default Button background color.
     */
    public var button:Hsla = ZERO;

    /**
     * Default Button active background color.
     */
    public var buttonActive:Hsla = ZERO;

    /**
     * Default Button text color.
     */
    public var buttonForeground:Hsla = ZERO;

    /**
     * Default Button hover background color.
     */
    public var buttonHover:Hsla = ZERO;

    /**
     * Button danger background color, fallback to `danger`.
     */
    public var buttonDanger:Hsla = ZERO;

    /**
     * Button danger active background color, fallback to `danger_active`.
     */
    public var buttonDangerActive:Hsla = ZERO;

    /**
     * Button danger text color, fallback to `danger_foreground`.
     */
    public var buttonDangerForeground:Hsla = ZERO;

    /**
     * Button danger hover background color, fallback to `danger_hover`.
     */
    public var buttonDangerHover:Hsla = ZERO;

    /**
     * Button info background color, fallback to `info`.
     */
    public var buttonInfo:Hsla = ZERO;

    /**
     * Button info active background color, fallback to `info_active`.
     */
    public var buttonInfoActive:Hsla = ZERO;

    /**
     * Button info text color, fallback to `info_foreground`.
     */
    public var buttonInfoForeground:Hsla = ZERO;

    /**
     * Button info hover background color, fallback to `info_hover`.
     */
    public var buttonInfoHover:Hsla = ZERO;

    /**
     * Button primary background color, fallback to `primary`.
     */
    public var buttonPrimary:Hsla = ZERO;

    /**
     * Button primary active background color, fallback to `primary_active`.
     */
    public var buttonPrimaryActive:Hsla = ZERO;

    /**
     * Button primary text color, fallback to `primary_foreground`.
     */
    public var buttonPrimaryForeground:Hsla = ZERO;

    /**
     * Button primary hover background color, fallback to `primary_hover`.
     */
    public var buttonPrimaryHover:Hsla = ZERO;

    /**
     * Button secondary background color, fallback to `secondary`.
     */
    public var buttonSecondary:Hsla = ZERO;

    /**
     * Button secondary active background color, fallback to `secondary_active`.
     */
    public var buttonSecondaryActive:Hsla = ZERO;

    /**
     * Button secondary text color, fallback to `secondary_foreground`.
     */
    public var buttonSecondaryForeground:Hsla = ZERO;

    /**
     * Button secondary hover background color, fallback to `secondary_hover`.
     */
    public var buttonSecondaryHover:Hsla = ZERO;

    /**
     * Button success background color, fallback to `success`.
     */
    public var buttonSuccess:Hsla = ZERO;

    /**
     * Button success active background color, fallback to `success_active`.
     */
    public var buttonSuccessActive:Hsla = ZERO;

    /**
     * Button success text color, fallback to `success_foreground`.
     */
    public var buttonSuccessForeground:Hsla = ZERO;

    /**
     * Button success hover background color, fallback to `success_hover`.
     */
    public var buttonSuccessHover:Hsla = ZERO;

    /**
     * Button warning background color, fallback to `warning`.
     */
    public var buttonWarning:Hsla = ZERO;

    /**
     * Button warning active background color, fallback to `warning_active`.
     */
    public var buttonWarningActive:Hsla = ZERO;

    /**
     * Button warning text color, fallback to `warning_foreground`.
     */
    public var buttonWarningForeground:Hsla = ZERO;

    /**
     * Button warning hover background color, fallback to `warning_hover`.
     */
    public var buttonWarningHover:Hsla = ZERO;

    /**
     * Background color for GroupBox.
     */
    public var groupBox:Hsla = ZERO;

    /**
     * Text color for GroupBox.
     */
    public var groupBoxForeground:Hsla = ZERO;

    /**
     * Input caret color (Blinking cursor).
     */
    public var caret:Hsla = ZERO;

    /**
     * Chart 1 color (`chart.1` in the theme file).
     */
    public var chart1:Hsla = ZERO;

    /**
     * Chart 2 color (`chart.2` in the theme file).
     */
    public var chart2:Hsla = ZERO;

    /**
     * Chart 3 color (`chart.3` in the theme file).
     */
    public var chart3:Hsla = ZERO;

    /**
     * Chart 4 color (`chart.4` in the theme file).
     */
    public var chart4:Hsla = ZERO;

    /**
     * Chart 5 color (`chart.5` in the theme file).
     */
    public var chart5:Hsla = ZERO;

    /**
     * Bullish color for candlestick charts (upward price movement).
     */
    public var chartBullish:Hsla = ZERO;

    /**
     * Bearish color for candlestick charts (downward price movement).
     */
    public var chartBearish:Hsla = ZERO;

    /**
     * Chart grid line color.
     */
    public var chartGrid:Hsla = ZERO;

    /**
     * Danger background color.
     */
    public var danger:Hsla = ZERO;

    /**
     * Danger active background color.
     */
    public var dangerActive:Hsla = ZERO;

    /**
     * Danger text color.
     */
    public var dangerForeground:Hsla = ZERO;

    /**
     * Danger hover background color.
     */
    public var dangerHover:Hsla = ZERO;

    /**
     * Description List label background color.
     */
    public var descriptionListLabel:Hsla = ZERO;

    /**
     * Description List label foreground color.
     */
    public var descriptionListLabelForeground:Hsla = ZERO;

    /**
     * Drag border color.
     */
    public var dragBorder:Hsla = ZERO;

    /**
     * Drop target background color.
     */
    public var dropTarget:Hsla = ZERO;

    /**
     * Default text color.
     */
    public var foreground:Hsla = ZERO;

    /**
     * Info background color.
     */
    public var info:Hsla = ZERO;

    /**
     * Info active background color.
     */
    public var infoActive:Hsla = ZERO;

    /**
     * Info text color.
     */
    public var infoForeground:Hsla = ZERO;

    /**
     * Info hover background color.
     */
    public var infoHover:Hsla = ZERO;

    /**
     * Border color for inputs such as Input, Select, etc.
     */
    public var input:Hsla = ZERO;

    /**
     * Link text color.
     */
    public var link:Hsla = ZERO;

    /**
     * Active link text color.
     */
    public var linkActive:Hsla = ZERO;

    /**
     * Hover link text color.
     */
    public var linkHover:Hsla = ZERO;

    /**
     * Background color for List and ListItem.
     */
    public var list:Hsla = ZERO;

    /**
     * Background color for active ListItem.
     */
    public var listActive:Hsla = ZERO;

    /**
     * Border color for active ListItem.
     */
    public var listActiveBorder:Hsla = ZERO;

    /**
     * Stripe background color for even ListItem.
     */
    public var listEven:Hsla = ZERO;

    /**
     * Background color for List header.
     */
    public var listHead:Hsla = ZERO;

    /**
     * Hover background color for ListItem.
     */
    public var listHover:Hsla = ZERO;

    /**
     * Muted backgrounds such as Skeleton and Switch.
     */
    public var muted:Hsla = ZERO;

    /**
     * Muted text color, as used in disabled text.
     */
    public var mutedForeground:Hsla = ZERO;

    /**
     * Background color for Popover.
     */
    public var popover:Hsla = ZERO;

    /**
     * Text color for Popover.
     */
    public var popoverForeground:Hsla = ZERO;

    /**
     * Primary background color.
     */
    public var primary:Hsla = ZERO;

    /**
     * Active primary background color.
     */
    public var primaryActive:Hsla = ZERO;

    /**
     * Primary text color.
     */
    public var primaryForeground:Hsla = ZERO;

    /**
     * Hover primary background color.
     */
    public var primaryHover:Hsla = ZERO;

    /**
     * Progress bar background color.
     */
    public var progressBar:Hsla = ZERO;

    /**
     * Used for focus ring.
     */
    public var ring:Hsla = ZERO;

    /**
     * Scrollbar background color.
     */
    public var scrollbar:Hsla = ZERO;

    /**
     * Scrollbar thumb background color.
     */
    public var scrollbarThumb:Hsla = ZERO;

    /**
     * Scrollbar thumb hover background color.
     */
    public var scrollbarThumbHover:Hsla = ZERO;

    /**
     * Secondary background color.
     */
    public var secondary:Hsla = ZERO;

    /**
     * Active secondary background color.
     */
    public var secondaryActive:Hsla = ZERO;

    /**
     * Secondary text color, used for secondary Button text color or secondary text.
     */
    public var secondaryForeground:Hsla = ZERO;

    /**
     * Hover secondary background color.
     */
    public var secondaryHover:Hsla = ZERO;

    /**
     * Input selection background color.
     */
    public var selection:Hsla = ZERO;

    /**
     * Sidebar background color.
     */
    public var sidebar:Hsla = ZERO;

    /**
     * Sidebar accent background color.
     */
    public var sidebarAccent:Hsla = ZERO;

    /**
     * Sidebar accent text color.
     */
    public var sidebarAccentForeground:Hsla = ZERO;

    /**
     * Sidebar border color.
     */
    public var sidebarBorder:Hsla = ZERO;

    /**
     * Sidebar text color.
     */
    public var sidebarForeground:Hsla = ZERO;

    /**
     * Sidebar primary background color.
     */
    public var sidebarPrimary:Hsla = ZERO;

    /**
     * Sidebar primary text color.
     */
    public var sidebarPrimaryForeground:Hsla = ZERO;

    /**
     * Skeleton background color.
     */
    public var skeleton:Hsla = ZERO;

    /**
     * Slider bar background color.
     */
    public var sliderBar:Hsla = ZERO;

    /**
     * Slider thumb background color.
     */
    public var sliderThumb:Hsla = ZERO;

    /**
     * Success background color.
     */
    public var success:Hsla = ZERO;

    /**
     * Success text color.
     */
    public var successForeground:Hsla = ZERO;

    /**
     * Success hover background color.
     */
    public var successHover:Hsla = ZERO;

    /**
     * Success active background color.
     */
    public var successActive:Hsla = ZERO;

    /**
     * Switch background color.
     */
    // Rust: `switch` (a Haxe keyword).
    public var switch_:Hsla = ZERO;

    /**
     * Switch thumb background color.
     */
    public var switchThumb:Hsla = ZERO;

    /**
     * Tab background color.
     */
    public var tab:Hsla = ZERO;

    /**
     * Tab active background color.
     */
    public var tabActive:Hsla = ZERO;

    /**
     * Tab active text color.
     */
    public var tabActiveForeground:Hsla = ZERO;

    /**
     * TabBar background color.
     */
    public var tabBar:Hsla = ZERO;

    /**
     * TabBar segmented background color.
     */
    public var tabBarSegmented:Hsla = ZERO;

    /**
     * Tab text color.
     */
    public var tabForeground:Hsla = ZERO;

    /**
     * Table background color.
     */
    public var table:Hsla = ZERO;

    /**
     * Table active item background color.
     */
    public var tableActive:Hsla = ZERO;

    /**
     * Table active item border color.
     */
    public var tableActiveBorder:Hsla = ZERO;

    /**
     * Stripe background color for even TableRow.
     */
    public var tableEven:Hsla = ZERO;

    /**
     * Table head background color.
     */
    public var tableHead:Hsla = ZERO;

    /**
     * Table head text color.
     */
    public var tableHeadForeground:Hsla = ZERO;

    /**
     * Table footer background color.
     */
    public var tableFoot:Hsla = ZERO;

    /**
     * Table footer text color.
     */
    public var tableFootForeground:Hsla = ZERO;

    /**
     * Table item hover background color.
     */
    public var tableHover:Hsla = ZERO;

    /**
     * Table row border color.
     */
    public var tableRowBorder:Hsla = ZERO;

    /**
     * TitleBar background color, use for Window title bar.
     */
    public var titleBar:Hsla = ZERO;

    /**
     * TitleBar border color.
     */
    public var titleBarBorder:Hsla = ZERO;

    /**
     * StatusBar background color, use for the bottom status bar.
     */
    public var statusBar:Hsla = ZERO;

    /**
     * StatusBar border color.
     */
    public var statusBarBorder:Hsla = ZERO;

    /**
     * Warning background color.
     */
    public var warning:Hsla = ZERO;

    /**
     * Warning active background color.
     */
    public var warningActive:Hsla = ZERO;

    /**
     * Warning hover background color.
     */
    public var warningHover:Hsla = ZERO;

    /**
     * Warning foreground color.
     */
    public var warningForeground:Hsla = ZERO;

    /**
     * Overlay background color.
     */
    public var overlay:Hsla = ZERO;

    /**
     * Window border color.
     *
     * # Platform specific:
     *
     * This is only works on Linux, other platforms we can't change the window border color.
     */
    public var windowBorder:Hsla = ZERO;

    /**
     * The base red color.
     */
    public var red:Hsla = ZERO;

    /**
     * The base red light color.
     */
    public var redLight:Hsla = ZERO;

    /**
     * The base green color.
     */
    public var green:Hsla = ZERO;

    /**
     * The base green light color.
     */
    public var greenLight:Hsla = ZERO;

    /**
     * The base blue color.
     */
    public var blue:Hsla = ZERO;

    /**
     * The base blue light color.
     */
    public var blueLight:Hsla = ZERO;

    /**
     * The base yellow color.
     */
    public var yellow:Hsla = ZERO;

    /**
     * The base yellow light color.
     */
    public var yellowLight:Hsla = ZERO;

    /**
     * The base magenta color.
     */
    public var magenta:Hsla = ZERO;

    /**
     * The base magenta light color.
     */
    public var magentaLight:Hsla = ZERO;

    /**
     * The base cyan color.
     */
    public var cyan:Hsla = ZERO;

    /**
     * The base cyan light color.
     */
    public var cyanLight:Hsla = ZERO;

    public function new() {}

    /**
     * Copies every color of `other` into this one.
     */
    public function copyColorsFrom(other:ThemeColor):Void {

        accent = other.accent;
        accentForeground = other.accentForeground;
        accordion = other.accordion;
        background = other.background;
        border = other.border;
        button = other.button;
        buttonActive = other.buttonActive;
        buttonForeground = other.buttonForeground;
        buttonHover = other.buttonHover;
        buttonDanger = other.buttonDanger;
        buttonDangerActive = other.buttonDangerActive;
        buttonDangerForeground = other.buttonDangerForeground;
        buttonDangerHover = other.buttonDangerHover;
        buttonInfo = other.buttonInfo;
        buttonInfoActive = other.buttonInfoActive;
        buttonInfoForeground = other.buttonInfoForeground;
        buttonInfoHover = other.buttonInfoHover;
        buttonPrimary = other.buttonPrimary;
        buttonPrimaryActive = other.buttonPrimaryActive;
        buttonPrimaryForeground = other.buttonPrimaryForeground;
        buttonPrimaryHover = other.buttonPrimaryHover;
        buttonSecondary = other.buttonSecondary;
        buttonSecondaryActive = other.buttonSecondaryActive;
        buttonSecondaryForeground = other.buttonSecondaryForeground;
        buttonSecondaryHover = other.buttonSecondaryHover;
        buttonSuccess = other.buttonSuccess;
        buttonSuccessActive = other.buttonSuccessActive;
        buttonSuccessForeground = other.buttonSuccessForeground;
        buttonSuccessHover = other.buttonSuccessHover;
        buttonWarning = other.buttonWarning;
        buttonWarningActive = other.buttonWarningActive;
        buttonWarningForeground = other.buttonWarningForeground;
        buttonWarningHover = other.buttonWarningHover;
        groupBox = other.groupBox;
        groupBoxForeground = other.groupBoxForeground;
        caret = other.caret;
        chart1 = other.chart1;
        chart2 = other.chart2;
        chart3 = other.chart3;
        chart4 = other.chart4;
        chart5 = other.chart5;
        chartBullish = other.chartBullish;
        chartBearish = other.chartBearish;
        chartGrid = other.chartGrid;
        danger = other.danger;
        dangerActive = other.dangerActive;
        dangerForeground = other.dangerForeground;
        dangerHover = other.dangerHover;
        descriptionListLabel = other.descriptionListLabel;
        descriptionListLabelForeground = other.descriptionListLabelForeground;
        dragBorder = other.dragBorder;
        dropTarget = other.dropTarget;
        foreground = other.foreground;
        info = other.info;
        infoActive = other.infoActive;
        infoForeground = other.infoForeground;
        infoHover = other.infoHover;
        input = other.input;
        link = other.link;
        linkActive = other.linkActive;
        linkHover = other.linkHover;
        list = other.list;
        listActive = other.listActive;
        listActiveBorder = other.listActiveBorder;
        listEven = other.listEven;
        listHead = other.listHead;
        listHover = other.listHover;
        muted = other.muted;
        mutedForeground = other.mutedForeground;
        popover = other.popover;
        popoverForeground = other.popoverForeground;
        primary = other.primary;
        primaryActive = other.primaryActive;
        primaryForeground = other.primaryForeground;
        primaryHover = other.primaryHover;
        progressBar = other.progressBar;
        ring = other.ring;
        scrollbar = other.scrollbar;
        scrollbarThumb = other.scrollbarThumb;
        scrollbarThumbHover = other.scrollbarThumbHover;
        secondary = other.secondary;
        secondaryActive = other.secondaryActive;
        secondaryForeground = other.secondaryForeground;
        secondaryHover = other.secondaryHover;
        selection = other.selection;
        sidebar = other.sidebar;
        sidebarAccent = other.sidebarAccent;
        sidebarAccentForeground = other.sidebarAccentForeground;
        sidebarBorder = other.sidebarBorder;
        sidebarForeground = other.sidebarForeground;
        sidebarPrimary = other.sidebarPrimary;
        sidebarPrimaryForeground = other.sidebarPrimaryForeground;
        skeleton = other.skeleton;
        sliderBar = other.sliderBar;
        sliderThumb = other.sliderThumb;
        success = other.success;
        successForeground = other.successForeground;
        successHover = other.successHover;
        successActive = other.successActive;
        switch_ = other.switch_;
        switchThumb = other.switchThumb;
        tab = other.tab;
        tabActive = other.tabActive;
        tabActiveForeground = other.tabActiveForeground;
        tabBar = other.tabBar;
        tabBarSegmented = other.tabBarSegmented;
        tabForeground = other.tabForeground;
        table = other.table;
        tableActive = other.tableActive;
        tableActiveBorder = other.tableActiveBorder;
        tableEven = other.tableEven;
        tableHead = other.tableHead;
        tableHeadForeground = other.tableHeadForeground;
        tableFoot = other.tableFoot;
        tableFootForeground = other.tableFootForeground;
        tableHover = other.tableHover;
        tableRowBorder = other.tableRowBorder;
        titleBar = other.titleBar;
        titleBarBorder = other.titleBarBorder;
        statusBar = other.statusBar;
        statusBarBorder = other.statusBarBorder;
        warning = other.warning;
        warningActive = other.warningActive;
        warningHover = other.warningHover;
        warningForeground = other.warningForeground;
        overlay = other.overlay;
        windowBorder = other.windowBorder;
        red = other.red;
        redLight = other.redLight;
        green = other.green;
        greenLight = other.greenLight;
        blue = other.blue;
        blueLight = other.blueLight;
        yellow = other.yellow;
        yellowLight = other.yellowLight;
        magenta = other.magenta;
        magentaLight = other.magentaLight;
        cyan = other.cyan;
        cyanLight = other.cyanLight;

    }

    /**
     * A copy of the colors (Rust: `ThemeColor` is `Copy`).
     */
    public function copyColors():ThemeColor {

        final result = new ThemeColor();
        result.copyColorsFrom(this);
        return result;

    }

    /**
     * Structural equality of every color (Rust: `PartialEq`).
     */
    public function colorsEqual(other:ThemeColor):Bool {

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
     * The names of the fields, in declaration order (Rust snake_case names).
     */
    public static final FIELD_NAMES:Array<String> = [
        'accent',
        'accent_foreground',
        'accordion',
        'background',
        'border',
        'button',
        'button_active',
        'button_foreground',
        'button_hover',
        'button_danger',
        'button_danger_active',
        'button_danger_foreground',
        'button_danger_hover',
        'button_info',
        'button_info_active',
        'button_info_foreground',
        'button_info_hover',
        'button_primary',
        'button_primary_active',
        'button_primary_foreground',
        'button_primary_hover',
        'button_secondary',
        'button_secondary_active',
        'button_secondary_foreground',
        'button_secondary_hover',
        'button_success',
        'button_success_active',
        'button_success_foreground',
        'button_success_hover',
        'button_warning',
        'button_warning_active',
        'button_warning_foreground',
        'button_warning_hover',
        'group_box',
        'group_box_foreground',
        'caret',
        'chart_1',
        'chart_2',
        'chart_3',
        'chart_4',
        'chart_5',
        'chart_bullish',
        'chart_bearish',
        'chart_grid',
        'danger',
        'danger_active',
        'danger_foreground',
        'danger_hover',
        'description_list_label',
        'description_list_label_foreground',
        'drag_border',
        'drop_target',
        'foreground',
        'info',
        'info_active',
        'info_foreground',
        'info_hover',
        'input',
        'link',
        'link_active',
        'link_hover',
        'list',
        'list_active',
        'list_active_border',
        'list_even',
        'list_head',
        'list_hover',
        'muted',
        'muted_foreground',
        'popover',
        'popover_foreground',
        'primary',
        'primary_active',
        'primary_foreground',
        'primary_hover',
        'progress_bar',
        'ring',
        'scrollbar',
        'scrollbar_thumb',
        'scrollbar_thumb_hover',
        'secondary',
        'secondary_active',
        'secondary_foreground',
        'secondary_hover',
        'selection',
        'sidebar',
        'sidebar_accent',
        'sidebar_accent_foreground',
        'sidebar_border',
        'sidebar_foreground',
        'sidebar_primary',
        'sidebar_primary_foreground',
        'skeleton',
        'slider_bar',
        'slider_thumb',
        'success',
        'success_foreground',
        'success_hover',
        'success_active',
        'switch',
        'switch_thumb',
        'tab',
        'tab_active',
        'tab_active_foreground',
        'tab_bar',
        'tab_bar_segmented',
        'tab_foreground',
        'table',
        'table_active',
        'table_active_border',
        'table_even',
        'table_head',
        'table_head_foreground',
        'table_foot',
        'table_foot_foreground',
        'table_hover',
        'table_row_border',
        'title_bar',
        'title_bar_border',
        'status_bar',
        'status_bar_border',
        'warning',
        'warning_active',
        'warning_hover',
        'warning_foreground',
        'overlay',
        'window_border',
        'red',
        'red_light',
        'green',
        'green_light',
        'blue',
        'blue_light',
        'yellow',
        'yellow_light',
        'magenta',
        'magenta_light',
        'cyan',
        'cyan_light'
    ];

    /**
     * Get the default light theme colors.
     */
    public static function light():ThemeColor {

        return DefaultThemeColors.get(ThemeMode.Light);

    }

    /**
     * Get the default dark theme colors.
     */
    public static function dark():ThemeColor {

        return DefaultThemeColors.get(ThemeMode.Dark);

    }

    static function applyColorValue(value:Null<String>, fallback:Hsla):Hsla {

        if (value != null) {
            final parsed = Color.tryParseColor(value);
            return parsed != null ? parsed : fallback;
        }
        return fallback;

    }

    static function applyBackgroundValue(value:Null<String>, fallback:ThemeToken):ThemeToken {

        if (value != null) {
            final token = ThemeToken.tryParse(value);
            return token != null ? token : fallback;
        }
        return fallback;

    }

    /**
     * Applies a `ThemeConfig` over `defaultTheme` and returns the resolved tokens.
     *
     * Rust: `ThemeColor::apply_config` (renamed because `Theme`, which extends
     * this class, has its own `applyConfig`).
     */
    @:allow(glaze.kit.theme)
    function applyConfigColors(config:ThemeConfig, defaultTheme:ThemeColor):ThemeTokens {

        final colors = config.colors;
        final defaultTokens = ThemeTokens.fromColors(defaultTheme);
        final tokens = defaultTokens.copy();

        // apply_background_color!(background);
        {
            final token = applyBackgroundValue(colors.background, defaultTokens.background);
            background = token.color;
            tokens.background = token;
        }
        // Base colors for fallback
        // apply_color!(red);
        red = applyColorValue(colors.red, defaultTheme.red);
        tokens.red = ThemeToken.fromHsla(red);
        // apply_color!( red_light, fallback = self.background.blend(self.red.opacity(0.8)) );
        redLight = applyColorValue(colors.redLight, background.blend(red.opacity(0.8)));
        tokens.redLight = ThemeToken.fromHsla(redLight);
        // apply_color!(green);
        green = applyColorValue(colors.green, defaultTheme.green);
        tokens.green = ThemeToken.fromHsla(green);
        // apply_color!( green_light, fallback = self.background.blend(self.green.opacity(0.8)) );
        greenLight = applyColorValue(colors.greenLight, background.blend(green.opacity(0.8)));
        tokens.greenLight = ThemeToken.fromHsla(greenLight);
        // apply_color!(blue);
        blue = applyColorValue(colors.blue, defaultTheme.blue);
        tokens.blue = ThemeToken.fromHsla(blue);
        // apply_color!( blue_light, fallback = self.background.blend(self.blue.opacity(0.8)) );
        blueLight = applyColorValue(colors.blueLight, background.blend(blue.opacity(0.8)));
        tokens.blueLight = ThemeToken.fromHsla(blueLight);
        // apply_color!(magenta);
        magenta = applyColorValue(colors.magenta, defaultTheme.magenta);
        tokens.magenta = ThemeToken.fromHsla(magenta);
        // apply_color!( magenta_light, fallback = self.background.blend(self.magenta.opacity(0.8)) );
        magentaLight = applyColorValue(colors.magentaLight, background.blend(magenta.opacity(0.8)));
        tokens.magentaLight = ThemeToken.fromHsla(magentaLight);
        // apply_color!(yellow);
        yellow = applyColorValue(colors.yellow, defaultTheme.yellow);
        tokens.yellow = ThemeToken.fromHsla(yellow);
        // apply_color!( yellow_light, fallback = self.background.blend(self.yellow.opacity(0.8)) );
        yellowLight = applyColorValue(colors.yellowLight, background.blend(yellow.opacity(0.8)));
        tokens.yellowLight = ThemeToken.fromHsla(yellowLight);
        // apply_color!(cyan);
        cyan = applyColorValue(colors.cyan, defaultTheme.cyan);
        tokens.cyan = ThemeToken.fromHsla(cyan);
        // apply_color!( cyan_light, fallback = self.background.blend(self.cyan.opacity(0.8)) );
        cyanLight = applyColorValue(colors.cyanLight, background.blend(cyan.opacity(0.8)));
        tokens.cyanLight = ThemeToken.fromHsla(cyanLight);
        // apply_color!(border);
        border = applyColorValue(colors.border, defaultTheme.border);
        tokens.border = ThemeToken.fromHsla(border);
        // apply_color!(foreground);
        foreground = applyColorValue(colors.foreground, defaultTheme.foreground);
        tokens.foreground = ThemeToken.fromHsla(foreground);
        // apply_color!(input, fallback = self.border);
        input = applyColorValue(colors.input, border);
        tokens.input = ThemeToken.fromHsla(input);
        // apply_background_color!(muted);
        {
            final token = applyBackgroundValue(colors.muted, defaultTokens.muted);
            muted = token.color;
            tokens.muted = token;
        }
        // apply_color!( muted_foreground, fallback = self.muted.blend(self.foreground.opacity(0.7)) );
        mutedForeground = applyColorValue(colors.mutedForeground, muted.blend(foreground.opacity(0.7)));
        tokens.mutedForeground = ThemeToken.fromHsla(mutedForeground);
        // Button colors
        final activeDarken = config.mode.isDark() ? 0.2 : 0.1;
        final hoverOpacity = 0.9;
        final transparent = Hsla.transparentBlack();
        final buttonBackground = config.mode.isDark() ? input.mixOklab(transparent, 0.3) : background;
        // apply_background_color!(button, fallback = button_background);
        {
            final token = applyBackgroundValue(colors.button, ThemeToken.fromHsla(buttonBackground));
            button = token.color;
            tokens.button = token;
        }
        // apply_color!(button_foreground, fallback = self.foreground);
        buttonForeground = applyColorValue(colors.buttonForeground, foreground);
        tokens.buttonForeground = ThemeToken.fromHsla(buttonForeground);
        // apply_background_color!( button_hover, fallback = self.input.mix_oklab(transparent, 0.5) );
        {
            final token = applyBackgroundValue(colors.buttonHover, ThemeToken.fromHsla(input.mixOklab(transparent, 0.5)));
            buttonHover = token.color;
            tokens.buttonHover = token;
        }
        // apply_background_color!( button_active, fallback = self.input.mix_oklab(transparent, 0.7) );
        {
            final token = applyBackgroundValue(colors.buttonActive, ThemeToken.fromHsla(input.mixOklab(transparent, 0.7)));
            buttonActive = token.color;
            tokens.buttonActive = token;
        }
        // apply_background_color!(primary);
        {
            final token = applyBackgroundValue(colors.primary, defaultTokens.primary);
            primary = token.color;
            tokens.primary = token;
        }
        // apply_color!(primary_foreground, fallback = self.foreground);
        primaryForeground = applyColorValue(colors.primaryForeground, foreground);
        tokens.primaryForeground = ThemeToken.fromHsla(primaryForeground);
        // apply_background_color!( primary_hover, fallback = self.background.blend(self.primary.opacity(hover_opacity)) );
        {
            final token = applyBackgroundValue(colors.primaryHover, ThemeToken.fromHsla(background.blend(primary.opacity(hoverOpacity))));
            primaryHover = token.color;
            tokens.primaryHover = token;
        }
        // apply_background_color!( primary_active, fallback = self.primary.darken(active_darken) );
        {
            final token = applyBackgroundValue(colors.primaryActive, ThemeToken.fromHsla(primary.darken(activeDarken)));
            primaryActive = token.color;
            tokens.primaryActive = token;
        }
        // apply_background_color!(button_primary, fallback = tokens.primary);
        {
            final token = applyBackgroundValue(colors.buttonPrimary, tokens.primary);
            buttonPrimary = token.color;
            tokens.buttonPrimary = token;
        }
        // apply_color!( button_primary_foreground, fallback = self.primary_foreground );
        buttonPrimaryForeground = applyColorValue(colors.buttonPrimaryForeground, primaryForeground);
        tokens.buttonPrimaryForeground = ThemeToken.fromHsla(buttonPrimaryForeground);
        // apply_background_color!(button_primary_hover, fallback = tokens.primary_hover);
        {
            final token = applyBackgroundValue(colors.buttonPrimaryHover, tokens.primaryHover);
            buttonPrimaryHover = token.color;
            tokens.buttonPrimaryHover = token;
        }
        // apply_background_color!(button_primary_active, fallback = tokens.primary_active);
        {
            final token = applyBackgroundValue(colors.buttonPrimaryActive, tokens.primaryActive);
            buttonPrimaryActive = token.color;
            tokens.buttonPrimaryActive = token;
        }
        // apply_background_color!(secondary);
        {
            final token = applyBackgroundValue(colors.secondary, defaultTokens.secondary);
            secondary = token.color;
            tokens.secondary = token;
        }
        // apply_color!(secondary_foreground, fallback = self.foreground);
        secondaryForeground = applyColorValue(colors.secondaryForeground, foreground);
        tokens.secondaryForeground = ThemeToken.fromHsla(secondaryForeground);
        // apply_background_color!( secondary_hover, fallback = self.background.blend(self.secondary.opacity(hover_opacity)) );
        {
            final token = applyBackgroundValue(colors.secondaryHover, ThemeToken.fromHsla(background.blend(secondary.opacity(hoverOpacity))));
            secondaryHover = token.color;
            tokens.secondaryHover = token;
        }
        // apply_background_color!( secondary_active, fallback = self.secondary.darken(active_darken) );
        {
            final token = applyBackgroundValue(colors.secondaryActive, ThemeToken.fromHsla(secondary.darken(activeDarken)));
            secondaryActive = token.color;
            tokens.secondaryActive = token;
        }
        // apply_background_color!(button_secondary, fallback = tokens.secondary);
        {
            final token = applyBackgroundValue(colors.buttonSecondary, tokens.secondary);
            buttonSecondary = token.color;
            tokens.buttonSecondary = token;
        }
        // apply_color!( button_secondary_foreground, fallback = self.secondary_foreground );
        buttonSecondaryForeground = applyColorValue(colors.buttonSecondaryForeground, secondaryForeground);
        tokens.buttonSecondaryForeground = ThemeToken.fromHsla(buttonSecondaryForeground);
        // apply_background_color!(button_secondary_hover, fallback = tokens.secondary_hover);
        {
            final token = applyBackgroundValue(colors.buttonSecondaryHover, tokens.secondaryHover);
            buttonSecondaryHover = token.color;
            tokens.buttonSecondaryHover = token;
        }
        // apply_background_color!(button_secondary_active, fallback = tokens.secondary_active);
        {
            final token = applyBackgroundValue(colors.buttonSecondaryActive, tokens.secondaryActive);
            buttonSecondaryActive = token.color;
            tokens.buttonSecondaryActive = token;
        }
        // apply_background_color!(success, fallback = self.green);
        {
            final token = applyBackgroundValue(colors.success, ThemeToken.fromHsla(green));
            success = token.color;
            tokens.success = token;
        }
        // apply_color!(success_foreground, fallback = self.primary_foreground);
        successForeground = applyColorValue(colors.successForeground, primaryForeground);
        tokens.successForeground = ThemeToken.fromHsla(successForeground);
        // apply_background_color!( success_hover, fallback = self.background.blend(self.success.opacity(hover_opacity)) );
        {
            final token = applyBackgroundValue(colors.successHover, ThemeToken.fromHsla(background.blend(success.opacity(hoverOpacity))));
            successHover = token.color;
            tokens.successHover = token;
        }
        // apply_background_color!( success_active, fallback = self.success.darken(active_darken) );
        {
            final token = applyBackgroundValue(colors.successActive, ThemeToken.fromHsla(success.darken(activeDarken)));
            successActive = token.color;
            tokens.successActive = token;
        }
        // apply_background_color!( button_success, fallback = self.success.mix_oklab(transparent, 0.2) );
        {
            final token = applyBackgroundValue(colors.buttonSuccess, ThemeToken.fromHsla(success.mixOklab(transparent, 0.2)));
            buttonSuccess = token.color;
            tokens.buttonSuccess = token;
        }
        // apply_color!(button_success_foreground, fallback = self.success);
        buttonSuccessForeground = applyColorValue(colors.buttonSuccessForeground, success);
        tokens.buttonSuccessForeground = ThemeToken.fromHsla(buttonSuccessForeground);
        // apply_background_color!( button_success_hover, fallback = self.success.mix_oklab(transparent, 0.3) );
        {
            final token = applyBackgroundValue(colors.buttonSuccessHover, ThemeToken.fromHsla(success.mixOklab(transparent, 0.3)));
            buttonSuccessHover = token.color;
            tokens.buttonSuccessHover = token;
        }
        // apply_background_color!( button_success_active, fallback = self.success.mix_oklab(transparent, 0.4) );
        {
            final token = applyBackgroundValue(colors.buttonSuccessActive, ThemeToken.fromHsla(success.mixOklab(transparent, 0.4)));
            buttonSuccessActive = token.color;
            tokens.buttonSuccessActive = token;
        }
        // apply_background_color!(info, fallback = self.cyan);
        {
            final token = applyBackgroundValue(colors.info, ThemeToken.fromHsla(cyan));
            info = token.color;
            tokens.info = token;
        }
        // apply_color!(info_foreground, fallback = self.primary_foreground);
        infoForeground = applyColorValue(colors.infoForeground, primaryForeground);
        tokens.infoForeground = ThemeToken.fromHsla(infoForeground);
        // apply_background_color!( info_hover, fallback = self.background.blend(self.info.opacity(hover_opacity)) );
        {
            final token = applyBackgroundValue(colors.infoHover, ThemeToken.fromHsla(background.blend(info.opacity(hoverOpacity))));
            infoHover = token.color;
            tokens.infoHover = token;
        }
        // apply_background_color!(info_active, fallback = self.info.darken(active_darken));
        {
            final token = applyBackgroundValue(colors.infoActive, ThemeToken.fromHsla(info.darken(activeDarken)));
            infoActive = token.color;
            tokens.infoActive = token;
        }
        // apply_background_color!( button_info, fallback = self.info.mix_oklab(transparent, 0.2) );
        {
            final token = applyBackgroundValue(colors.buttonInfo, ThemeToken.fromHsla(info.mixOklab(transparent, 0.2)));
            buttonInfo = token.color;
            tokens.buttonInfo = token;
        }
        // apply_color!(button_info_foreground, fallback = self.info);
        buttonInfoForeground = applyColorValue(colors.buttonInfoForeground, info);
        tokens.buttonInfoForeground = ThemeToken.fromHsla(buttonInfoForeground);
        // apply_background_color!( button_info_hover, fallback = self.info.mix_oklab(transparent, 0.3) );
        {
            final token = applyBackgroundValue(colors.buttonInfoHover, ThemeToken.fromHsla(info.mixOklab(transparent, 0.3)));
            buttonInfoHover = token.color;
            tokens.buttonInfoHover = token;
        }
        // apply_background_color!( button_info_active, fallback = self.info.mix_oklab(transparent, 0.4) );
        {
            final token = applyBackgroundValue(colors.buttonInfoActive, ThemeToken.fromHsla(info.mixOklab(transparent, 0.4)));
            buttonInfoActive = token.color;
            tokens.buttonInfoActive = token;
        }
        // apply_background_color!(warning, fallback = self.yellow);
        {
            final token = applyBackgroundValue(colors.warning, ThemeToken.fromHsla(yellow));
            warning = token.color;
            tokens.warning = token;
        }
        // apply_color!(warning_foreground, fallback = self.primary_foreground);
        warningForeground = applyColorValue(colors.warningForeground, primaryForeground);
        tokens.warningForeground = ThemeToken.fromHsla(warningForeground);
        // apply_background_color!( warning_hover, fallback = self.background.blend(self.warning.opacity(0.9)) );
        {
            final token = applyBackgroundValue(colors.warningHover, ThemeToken.fromHsla(background.blend(warning.opacity(0.9))));
            warningHover = token.color;
            tokens.warningHover = token;
        }
        // apply_background_color!( warning_active, fallback = self.background.blend(self.warning.darken(active_darken)) );
        {
            final token = applyBackgroundValue(colors.warningActive, ThemeToken.fromHsla(background.blend(warning.darken(activeDarken))));
            warningActive = token.color;
            tokens.warningActive = token;
        }
        // apply_background_color!( button_warning, fallback = self.warning.mix_oklab(transparent, 0.2) );
        {
            final token = applyBackgroundValue(colors.buttonWarning, ThemeToken.fromHsla(warning.mixOklab(transparent, 0.2)));
            buttonWarning = token.color;
            tokens.buttonWarning = token;
        }
        // apply_color!(button_warning_foreground, fallback = self.warning);
        buttonWarningForeground = applyColorValue(colors.buttonWarningForeground, warning);
        tokens.buttonWarningForeground = ThemeToken.fromHsla(buttonWarningForeground);
        // apply_background_color!( button_warning_hover, fallback = self.warning.mix_oklab(transparent, 0.3) );
        {
            final token = applyBackgroundValue(colors.buttonWarningHover, ThemeToken.fromHsla(warning.mixOklab(transparent, 0.3)));
            buttonWarningHover = token.color;
            tokens.buttonWarningHover = token;
        }
        // apply_background_color!( button_warning_active, fallback = self.warning.mix_oklab(transparent, 0.4) );
        {
            final token = applyBackgroundValue(colors.buttonWarningActive, ThemeToken.fromHsla(warning.mixOklab(transparent, 0.4)));
            buttonWarningActive = token.color;
            tokens.buttonWarningActive = token;
        }
        // Other colors
        // apply_background_color!(accent, fallback = tokens.secondary);
        {
            final token = applyBackgroundValue(colors.accent, tokens.secondary);
            accent = token.color;
            tokens.accent = token;
        }
        // apply_color!(accent_foreground, fallback = self.foreground);
        accentForeground = applyColorValue(colors.accentForeground, foreground);
        tokens.accentForeground = ThemeToken.fromHsla(accentForeground);
        // apply_background_color!(accordion, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.accordion, tokens.background);
            accordion = token.color;
            tokens.accordion = token;
        }
        // apply_background_color!( group_box, fallback = self .background .blend( self.secondary .opacity(if config.mode.is_dark() { 0.3 } else { 0.4 }) ) );
        {
            final token = applyBackgroundValue(colors.groupBox, ThemeToken.fromHsla(background .blend( secondary .opacity((config.mode.isDark() ? 0.3 : 0.4)) )));
            groupBox = token.color;
            tokens.groupBox = token;
        }
        // apply_color!(group_box_foreground, fallback = self.foreground);
        groupBoxForeground = applyColorValue(colors.groupBoxForeground, foreground);
        tokens.groupBoxForeground = ThemeToken.fromHsla(groupBoxForeground);
        // apply_color!(caret, fallback = self.primary);
        caret = applyColorValue(colors.caret, primary);
        tokens.caret = ThemeToken.fromHsla(caret);
        // apply_color!(chart_1, fallback = self.blue.lighten(0.4));
        chart1 = applyColorValue(colors.chart1, blue.lighten(0.4));
        tokens.chart1 = ThemeToken.fromHsla(chart1);
        // apply_color!(chart_2, fallback = self.blue.lighten(0.2));
        chart2 = applyColorValue(colors.chart2, blue.lighten(0.2));
        tokens.chart2 = ThemeToken.fromHsla(chart2);
        // apply_color!(chart_3, fallback = self.blue);
        chart3 = applyColorValue(colors.chart3, blue);
        tokens.chart3 = ThemeToken.fromHsla(chart3);
        // apply_color!(chart_4, fallback = self.blue.darken(0.2));
        chart4 = applyColorValue(colors.chart4, blue.darken(0.2));
        tokens.chart4 = ThemeToken.fromHsla(chart4);
        // apply_color!(chart_5, fallback = self.blue.darken(0.4));
        chart5 = applyColorValue(colors.chart5, blue.darken(0.4));
        tokens.chart5 = ThemeToken.fromHsla(chart5);
        // apply_color!(chart_bullish, fallback = self.green);
        chartBullish = applyColorValue(colors.chartBullish, green);
        tokens.chartBullish = ThemeToken.fromHsla(chartBullish);
        // apply_color!(chart_bearish, fallback = self.red);
        chartBearish = applyColorValue(colors.chartBearish, red);
        tokens.chartBearish = ThemeToken.fromHsla(chartBearish);
        // apply_color!(chart_grid, fallback = self.border.opacity(0.6));
        chartGrid = applyColorValue(colors.chartGrid, border.opacity(0.6));
        tokens.chartGrid = ThemeToken.fromHsla(chartGrid);
        // apply_background_color!(danger, fallback = self.red);
        {
            final token = applyBackgroundValue(colors.danger, ThemeToken.fromHsla(red));
            danger = token.color;
            tokens.danger = token;
        }
        // apply_background_color!(danger_active, fallback = self.danger.darken(active_darken));
        {
            final token = applyBackgroundValue(colors.dangerActive, ThemeToken.fromHsla(danger.darken(activeDarken)));
            dangerActive = token.color;
            tokens.dangerActive = token;
        }
        // apply_color!(danger_foreground, fallback = self.primary_foreground);
        dangerForeground = applyColorValue(colors.dangerForeground, primaryForeground);
        tokens.dangerForeground = ThemeToken.fromHsla(dangerForeground);
        // apply_background_color!( danger_hover, fallback = self.background.blend(self.danger.opacity(0.9)) );
        {
            final token = applyBackgroundValue(colors.dangerHover, ThemeToken.fromHsla(background.blend(danger.opacity(0.9))));
            dangerHover = token.color;
            tokens.dangerHover = token;
        }
        // apply_background_color!( button_danger, fallback = self.danger.mix_oklab(transparent, 0.2) );
        {
            final token = applyBackgroundValue(colors.buttonDanger, ThemeToken.fromHsla(danger.mixOklab(transparent, 0.2)));
            buttonDanger = token.color;
            tokens.buttonDanger = token;
        }
        // apply_color!(button_danger_foreground, fallback = self.danger);
        buttonDangerForeground = applyColorValue(colors.buttonDangerForeground, danger);
        tokens.buttonDangerForeground = ThemeToken.fromHsla(buttonDangerForeground);
        // apply_background_color!( button_danger_hover, fallback = self.danger.mix_oklab(transparent, 0.3) );
        {
            final token = applyBackgroundValue(colors.buttonDangerHover, ThemeToken.fromHsla(danger.mixOklab(transparent, 0.3)));
            buttonDangerHover = token.color;
            tokens.buttonDangerHover = token;
        }
        // apply_background_color!( button_danger_active, fallback = self.danger.mix_oklab(transparent, 0.4) );
        {
            final token = applyBackgroundValue(colors.buttonDangerActive, ThemeToken.fromHsla(danger.mixOklab(transparent, 0.4)));
            buttonDangerActive = token.color;
            tokens.buttonDangerActive = token;
        }
        // apply_background_color!( description_list_label, fallback = self.background.blend(self.border.opacity(0.2)) );
        {
            final token = applyBackgroundValue(colors.descriptionListLabel, ThemeToken.fromHsla(background.blend(border.opacity(0.2))));
            descriptionListLabel = token.color;
            tokens.descriptionListLabel = token;
        }
        // apply_color!( description_list_label_foreground, fallback = self.muted_foreground );
        descriptionListLabelForeground = applyColorValue(colors.descriptionListLabelForeground, mutedForeground);
        tokens.descriptionListLabelForeground = ThemeToken.fromHsla(descriptionListLabelForeground);
        // apply_color!(drag_border, fallback = self.primary.opacity(0.65));
        dragBorder = applyColorValue(colors.dragBorder, primary.opacity(0.65));
        tokens.dragBorder = ThemeToken.fromHsla(dragBorder);
        // apply_background_color!(drop_target, fallback = self.primary.opacity(0.2));
        {
            final token = applyBackgroundValue(colors.dropTarget, ThemeToken.fromHsla(primary.opacity(0.2)));
            dropTarget = token.color;
            tokens.dropTarget = token;
        }
        // apply_color!(link, fallback = self.primary);
        link = applyColorValue(colors.link, primary);
        tokens.link = ThemeToken.fromHsla(link);
        // apply_color!(link_active, fallback = self.link);
        linkActive = applyColorValue(colors.linkActive, link);
        tokens.linkActive = ThemeToken.fromHsla(linkActive);
        // apply_color!(link_hover, fallback = self.link);
        linkHover = applyColorValue(colors.linkHover, link);
        tokens.linkHover = ThemeToken.fromHsla(linkHover);
        // apply_background_color!(list, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.list, tokens.background);
            list = token.color;
            tokens.list = token;
        }
        // apply_background_color!( list_active, fallback = self.background.blend(self.primary.opacity(0.1)) );
        {
            final token = applyBackgroundValue(colors.listActive, ThemeToken.fromHsla(background.blend(primary.opacity(0.1))));
            listActive = token.color;
            tokens.listActive = token;
        }
        // apply_color!( list_active_border, fallback = self.background.blend(self.primary.opacity(0.6)) );
        listActiveBorder = applyColorValue(colors.listActiveBorder, background.blend(primary.opacity(0.6)));
        tokens.listActiveBorder = ThemeToken.fromHsla(listActiveBorder);
        // apply_background_color!(list_even, fallback = tokens.list);
        {
            final token = applyBackgroundValue(colors.listEven, tokens.list);
            listEven = token.color;
            tokens.listEven = token;
        }
        // apply_background_color!(list_head, fallback = tokens.list);
        {
            final token = applyBackgroundValue(colors.listHead, tokens.list);
            listHead = token.color;
            tokens.listHead = token;
        }
        // apply_background_color!(list_hover, fallback = self.accent.opacity(0.6));
        {
            final token = applyBackgroundValue(colors.listHover, ThemeToken.fromHsla(accent.opacity(0.6)));
            listHover = token.color;
            tokens.listHover = token;
        }
        // apply_background_color!(popover, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.popover, tokens.background);
            popover = token.color;
            tokens.popover = token;
        }
        // apply_color!(popover_foreground, fallback = self.foreground);
        popoverForeground = applyColorValue(colors.popoverForeground, foreground);
        tokens.popoverForeground = ThemeToken.fromHsla(popoverForeground);
        // apply_background_color!(progress_bar, fallback = tokens.primary);
        {
            final token = applyBackgroundValue(colors.progressBar, tokens.primary);
            progressBar = token.color;
            tokens.progressBar = token;
        }
        // apply_color!(ring, fallback = self.blue);
        ring = applyColorValue(colors.ring, blue);
        tokens.ring = ThemeToken.fromHsla(ring);
        // apply_background_color!(scrollbar, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.scrollbar, tokens.background);
            scrollbar = token.color;
            tokens.scrollbar = token;
        }
        // apply_background_color!(scrollbar_thumb, fallback = tokens.accent);
        {
            final token = applyBackgroundValue(colors.scrollbarThumb, tokens.accent);
            scrollbarThumb = token.color;
            tokens.scrollbarThumb = token;
        }
        // apply_background_color!(scrollbar_thumb_hover, fallback = tokens.scrollbar_thumb);
        {
            final token = applyBackgroundValue(colors.scrollbarThumbHover, tokens.scrollbarThumb);
            scrollbarThumbHover = token.color;
            tokens.scrollbarThumbHover = token;
        }
        // apply_background_color!(selection, fallback = tokens.primary);
        {
            final token = applyBackgroundValue(colors.selection, tokens.primary);
            selection = token.color;
            tokens.selection = token;
        }
        // apply_background_color!( sidebar, fallback = self.background.blend(self.border.opacity(0.15)) );
        {
            final token = applyBackgroundValue(colors.sidebar, ThemeToken.fromHsla(background.blend(border.opacity(0.15))));
            sidebar = token.color;
            tokens.sidebar = token;
        }
        // apply_background_color!(sidebar_accent, fallback = tokens.accent);
        {
            final token = applyBackgroundValue(colors.sidebarAccent, tokens.accent);
            sidebarAccent = token.color;
            tokens.sidebarAccent = token;
        }
        // apply_color!(sidebar_accent_foreground, fallback = self.accent_foreground);
        sidebarAccentForeground = applyColorValue(colors.sidebarAccentForeground, accentForeground);
        tokens.sidebarAccentForeground = ThemeToken.fromHsla(sidebarAccentForeground);
        // apply_color!(sidebar_border, fallback = self.border);
        sidebarBorder = applyColorValue(colors.sidebarBorder, border);
        tokens.sidebarBorder = ThemeToken.fromHsla(sidebarBorder);
        // apply_color!(sidebar_foreground, fallback = self.foreground);
        sidebarForeground = applyColorValue(colors.sidebarForeground, foreground);
        tokens.sidebarForeground = ThemeToken.fromHsla(sidebarForeground);
        // apply_background_color!(sidebar_primary, fallback = tokens.primary);
        {
            final token = applyBackgroundValue(colors.sidebarPrimary, tokens.primary);
            sidebarPrimary = token.color;
            tokens.sidebarPrimary = token;
        }
        // apply_color!( sidebar_primary_foreground, fallback = self.primary_foreground );
        sidebarPrimaryForeground = applyColorValue(colors.sidebarPrimaryForeground, primaryForeground);
        tokens.sidebarPrimaryForeground = ThemeToken.fromHsla(sidebarPrimaryForeground);
        // apply_background_color!(skeleton, fallback = tokens.secondary);
        {
            final token = applyBackgroundValue(colors.skeleton, tokens.secondary);
            skeleton = token.color;
            tokens.skeleton = token;
        }
        // apply_background_color!(slider_bar, fallback = tokens.primary);
        {
            final token = applyBackgroundValue(colors.sliderBar, tokens.primary);
            sliderBar = token.color;
            tokens.sliderBar = token;
        }
        // apply_background_color!(slider_thumb, fallback = self.primary_foreground);
        {
            final token = applyBackgroundValue(colors.sliderThumb, ThemeToken.fromHsla(primaryForeground));
            sliderThumb = token.color;
            tokens.sliderThumb = token;
        }
        // apply_background_color!(switch, fallback = tokens.secondary_active);
        {
            final token = applyBackgroundValue(colors.switch_, tokens.secondaryActive);
            switch_ = token.color;
            tokens.switch_ = token;
        }
        // apply_background_color!(switch_thumb, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.switchThumb, tokens.background);
            switchThumb = token.color;
            tokens.switchThumb = token;
        }
        // apply_background_color!(tab, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.tab, tokens.background);
            tab = token.color;
            tokens.tab = token;
        }
        // apply_background_color!(tab_active, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.tabActive, tokens.background);
            tabActive = token.color;
            tokens.tabActive = token;
        }
        // apply_color!(tab_active_foreground, fallback = self.foreground);
        tabActiveForeground = applyColorValue(colors.tabActiveForeground, foreground);
        tokens.tabActiveForeground = ThemeToken.fromHsla(tabActiveForeground);
        // apply_background_color!(tab_bar, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.tabBar, tokens.background);
            tabBar = token.color;
            tokens.tabBar = token;
        }
        // apply_background_color!(tab_bar_segmented, fallback = tokens.secondary);
        {
            final token = applyBackgroundValue(colors.tabBarSegmented, tokens.secondary);
            tabBarSegmented = token.color;
            tokens.tabBarSegmented = token;
        }
        // apply_color!(tab_foreground, fallback = self.foreground);
        tabForeground = applyColorValue(colors.tabForeground, foreground);
        tokens.tabForeground = ThemeToken.fromHsla(tabForeground);
        // apply_background_color!(table, fallback = tokens.list);
        {
            final token = applyBackgroundValue(colors.table, tokens.list);
            table = token.color;
            tokens.table = token;
        }
        // apply_background_color!(table_active, fallback = tokens.list_active);
        {
            final token = applyBackgroundValue(colors.tableActive, tokens.listActive);
            tableActive = token.color;
            tokens.tableActive = token;
        }
        // apply_color!(table_active_border, fallback = self.list_active_border);
        tableActiveBorder = applyColorValue(colors.tableActiveBorder, listActiveBorder);
        tokens.tableActiveBorder = ThemeToken.fromHsla(tableActiveBorder);
        // apply_background_color!(table_even, fallback = tokens.list_even);
        {
            final token = applyBackgroundValue(colors.tableEven, tokens.listEven);
            tableEven = token.color;
            tokens.tableEven = token;
        }
        // apply_background_color!(table_head, fallback = tokens.list_head);
        {
            final token = applyBackgroundValue(colors.tableHead, tokens.listHead);
            tableHead = token.color;
            tokens.tableHead = token;
        }
        // apply_color!(table_head_foreground, fallback = self.muted_foreground);
        tableHeadForeground = applyColorValue(colors.tableHeadForeground, mutedForeground);
        tokens.tableHeadForeground = ThemeToken.fromHsla(tableHeadForeground);
        // apply_background_color!(table_foot, fallback = tokens.list_head);
        {
            final token = applyBackgroundValue(colors.tableFoot, tokens.listHead);
            tableFoot = token.color;
            tokens.tableFoot = token;
        }
        // apply_color!(table_foot_foreground, fallback = self.muted_foreground);
        tableFootForeground = applyColorValue(colors.tableFootForeground, mutedForeground);
        tokens.tableFootForeground = ThemeToken.fromHsla(tableFootForeground);
        // apply_background_color!(table_hover, fallback = tokens.list_hover);
        {
            final token = applyBackgroundValue(colors.tableHover, tokens.listHover);
            tableHover = token.color;
            tokens.tableHover = token;
        }
        // apply_color!(table_row_border, fallback = self.border);
        tableRowBorder = applyColorValue(colors.tableRowBorder, border);
        tokens.tableRowBorder = ThemeToken.fromHsla(tableRowBorder);
        // apply_background_color!(title_bar, fallback = tokens.background);
        {
            final token = applyBackgroundValue(colors.titleBar, tokens.background);
            titleBar = token.color;
            tokens.titleBar = token;
        }
        // apply_color!(title_bar_border, fallback = self.border);
        titleBarBorder = applyColorValue(colors.titleBarBorder, border);
        tokens.titleBarBorder = ThemeToken.fromHsla(titleBarBorder);
        // apply_background_color!(status_bar, fallback = tokens.title_bar);
        {
            final token = applyBackgroundValue(colors.statusBar, tokens.titleBar);
            statusBar = token.color;
            tokens.statusBar = token;
        }
        // apply_color!(status_bar_border, fallback = self.title_bar_border);
        statusBarBorder = applyColorValue(colors.statusBarBorder, titleBarBorder);
        tokens.statusBarBorder = ThemeToken.fromHsla(statusBarBorder);
        // apply_background_color!(overlay);
        {
            final token = applyBackgroundValue(colors.overlay, defaultTokens.overlay);
            overlay = token.color;
            tokens.overlay = token;
        }
        // apply_color!(window_border, fallback = self.border);
        windowBorder = applyColorValue(colors.windowBorder, border);
        tokens.windowBorder = ThemeToken.fromHsla(windowBorder);

        // TODO: Apply default fallback colors to highlight.

        // Ensure opacity for list_active, table_active, selection.
        var clamped = clampAlpha(colors.listActive, listActive, tokens.listActive.background, 0.2);
        listActive = clamped.color;
        tokens.listActive = clamped;
        clamped = clampAlpha(colors.tableActive, tableActive, tokens.tableActive.background, 0.2);
        tableActive = clamped.color;
        tokens.tableActive = clamped;
        clamped = clampAlpha(colors.selection, selection, tokens.selection.background, 0.3);
        selection = clamped.color;
        tokens.selection = clamped;

        return tokens;

    }

    static function clampAlpha(raw:Null<String>, color:Hsla, background:Background, max:Float):ThemeToken {

        final base = color.a;
        final target = Math.min(base, max);
        final color = color.alpha(target);
        var parsed:Null<Background> = raw != null ? Color.tryParseBackgroundClamped(raw, max) : null;
        if (parsed == null) {
            final factor = base > 0.0 ? target / base : 1.0;
            parsed = background.opacity(factor);
        }
        return new ThemeToken(color, parsed);

    }

}
