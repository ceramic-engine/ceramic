package elements;

using ceramic.Extensions;

/**
 * A container that groups multiple labeled field views in a horizontal layout.
 * 
 * This view is designed to organize related fields together, managing their
 * layout and providing consistent label widths across the group. It's particularly
 * useful for creating forms with multiple related inputs on the same line.
 * 
 * ## Type Parameters
 * 
 * - `T`: The type of labeled field views (must extend LabeledFieldView)
 * - `U`: The underlying field view type
 * 
 * ## Features
 * 
 * - Automatic layout management for grouped fields
 * - Consistent label width distribution
 * - Disabled state synchronization
 * - Responsive width allocation
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Create a group of coordinate fields
 * var xField = new LabeledFieldView(new TextFieldView(), "X:");
 * var yField = new LabeledFieldView(new TextFieldView(), "Y:");
 * var zField = new LabeledFieldView(new TextFieldView(), "Z:");
 * 
 * var coordGroup = new LabeledFieldGroupView([xField, yField, zField]);
 * coordGroup.label = "Position";
 * ```
 * 
 * @see LabeledFieldView
 * @see FieldView
 */
class LabeledFieldGroupView<T:LabeledFieldView<U>,U:FieldView> extends LinearLayout implements Observable {

/// Public properties

    /**
     * The label text for the entire field group.
     * Can be used to describe the purpose of the grouped fields.
     */
    @observe public var label:String = '';

    /**
     * Whether all fields in the group are disabled.
     * Automatically computed based on individual field states.
     */
    @observe public var disabled:Bool = false;

    /**
     * The array of labeled field views in this group.
     * Setting this property triggers layout recalculation.
     */
    public var fields(default,set):Array<T>;
    function set_fields(fields:Array<T>):Array<T> {
        this.fields = fields;
        invalidateDisabled();
        return fields;
    }

/// Lifecycle

    /**
     * Creates a new labeled field group view.
     * @param fields Array of labeled field views to group together
     */
    public function new(fields:Array<T>) {

        super();

        direction = HORIZONTAL;
        itemSpacing = 8;
        //padding(4, 4);

        this.fields = fields;
        //app.onceUpdate(this, _ -> {
            for (i in 0...fields.length) {
                var field = fields[i];
                field.viewSize(fill(), auto());
                add(field);
            }
        //});

        viewSize(fill(), auto());

        autorun(updateDisabled);
        autorun(updateStyle);

    }

/// Internal

    /**
     * Performs custom layout to ensure consistent label widths across fields.
     * The first field gets a different label width than subsequent fields
     * to maintain visual alignment.
     */
    override function layout() {

        if (fields.length > 0) {

            final labelWidth1 = 75;
            final labelWidth2 = 75;

            var itemWidth = ((width - paddingLeft - paddingRight - labelWidth1 + labelWidth2 - 8 * (fields.length - 1)) / fields.length);

            for (i in 0...fields.length) {
                var field = fields[i];
                if (i == 0) {
                    field.labelViewWidth = labelWidth1;
                    field.viewSize(itemWidth + labelWidth1 - labelWidth2, auto());
                }
                else {
                    field.labelViewWidth = labelWidth2;
                    field.viewSize(itemWidth, auto());
                }
            }
        }

        super.layout();

    }

    /**
     * Updates the disabled state by checking all child fields.
     * The group is considered disabled only if all fields are disabled.
     */
    function updateDisabled() {

        var fields = this.fields;
        var allDisabled = true;
        unobserve();

        for (field in fields) {
            reobserve();
            if (!field.field.getProperty('disabled')) {
                unobserve();
                allDisabled = false;
                break;
            }
            unobserve();
        }

        this.disabled = allDisabled;

        reobserve();

    }

    /**
     * Updates the visual style of the group.
     * Currently commented out but can be used to apply themed styling.
     */
    function updateStyle() {

        /*
        transparent = false;
        color = Color.interpolate(
            theme.mediumBackgroundColor,
            theme.lightBackgroundColor,
            1
        );
        borderColor = theme.mediumBorderColor;
        borderSize = 1;
        borderPosition = INSIDE;
        */

    }

}
