#pragma once

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

namespace linc {

    namespace ceramic {

        extern void file_utime( ::String path, double mtime);

        extern void file_utime_now( ::String path);

        extern ::String executable_path();

    }

}
