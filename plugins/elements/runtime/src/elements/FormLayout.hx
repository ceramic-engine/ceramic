package elements;

import ceramic.ColumnLayout;
import elements.FieldsTabFocus;
import elements.Context.context;

class FormLayout extends ColumnLayout {

/// Lifecycle

    public function new() {

        super();

        itemSpacing = 4;
        transparent = false;

        component(new FieldsTabFocus());

        padding(10, 10);

        autorun(updateStyle);

    }

/// Internal

    function updateStyle() {

        var theme = context.theme;

        color = theme.mediumBackgroundColor;

    }

}
