package elements;

import ceramic.Entity;
import ceramic.ReadOnlyMap;
import ceramic.View;
import tracker.Observable;

@:allow(elements.Im)
@:allow(elements.ImSystem)
class Context extends Entity implements Observable {

    @lazy public static var context = new Context();

    @observe public var theme = new Theme();

    @observe public var user = new UserData();

    public var view(default, null):View = null;

    private function new() {

        super();

    }

/// Helpers

}