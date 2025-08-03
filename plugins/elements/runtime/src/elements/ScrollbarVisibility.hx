package elements;

/**
 * Enumeration defining different scrollbar visibility behaviors for scrollable containers.
 * 
 * This enum controls how and when scrollbars appear in scrolling layouts, providing
 * different strategies for managing the trade-off between visual space and scroll
 * functionality feedback.
 * 
 * Usage example:
 * ```haxe
 * var scrollView = new ScrollView();
 * scrollView.scrollbarVisibility = ScrollbarVisibility.AUTO_SHOW;
 * ```
 */
enum abstract ScrollbarVisibility(Int) {

    /**
     * Dynamically adds a scrollbar only when content exceeds container height.
     * 
     * When the scrollbar is not present, content uses the full available width
     * including the space normally reserved for the scrollbar. This maximizes
     * content area but may cause layout shifts when scrollbars appear/disappear.
     * 
     * Best for: Content that rarely needs scrolling
     */
    var AUTO_ADD = 0;

    /**
     * Like AUTO_ADD, but once added, the scrollbar persists until container resizes.
     * 
     * When content initially requires scrolling, the scrollbar appears and remains
     * visible even if content later shrinks to fit. This prevents oscillating
     * scrollbar visibility when content height fluctuates frequently, providing
     * stable layout at the cost of some visual space.
     * 
     * The scrollbar only disappears if the container itself grows large enough
     * to accommodate the current content without scrolling.
     * 
     * Best for: Dynamic content with frequently changing heights
     */
    var AUTO_ADD_STAY = 1;

    /**
     * Shows/hides scrollbar based on content overflow, but always reserves space.
     * 
     * Content width remains constant regardless of scrollbar visibility because
     * the scrollbar space is always reserved. When not needed, the scrollbar
     * is hidden (visibility = false) rather than removed from layout.
     * 
     * This prevents layout shifts while providing visual feedback only when needed.
     * 
     * Best for: Stable layouts where content width consistency is important
     */
    var AUTO_SHOW = 2;

    /**
     * Scrollbar is always present and visible regardless of content size.
     * 
     * Provides consistent visual indication of scroll capability and stable
     * layout dimensions. The scrollbar may be inactive when content fits
     * within the container.
     * 
     * Best for: Fixed-height containers where scroll indication is always desired
     */
    var ALWAYS = 3;

    /**
     * No scrollbar is ever displayed, regardless of content overflow.
     * 
     * Content may still be scrollable through other means (touch, mouse wheel),
     * but no visual scrollbar indicator is provided. This maximizes content
     * area but provides no visual feedback about scroll state.
     * 
     * Best for: Touch interfaces or minimal designs where scrollbars are undesired
     */
    var NEVER = -1;

}