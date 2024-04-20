package elements;

enum abstract ScrollbarVisibility(Int) {

    /**
     * Adds a scrollbar only if the content is higher than the container.
     * When the scrollbar is not there, it give a bit more width to
     * the content as the space for the scrollbar is free.
     */
    var AUTO_ADD = 0;

    /**
     * Show a scrollbar only if the content is higher than the container.
     * When the scrollbar is not visible, the content doesn't have more
     * width than when the scrollbar is visible. The extra width is always
     * reserved for the scrollbar, which is only hidden in the hierarchy
     * as needed, not really removed entirely.
     */
    var AUTO_SHOW = 1;

    /**
     * The scrollbar is always included and visible, given that the container
     * has a fixed height.
     */
    var ALWAYS = 2;

    /**
     * There is never a scrollbar
     */
    var NEVER = -1;

}