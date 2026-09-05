#include "render/compositor.h"
#include "pack/pack_manager.h"
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
    // A single-entry pf8 fixture keeps the production pack/font loading path.
    std::vector<unsigned char> pack{'p','f','8'};
    auto u32=[&](uint32_t n){for(int i=0;i<4;++i)pack.push_back((n>>(8*i))&255);};
    const std::string name="font.ttf";
    u32(20+name.size());u32(1);u32(name.size());
    pack.insert(pack.end(),name.begin(),name.end());u32(0);u32(27+name.size());u32(font_data.size());
    pack.insert(pack.end(),font_data.begin(),font_data.end());
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
    std::filesystem::remove(path);
    c.Shutdown();
    Check(glGetError()==GL_NO_ERROR, "resource cleanup");
    eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroyContext(d,ctx); eglDestroySurface(d,surface); eglTerminate(d);
    std::cout << "retained framebuffer regression passed\n";
}
