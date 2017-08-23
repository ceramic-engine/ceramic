package spec;

/** Various backend informations.
    Important: implementstions can be instanciated both at runtime and at compile time. */
interface Info {

/// Assets

    function imageExtensions():Array<String>;

    function textExtensions():Array<String>;

    function soundExtensions():Array<String>;

} //Info
