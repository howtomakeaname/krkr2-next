#pragma once
#include "render/emote_model.h"
namespace emote_fixture {
inline artc::PsbValue N(double n){artc::PsbValue v;v.type=artc::PsbValue::Number;v.number=n;return v;}
inline artc::PsbValue S(const char* s){artc::PsbValue v;v.type=artc::PsbValue::String;v.string=s;return v;}
inline artc::PsbValue A(std::initializer_list<artc::PsbValue> a){artc::PsbValue v;v.type=artc::PsbValue::Array;v.array=a;return v;}
inline artc::PsbValue O(std::initializer_list<std::pair<const std::string,artc::PsbValue>> o){artc::PsbValue v;v.type=artc::PsbValue::Object;v.object=o;return v;}
inline artc::PsbValue Key(double time,int type,artc::PsbValue content={}) {
    return O({{"time",N(time)},{"type",N(type)},{"content",std::move(content)}});
}
inline artc::PsbValue Node(int type,const char* label,artc::PsbValue frames,artc::PsbValue children=A({})) {
    return O({{"type",N(type)},{"label",S(label)},{"frameList",std::move(frames)},{"children",std::move(children)},
        {"inheritMask",N(33556476)},{"transformOrder",A({N(0),N(3),N(2),N(1)})}});
}
inline artc::PsbDocument Scene() {
    artc::PsbDocument doc;
    auto image=[&](int width,int height,int red,int green,double ox,double oy) {
        artc::PsbValue resource;resource.type=artc::PsbValue::Resource;resource.resource=doc.resources.size();
        const auto offset=doc.bytes.size();
        for(int i=0;i<width*height;++i)doc.bytes.insert(doc.bytes.end(),{uint8_t(red),uint8_t(green),0,255});
        doc.resources.push_back({offset,doc.bytes.size()-offset});
        return O({{"width",N(width)},{"height",N(height)},{"originX",N(ox)},{"originY",N(oy)},
            {"type",S("RGBA8")},{"pixel",resource}});
    };
    auto body=Node(0,"body",A({Key(0,2,O({{"src",S("src/images/body")}})),Key(11,0)}));
    auto face=Node(0,"face",A({Key(0,2,O({{"src",S("src/images/face")}})),
        Key(10,2,O({{"src",S("src/images/wide")}})),Key(11,0)}));
    face.object["parameterize"]=N(0);
    auto face_motion=O({{"layer",A({face})},{"lastTime",N(11)},{"loopTime",N(-1)},
        {"parameter",A({O({{"id",S("expression")},{"rangeBegin",N(0)},{"rangeEnd",N(10)},{"division",N(10)}})})}});
    auto child=Node(3,"face child",A({Key(0,2,O({{"src",S("motion/actor/face")},{"coord",A({N(0),N(-1),N(0)})}})),Key(11,0)}));
    auto group=Node(2,"root",A({Key(0,3,O({{"src",S("layout")},{"coord",A({N(8),N(8),N(0)})}})),
        Key(10,3,O({{"src",S("layout")},{"coord",A({N(18),N(8),N(0)})}})),Key(11,0)}),A({body,child}));
    auto motion=O({{"layer",A({group})},{"lastTime",N(11)},{"loopTime",N(0)}});
    doc.root=O({{"spec",S("common")},{"source",O({{"images",O({{"icon",O({
        {"body",image(4,4,255,0,2,2)},{"face",image(2,2,0,255,1,1)},{"wide",image(4,2,0,255,2,1)}})}})}})},
        {"object",O({{"actor",O({{"motion",O({{"idle",motion},{"face",face_motion}})}})}})},
        {"metadata",O({{"base",O({{"chara",S("actor")},{"motion",S("idle")}})},
            {"variableList",A({O({{"label",S("expression")}})})}})}});
    return doc;
}
}
