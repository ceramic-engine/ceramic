//hxcpp include should be first
#include <hxcpp.h>

#include "./linc_ceramic.h"
#include <ctime>
#include <fstream>

#ifdef _WIN32
#include <sys/utime.h>
#else
#include <utime.h>
#endif

#include <sys/stat.h>
#include <string>

#ifdef _WIN32
#include <windows.h>
#elif __APPLE__
#include <mach-o/dyld.h>
#include <limits.h>
#else  // Linux
#include <unistd.h>
#include <limits.h>
#endif

namespace linc {

    namespace ceramic {

        void file_utime( ::String path, double mtime) {

            const char* cpath = path.c_str();

            struct utimbuf new_times;
            new_times.actime = static_cast<time_t>(mtime / 1000);  // access time
            new_times.modtime = static_cast<time_t>(mtime / 1000); // modification time

            utime(cpath, &new_times);

        }

        void file_utime_now(::String path) {

           const char* cpath = path.c_str();
           utime(cpath, nullptr); // nullptr means "use current time"

        }

        ::String executable_path() {
            #ifdef _WIN32
                char path[MAX_PATH] = { 0 };
                GetModuleFileNameA(NULL, path, MAX_PATH);
                return ::String(path);

            #elif __APPLE__
                char path[PATH_MAX];
                uint32_t size = sizeof(path);
                if (_NSGetExecutablePath(path, &size) == 0) {
                    char real_path[PATH_MAX];
                    if (realpath(path, real_path) != NULL) {
                        return ::String(real_path);
                    }
                }
                return null();

            #else  // Linux
                char path[PATH_MAX];
                ssize_t count = readlink("/proc/self/exe", path, PATH_MAX);
                if (count != -1) {
                    path[count] = '\0';
                    return ::String(path);
                }
                return null();
            #endif
        }

    }

}
