package elements;

import ceramic.Click;
import ceramic.RowLayout;
import ceramic.TextView;
import ceramic.View;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.Extensions;

/**
 * A container that pairs a text label with any view, providing flexible label positioning.
 * 
 * LabeledView creates a horizontal layout containing a text label and a generic view of type T.
 * The label can be positioned either to the left or right of the view, and the label's
 * width can be customized. When the label is clicked, it automatically focuses the contained
 * view if it's a FieldView.
 * 
 * Features:
 * - Generic type parameter allows any view type
 * - Configurable label positioning (LEFT or RIGHT)
 * - Adjustable label width
 * - Automatic focus delegation from label to view
 * - Theme integration for consistent styling
 * - Optional container wrapper for complex layouts
 * - Automatic disabled state synchronization
 * 
 * Example usage:
 * ```haxe
 * var textField = new TextFieldView();
 * var labeledField = new LabeledView(textField);
 * labeledField.label = "Name:";
 * labeledField.labelPosition = LEFT;
 * labeledField.labelWidth = 100;
 * ```
 * 
 * @param T The type of view to be labeled (must extend View)
 * @see LabelPosition
 * @see FieldView
 */
class LabeledView<T:View> extends RowLayout implements Observable {

    /** Custom theme override for this labeled view */
    @observe public var theme:Theme = null;

/// Public properties

    /** The text content displayed in the label */
    @observe public var label:String = '';

    /** Whether the labeled view is disabled (automatically synced with contained view) */
    @observe public var disabled:Bool = false;

    /** Optional container view for more complex layouts */
    var containerView:RowLayout;

    /** Whether to use a container wrapper around the main view */
    var useContainer:Bool = false;

    /** The main view being labeled */
    public var view(default,set):T;
    /**
     * Sets the main view to be labeled.
     * 
     * When a new view is assigned:
     * - The previous view is destroyed if it exists
     * - The new view is added to either the container or directly to this layout
     * - The disabled state is updated
     * - The label text is repositioned to maintain proper order
     * 
     * @param view The view to be labeled
     * @return The assigned view
     */
    function set_view(view:T):T {
        if (this.view == view)
            return view;
        if (this.view != null) {
            this.view.destroy();
        }
        this.view = view;
        if (view != null) {
            if (useContainer) {
                containerView.add(view);
            }
            else {
                add(view);
            }
            invalidateDisabled();
        }
        remove(labelText);
        add(labelText);
        return view;
    }

    /** The position of the label relative to the view (LEFT or RIGHT) */
    public var labelPosition(default,set):LabelPosition = RIGHT;
    /**
     * Sets the label position relative to the view.
     * 
     * Repositions the label and view elements in the layout and adjusts
     * their alignment properties accordingly:
     * - LEFT: Label appears before the view, aligned to the right
     * - RIGHT: Label appears after the view, aligned to the left
     * 
     * @param labelPosition The new position for the label
     * @return The assigned label position
     */
    function set_labelPosition(labelPosition:LabelPosition):LabelPosition {
        if (this.labelPosition != labelPosition) {
            this.labelPosition = labelPosition;
            switch labelPosition {
                case LEFT:
                    remove(labelText);
                    remove(useContainer ? containerView : view);
                    add(labelText);
                    add(useContainer ? containerView : view);
                    if (containerView != null)
                        containerView.align = LEFT;
                    labelText.align = RIGHT;
                case RIGHT:
                    remove(labelText);
                    add(labelText);
                    if (containerView != null)
                        containerView.align = RIGHT;
                    labelText.align = LEFT;
            }
        }
        return labelPosition;
    }

    /** The fixed width of the label (default: 70) */
    public var labelWidth(default,set):Float = 70;
    /**
     * Sets the fixed width of the label.
     * 
     * @param labelWidth The new width for the label
     * @return The assigned width
     */
    function set_labelWidth(labelWidth:Float):Float {
        if (this.labelWidth != labelWidth) {
            this.labelWidth = labelWidth;
            labelText.viewWidth = labelWidth;
        }
        return labelWidth;
    }

    /** Direct access to the label's view width (convenience property) */
    public var labelViewWidth(get, set):Float;
    
    /**
     * Gets the current width of the label view.
     * 
     * @return The current width of the label
     */
    function get_labelViewWidth():Float {
        return labelText.viewWidth;
    }
    
    /**
     * Sets the width of the label view directly.
     * 
     * @param labelViewWidth The new width for the label view
     * @return The assigned width
     */
    function set_labelViewWidth(labelViewWidth:Float):Float {
        return labelText.viewWidth = labelViewWidth;
    }

/// Internal properties

    /** Internal TextView instance that displays the label text */
    var labelText:TextView;

/// Lifecycle

    /**
     * Creates a new LabeledView instance.
     * 
     * Initializes the layout with a text label and the provided view. Sets up
     * automatic styling updates, focus delegation, and proper positioning.
     * 
     * @param view The view to be labeled
     * @param useContainer Whether to wrap the view in a container (default: false)
     */
    public function new(view:T, useContainer:Bool = false) {

        super();

        itemSpacing = 6;

        labelText = new TextView();
        labelText.viewSize(labelWidth, auto());
        labelText.align = LEFT;
        labelText.verticalAlign = CENTER;
        labelText.pointSize = 12;
        labelText.preRenderedSize = 20;
        add(labelText);

        this.useContainer = useContainer;
        if (useContainer) {
            containerView = new RowLayout();
            containerView.transparent = true;
            containerView.viewSize(fill(), auto());
            containerView.align = RIGHT;
            add(containerView);
        }

        this.view = view;

        autorun(updateDisabled);
        autorun(updateLabel);
        autorun(updateStyle);

        // Focus view on label click
        #if !(ios || android)
        labelText.onPointerDown(this, _ -> handleLabelClick());
        #else
        var labelClick = new Click();
        labelText.component(labelClick);
        labelClick.onClick(this, handleLabelClick);
        #end

    }

/// Internal

    /**
     * Handles click events on the label text.
     * 
     * When the label is clicked and the view is not disabled,
     * automatically focuses the contained view if it's a FieldView.
     * This provides intuitive interaction where clicking the label
     * activates the associated input field.
     */
    function handleLabelClick() {

        if (!disabled) {
            if (view is FieldView) {
                var field:FieldView = cast view;
                field.focus();
            }
        }

    }

    /**
     * Updates the label text content.
     * 
     * This method is called automatically when the label property changes
     * to synchronize the displayed text with the current label value.
     */
    function updateLabel() {

        labelText.content = label;

    }

    /**
     * Updates the disabled state by checking the contained view.
     * 
     * Automatically synchronizes the disabled state of this labeled view
     * with the disabled state of the contained view. If the view has a
     * 'disabled' property that is true, this labeled view becomes disabled.
     * Uses unobserve/reobserve to prevent observation cycles.
     */
    function updateDisabled() {

        var view = this.view;
        unobserve();

        if (view != null) {
            var disabled = false;
            reobserve();
            if (view.getProperty('disabled')) {
                disabled = true;
            }
            unobserve();
            this.disabled = disabled;
        }
        else {
            this.disabled = false;
        }

        reobserve();

    }

    /**
     * Updates the visual styling of the label based on theme and state.
     * 
     * Applies the appropriate text color and font from the current theme:
     * - Uses darkTextColor when disabled, lightTextColor when enabled
     * - Always uses the medium font from the theme
     * Falls back to the global context theme if no custom theme is set.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (disabled) {
            labelText.textColor = theme.darkTextColor;
        }
        else {
            labelText.textColor = theme.lightTextColor;
        }

        labelText.font = theme.mediumFont;

    }

}
