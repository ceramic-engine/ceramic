#include <hxcpp.h>
#include "linc_NativeWindows.h"

#include <Windows.h>
#include <ShellScalingAPI.h>
#include <comdef.h>

// Link with SetupAPI.Lib.
#pragma comment (lib, "SetupAPI.lib")

// Link with Shcore.lib.
#pragma comment (lib, "Shcore.lib")

namespace backend {

    void NativeWindows_init() {

        // Enable HiDPI screen
        HRESULT hr = SetProcessDpiAwareness(PROCESS_PER_MONITOR_DPI_AWARE);
        if (FAILED(hr))
        {
            _com_error err(hr);
            fwprintf(stderr, L"SetProcessDpiAwareness: %s\n", err.ErrorMessage());
        }

    }

}

