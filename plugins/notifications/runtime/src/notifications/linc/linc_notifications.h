// System notifications of the Ceramic notifications plugin (native targets).
//
// One API for every native platform, implemented by
// linc_notifications_apple.mm (macOS, later iOS), linc_notifications_linux.cpp
// (freedesktop notifications over DBus, libdbus loaded at run time) and
// linc_notifications_windows.cpp (WinRT toasts, untested). Every function is
// called from the main thread. What the platform delivers (responses,
// authorization answers), possibly from another thread, goes to a queue
// (linc_notifications_common.cpp) that the Haxe side reads each frame with
// nextEvent().

#pragma once

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include <string>

namespace linc {
    namespace notifications {

        // Authorization values (ceramic.NotificationAuthorization)
        enum {
            AUTHORIZATION_UNAVAILABLE = 0,
            AUTHORIZATION_NOT_DETERMINED = 1,
            AUTHORIZATION_DENIED = 2,
            AUTHORIZATION_AUTHORIZED = 3
        };

        // Event kinds returned by nextEvent()
        enum {
            EVENT_NONE = 0,
            EVENT_RESPONSE = 1,
            EVENT_AUTHORIZATION_READ = 2,
            EVENT_AUTHORIZATION_REQUESTED = 3
        };

        // Platform implementation

        bool available();
        void setAppIdentity(::String identifier, ::String name);
        bool start();
        void readAuthorization();
        void requestAuthorization();
        void show(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels);
        void dismiss(::String tag);
        void poll();

        // Test helpers: never post anything nor ask the user
        ::String describe();
        ::String describeRequest(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels);
        ::String describeCategories(int timeoutMs);
        int readAuthorizationNow(int timeoutMs);
        // Queues a response like the platform does (tests): actionId null for the body
        void simulateResponse(::String tag, ::String actionId);

        // Event queue (linc_notifications_common.cpp)

        int nextEvent();
        ::String eventTag();
        ::String eventActionId();
        int eventAuthorization();

        // Called by the platform implementations, from any thread
        void pushResponse(const std::string &tag, const std::string *actionId);
        void pushAuthorization(int authorization, bool requested);

        // Helpers
        std::string toStdString(::String value);
        ::String fromStdString(const std::string &value);

    }
}
