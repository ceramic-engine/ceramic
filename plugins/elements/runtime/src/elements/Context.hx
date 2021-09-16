package elements;

import ceramic.Assert.assert;
import ceramic.Entity;
import ceramic.ReadOnlyMap;
import ceramic.View;
import tracker.Model;
import tracker.Observable;

using tracker.SaveModel;

@:allow(elements.Im)
@:allow(elements.ImSystem)
class Context extends Entity implements Observable {

    @lazy public static var context = new Context();

    @observe public var theme = new Theme();

    public var user = new UserData();

    public var windowsData(get,never):ReadOnlyMap<String,WindowData>;
    inline function get_windowsData():ReadOnlyMap<String,WindowData> {
        return user.windowsData;
    }

    public var view(default, null):View = null;

    public var focusedWindow(default, null):Window = null;

    private function new() {

        super();

        user.loadFromKey('elements-context', true);
        user.autoSaveAsKey('elements-context');

    }

/// Helpers

    public function addWindowData(windowData:WindowData):Void {

        assert(windowData != null, 'Cannot add null window data');
        assert(windowData.id != null, 'Cannot add window data with null id');

        windowsData.original.set(windowData.id, windowData);
        user.dirty = true;

    }

}