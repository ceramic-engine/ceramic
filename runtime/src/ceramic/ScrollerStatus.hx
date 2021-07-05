package ceramic;

enum ScrollerStatus {

    /**
     * Nothing happening
     */
    IDLE;

    /**
     * Being touched, but not dragging yet
     */
    TOUCHING;

    /**
     * Being dragged by a touch/mouse event
     */
    DRAGGING;

    /**
     * Scrolling after dragging has ended
     */
    SCROLLING;

}
