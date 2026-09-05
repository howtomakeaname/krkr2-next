#include "audio/audio_channels.h"
#include "config/ini.h"
#include "pack/pack_manager.h"
#include "script/lua_engine.h"
#include "script/asb_parser.h"
#include "render/compositor.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <cstdlib>
#include <iostream>
#include <map>
#include <thread>

static void Check(bool ok, const char* why) {
    if (!ok) { std::cerr << why << '\n'; std::exit(1); }
}

class Output : public artc::Audio {
public:
    struct Voice { std::string file; int gain, pan = 0; bool playing = true; };
    std::map<std::string, Voice> voices;
    bool Play(const std::string& k, const std::string& f, bool, int g) override {
        if (f == "missing") return false;
        voices[k] = {f, g}; return true;
    }
    void Stop(const std::string& k) override { voices.erase(k); }
    bool IsPlaying(const std::string& k) const override {
        auto v = voices.find(k); return v != voices.end() && v->second.playing;
    }
    void SetVolume(const std::string& k, int gain) override { voices.at(k).gain = gain; }
    void SetPan(const std::string& k, int pan) override { voices.at(k).pan = pan; }
    Voice& File(const std::string& file) {
        for (auto& v : voices) if (v.second.file == file) return v.second;
        std::abort();
    }
};

