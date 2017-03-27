package;

import ceramic.App;

class Main extends ceramic.Main implements ceramic.Shortcuts {

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

            var quad = new ceramic.Quad();

            quad.background = ceramic.Color.RED;
            quad.size(80, 100);
            quad.anchor(0.5, 0.5);
            quad.pos(320 * 0.5, 568 * 0.5);

            trace(quad);

        });

    } //main

} //Main
