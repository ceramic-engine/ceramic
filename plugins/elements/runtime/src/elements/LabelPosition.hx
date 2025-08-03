package elements;

/**
 * Enumeration defining the position of a label relative to its associated view.
 * 
 * Used by LabeledView and other UI components to control the spatial relationship
 * between labels and their corresponding input fields or views.
 * 
 * Values:
 * - LEFT: Label appears to the left of the view
 * - RIGHT: Label appears to the right of the view
 * 
 * Example usage:
 * ```haxe
 * var labeledField = new LabeledView(textField);
 * labeledField.labelPosition = LEFT;  // Label on the left side
 * labeledField.labelPosition = RIGHT; // Label on the right side
 * ```
 * 
 * @see LabeledView
 */
enum abstract LabelPosition(Int) from Int to Int {

    /** Label positioned to the left of the view */
    var LEFT;

    /** Label positioned to the right of the view */
    var RIGHT;

}