package elements;

/**
 * Represents the possible states of a tab in a tab control.
 * 
 * This enum abstract defines the various states that a tab can be in,
 * which affects how the tab is displayed and whether it can be interacted with.
 * Used primarily by tab navigation components to control tab appearance and behavior.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Create a tab with default state
 * var myTab = new Tab();
 * myTab.state = TabState.DEFAULT;
 * 
 * // Disable a tab
 * myTab.state = TabState.DISABLED;
 * ```
 * 
 * @see TabsLayout
 * @see TabFocus
 */
enum abstract TabState(Int) from Int to Int {

    /**
     * The default, active state of a tab.
     * In this state, the tab is fully interactive and can be selected by the user.
     */
    var DEFAULT = 0;

    /**
     * The disabled state of a tab.
     * In this state, the tab cannot be selected or interacted with by the user.
     * The tab will typically be rendered with a different visual style to indicate
     * its disabled state (e.g., grayed out or with reduced opacity).
     */
    var DISABLED = 1;

}