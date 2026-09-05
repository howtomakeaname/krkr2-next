#include "pack/psb.h"
#include "render/emote_model.h"
#include <cmath>
#include <zlib.h>
#include <cstdlib>
#include <fstream>
#include <iostream>

static void Check(bool ok,const char* why) {
    if(!ok){std::cerr<<why<<'\n';std::exit(1);}
}
static std::vector<uint8_t> Fixture() {
    std::vector<uint8_t> b(44);b[0]='P';b[1]='S';b[2]='B';b[4]=3;
    auto field=[&](size_t at){for(int i=0;i<4;++i)b[at+i]=uint8_t(b.size()>>(8*i));};
    auto array=[&](const std::vector<uint8_t>& a){b.push_back(13);b.push_back(uint8_t(a.size()));b.push_back(13);b.insert(b.end(),a.begin(),a.end());};
    field(12);array({0});std::vector<uint8_t> parent(99);parent[98]=97;array(parent);array({98}); // trie: "a"
    field(16);array({0});field(20);b.insert(b.end(),{'h','i',0});
    field(24);array({0});field(28);array({4});field(32);b.insert(b.end(),{255,0,0,255});
    field(36);b.push_back(33);array({0});array({0}); // {a: ["hi", resource0, -2, true]}
    b.push_back(32);array({0,2,4,6});b.insert(b.end(),{21,0,25,0,5,254,3});return b;
}
static artc::PsbValue N(double n) {artc::PsbValue v;v.type=artc::PsbValue::Number;v.number=n;return v;}
static artc::PsbValue S(const std::string& s) {artc::PsbValue v;v.type=artc::PsbValue::String;v.string=s;return v;}
static artc::PsbValue A(std::initializer_list<artc::PsbValue> a) {artc::PsbValue v;v.type=artc::PsbValue::Array;v.array=a;return v;}
static artc::PsbValue O(std::initializer_list<std::pair<const std::string,artc::PsbValue>> o) {artc::PsbValue v;v.type=artc::PsbValue::Object;v.object=o;return v;}
static void ModelTests() {
    auto key=[](double t,double v,double e=0){return O({{"time",N(t)},{"type",N(2)},{"content",O({{"value",N(v)},{"easing",N(e)}})}});};
    auto track=[&](const char* label){return O({{"label",S(label)},{"frameList",A({key(0,0),key(10,10,1),O({{"time",N(20)},{"type",N(0)}})})}});};
    artc::PsbDocument doc;doc.root=O({{"spec",S("krkr")},{"object",O({{"body",O({{"motion",O({{"idle",O({})}})}})}})},
        {"metadata",O({{"base",O({{"chara",S("body")},{"motion",S("idle")}})},
        {"variableList",A({O({{"label",S("head")}}),O({{"label",S("eye")}})})},
        {"instantVariableList",A({S("eye")})},
        {"timelineControl",A({O({{"label",S("blink")},{"lastTime",N(-1)},{"loopBegin",N(0)},{"loopEnd",N(20)},
        {"variableList",A({track("head"),track("eye")})}})})}})}});
    artc::EmoteModel model;std::string error;Check(model.Load(doc,error),error.c_str());
    std::map<std::string,double> values;
    Check(model.Sample("blink",5,values) && std::abs(values.at("head")-2.5)<1e-6 && values.at("eye")==0,"continuous easing and discrete expression tracks");
    Check(model.Sample("blink",15,values) && values.at("head")==10 && values.at("eye")==10,"terminal marker retains previous value");
    Check(model.Sample("blink",45,values) && std::abs(values.at("head")-2.5)<1e-6,"timeline seek wraps multiple loops");
    Check(!model.Sample("missing",0,values) && values.count("head"),"unknown timeline preserves output");
    doc.root.object["metadata"].object["base"].object["motion"]=S("missing");
    Check(!model.Load(doc,error) && model.Timelines().size()==1,"invalid model preserves prior timelines");
    doc.root.object["metadata"].object["base"].object["motion"]=S("idle");
    artc::PsbValue resource;resource.type=artc::PsbValue::Resource;
    doc.root.object["source"]=O({{"face",O({{"icon",O({{"smile",O({{"width",N(1)},{"height",N(1)},
        {"originX",N(3.5)},{"originY",N(-2)},{"type",S("RGBA8")},{"pixel",resource},{"pal",resource}})}})}})}});
    doc.bytes={10,20,30,128};doc.resources={{0,4}};
    Check(model.Load(doc,error),error.c_str());artc::EmoteImage image;
    Check(model.Image("face","smile",image,error) && image.rgba==std::vector<uint8_t>({30,20,10,128}) && image.origin_x==3.5 && image.origin_y==-2,
        "desktop color order, independent sprite origins and unused palette reference");
    auto& icon=doc.root.object["source"].object["face"].object["icon"].object["smile"];
    icon.object["type"]=S("CI8");icon.object["pal"].resource=1;
    doc.bytes={0,10,20,30,128};doc.resources={{0,1},{1,4}};
    Check(model.Load(doc,error) && model.Image("face","smile",image,error) && image.rgba[0]==30,"CI8 palette expansion");
    doc.bytes[0]=1;Check(model.Load(doc,error),error.c_str());
    Check(!model.Image("face","smile",image,error) && image.rgba[0]==30,"invalid texture retains prior pixels");
}
int main(int argc,char** argv) {
    ModelTests();
    const auto fixture=Fixture();artc::PsbDocument doc;std::string error;
    Check(artc::DecodePsb(fixture,doc,error),error.c_str());
    const auto& a=doc.root.At("a").array;
    Check(a.size()==4 && a[0].string=="hi" && a[2].number==-2 && a[3].number==1,"PSB dictionaries, arrays, signed numbers and strings");
    std::vector<uint8_t> pixels;
    Check(doc.ReadResource(a[1],pixels) && pixels==std::vector<uint8_t>({255,0,0,255}),"PSB resource ranges");
    for(size_t size=0;size<fixture.size();++size) {
        const std::vector<uint8_t> cut(fixture.begin(),fixture.begin()+size);
        Check(!artc::DecodePsb(cut,doc,error) && doc.root.At("a").array.size()==4,"truncated PSB leaves previous document intact");
    }
    auto broken=fixture;broken[6]=1;
    Check(!artc::DecodePsb(broken,doc,error) && error.find("encrypted")!=std::string::npos,"encrypted PSB reports unsupported");
    // The root's sole value offset loops back to the root dictionary.
    broken=fixture;broken[36]=255;broken[37]=255;broken[38]=255;broken[39]=255;
    Check(!artc::DecodePsb(broken,doc,error),"PSB rejects overflowing offsets");
    std::vector<uint8_t> mdf={'m','d','f',0};for(int i=0;i<4;++i)mdf.push_back(uint8_t(fixture.size()>>(8*i)));
    uLongf len=compressBound(fixture.size());mdf.resize(8+len);
    Check(compress2(mdf.data()+8,&len,fixture.data(),fixture.size(),6)==Z_OK,"MDF compress fixture");mdf.resize(8+len);
    Check(artc::DecodePsb(mdf,doc,error),error.c_str());mdf.back()^=1;
    Check(!artc::DecodePsb(mdf,doc,error),"MDF checksum failure");
    Check(artc::DecodePsbRl({128,1,2,3,4,0,5,6,7,8},4,4,pixels) && pixels.size()==16 && pixels[12]==5,"RL repeat and literal complete pixels");
    Check(artc::DecodePsbRl({128,7,0,9},4,1,pixels) && pixels==std::vector<uint8_t>({7,7,7,9}),"RL palette indices");
    Check(!artc::DecodePsbRl({129,7},3,1,pixels) && pixels.back()==9,"RL rejects oversized packet transactionally");
    Check(!artc::DecodePsbRl({128,7},4,1,pixels),"RL rejects undersized stream");
    Check(!artc::DecodePsbRl({128,7,0,9},3,1,pixels),"RL rejects trailing packet");
    for(int i=1;i<argc;++i) {
        std::ifstream f(argv[i],std::ios::binary);std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(f)),{});
        Check(artc::DecodePsb(bytes,doc,error),error.c_str());
        std::cout<<"PSB v"<<doc.version<<" spec="<<doc.root.At("spec").string
                 <<" resources="<<doc.resources.size()<<" timelines="<<doc.root.At("metadata").At("timelineControl").array.size()<<'\n';
        artc::EmoteModel model;Check(model.Load(std::move(doc),error),error.c_str());size_t images=0;
        for(const auto& source:model.Document().root.At("source").object)
            for(const auto& icon:source.second.At("icon").object) {
                artc::EmoteImage image;Check(model.Image(source.first,icon.first,image,error),error.c_str());++images;
            }
        for(const auto& t:model.Timelines()) {
            std::map<std::string,double> values;Check(model.Sample(t.first,100.25,values),"sample real model track");
            for(const auto& v:values)Check(std::isfinite(v.second),"real timeline produces finite variables");
        }
        std::cout<<"decoded_images="<<images<<" variables="<<model.Variables().size()<<'\n';
    }
}
