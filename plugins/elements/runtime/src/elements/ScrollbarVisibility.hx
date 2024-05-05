package elements;

enum abstract ScrollbarVisibility(Int) {

    /**
     * Adds a scrollbar only if the content is higher than the container.
     * When the scrollbar is not there, it give a bit more width to
     * the content as the space for the scrollbar is free.
     */
    var AUTO_ADD = 0;

    /**
     * Like `AUTO_ADD`, but when the scrollbar is added, it stays,
     * even if the content fits again within the visible area later.
     * This can be useful to prevent continuous inner width changes
     * and scrollbar appearing and disappearing over and over
     * again when the content height varies many times. The only way to
     * make the scrollbar disappear again would be to increase the
     * height of the window itself so that the current content fits in it.
     */
    var AUTO_ADD_STAY = 1;

    /**
     * Show a scrollbar only if the content is higher than the container.
     * When the scrollbar is not visible, the content doesn't have more
     * width than when the scrollbar is visible. The extra width is always
     * reserved for the scrollbar, which is only hidden in the hierarchy
     * as needed, not really removed entirely.
     */
    var AUTO_SHOW = 2;

    /**
     * The scrollbar is always included and visible, given that the container
     * has a fixed height.
     */
    var ALWAYS = 3;

    /**
     * There is never a scrollbar
     */
    var NEVER = -1;

}