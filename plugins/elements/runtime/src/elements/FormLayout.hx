package elements;

import ceramic.ColumnLayout;
import elements.Context.context;
import elements.FieldsTabFocus;

class FormLayout extends ColumnLayout {

/// Lifecycle

    public function new() {

        super();

        transparent = false;

        component(new FieldsTabFocus());

        autorun(updateStyle);

    }

/// Internal

    function updateStyle() {

        var theme = context.theme;

        color = theme.mediumBackgroundColor;
        itemSpacing = theme.formItemSpacing;
        padding(theme.formPadding);

    }

}
