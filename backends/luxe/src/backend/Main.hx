package backend;

class Main implements spec.Main extends luxe.Game {

    override function config(config:luxe.GameConfig) {

        // Call Main.main()
        @:privateAccess Main_call.main();

        var app = ceramic.App.app;

        // Configure luxe
        config.window.borderless = false;
        config.window.width = cast app.settings.width;
        config.window.height = cast app.settings.height;
        config.window.resizable = false;
        config.window.title = cast app.settings.title;

        return config;

    } //config

}