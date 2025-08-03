package elements;

/**
 * Interface for elements that can participate in Tab key focus navigation.
 * 
 * TabFocusable defines the contract for visual elements that can receive focus
 * through Tab key navigation managed by the TabFocus component. Implementing
 * this interface allows elements to be included in the focus traversal order
 * and provides hooks for focus-related behavior.
 * 
 * Classes implementing this interface typically include form fields, buttons,
 * and other interactive UI elements that should be accessible via keyboard navigation.
 * 
 * Usage example:
 * ```haxe
 * class MyCustomField extends View implements TabFocusable {
 *     
 *     public function allowsTabFocus():Bool {
 *         return enabled && visible; // Only focusable when enabled and visible
 *     }
 *     
 *     public function tabFocus():Void {
 *         // Set focus and visual feedback
 *         screen.focusedVisual = this;
 *         focused = true;
 *     }
 *     
 *     public function escapeTabFocus():Void {
 *         // Handle escape key - lose focus or close dropdown
 *         screen.focusedVisual = null;
 *     }
 * }
 * ```
 */
interface TabFocusable {

    /**
     * Determines whether this element can currently receive Tab focus.
     * 
     * This method is called by TabFocus during navigation to determine if
     * the element should be included in the focus traversal. Elements can
     * return false when they are disabled, hidden, or otherwise not ready
     * to receive focus.
     * 
     * @return true if the element can receive focus, false otherwise
     */
    public function allowsTabFocus():Bool;

    /**
     * Called when this element receives focus through Tab navigation.
     * 
     * Implementations should set the appropriate focus state, update visual
     * appearance, and perform any other actions needed when the element
     * becomes focused. This typically includes setting screen.focusedVisual.
     */
    public function tabFocus():Void;

    /**
     * Called when the Escape key is pressed while this element has focus.
     * 
     * Implementations can use this to provide escape behavior such as
     * closing dropdowns, canceling edits, or removing focus. The behavior
     * is element-specific and should match user expectations for the
     * particular UI component.
     */
    public function escapeTabFocus():Void;

}
