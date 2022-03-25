package elements;

import ceramic.TextView;
import ceramic.View;
import elements.Button;
import elements.SelectListView;

/**
 * Just a draft to create a file picker dialog fully built with elements UI
 */
class FilePickerView extends View {

    var fileNameTextField:TextFieldView;

    var folderHierarchy:SelectListView;

    public function new() {

        super();

        // TODO

        autorun(updateStyle);

    }

    override function layout() {

        // TODO

    }

    function updateStyle() {

        // TODO

    }

}
