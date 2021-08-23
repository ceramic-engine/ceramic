package elements;

using ceramic.Extensions;

class LabeledFieldGroupView<T:LabeledFieldView<U>,U:FieldView> extends LinearLayout implements Observable {

/// Public properties

    @observe public var label:String = '';

    @observe public var disabled:Bool = false;

    public var fields(default,set):Array<T>;
    function set_fields(fields:Array<T>):Array<T> {
        this.fields = fields;
        invalidateDisabled();
        return fields;
    }

/// Lifecycle

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
