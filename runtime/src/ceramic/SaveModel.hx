package ceramic;

import ceramic.Shortcuts.*;

class SaveModel {

/// Public API

    public static function autoSave(model:Model, key:String, interval:Float = #if debug 10.0 #else 60.0 #end) {

        var serializer = new ModelSerializer();
        serializer.checkInterval = interval;

        // Start listening for changes to save them
        serializer.onChangeset(model, function(changeset) {

            warning('RECEIVE CHANGESET');
            trace(changeset);

        });

        // Assign component
        model.serializer = serializer;

    } //autoSave

} //SaveModel
