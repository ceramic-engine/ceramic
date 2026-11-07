#include <stdio.h>
#define MAX(a, b) ((a) > (b) ? (a) : (b))

/* Block comment */
typedef struct Point { int x; int y; } Point;

static const char *name = "demo\n";

int main(int argc, char **argv) {
    unsigned long total = 0;
    for (int i = 0; i < argc; i++) {
        total += MAX(i, 3) * 0x1F;
    }
    printf("%lu %s\n", total, name); // done
    return 0;
}
