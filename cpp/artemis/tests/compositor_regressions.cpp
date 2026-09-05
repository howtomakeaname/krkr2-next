#include "render/compositor.h"
#include "pack/pack_manager.h"
#include "script/lua_engine.h"
#include "render/video_player.h"
#include "audio/audio.h"
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <array>
#include <cstdlib>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <chrono>

static void Check(bool ok, const char* why) {
    if (!ok) { std::cerr << why << " GL=" << glGetError() << '\n'; std::exit(1); }
}
static std::array<unsigned char, 4> Pixel() {
    std::array<unsigned char, 4> p{};
    glReadPixels(16, 16, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, p.data());
    return p;
}
static std::array<unsigned char,4> At(int x, int y) {
    std::array<unsigned char,4> p{};
    glReadPixels(x,31-y,1,1,GL_RGBA,GL_UNSIGNED_BYTE,p.data());
    return p;
}
int main() {
    EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    Check(eglInitialize(d, nullptr, nullptr), "initialize EGL");
    EGLint attrs[] = {EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,
                      EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_NONE};
    EGLConfig cfg; EGLint count;
    Check(eglChooseConfig(d, attrs, &cfg, 1, &count) && count, "choose config");
    EGLint pb[] = {EGL_WIDTH,32,EGL_HEIGHT,32,EGL_NONE};
    EGLSurface surface = eglCreatePbufferSurface(d,cfg,pb);
    EGLint ca[] = {EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    EGLContext ctx = eglCreateContext(d,cfg,EGL_NO_CONTEXT,ca);
    Check(eglMakeCurrent(d,surface,surface,ctx), "make current");
    artc::Compositor c; c.Init(32,32);
    // Synthetic pixels only: no game assets in this regression suite.
    GLuint tex; glGenTextures(1,&tex); glBindTexture(GL_TEXTURE_2D,tex);
    const unsigned char red[4] = {255,0,0,255};
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,1,1,0,GL_RGBA,GL_UNSIGNED_BYTE,red);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
    c.SetProps("1", {{"w","32"},{"h","32"}});
    auto& layer = const_cast<artc::Layer&>(c.Layers().front());
    layer.texture=tex; layer.tex_w=layer.tex_h=1;
    glViewport(0,0,32,32); c.Draw();
    Check(Pixel()[0] == 255, "initial red scene");
    // Simulate a native window handing out a discarded/different back buffer.
    glClearColor(0,1,0,1); glClear(GL_COLOR_BUFFER_BIT);
    Check(c.BeginTransition(0,1000,{},0,0,0), "capture retained scene");
    const unsigned char blue[4] = {0,0,255,255};
    glBindTexture(GL_TEXTURE_2D,tex);
    glTexSubImage2D(GL_TEXTURE_2D,0,0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,blue);
    c.Update(500); c.Draw();
    auto p=Pixel();
    Check(p[0]>=125 && p[0]<=130 && p[1]==0 && p[2]>=125 && p[2]<=130,
          "transition must blend retained red and new blue, never discarded green");
    c.Update(1000); c.Draw();
    p=Pixel(); Check(p[0]==0 && p[2]==255, "completed transition shows new scene");
    c.SetProps("1",{{"alpha","1"}});
    c.Draw(); p=Pixel();
    Check(p[2]<=2 && p[3]==255, "alpha=1 means 1/255 opacity, with an opaque composed frame");
    c.SetProps("1",{{"alpha","255"}});
    c.AddTween("1",{{"param","alpha"},{"from","255"},{"to","0"},{"time","1000"}},1000);
    c.Update(1998); c.Draw();p=Pixel();
    Check(p[2]<=2,"last tween fraction must not flash to full opacity");
    c.SetProps("1",{{"xscale","0"}});
    float x,y,w,h,a;bool visible;
    c.EffectiveRect(c.Layers().front(),&x,&y,&w,&h,&a,&visible);
    Check(w==0,"zero scale must collapse a layer");
    c.SetProps("1",{{"xscale","100"},{"alpha","255"}});
    std::ifstream font(std::string(ARTC_TEST_DATA)+"/rectangle.ttf",std::ios::binary);
    Check(bool(font),"open synthetic font");
    std::vector<unsigned char> font_data{std::istreambuf_iterator<char>(font),{}};
    // Synthetic uncompressed TGA surfaces with different bounding boxes.
    auto solid = [](int w, int h) {
        std::vector<unsigned char> tga(18, 0);
        tga[2]=2; tga[12]=w; tga[14]=h; tga[16]=32; tga[17]=0x28;
        for (int i=0;i<w*h;++i) tga.insert(tga.end(), {0,0,255,255});
        return tga;
    };
    const std::string name="font.ttf";
    std::vector<std::pair<std::string,std::vector<unsigned char>>> files = {
        {name,font_data}, {"small.tga",solid(4,2)}, {"large.tga",solid(8,6)}};
#if defined(ARTC_TEST_MOVIE)
    std::ifstream movie_file(ARTC_TEST_MOVIE,std::ios::binary);
    auto movie=std::make_shared<std::vector<uint8_t>>(std::istreambuf_iterator<char>(movie_file),std::istreambuf_iterator<char>());
    files.push_back({"movie.mp4",*movie});
#endif
    // A pf8 fixture keeps the production pack/font/image loading path.
    std::vector<unsigned char> pack{'p','f','8'};
    auto u32=[&](uint32_t n){for(int i=0;i<4;++i)pack.push_back((n>>(8*i))&255);};
    uint32_t index_size=4;
    for(const auto& f:files) index_size+=16+f.first.size();
    u32(index_size);u32(files.size());
    uint32_t offset=7+index_size;
    for(const auto& f:files) {
        u32(f.first.size());pack.insert(pack.end(),f.first.begin(),f.first.end());
        u32(0);u32(offset);u32(f.second.size());offset+=f.second.size();
    }
    for(const auto& f:files) pack.insert(pack.end(),f.second.begin(),f.second.end());
    auto path=std::filesystem::temp_directory_path()/
        ("artemis-font-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count())+".pfs");
    {std::ofstream out(path,std::ios::binary);out.write((char*)pack.data(),pack.size());}
    artc::PackManager packs;Check(packs.OpenChain(path.string(),{0}),"open font pack");
    c.SetPackManager(&packs);Check(c.LoadFont(name),"load synthetic font");
    Check(c.SetText("2","AA\nAA",10,0xffffff,30,
        {{"align","center"},{"outline","1"},{"outlinecolor","0x000000"}}),"rasterize aligned outlined multiline text");
    c.SetProps("2",{{"left","0"},{"top","0"}});c.Draw();
    auto left=At(2,4), edge=At(8,4), fill=At(10,4), second=At(10,14);
    Check(left[0]==0 && left[2]==255,"center alignment retains left margin");
    Check(edge[0]==0 && edge[2]==0,"outline darkens the border");
    Check(fill[0]==255 && fill[2]==255,"glyph uses em-sized fill");
    Check(second[0]==255 && second[2]==255,"explicit newline places a second line");
    Check(c.SetText("2","A\nA",10,0xffffff,30,
        {{"rubysize","6"},{"spacemiddle","-3"},{"spacebottom","-1"},
         {"left","2"},{"top","1"}}), "reserve ruby row before line spacing");
    c.SetProps("2",{{"left","3"},{"top","1"}});c.Draw();
    auto upper=At(7,7), gap=At(7,14), lower=At(7,19);
    Check(upper[0]==255 && lower[0]==255 && gap[0]==0 && gap[2]==255,
          "ruby spacing leaves a gap and text origin composes with layer translation");
    Check(c.SetText("2","",10,0xffffff,30), "clear empty message");c.Draw();
    Check(At(7,7)[0]==0 && At(7,7)[2]==255, "empty print removes previous glyph pixels");
    artc::LuaEngine messages;
    artc::Ini ini;
    Check(messages.Init(&packs,ini,"android",32,32,&c), "message engine init");
    Check(messages.DoString("e:tag{'chgmsg',id='2'}; e:tag{'font',face='font.ttf',size=10,width=30}; "
        "e:tag{'print',data='A'}; e:tag{'/chgmsg'}; e:tag{'chgmsg',id='4'}; "
        "e:tag{'font',face='font.ttf',size=10,width=30}; e:tag{'print',data='A'}; "
        "e:tag{'chgmsg',id='2'}; e:tag{'print',data='A'}; e:tag{'/chgmsg'}; e:tag{'lydel',id='4'}",
        "append pages"), "selecting a message layer preserves its page");
    c.SetProps("2",{{"left","0"},{"top","0"}}); c.Draw();
    Check(At(9,4)[0]==255, "appended second glyph survives switching message layers");
    Check(messages.DoString("e:tag{'chgmsg',id='2'}; e:tag{'rp'}; e:tag{'print',data='A'}", "clear page"),
          "rp clears the selected page"); c.Draw();
    Check(At(9,4)[0]==0 && At(3,4)[0]==255, "rp replaces the old page instead of appending");
    Check(messages.DoString("e:tag{'lydel',id='2'}; e:tag{'chgmsg',id='2'}; e:tag{'print',data='A'}",
        "recreate message"), "delete message layer"); c.Draw();
    Check(At(9,4)[0]==0, "deleting a layer clears its saved page");
    c.DeleteLayer("2");
    c.DeleteTweens("1"); c.SetProps("1",{{"alpha","255"}});
    c.Update(3000);
    c.SetTextTween("2",{{"mode","init"},{"type","in"}});
    c.SetTextTween("2",{{"mode","add"},{"type","in"},{"param","alpha"},
                         {"delay","100"},{"time","100"},{"diff","-255"}});
    Check(c.SetText("2","AA",10,0xffffff,30),"rasterize animated text"); c.Draw();
    Check(At(3,4)[0]==0 && At(9,4)[0]==0,"character fade starts transparent");
    c.Update(3050); c.Draw();
    Check(At(3,4)[0]>=125 && At(3,4)[0]<=130 && At(9,4)[0]==0,
          "first glyph fades while the next glyph waits");
    c.Update(3100); c.Draw();
    Check(At(3,4)[0]==255 && At(9,4)[0]==0,"glyph delay uses characters, independent of layout");
    Check(c.PendingTextMs(3100)==100 && c.FinishText(3100),"finish remaining character animation");
    c.Draw(); Check(At(9,4)[0]==255 && c.PendingTextMs(3100)==0,"finish reveals the complete page");
    Check(c.SetText("2","AAA",10,0xffffff,30),"append to animated page"); c.Draw();
    Check(At(3,4)[0]==255 && At(9,4)[0]==255 && At(15,4)[0]==0,
          "appending preserves revealed glyphs and animates only new text");
    c.Update(3200); c.Draw();
    Check(At(15,4)[0]==255,"appended character completes");
    c.SetProps("2",{{"visible","0"}});
    Check(c.PendingTextMs(3100)==0,"hidden text does not block a visible page");
    c.DeleteLayer("2");
    c.Update(messages.NowMs());
    Check(messages.DoString("e:tag{'chgmsg',id='2'}; e:tag{'rp'}; "
        "e:tag{'scetween',type='in',mode='init'}; "
        "e:tag{'scetween',type='in',mode='add',param='alpha',delay=10000,time=10000,diff=-255}; "
        "e:tag{'print',data='AA'}; e:tag{'@'}; assert(e:getScriptWaitReason().textTween)",
        "typewriter wait"), "script observes pending character animation");
    messages.ClickAt(31,31); messages.RunEnterFrame();
    Check(messages.IsWaiting() && c.PendingTextMs(messages.NowMs())==0,
          "first click completes text and preserves the page wait");
    messages.ClickAt(31,31); messages.RunEnterFrame();
    Check(!messages.IsWaiting(),"second click advances the completed page");
    Check(messages.DoString("e:tag{'rp'}; e:tag{'print',data='AA'}; "
        "e:tag{'automode',allow=1}; e:tag{'exec',command='automode',mode=1}; "
        "e:tag{'var',name='s.automodewait',data=0}; e:tag{'@'}", "auto text wait"),
        "start auto while text is revealing");
    Check(messages.IsWaiting(),"auto waits for text even with zero reading interval");
    c.FinishText(messages.NowMs());
    Check(!messages.IsWaiting(),"auto continues after the complete page is visible");
    c.DeleteLayer("2");
    Check(c.SetText("2","AAAAA",10,0xffffff,30,{{"rubysize","6"}},{{3,2,"AAAA"}}),
          "layout longer ruby as an unbreakable block"); c.Draw();
    const auto& ruby_layer=c.Layers().back();
    Check(ruby_layer.glyphs.size()==9,"ruby adds glyphs without replacing its base");
    const auto& rg=ruby_layer.glyphs;
    Check(rg[3].y>rg[2].y && rg[4].y==rg[3].y,
          "base text and its longer reading wrap together");
    Check(rg[5].y<rg[3].y && rg[5].start_ms==rg[3].start_ms,
          "ruby is placed above the base and shares its character timing");
    int ruby_coverage=0;
    for(int yy=int(rg[5].y);yy<rg[5].y+rg[5].h;++yy)
        for(int xx=int(rg[5].x);xx<rg[5].x+rg[5].w;++xx)
            ruby_coverage=std::max(ruby_coverage,int(At(xx,yy)[0]));
    Check(ruby_coverage>128,"ruby actually produces visible pixels");
    c.DeleteLayer("2");
    Check(c.SetText("2",u8"Aé",10,0xffffff,30,{{"rubysize","6"}},{{1,2,"A"}}),
          "ruby range uses UTF-8 byte boundaries");
    Check(c.Layers().back().glyphs.size()==3,"multibyte base character occupies one glyph");
    c.DeleteLayer("2");
    Check(messages.DoString("e:tag{'chgmsg',id='2'}; e:tag{'rp'}; e:tag{'font',rubysize=6}; "
        "e:tag{'ruby',text='AAAA'}; e:tag{'print',data='AA'}; e:tag{'/ruby'}",
        "ruby tags"), "ruby tags collect base text and render at close");
    Check(c.Layers().back().glyphs.size()==6,"ruby tags retain both the base and annotation");
    Check(messages.DoString("e:tag{'rp'}; e:tag{'print',data='A'}", "clear ruby"), "clear ruby page");
    Check(c.Layers().back().glyphs.size()==1,"rp also clears ruby ranges");
    c.DeleteLayer("2");
    c.SetProps("3",{{"left","4"},{"top","3"},{"xscale","200"},{"yscale","200"}});
    Check(c.LoadImage("3.1","small.tga"),"load first expression");
    c.SetProps("3.1",{{"left","5"},{"top","4"}});
    Check(c.LoadImage("3.1","large.tga"),"replace expression with larger bounding box");
    c.SetProps("3.1",{{"left","3"},{"top","2"}});c.Draw();
    Check(At(24,15)[0]==255 && At(27,20)[2]==255,
          "replacement adopts new natural size and composes its offset with parent scale");
    c.SetProps("3.1",{{"clip","2,1,3,2"}});
    Check(c.LoadImage("3.1","small.tga"),"replace cropped expression");c.Draw();
    const auto info=c.GetLayerInfo("3.1");
    Check(info.width==4 && info.height==2,"new surface discards old crop dimensions");
    const auto& face=c.Layers().back();
    Check(face.u0==0 && face.v0==0 && face.u1==1 && face.v1==1,
          "new surface discards old crop UVs");
    Check(At(16,9)[0]==255 && At(18,9)[2]==255,
          "smaller replacement retains layer position and parent transform");
    Check(!c.LoadImage("3.1","missing.png"),"missing replacement fails");
    Check(c.GetLayerInfo("3.1").width==4,"failed replacement keeps existing surface");
#if defined(ARTC_TEST_MOVIE)
    c.DeleteLayer("3");
    artc::Audio movie_audio; movie_audio.Init(&packs);
    artc::VideoPlayer player(c,movie_audio);
    Check(player.Start(movie,"9",false,true,1000,1000),"start fullscreen movie"); c.Draw();
    Check(Pixel()[0]>220 && Pixel()[2]<30,"movie frame renders above the scene");
    player.Update(1600); c.Draw();
    Check(!player.Active() && Pixel()[2]==255,"movie end restores the underlying scene");
    Check(player.Start(movie,"8",true,false,1000,2000),"start looping layer movie");
    player.Update(2600); player.Update(2800);
    Check(player.Active(),"layer movie loops without ending the player"); player.Stop();
    Check(messages.DoString("e:tag{'video',file='movie.mp4',skip=0}; assert(e:getScriptWaitReason().video)",
        "video wait"),"video tag establishes a script wait");
    messages.ClickAt(31,31); messages.RunEnterFrame();
    Check(messages.IsWaiting(),"unskippable movie consumes taps without advancing the scenario");
    Check(messages.DoString("e:tag{'video',file='movie.mp4',skip=2}; e:tag{'keyconfig',role=1,keys='27'}",
        "movie cancel role"),"configure movie cancel key");
    messages.ClickAt(31,31); messages.RunEnterFrame();
    Check(messages.IsWaiting(),"cancel role excludes ordinary pointer taps");
    messages.PushKeyDown(27); messages.RunEnterFrame(); messages.EndFrame();
    Check(!messages.IsWaiting(),"configured cancel key stops the movie and releases the wait");
#endif
    std::filesystem::remove(path);
    c.Shutdown();
    Check(glGetError()==GL_NO_ERROR, "resource cleanup");
    eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroyContext(d,ctx); eglDestroySurface(d,surface); eglTerminate(d);
    std::cout << "retained framebuffer regression passed\n";
}
