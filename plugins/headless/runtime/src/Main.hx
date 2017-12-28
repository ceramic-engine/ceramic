package;

class Main {

    public static var project:Project = null;

    public static function main() {

        project = @:privateAccess new Project(ceramic.App.init());

    } //main

} //Main
