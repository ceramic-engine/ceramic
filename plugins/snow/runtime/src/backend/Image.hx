package backend;

/** Encapsulate an image as a whole. Can have different states: only in-memory pixels, only texture, both...
    Should also take care of restoring gpu texture if needed from the in-memory pixels etc...
    The idea is that the backend is responsible of differenciating these different states of an image (in cpu / in gpu)
    but that these specifics should not be exposed to standard ceramic API. On high-level ceramic, we load and manipulate images.
    That's it. */
abstract Image(ImageImpl) from ImageImpl to ImageImpl {}
