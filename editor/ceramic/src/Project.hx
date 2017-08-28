package;

import ceramic.Settings;
import ceramic.Shortcuts.*;

/** Minimal project to bootstrap default ceramic editor canvas. */
class Project {

    function new(settings:InitSettings) {

#if editor

        new editor.Editor(settings);
        app.onceReady(editor.start);
        
#end

    } //new

}
