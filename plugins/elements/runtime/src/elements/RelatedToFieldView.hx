package elements;

/**
 * Interface for views that are related to or associated with a FieldView.
 * 
 * This interface allows views to declare their relationship to a specific
 * FieldView, enabling coordinated behavior, focus management, and event
 * handling between related UI components.
 * 
 * Common use cases include:
 * - Buttons or icons that should trigger actions on a related field
 * - Labels that should focus their associated input field when clicked
 * - Validation indicators that show the status of a specific field
 * - Popup menus or dropdowns that are bound to a particular field
 * 
 * Example implementation:
 * ```haxe
 * class MyButton extends Button implements RelatedToFieldView {
 *     var field:FieldView;
 *     
 *     public function new(field:FieldView) {
 *         super();
 *         this.field = field;
 *     }
 *     
 *     public function relatedFieldView():FieldView {
 *         return field;
 *     }
 * }
 * ```
 * 
 * @see FieldView
 * @see LabeledView
 */
interface RelatedToFieldView {

    /**
     * Returns the FieldView that this view is related to.
     * 
     * This method should return the specific FieldView instance that this
     * view is associated with for coordination of behavior, focus management,
     * or other interactive features.
     * 
     * @return The related FieldView instance
     */
    public function relatedFieldView():FieldView;

}