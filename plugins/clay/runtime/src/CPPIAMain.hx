package;

/**
 * Entry point of the cppia module holding the project code, when the app
 * is split between a native host (ceramic runtime + clay backend) and a
 * cppia client rebuilt in seconds for fast iteration.
 *
 * The host boots the module after `ceramic.App.init()`: constructing
 * `Project` here plays the role that `new Project(settings)` plays in
 * `backend.Main` for a regular monolithic build.
 */
class CPPIAMain {

    #if cppia

    public static var project:Project = null;

    public static function main():Void {

        project = @:privateAccess new Project(@:privateAccess ceramic.App.app.initSettings);

    }

    #end

}
