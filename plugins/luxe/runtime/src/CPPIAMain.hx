package;

class CPPIAMain {

#if cppia

    public static var project:Project;

    public static function main():Void {
        
        project = @:privateAccess new Project(ceramic.App.app.initSettings);

    }

#end

}