package;

import ceramic.App;

class Main extends ceramic.Main {

    public static function main() {

        App.init({
            antialiasing: true,
            background: ceramic.Color.CYAN,
            width: 320,
            height: 568,
            scaling: FILL
        },
        function(app) {

            trace("APP READY");

        });

    } //main

} //Main
