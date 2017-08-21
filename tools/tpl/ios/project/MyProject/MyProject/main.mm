/*
 *  Main.mm
 *
 *  Boot code for lime.
 *
 */

#include <stdio.h>

extern "C" const char *hxRunLibrary();
extern "C" void hxcpp_set_top_of_stack();
extern "C" int std_register_prims();
extern "C" int regexp_register_prims();
extern "C" int lime_legacy_register_prims();

extern "C" int main(int argc, char *argv[])
{
    hxcpp_set_top_of_stack();
    std_register_prims();
    regexp_register_prims();
    lime_legacy_register_prims();
    
    const char *err = NULL;
    err = hxRunLibrary();
    if (err) {
        printf(" Error %s\n", err );
        return -1;
    }
    
    return 0;
}
