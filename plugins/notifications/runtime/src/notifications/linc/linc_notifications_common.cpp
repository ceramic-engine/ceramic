// Event queue shared by the native implementations of system notifications:
// the platform pushes responses and authorization answers from any thread,
// the Haxe side pops them on the main thread at the start of a frame.

#include "linc_notifications.h"

#include <deque>
#include <mutex>

namespace linc {
    namespace notifications {

        struct Event {
            int kind;
            std::string tag;
            bool hasActionId;
            std::string actionId;
            int authorization;
        };

        static std::mutex _queueMutex;
        static std::deque<Event> _queue;
        static Event _current = { EVENT_NONE, "", false, "", 0 };

        void pushResponse(const std::string &tag, const std::string *actionId) {
            Event event;
            event.kind = EVENT_RESPONSE;
            event.tag = tag;
            event.hasActionId = actionId != NULL;
            event.actionId = actionId != NULL ? *actionId : std::string();
            event.authorization = 0;
            std::lock_guard<std::mutex> lock(_queueMutex);
            _queue.push_back(event);
        }

        void pushAuthorization(int authorization, bool requested) {
            Event event;
            event.kind = requested ? EVENT_AUTHORIZATION_REQUESTED : EVENT_AUTHORIZATION_READ;
            event.hasActionId = false;
            event.authorization = authorization;
            std::lock_guard<std::mutex> lock(_queueMutex);
            _queue.push_back(event);
        }

        void simulateResponse(::String tag, ::String actionId) {
            std::string actionValue = toStdString(actionId);
            pushResponse(toStdString(tag), actionId.__s != NULL ? &actionValue : NULL);
        }

        int nextEvent() {
            std::lock_guard<std::mutex> lock(_queueMutex);
            if (_queue.empty()) {
                _current.kind = EVENT_NONE;
                return EVENT_NONE;
            }
            _current = _queue.front();
            _queue.pop_front();
            return _current.kind;
        }

        ::String eventTag() {
            return fromStdString(_current.tag);
        }

        ::String eventActionId() {
            if (!_current.hasActionId) return null();
            return fromStdString(_current.actionId);
        }

        int eventAuthorization() {
            return _current.authorization;
        }

        std::string toStdString(::String value) {
            if (value.__s == NULL) return std::string();
            const char *utf8 = value.utf8_str();
            return utf8 != NULL ? std::string(utf8) : std::string();
        }

        ::String fromStdString(const std::string &value) {
            return ::String::create(value.c_str(), (int)value.size());
        }

    }
}