int main() {
    Output out;
    artc::AudioChannels sounds(out);
    Check(sounds.Play("bgm", "title", true, 800, 0, 0), "play BGM");
    Check(sounds.Play("1", "voice", false, 1000, 0, 0), "play voice");
    Check(sounds.Play("bgm", "story", true, 600, 1000, 0, true), "crossfade BGM");
    sounds.Update(500);
    Check(out.File("title").gain == 400 && out.File("story").gain == 300,
          "crossfade must retain both tracks and interpolate them");
    Check(out.File("voice").gain == 1000, "crossfade must not change voice gain");
    sounds.Update(1000);
    Check(out.voices.size() == 2, "old BGM must retire at fade completion");
    sounds.Stop("1", 0, 1000);
    Check(sounds.IsPlaying("bgm") && !sounds.IsPlaying("1"), "SE stop must isolate channel");
    Check(!sounds.Play("bgm", "missing", true, 1000, 0, 1000, true), "missing BGM fails");
    Check(sounds.IsPlaying("bgm"), "failed replacement must retain current BGM");
    sounds.Fade("bgm", 0, 1000, 1000);
    sounds.Update(1500);
    Check(out.File("story").gain == 300, "gain fade midpoint");
    sounds.Fade("bgm", 900, 1000, 1500);
    sounds.Pan("bgm", -1000, 1000, 1500);
    sounds.Update(2000);
    Check(out.File("story").gain == 600 && out.File("story").pan == -500,
          "retargeting starts from interpolated gain; pan is independent");
    out.File("story").playing = false;
    sounds.Update(2100);
    Check(out.voices.empty() && !sounds.IsPlaying("bgm"), "completed output resources are released");

    artc::Compositor animation;
    animation.BeginTweenSet();
    animation.AddTween("1",{{"param","top"},{"from","0"},{"to","10"},{"time","120"}},0);
    animation.AddTween("1",{{"param","top"},{"from","10"},{"to","5"},{"time","60"}},0);
    animation.AddTween("1",{{"param","top"},{"from","5"},{"to","0"},{"time","60"}},0);
    animation.EndTweenSet(0);
    Check(animation.PendingAnimationMs(0)==240,"nod animation retains all three durations");
    animation.Update(60);
    Check(animation.GetLayerInfo("1").top==5,"nod rises in its first segment");
    animation.Update(150);
    Check(animation.GetLayerInfo("1").top==7.5,"nod executes its middle segment");
    animation.Update(240);
    Check(animation.GetLayerInfo("1").top==0 && animation.PendingAnimationMs(240)==0,
          "nod returns to its original position");
    animation.AddTween("1",{{"param","top"},{"from","0"},{"to","-15"},
                           {"time","100"},{"yoyo","1"}},300);
    animation.Update(400);
    Check(animation.GetLayerInfo("1").top==-15,"yoyo reaches the turning point");
    animation.Update(450);
    Check(animation.GetLayerInfo("1").top==-7.5,"yoyo traverses back");
    animation.Update(500);
    Check(animation.GetLayerInfo("1").top==0,"yoyo finishes at its origin");
    animation.BeginTweenSet();
    animation.AddTween("1",{{"param","left"},{"from","0"},{"to","20"},{"time","100"}},600);
    animation.AddTween("1",{{"param","left"},{"to","40"},{"time","100"}},600);
    animation.AddTween("1",{{"param","top"},{"from","0"},{"to","30"},{"time","100"}},600);
    animation.EndTweenSet(600);
    animation.Update(750);
    Check(animation.GetLayerInfo("1").left==30 && animation.GetLayerInfo("1").top==30,
          "sequences resolve implicit starts after earlier segments; independent properties run together");
    animation.AddTween("2",{{"param","top"},{"from","0"},{"to","20"},
                           {"time","100"},{"loop","-1"}},800);
    animation.Update(1050);
    Check(animation.GetLayerInfo("2").top==10,"infinite loop handles frames spanning several traversals");
    animation.DeleteTweens("2");
    animation.Update(1100);
    Check(animation.PendingAnimationMs(1100)==0,"deleting a loop releases animation wait");

    artc::LuaEngine lua;
    artc::PackManager packs;
    artc::Ini ini;
    Check(lua.Init(&packs, ini, "android", 1280, 720), "initialize Lua");
    lua.PushKeyDown(13);
    Check(lua.DoString("assert(e:isDown(13) and e:isDownEdge(13) and e:isPush(13)); "
        "e:overrideKey{key=13,status=0}; assert(not e:isDown(13)); "
        "e:overrideKey{key=13,status=-1}; assert(e:isDown(13)); "
        "e:overrideKey{status=0}; assert(not e:isDown(13)); "
        "e:overrideKey{key=319,status=32}; assert(e:isDecide(319)); "
        "assert(not e:isDown(319) and not e:isDownEdge(319)); "
        "e:overrideKey{key=13,status=8}; assert(e:isDownEdge(13) and not e:isDown(13)); "
        "e:overrideKey{key=14,status=16}; assert(e:isUpEdge(14)); "
        "e:overrideKey{key=15,status=4}; assert(e:isDown(15) and not e:isPush(15)); "
        "e:overrideKey{key=16,status=2}; assert(e:isPush(16) and not e:isDownEdge(16))",
        "override flags"),"override query bits match the original input API");
    lua.EndFrame();
    Check(lua.DoString("assert(e:isDown(13) and not e:isDownEdge(13)); "
        "assert(not e:isDecide(319) and not e:isUpEdge(14))", "next frame"),
        "frame completion removes overrides and preserves physical held keys");
    lua.PushKeyUp(13);lua.EndFrame();
    lua.DispatchTag("wait", {{"time", "10000"}, {"input", "0"}});
    lua.ClickAt(20, 20); lua.RunEnterFrame();
    Check(lua.IsWaiting(), "mandatory wait must survive pointer input");
    Check(lua.DoString("assert(e:getScriptWaitReason().time)", "wait reason"), "time wait reason");
    lua.SetWaiting(false);
    lua.DispatchTag("wait", {{"time", "10000"}, {"input", "1"}});
    lua.ClickAt(20, 20); lua.RunEnterFrame();
    Check(!lua.IsWaiting(), "skippable timed wait accepts a tap");
    lua.DispatchTag("wait", {{"input", "1"}});
    Check(!lua.IsWaiting(), "input permission without a time/animation must not create a click barrier");
    lua.DispatchTag("wait", {{"input", "1"}, {"time", "0"}});
    Check(!lua.IsWaiting(), "repeated completed waits must fall through");
    lua.DispatchTag("@", {});
    Check(lua.IsWaiting(), "click wait starts");
    Check(lua.DoString("assert(next(e:getScriptWaitReason()) == nil)", "click reason"), "click wait has no timer reason");
    lua.ClickAt(20, 20); lua.RunEnterFrame();
    Check(!lua.IsWaiting(), "click wait ends");

    Check(lua.DoString("function mask(e) e:overrideKey{status=0} end; "
        "e:setEventHandler{onEnterFrame='mask'}", "mask input"),"install frame input filter");
    lua.SetWaiting(true);lua.ClickAt(20,20);lua.RunEnterFrame();
    Check(lua.IsWaiting(),"vsync can suppress a queued tap before it advances the scenario");
    lua.EndFrame();
    Check(lua.DoString("e:tag{'keyconfig',role=0,keys='124'}; "
        "function mask(e) e:overrideKey{status=0}; e:overrideKey{key=124,status=32} end",
        "virtual input"),"configure virtual confirm role");
    lua.RunEnterFrame();
    Check(!lua.IsWaiting(),"a virtual Decide key advances the configured click role");
    lua.EndFrame();
    Check(lua.DoString("e:setEventHandler{onEnterFrame=''}", "remove filter"),"remove frame filter");

    artc::AutoReadTimer reading;
    Check(!reading.Ready(0, 100, true), "voice/text blocks the auto timer");
    Check(!reading.Ready(500, 100, false), "reading interval starts after voice/text");
    Check(!reading.Ready(599, 100, false), "auto respects the configured interval");
    const double elapsed = reading.Elapsed(550);
    reading.Reset(); reading.Restore(2000, elapsed);
    Check(!reading.Ready(2049, 100, false) && reading.Ready(2050, 100, false),
          "menu time does not consume the suspended reading interval");
    Check(!reading.Ready(2060, 100, true) && !reading.Ready(3000, 100, false),
          "a newly synchronized voice resets the reading interval");

    artc::LuaEngine auto_script;
    Check(auto_script.Init(&packs, ini, "android", 1280, 720), "auto engine init");
    Check(auto_script.DoString("auto_out=0; function auto_stop(e,p) auto_out=auto_out+1 end; "
        "e:tag{'setonautomodeout',['function']='auto_stop'}; "
        "e:tag{'automode',allow=0}; e:tag{'exec',command='automode',mode=1}; "
        "assert(e:var('s.status.automode')=='0'); e:tag{'automode',allow=1}; "
        "e:tag{'exec',command='automode',mode=1}; e:tag{'var',name='s.automodewait',data=0}; "
        "assert(e:var('s.status.automode')=='1')", "auto setup"), "auto permission and state");
    auto_script.SetTimedWait(10000);
    Check(auto_script.IsWaiting(), "auto must not bypass a mandatory timer");
    auto_script.SetWaiting(false); auto_script.SetWaiting(true);
    Check(!auto_script.IsWaiting(), "zero-delay auto releases a click wait");
    Check(auto_script.DoString("e:tag{'var',name='s.automodewait',data=10000}", "auto interval"),
          "set reading interval");
    auto_script.SetWaiting(true); auto_script.ClickAt(10,10); auto_script.RunEnterFrame();
    Check(auto_script.IsWaiting(), "first click cancels auto without skipping the page");
    Check(auto_script.DoString("assert(auto_out==1 and e:var('s.status.automode')=='0'); "
        "e:tag{'exec',command='automode',mode=0}; assert(auto_out==1)", "auto stopped"),
        "auto stop callback fires exactly once");
    auto_script.ClickAt(10,10); auto_script.RunEnterFrame();
    Check(!auto_script.IsWaiting(), "next click advances after cancelling auto");

    artc::Compositor compositor;
    compositor.SetProps("500.1", {{"w", "100"}, {"h", "100"}});
    const_cast<artc::Layer&>(compositor.Layers().front()).texture = 1;
    // Separate Lua instance avoids depending on game-global button tables.
    artc::LuaEngine events;
    Check(events.Init(&packs, ini, "android", 1280, 720, &compositor), "event engine init");
    Check(events.DoString("calls=0; function button(e,p) calls=calls+1 end; "
                          "e:setEventFilter(function(e,kind,p) return 1 end); "
                          "e:tag{'lyevent',id='500.1',type='click',handler='calllua',['function']='button'}",
                          "event setup"), "set filtered layer event");
    events.SetWaiting(true);
    events.ClickAt(50,50); events.RunEnterFrame();
    Check(events.IsWaiting(), "filtered button must not release the script wait");
    Check(events.DoString("assert(calls==0); e:setEventFilter(nil)", "filter consumed"), "filter suppresses action");
    events.ClickAt(50,50); events.RunEnterFrame();
    Check(events.DoString("assert(calls==1)", "filter cleared"), "clearing filter restores action exactly once");
    Check(events.IsWaiting(), "button action must not release the scenario wait");
    Check(events.DoString("nested={callbacks={tick=function(e) end}}", "nested callback"), "define dotted callback");
    const int stack_top = lua_gettop(events.state());
    for (int i=0; i<100; ++i) Check(events.CallGlobal("nested.callbacks.tick"), "invoke dotted callback");
    Check(lua_gettop(events.state()) == stack_top, "dotted callbacks must not leak parent tables on the Lua stack");

    // A tiny pack containing only synthetic scripts tests re-entrant native
    // dispatch: the Lua callback replaces the script being executed.
    const std::map<std::string,std::string> files = {
        {"main.iet", "*main\n[calllua function=redirect]\n[calllua function=wrong]\n[stop]\n"},
        {"next.iet", "*next\n[calllua function=right]\n"},
        {"menu.iet", "*menu\n[calllua function=right]\n[return]\n"}
    };
    std::vector<unsigned char> pack;
    auto u32=[&](uint32_t v){ for(int i=0;i<4;++i) pack.push_back((v>>(i*8))&255); };
    uint32_t index=4;
    for(const auto& f:files) index+=16+f.first.size();
    pack.insert(pack.end(),{'p','f','8'});u32(index);u32(files.size());
    uint32_t offset=7+index;
    for(const auto& f:files) {
        u32(f.first.size());pack.insert(pack.end(),f.first.begin(),f.first.end());
        u32(0);u32(offset);u32(f.second.size());offset+=f.second.size();
    }
    for(const auto& f:files) pack.insert(pack.end(),f.second.begin(),f.second.end());
    const auto path=std::filesystem::temp_directory_path()/
        ("artemis-regression-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count())+".pfs");
    { std::ofstream f(path,std::ios::binary); f.write(reinterpret_cast<const char*>(pack.data()),pack.size()); }
    artc::PackManager fixture;
    Check(fixture.OpenChain(path.string(),{0}), "open synthetic script pack");
    artc::AsbRunner runner;runner.SetPackSource(&fixture);
    artc::LuaEngine script;
    Check(script.Init(&fixture,ini,"android",1280,720), "script engine init");
    script.SetJumpHandler([&](const std::string& f,const std::string& l){runner.Jump(f,l);});
    Check(script.DoString("value=0; function redirect(e) e:tag{'jump',file='next.iet',label='next'} end; "
                          "function right(e) value=value+1 end; function wrong(e) error('stale script') end",
                          "script functions"), "script callbacks");
    Check(runner.Jump("main.iet","main"), "load main script");
    for(int i=0;i<8 && !runner.Halted();++i) runner.ExecuteLine(script);
    Check(script.DoString("assert(value==1)","new cursor"), "reentrant jump executes target exactly once");
    Check(runner.Halted(), "end of script halts without an out-of-bounds Current");
    script.SetScriptRunner(&runner);
    Check(runner.Jump("main.iet","main"), "reset original scenario");
    script.SetWaiting(true);
    const auto saved_pc = runner.CurrentIndex();
    const auto token = runner.BeginEvent(script);
    Check(!script.IsWaiting(), "event can run while scenario waits");
    runner.Jump("menu.iet","menu"); runner.EndEvent(token);
    for(int i=0;i<8 && !script.IsWaiting();++i) runner.ExecuteLine(script);
    Check(script.IsWaiting() && runner.CurrentIndex()==saved_pc,
          "menu return restores the exact interrupted cursor and wait");
    Check(script.DoString("assert(value==2); assert(#e:getScriptStack()==1)", "event return"),
          "event runs once and leaves no stale stack frame");
    runner.Halt();
    const auto idle = runner.BeginEvent(script); runner.EndEvent(idle);
    Check(runner.Halted() && script.IsWaiting(), "synchronous event preserves a halted runner");
    const auto called = runner.BeginEvent(script);
    runner.Call("menu.iet","menu"); runner.EndEvent(called);
    for(int i=0;i<8 && !script.IsWaiting();++i) runner.ExecuteLine(script);
    Check(runner.Halted() && runner.CurrentIndex()==saved_pc && script.IsWaiting(),
          "event call returns to the suspended frame, not its next instruction");
    script.SetTimedWait(30);
    const auto paused = runner.BeginEvent(script);
    script.PauseClock();
    std::this_thread::sleep_for(std::chrono::milliseconds(60));
    script.ResumeClock();
    runner.EndEvent(paused);
    Check(script.IsWaiting(), "app pause also freezes the wait suspended below a menu event");
    std::filesystem::remove(path);
    std::cout << "audio channels and wait regressions passed\n";
}
