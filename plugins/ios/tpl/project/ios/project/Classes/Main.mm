#include <stdio.h>

extern "C" const char *hxRunLibrary();
extern "C" void hxcpp_set_top_of_stack();

extern "C" int SDL_main(int argc, char *argv[]) {

    hxcpp_set_top_of_stack();

    const char *err = NULL;
    err = hxRunLibrary();

    if (err) {
        printf(" Error %s\n", err );
        return -1;
    }

    return 0;
}
