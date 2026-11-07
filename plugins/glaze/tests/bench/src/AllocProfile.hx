package;

/**
 * Allocation sites of the measured frames, natively, with
 * `ceramic clay build mac --variant allocprof` (hxcpp's telemetry,
 * `HXCPP_TELEMETRY`: every GC allocation is recorded with its type, its size
 * and the Haxe call stack).
 *
 * `start()` before the measured block, `stop(label, frames)` after it: the
 * allocations are grouped by type and allocating function (the innermost
 * Haxe frame) with its two callers, and by allocating function alone, and
 * the report (count and bytes per frame, largest first) is returned as text.
 * Boxed Int, Float and Bool values show as `_non_class`, arrays and their
 * buffers as `Array`, strings as `String`, local functions under their
 * closure class.
 *
 * It is a diagnostic: telemetry slows every allocation down a lot and its
 * numbers say where and how much, not how long.
 */
#if (cpp && HXCPP_TELEMETRY)
@:cppFileCode('
#include <hx/Telemetry.h>
#include <map>
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>

namespace {
struct GpuiAllocStat { double count; double bytes; };

// Names and stacks come in pieces (each stash holds the new ones only) but
// their ids are global: keep them all
static std::vector<const char*> gpuiAllocNames;
static std::vector<int> gpuiAllocStacks;

static std::string gpuiAllocReport(int thread, bool report, int frames, int top)
{
    TelemetryFrame *frame = __hxcpp_hxt_dump_telemetry(thread);
    std::ostringstream out;
    if (frame == 0 || frame->allocation_data == 0 || frame->stacks == 0 || frame->names == 0) {
        out << "no telemetry data\\n";
        return out.str();
    }
    gpuiAllocNames.insert(gpuiAllocNames.end(), frame->names->begin(), frame->names->end());
    gpuiAllocStacks.insert(gpuiAllocStacks.end(), frame->stacks->begin(), frame->stacks->end());
    if (!report) return out.str();
    std::vector<const char*> &names = gpuiAllocNames;
    auto name = [&](int idx) -> std::string {
        if (idx >= 1 && idx - 1 < (int)names.size()) return std::string(names[idx - 1]);
        return std::string("?");
    };
    // Stacks: [size, leaf, caller, ..., root] one after the other, by id
    std::vector<int> stackStart;
    std::vector<int> &stacks = gpuiAllocStacks;
    for (size_t i = 0; i < stacks.size(); ) {
        stackStart.push_back((int)i);
        i += 1 + stacks[i];
    }
    std::map<std::string, GpuiAllocStat> bySite;
    std::map<std::string, GpuiAllocStat> byFunction;
    std::map<std::string, GpuiAllocStat> byType;
    double totalCount = 0, totalBytes = 0;
    std::vector<int> &data = *frame->allocation_data;
    for (size_t i = 0; i < data.size(); ) {
        int flag = data[i];
        if (flag == 0) {
            int type = data[i + 2];
            int size = data[i + 3];
            int stackId = data[i + 4];
            i += 5;
            std::string leaf = "?", caller1 = "", caller2 = "";
            if (stackId >= 0 && stackId < (int)stackStart.size()) {
                int s = stackStart[stackId];
                int depth = stacks[s];
                if (depth > 0) leaf = name(stacks[s + 1]);
                if (depth > 1) caller1 = name(stacks[s + 2]);
                if (depth > 2) caller2 = name(stacks[s + 3]);
            }
            std::string typeName = name(type);
            std::string site = typeName + " @ " + leaf + " < " + caller1 + " < " + caller2;
            GpuiAllocStat &a = bySite[site]; a.count += 1; a.bytes += size;
            GpuiAllocStat &b = byFunction[leaf]; b.count += 1; b.bytes += size;
            GpuiAllocStat &c = byType[typeName]; c.count += 1; c.bytes += size;
            totalCount += 1; totalBytes += size;
        }
        else if (flag == 1) i += 2;
        else if (flag == 2) i += 4;
        else break;
    }
    auto print = [&](const char *title, std::map<std::string, GpuiAllocStat> &stats, int limit) {
        std::vector<std::pair<std::string, GpuiAllocStat>> list(stats.begin(), stats.end());
        std::sort(list.begin(), list.end(), [](const std::pair<std::string, GpuiAllocStat> &x, const std::pair<std::string, GpuiAllocStat> &y) {
            return x.second.count > y.second.count;
        });
        out << "## " << title << " (count per frame, bytes per frame)\\n";
        int n = 0;
        for (auto &e : list) {
            if (n++ >= limit) break;
            char line[64];
            snprintf(line, sizeof(line), "%10.1f %12.0f  ", e.second.count / frames, e.second.bytes / frames);
            out << line << e.first << "\\n";
        }
        out << "\\n";
    };
    char head[160];
    snprintf(head, sizeof(head), "allocations per frame: %.1f objects, %.0f bytes (%d frames)\\n\\n", totalCount / frames, totalBytes / frames, frames);
    out << head;
    print("by type", byType, 40);
    print("by allocating function", byFunction, top);
    print("by site (type @ function < caller < caller)", bySite, top);
    return out.str();
}
}
')
#end
class AllocProfile {

    static var thread:Int = -1;

    /**
     * Starts recording the allocations of the current (main) thread. The
     * telemetry is created once and only paused between blocks: deleting it
     * would leave its live objects pointing at it.
     */
    public static function start():Void {
        #if (cpp && HXCPP_TELEMETRY)
        if (thread < 0) {
            thread = untyped __cpp__('__hxcpp_hxt_start_telemetry(true, true)');
        }
        else {
            // Drop what was recorded since the last block (collections only)
            untyped __cpp__('__hxcpp_hxt_stash_telemetry()');
            untyped __cpp__('gpuiAllocReport({0}, false, 1, 0)', thread);
            untyped __cpp__('__hxcpp_hxt_ignore_allocs(-1)');
        }
        #end
    }

    /**
     * Stops recording and returns the report of the block (`frames` frames,
     * `top` lines per table).
     */
    public static function stop(frames:Int, top:Int):Null<String> {
        #if (cpp && HXCPP_TELEMETRY)
        untyped __cpp__('__hxcpp_hxt_ignore_allocs(1)');
        untyped __cpp__('__hxcpp_hxt_stash_telemetry()');
        final report:String = untyped __cpp__('::String(gpuiAllocReport({0}, true, {1}, {2}).c_str())', thread, frames, top);
        return report;
        #else
        return null;
        #end
    }

}
