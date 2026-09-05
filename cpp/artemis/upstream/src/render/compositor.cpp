#include "render/compositor.h"
#include "pack/pack_manager.h"
#include "pack/pf8_reader.h"
#include "log/logger.h"

// KrKr2-Next: the GLES2 compositor is also used on OpenHarmony (the host
// bridge makes an EGL context current before driving it). ARTC_HAS_GLES is
// set by cpp/artemis/CMakeLists.txt for every platform with a GLES2 sysroot.
#if defined(__ANDROID__) && !defined(ARTC_HAS_GLES)
#define ARTC_HAS_GLES 1
#endif

#if defined(ARTC_HAS_GLES)
#include <GLES2/gl2.h>
#define STB_IMAGE_IMPLEMENTATION
#include "render/stb_image.h"
#define STB_TRUETYPE_IMPLEMENTATION
#include "render/stb_truetype.h"
#endif

#include <algorithm>
#include <cmath>
#include <set>
#include <cstdio>

namespace artc {

// Artemis layer z is a two-level sort. The leading integer is the primary
// layer ("600", "1", "-273"); within the same primary layer the SECOND id
// segment breaks ties the way the engine draws it:
//   * numeric second segments sort by value — the message layer ("1.80…")
//     sits ABOVE the scene group ("1.0…") because 80 > 0;
//   * a letter second segment sorts ABOVE any number — the title button
//     ("500.d.…") sits ABOVE the title background ("500.0").
// Official z-order spec (spec/layer.md): stacking is decided by the LAYER ID.
//   * purely-numeric ids sort numerically (larger = drawn on top);
//   * an id with a leading number sorts by that number's VALUE first, then
//     by the string tail (so "500.d.1.0" > "500.0", and "1hoge" < "20hoge",
//     matching the documented example);
//   * an id with NO leading number ("bg", "froid"...) sorts to the bottom
//     (letter-only names are framework helper/background layers and must not
//     cover the numeric layer-set UI and scene layers).
int ZCmp(const std::string &a, const std::string &b) {
    auto lead = [](const std::string &s, int *start) -> long long {
        *start = 0;
        size_t i = 0;
        while (i < s.size() && s[i] >= '0' && s[i] <= '9') ++i;
        if (i == 0) return -1;                 // no leading number
        long long v = 0;
        try { v = std::stoll(s.substr(0, i)); } catch (...) { v = 0; }
        *start = static_cast<int>(i);
        return v;
    };
    int sa = 0, sb = 0;
    const long long pa = lead(a, &sa);
    const long long pb = lead(b, &sb);
    if (pa == -1 && pb == -1) return a == b ? 0 : (a < b ? -1 : 1);
    if (pa != pb) return pa < pb ? -1 : 1;
    // same leading value: compare the whole strings lexicographically
    // (numeric tails compared on equal numbers fall back to the id text).
    if (a == b) return 0;
    return a < b ? -1 : 1;
}

// Layer hierarchy depth ("500.d.1.0" → 4 segments). Ties at the same z break
// toward deeper layers: the title background ("500.0") and its buttons
// ("500.d.*") share z=500, and the background must render *below* the buttons
// regardless of insertion order. Behavior observed from the real engine: the
// background is created after the buttons yet never covers them.
int SectionCount(const std::string &id) {
    int n = 1;
    for (const char c : id)
        if (c == '.') ++n;
    return n;
}

void Compositor::EffectiveRect(const Layer &l, float *ex, float *ey,
                               float *ea, bool *ev) const {
    float w, h;
    EffectiveRect(l, ex, ey, &w, &h, ea, ev);
}

// KrKr2-Next: layer transform model, replacing the upstream absolute/inherit
// heuristic. Each layer contributes
//     T = translate(x, y) . translate(ax, ay) . scale(sx, sy) . translate(-ax, -ay)
// i.e. an offset RELATIVE to its parent plus a scale about its own anchor,
// and a layer's world transform is the composition of every ancestor's T
// (root first). For axis-aligned scale+translate this collapses to
//     origin' = origin + scale * (x + ax * (1 - sx)),   scale' = scale * sx
// which reproduces the framework's layouts observed on device:
//   * `1.0 {left=0 top=0 anchor=640,360 xscale=100}` covers the stage
//     (the old `x - ax` rule pushed it to -640,-360 and dragged every BG
//     with it);
//   * face parts `<char>.<part> {x=f.x-z.x ...}` land on the head of a
//     positioned character container; choice buttons `1.80.120.N.0
//     {left=360}` stack under `1.80.120.N {top=284/368}`;
//   * the pull-out toolbar `1.80.tb.tb {left=1240}` keeps its buttons
//     off-screen except the 40px tab, as the real engine does;
//   * the title character `500.b.1 {left=120 top=150 anchor=592,160
//     xscale=200}` doubles around its anchor (top-left -472,-10 — the case
//     the old `x - ax` rule was fitted to, valid only for scale 2).
// Anchors without scale/rotation therefore never move a layer; a layer
// without an explicit position simply inherits its parent's origin.
void Compositor::EffectiveRect(const Layer &l, float *ex, float *ey, float *ew,
                               float *eh, float *ea, bool *ev) const {
    // Collect the ancestor chain root-first ("a.b.c" -> "a", "a.b").
    std::vector<const Layer *> chain;
    {
        std::string id = l.id;
        size_t dot;
        while ((dot = id.rfind('.')) != std::string::npos) {
            id = id.substr(0, dot);
            for (const auto &p : layers_) {
                if (p.id == id) { chain.push_back(&p); break; }
            }
        }
    }
    float ox = 0, oy = 0, sx = 1, sy = 1;
    float a = 1.0f;
    bool vis = true;
    auto apply = [&](const Layer &n) {
        a *= n.alpha;
        vis = vis && n.visible;
        // n.x/n.y stay 0 for plain group layers; SetText's default message
        // placement and draggable pins store relative offsets here too.
        ox += sx * (n.x + n.ax * (1.0f - n.sx));
        oy += sy * (n.y + n.ay * (1.0f - n.sy));
        sx *= n.sx;
        sy *= n.sy;
    };
    for (auto it = chain.rbegin(); it != chain.rend(); ++it) apply(**it);
    apply(l);
    *ex = ox + l.content_x * sx; *ey = oy + l.content_y * sy;
    *ew = l.w * sx; *eh = l.h * sy;
    *ea = a; *ev = vis;
}

std::string Compositor::HitLayer(float x, float y) const {
    const Layer *best = nullptr;
    for (const auto &l : layers_) {
        float ex, ey, ew, eh, ea; bool ev;
        EffectiveRect(l, &ex, &ey, &ew, &eh, &ea, &ev);
        if (!ev || !l.texture) continue;
        if (x < std::min(ex, ex + ew) || y < std::min(ey, ey + eh) ||
            x >= std::max(ex, ex + ew) || y >= std::max(ey, ey + eh)) continue;
        if (!best) best = &l;
        else {
            const int c = ZCmp(l.id, best->id);
            const bool lFront = c > 0 ||
                                (c == 0 &&
                                 SectionCount(l.id) > SectionCount(best->id));
            if (lFront) best = &l;
        }
    }
    return best ? best->id : std::string();
}

// [var system="get_layer_info"] — stored (relative) offsets and draggable
// bounds. slider_dragX reads left to derive the percentage, so we return the
// raw stored value, not the cascade-resolved absolute position.
// ---------------------------------------------------------------------------
// KrKr2-Next: tween engine (platform independent)
// ---------------------------------------------------------------------------
namespace {
enum Ease { kEaseLinear = 0, kEaseInQuad, kEaseOutQuad, kEaseInOutQuad,
            kEaseInCubic, kEaseOutCubic, kEaseInOutCubic, kEaseInSine,
            kEaseOutSine, kEaseInOutSine, kEaseOutBack, kEaseOutBounce };

int ParseEase(const std::string &name) {
    if (name.empty() || name == "none" || name == "linear") return kEaseLinear;
    if (name == "easein_quad") return kEaseInQuad;
    if (name == "easeout_quad") return kEaseOutQuad;
    if (name == "easeinout_quad") return kEaseInOutQuad;
    if (name == "easein_cubic") return kEaseInCubic;
    if (name == "easeout_cubic") return kEaseOutCubic;
    if (name == "easeinout_cubic") return kEaseInOutCubic;
    if (name == "easein_sine") return kEaseInSine;
    if (name == "easeout_sine") return kEaseOutSine;
    if (name == "easeinout_sine") return kEaseInOutSine;
    if (name == "easeout_back") return kEaseOutBack;
    if (name == "easeout_bounce") return kEaseOutBounce;
    // unknown curve families (elastic, quart, expo...) fall back by direction
    if (name.rfind("easein", 0) == 0 && name.find("out") == std::string::npos) return kEaseInQuad;
    if (name.rfind("easeout", 0) == 0) return kEaseOutQuad;
    return kEaseInOutQuad;
}

float ApplyEase(int ease, float t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const float pi = 3.14159265f;
    switch (ease) {
    case kEaseInQuad: return t * t;
    case kEaseOutQuad: return 1 - (1 - t) * (1 - t);
    case kEaseInOutQuad: return t < 0.5f ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;
    case kEaseInCubic: return t * t * t;
    case kEaseOutCubic: { const float u = 1 - t; return 1 - u * u * u; }
    case kEaseInOutCubic: return t < 0.5f ? 4 * t * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;
    case kEaseInSine: return 1 - std::cos(t * pi / 2);
    case kEaseOutSine: return std::sin(t * pi / 2);
    case kEaseInOutSine: return -(std::cos(pi * t) - 1) / 2;
    case kEaseOutBack: { const float c1 = 1.70158f, c3 = c1 + 1; const float u = t - 1;
                         return 1 + c3 * u * u * u + c1 * u * u; }
    case kEaseOutBounce: {
        const float n1 = 7.5625f, d1 = 2.75f;
        if (t < 1 / d1) return n1 * t * t;
        if (t < 2 / d1) { t -= 1.5f / d1; return n1 * t * t + 0.75f; }
        if (t < 2.5f / d1) { t -= 2.25f / d1; return n1 * t * t + 0.9375f; }
        t -= 2.625f / d1; return n1 * t * t + 0.984375f;
    }
    default: return t;
    }
}

float ToF(const std::string &s, float def = 0) {
    try { return s.empty() ? def : std::stof(s); } catch (...) { return def; }
}
} // namespace

bool Compositor::ReadParam(const Layer &l, const std::string &param, float *v) {
    if (param == "alpha") { *v = l.alpha * 255.0f; return true; }
    if (param == "left" || param == "x") { *v = l.x; return true; }
    if (param == "top" || param == "y") { *v = l.y; return true; }
    if (param == "xscale") { *v = l.sx * 100.0f; return true; }
    if (param == "yscale") { *v = l.sy * 100.0f; return true; }
    if (param == "zoom") { *v = l.sx * 100.0f; return true; }
    if (param == "w") { *v = l.w; return true; }
    if (param == "h") { *v = l.h; return true; }
    return false;
}

bool Compositor::ApplyParam(Layer &l, const std::string &param, float v) {
    if (param == "alpha") { l.alpha = std::clamp(v / 255.0f, 0.0f, 1.0f); return true; }
    if (param == "left" || param == "x") { l.x = v; l.own_pos = true; return true; }
    if (param == "top" || param == "y") { l.y = v; l.own_pos = true; return true; }
    if (param == "xscale") { l.sx = v / 100.0f; return true; }
    if (param == "yscale") { l.sy = v / 100.0f; return true; }
    if (param == "zoom") { l.sx = l.sy = v / 100.0f; return true; }
    if (param == "w") { l.w = v; return true; }
    if (param == "h") { l.h = v; return true; }
    return false;
}

void Compositor::AddTween(const std::string &id,
                          const std::map<std::string, std::string> &attrs, double now_ms) {
    auto get = [&](const char *k) -> std::string {
        const auto it = attrs.find(k);
        return it == attrs.end() ? std::string() : it->second;
    };
    std::string param = get("param");
    // `param` missing: the animated property is whichever known key carries
    // a "from,to" pair (tween{ id, alpha="255,0" } style).
    if (param.empty()) {
        for (const char *k : {"alpha", "left", "top", "x", "y", "xscale", "yscale", "zoom", "w", "h"}) {
            if (attrs.count(k)) { param = k; break; }
        }
    }
    if (param.empty()) return;
    Tween tw;
    tw.id = id;
    tw.param = param;
    tw.time_ms = ToF(get("time"), 0);
    tw.delay_ms = ToF(get("delay"), 0);
    tw.ease = ParseEase(get("ease"));
    tw.start_ms = now_ms;
    // from/to: explicit attrs win; else "<param>=a,b"; else current -> to.
    const std::string from = get("from"), to = get("to");
    const std::string pair = get(param.c_str());
    const size_t comma = pair.find(',');
    if (!to.empty()) tw.to = ToF(to);
    else if (comma != std::string::npos) tw.to = ToF(pair.substr(comma + 1));
    else tw.to = ToF(pair);
    if (!from.empty()) { tw.from = ToF(from); tw.from_current = false; }
    else if (comma != std::string::npos) { tw.from = ToF(pair.substr(0, comma)); tw.from_current = false; }
    // Replace an in-flight tween of the same property on the same layer.
    for (auto it = tweens_.begin(); it != tweens_.end();) {
        if (it->id == id && it->param == param) it = tweens_.erase(it); else ++it;
    }
    if (tw.time_ms <= 0 && tw.delay_ms <= 0) {
        // instantaneous: apply and bump
        for (auto &l : layers_) if (l.id == id) { ApplyParam(l, param, tw.to); ++revision_; }
        return;
    }
    // Materialize the target layer so the tween has something to drive
    // (the framework sometimes tweens a group id before children exist).
    bool found = false;
    for (auto &l : layers_) if (l.id == id) { found = true; break; }
    if (!found) { Layer g; g.id = id; layers_.push_back(g); }
    tweens_.push_back(tw);
    ++revision_;
}

void Compositor::DeleteTweens(const std::string &id) {
    const std::string prefix = id + ".";
    for (auto it = tweens_.begin(); it != tweens_.end();) {
        if (it->id == id || it->id.compare(0, prefix.size(), prefix) == 0) {
            // cancel = jump to the end value (the framework deletes tweens
            // once their visual purpose is served, e.g. reveal done)
            for (auto &l : layers_) if (l.id == it->id) ApplyParam(l, it->param, it->to);
            it = tweens_.erase(it);
            ++revision_;
        } else {
            ++it;
        }
    }
}

bool Compositor::Update(double now_ms) {
    now_ms_ = now_ms;
    bool changed = false;
    for (auto it = tweens_.begin(); it != tweens_.end();) {
        Tween &tw = *it;
        const double since = now_ms - tw.start_ms;
        if (since < tw.delay_ms) { ++it; continue; }
        Layer *target = nullptr;
        for (auto &l : layers_) if (l.id == tw.id) { target = &l; break; }
        if (!target) { it = tweens_.erase(it); continue; }
        if (!tw.started) {
            tw.started = true;
            if (tw.from_current) {
                float cur = tw.to;
                if (ReadParam(*target, tw.param, &cur)) tw.from = cur;
            }
        }
        const double run = since - tw.delay_ms;
        float t = tw.time_ms > 0 ? static_cast<float>(run / tw.time_ms) : 1.0f;
        const bool done = t >= 1.0f;
        if (done) t = 1.0f;
        const float v = tw.from + (tw.to - tw.from) * ApplyEase(tw.ease, t);
        ApplyParam(*target, tw.param, v);
        changed = true;
        if (done) it = tweens_.erase(it); else ++it;
    }
    if (trans_active_) {
        if (now_ms - trans_start_ms_ >= trans_time_ms_) trans_active_ = false;
        changed = true;   // the overlay fades every frame (or just went away)
    }
    if (changed) ++revision_;
    return changed;
}

double Compositor::PendingAnimationMs(double now_ms) const {
    double remain = 0;
    for (const Tween &tw : tweens_) {
        const double end = tw.start_ms + tw.delay_ms + tw.time_ms;
        if (end - now_ms > remain) remain = end - now_ms;
    }
    if (trans_active_) {
        const double end = trans_start_ms_ + trans_time_ms_;
        if (end - now_ms > remain) remain = end - now_ms;
    }
    return remain < 0 ? 0 : remain;
}

std::string Compositor::DescribeDrawList(size_t max_layers) const {
    std::vector<const Layer *> sorted;
    for (const auto &l : layers_) sorted.push_back(&l);
    std::stable_sort(sorted.begin(), sorted.end(), [](const Layer *a, const Layer *b) {
        const int c = ZCmp(a->id, b->id);
        if (c != 0) return c < 0;
        return SectionCount(a->id) < SectionCount(b->id);
    });
    std::string out = "layers=" + std::to_string(layers_.size()) +
                      " tweens=" + std::to_string(tweens_.size()) +
                      " trans=" + std::to_string(trans_active_ ? 1 : 0) + " |";
    size_t n = 0;
    for (const Layer *l : sorted) {
        float ex, ey, ew, eh, ea; bool ev;
        EffectiveRect(*l, &ex, &ey, &ew, &eh, &ea, &ev);
        if (!ev || !l->texture) continue;
        if (n++ >= max_layers) { out += " ..."; break; }
        char buf[160];
        std::snprintf(buf, sizeof(buf), " %s(%d,%d %dx%d a=%.2f)", l->id.c_str(), (int)ex, (int)ey,
                      (int)ew, (int)eh, ea);
        out += buf;
    }
    return out;
}

std::vector<std::string> Compositor::HitLayers(float x, float y) const {
    std::vector<const Layer *> hits;
    for (const auto &l : layers_) {
        float ex, ey, ew, eh, ea; bool ev;
        EffectiveRect(l, &ex, &ey, &ew, &eh, &ea, &ev);
        if (!ev || !l.texture) continue;
        if (x < std::min(ex, ex + ew) || y < std::min(ey, ey + eh) ||
            x >= std::max(ex, ex + ew) || y >= std::max(ey, ey + eh)) continue;
        hits.push_back(&l);
    }
    // topmost first: higher z (ZCmp) then deeper id wins
    std::stable_sort(hits.begin(), hits.end(), [](const Layer *a, const Layer *b) {
        const int c = ZCmp(a->id, b->id);
        if (c != 0) return c > 0;
        return SectionCount(a->id) > SectionCount(b->id);
    });
    std::vector<std::string> ids;
    ids.reserve(hits.size());
    for (const Layer *l : hits) ids.push_back(l->id);
    return ids;
}

Compositor::LayerInfo Compositor::GetLayerInfo(const std::string &id) const {
    LayerInfo info;
    for (const auto &l : layers_) {
        if (l.id != id) continue;
        info.found = true;
        info.left = l.x;
        info.top = l.y;
        info.width = l.w;
        info.height = l.h;
        info.draggable = l.draggable;
        info.has_dragarea = l.has_dragarea;
        info.drag_l = l.drag_l;
        info.drag_t = l.drag_t;
        info.drag_r = l.drag_r;
        info.drag_b = l.drag_b;
        break;
    }
    return info;
}

void Compositor::DumpRects() {
    for (const Layer &l : layers_) {
        if (!l.visible || !l.texture) continue;
        if (!dumped_.insert(l.id).second) continue;
        float ex, ey, ea; bool ev;
        EffectiveRect(l, &ex, &ey, &ea, &ev);
        if (!ev) continue;
        Log(kLogInfo, "rect: " + l.id + " x=" + std::to_string(ex) +
                          " y=" + std::to_string(ey) + " w=" + std::to_string(l.w) +
                          " h=" + std::to_string(l.h) + " z=" + std::to_string(l.z) +
                          " a=" + std::to_string(ea));
    }
}

#if defined(ARTC_HAS_GLES)

namespace {
const char *kVs = R"(attribute vec2 a_pos;
attribute vec2 a_uv;
uniform vec2 u_screen;
varying vec2 v_uv;
void main() {
    vec2 clip = vec2(a_pos.x / u_screen.x * 2.0 - 1.0,
                     1.0 - a_pos.y / u_screen.y * 2.0);
    gl_Position = vec4(clip, 0.0, 1.0);
    v_uv = a_uv;
})";

const char *kFs = R"(precision mediump float;
varying vec2 v_uv;
uniform sampler2D u_tex;
uniform float u_alpha;
void main() {
    vec4 c = texture2D(u_tex, v_uv);
    gl_FragColor = vec4(c.rgb, c.a * u_alpha);
})";

// KrKr2-Next: [trans] overlay — the previous frame fades out over the new
// layer state. Plain fade uses u_t; rule transitions threshold the rule
// image (dark pixels change first) with a `vague` soft edge.
const char *kTransFs = R"(precision mediump float;
varying vec2 v_uv;
uniform sampler2D u_tex;
uniform sampler2D u_rule;
uniform float u_t;
uniform float u_vague;
uniform int u_use_rule;
void main() {
    vec4 c = texture2D(u_tex, v_uv);
    float a;
    if (u_use_rule == 1) {
        float r = texture2D(u_rule, vec2(v_uv.x, 1.0 - v_uv.y)).r;
        float edge = mix(-u_vague, 1.0 + u_vague, u_t);
        a = smoothstep(edge - u_vague, edge + u_vague, r);
    } else {
        a = 1.0 - u_t;
    }
    gl_FragColor = vec4(c.rgb, c.a * a);
})";

// Artemis layer ids sort by their leading integer ("600.4.0" → 600,
// "1.80.mw" → 1, "-273" → -273); non-numeric ids keep insertion order.
uint32_t CompileShader(uint32_t type, const char *src) {
    uint32_t s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    return s;
}
} // namespace

bool Compositor::InitGl() {
    if (gl_ready_) return true;
    prog_.program = glCreateProgram();
    uint32_t vs = CompileShader(GL_VERTEX_SHADER, kVs);
    uint32_t fs = CompileShader(GL_FRAGMENT_SHADER, kFs);
    glAttachShader(prog_.program, vs);
    glAttachShader(prog_.program, fs);
    glLinkProgram(prog_.program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    prog_.a_pos = glGetAttribLocation(prog_.program, "a_pos");
    prog_.a_uv = glGetAttribLocation(prog_.program, "a_uv");
    prog_.u_screen = glGetUniformLocation(prog_.program, "u_screen");
    prog_.u_tex = glGetUniformLocation(prog_.program, "u_tex");
    prog_.u_alpha = glGetUniformLocation(prog_.program, "u_alpha");

    tprog_.program = glCreateProgram();
    uint32_t tvs = CompileShader(GL_VERTEX_SHADER, kVs);
    uint32_t tfs = CompileShader(GL_FRAGMENT_SHADER, kTransFs);
    glAttachShader(tprog_.program, tvs);
    glAttachShader(tprog_.program, tfs);
    glLinkProgram(tprog_.program);
    glDeleteShader(tvs);
    glDeleteShader(tfs);
    tprog_.a_pos = glGetAttribLocation(tprog_.program, "a_pos");
    tprog_.a_uv = glGetAttribLocation(tprog_.program, "a_uv");
    tprog_.u_screen = glGetUniformLocation(tprog_.program, "u_screen");
    tprog_.u_tex = glGetUniformLocation(tprog_.program, "u_tex");
    tprog_.u_rule = glGetUniformLocation(tprog_.program, "u_rule");
    tprog_.u_t = glGetUniformLocation(tprog_.program, "u_t");
    tprog_.u_vague = glGetUniformLocation(tprog_.program, "u_vague");
    tprog_.u_use_rule = glGetUniformLocation(tprog_.program, "u_use_rule");
    gl_ready_ = true;
    return true;
}

// Copy the composited stage (the current viewport) into last_frame_tex_ so
// the next [trans] can fade it out. GPU-side copy; nothing is read back.
void Compositor::CaptureFrame() {
    if (!gl_ready_ || !scene_fbo_) return;
    GLint previous_fbo = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previous_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, scene_fbo_);
    glActiveTexture(GL_TEXTURE0);
    if (!last_frame_tex_) {
        glGenTextures(1, &last_frame_tex_);
        glBindTexture(GL_TEXTURE_2D, last_frame_tex_);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    } else {
        glBindTexture(GL_TEXTURE_2D, last_frame_tex_);
    }
    // GLES2 rejects copying more components than the framebuffer stores:
    // pick RGB when the surface has no alpha plane.
    glGetError();   // clear any stale error before the copy
    glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 0, 0, stage_w_, stage_h_, 0);
    trans_have_frame_ = glGetError() == GL_NO_ERROR;
    glBindFramebuffer(GL_FRAMEBUFFER, previous_fbo);
}

bool Compositor::BeginTransition(double now_ms, int time_ms, const std::vector<uint8_t> &rule,
                                 int rule_w, int rule_h, int vague) {
    // Window back buffers are undefined after eglSwapBuffers. The retained
    // scene remains valid on Android, OHOS and pbuffer hosts alike.
    CaptureFrame();
    if (!gl_ready_ || time_ms <= 0 || !trans_have_frame_) return false;
    if (trans_rule_tex_) { glDeleteTextures(1, &trans_rule_tex_); trans_rule_tex_ = 0; }
    if (!rule.empty() && rule_w > 0 && rule_h > 0 &&
        rule.size() >= static_cast<size_t>(rule_w) * rule_h) {
        // expand 8-bit rule to RGBA (GLES2 has no single-channel float path
        // worth the trouble; LUMINANCE would also work)
        std::vector<uint8_t> rgba(static_cast<size_t>(rule_w) * rule_h * 4);
        for (size_t i = 0; i < static_cast<size_t>(rule_w) * rule_h; ++i) {
            rgba[i * 4 + 0] = rgba[i * 4 + 1] = rgba[i * 4 + 2] = rule[i];
            rgba[i * 4 + 3] = 255;
        }
        trans_rule_tex_ = CreateTexture(rgba.data(), rule_w, rule_h);
    }
    trans_vague_ = vague < 0 ? 0 : (vague > 255 ? 1.0f : vague / 255.0f);
    trans_start_ms_ = now_ms;
    trans_time_ms_ = time_ms;
    trans_active_ = true;
    ++revision_;
    return true;
}

void Compositor::DrawTransitionOverlay() {
    if (!trans_active_ || !last_frame_tex_) return;
    float t = trans_time_ms_ > 0 ? static_cast<float>((now_ms_ - trans_start_ms_) / trans_time_ms_) : 1.0f;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    glUseProgram(tprog_.program);
    glUniform2f(tprog_.u_screen, (float)stage_w_, (float)stage_h_);
    glUniform1i(tprog_.u_tex, 0);
    glUniform1i(tprog_.u_rule, 1);
    glUniform1f(tprog_.u_t, t);
    glUniform1f(tprog_.u_vague, trans_vague_ > 0.002f ? trans_vague_ : 0.002f);
    glUniform1i(tprog_.u_use_rule, trans_rule_tex_ ? 1 : 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, trans_rule_tex_ ? trans_rule_tex_ : last_frame_tex_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, last_frame_tex_);
    glEnable(GL_BLEND);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    // Captured frame rows are bottom-up: sample v=1 at the stage top.
    const float W = (float)stage_w_, H = (float)stage_h_;
    float verts[16] = {
        0, 0, 0, 1,   W, 0, 1, 1,
        0, H, 0, 0,   W, H, 1, 0,
    };
    glVertexAttribPointer(tprog_.a_pos, 2, GL_FLOAT, GL_FALSE, 16, verts);
    glEnableVertexAttribArray(tprog_.a_pos);
    glVertexAttribPointer(tprog_.a_uv, 2, GL_FLOAT, GL_FALSE, 16, verts + 2);
    glEnableVertexAttribArray(tprog_.a_uv);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisable(GL_BLEND);
    glUseProgram(prog_.program);
}

uint32_t Compositor::CreateTexture(const uint8_t *pixels, int w, int h) {
    uint32_t tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return tex;
}

bool Compositor::LoadImage(const std::string &id, const std::string &file) {
    ++revision_;
    if (!gl_ready_ || !packs_) return false;
    // Scripts usually omit extensions (:bg/black); the real engine matches
    // packed assets by trying the common image extensions.
    static const char *kExtensions[] = {"", ".png", ".jpg", ".jpeg"};
    std::vector<uint8_t> bytes;
    std::string resolved;
    for (const char *ext : kExtensions) {
        resolved = file + ext;
        if (packs_->Read(resolved, bytes)) break;
    }
    if (bytes.empty()) {
        Log(kLogWarn, "lyc: image not found: " + file);
        return false;
    }
    int w, h, channels;
    uint8_t *pixels = stbi_load_from_memory(bytes.data(), (int)bytes.size(), &w, &h, &channels, 4);
    if (!pixels) {
        Log(kLogWarn, "lyc: decode failed: " + file);
        return false;
    }
    uint32_t tex = CreateTexture(pixels, w, h);
    stbi_image_free(pixels);

    // replace or create layer
    for (auto &l : layers_) {
        if (l.id == id) {
            if (l.texture) glDeleteTextures(1, &l.texture);
            l.texture = tex;
            l.tex_w = w; l.tex_h = h;
            l.content_x = l.content_y = 0;
            if (l.w == 0) { l.w = (float)w; l.h = (float)h; }
            Log(kLogDebug, "lyc: replaced " + id);
            return true;
        }
    }
    Layer l;
    l.id = id;
    l.texture = tex;
    l.tex_w = w; l.tex_h = h;
    l.w = (float)w; l.h = (float)h;
    l.z = 0;
    layers_.push_back(l);
    Log(kLogDebug, "lyc: added " + id + " " + std::to_string(w) + "x" + std::to_string(h));
    return true;
}

bool Compositor::LoadFont(const std::string &file) {
    if (!gl_ready_ || !packs_) return false;
    if (font_ready_ && file == font_path_) return true;
    std::vector<uint8_t> data;
    if (!packs_->Read(file, data)) {
        Log(kLogWarn, "font not found in packs: " + file);
        return false;
    }
    auto *info = new stbtt_fontinfo;
    const int offset = stbtt_GetFontOffsetForIndex(data.data(), 0);
    if (offset < 0 || !stbtt_InitFont(info, data.data(), offset)) {
        Log(kLogError, "font init failed: " + file);
        delete info;
        return false;
    }
    delete static_cast<stbtt_fontinfo *>(font_info_);
    font_data_ = std::move(data);
    font_path_ = file;
    font_info_ = info;
    font_ready_ = true;
    Log(kLogInfo, "font loaded: " + file + " (" + std::to_string(font_data_.size()) + " B)");
    return true;
}

bool Compositor::SetText(const std::string &id, const std::string &text,
                         float size, uint32_t color, float wrapWidth,
                         const std::map<std::string, std::string>& style) {
    ++revision_;
    if (text.empty()) {
        for (auto& l : layers_) if (l.id == id) {
            if (l.texture) glDeleteTextures(1, &l.texture);
            l.texture = 0;
            l.tex_w = l.tex_h = 0;
            l.w = l.h = 0;
        }
        return true;
    }
    if (!font_ready_) return false;
    auto *info = static_cast<stbtt_fontinfo *>(font_info_);
    const auto number = [&](const char* name, float fallback) {
        const auto it = style.find(name);
        return it == style.end() ? fallback : std::atof(it->second.c_str());
    };
    size = std::clamp(size, 1.0f, 256.0f);
    const float scale = stbtt_ScaleForMappingEmToPixels(info, size);
    const int outline = std::clamp(static_cast<int>(number("outline", 0)), 0, 8);
    const float tracking = number("kerning", 0);
    const auto alignment = style.find("align");
    const std::string align = alignment == style.end() ? "left" : alignment->second;
    const auto stroke = style.find("outlinecolor");
    const uint32_t outline_color = stroke == style.end() ? 0 :
        static_cast<uint32_t>(strtoul(stroke->second.c_str(), nullptr, 16));
    int ascent = 0, descent = 0, linegap = 0;
    stbtt_GetFontVMetrics(info, &ascent, &descent, &linegap);
    // CJK fonts often keep a much taller hhea clipping box than their
    // typographic em box. Using it as a baseline pushes centered button
    // captions below their scripted top and inflates every line's spacing.
    stbtt_GetFontVMetricsOS2(info, &ascent, &descent, &linegap);
    const float sascent = ascent * scale;
    const float sdescent = descent * scale;
    // spacemiddle separates the reserved ruby row from the main glyph row.
    // It is often negative; omitting rubysize makes adjacent lines overlap.
    const float ruby_row = std::max(0.0, number("rubysize", 0));
    const float row_top = number("spacetop", 0) + ruby_row + number("spacemiddle", 0);
    const int baseline = static_cast<int>(std::ceil(sascent + row_top)) + outline;
    const float advance_h = sascent - sdescent + linegap * scale +
        row_top + number("spacebottom", 0);

    // UTF-8 → codepoints → glyphs, then two-pass word layout:
    //   pass 1 measures every glyph's advance;
    //   pass 2 places them into lines, wrapping whenever pen_x would exceed
    //   wrapWidth (>0). Line width = max over the line; total height = #lines.
    std::vector<uint32_t> cps;
    for (size_t i = 0; i < text.size();) {
        const unsigned char c = text[i];
        uint32_t cp = c; int len = 1;
        if ((c & 0xE0) == 0xC0 && i + 1 < text.size()) { cp = c & 0x1F; len = 2; cp = (cp << 6) | (text[i + 1] & 0x3F); }
        else if ((c & 0xF0) == 0xE0 && i + 2 < text.size()) { cp = c & 0x0F; len = 3; cp = (cp << 6) | (text[i + 1] & 0x3F); cp = (cp << 6) | (text[i + 2] & 0x3F); }
        else if ((c & 0xF8) == 0xF0 && i + 3 < text.size()) { cp = c & 0x07; len = 4; cp = (cp << 6) | (text[i + 1] & 0x3F); cp = (cp << 6) | (text[i + 2] & 0x3F); cp = (cp << 6) | (text[i + 3] & 0x3F); }
        i += len; cps.push_back(cp);
    }
    std::vector<int> glyphs;
    std::vector<int> advances;
    glyphs.reserve(cps.size()); advances.reserve(cps.size());
    for (uint32_t cp : cps) {
        const int gi = stbtt_FindGlyphIndex(info, static_cast<int>(cp));
        int adv = 0, lsb = 0;
        stbtt_GetGlyphHMetrics(info, gi, &adv, &lsb);
        glyphs.push_back(gi);
        advances.push_back(static_cast<int>(std::lround(adv * scale + tracking)));
    }
    if (glyphs.empty()) return false;

    // layout: (line, pen_x_in_line)
    std::vector<int> lx(glyphs.size()), ly(glyphs.size());
    std::vector<int> line_w(1, 0);
    int pen = 0, line = 0;
    for (size_t k = 0; k < glyphs.size(); ++k) {
        if (cps[k] == '\r') { lx[k] = -1; continue; }
        if (cps[k] == '\n') { lx[k] = -1; pen = 0; ++line; line_w.push_back(0); continue; }
        if (pen > 0 && wrapWidth > 0 && pen + advances[k] > wrapWidth) {
            pen = 0; ++line; line_w.push_back(0);
        }
        lx[k] = pen; ly[k] = line;
        pen += advances[k];
        if (line_w[line] < pen) line_w[line] = pen;
    }
    const int n_lines = static_cast<int>(line_w.size());
    int tex_w = 0;
    for (int w : line_w) tex_w = w > tex_w ? w : tex_w;
    if (wrapWidth > 0) tex_w = std::max(tex_w, static_cast<int>(std::ceil(wrapWidth)));
    tex_w += outline * 2;
    if (tex_w <= 0 || tex_w > 4096) {
        Log(kLogWarn, "SetText: degenerate width " + std::to_string(tex_w));
        return false;
    }
    const int line_h = std::max(1, static_cast<int>(std::ceil(advance_h)));
    int bottom = line_h * n_lines + outline * 2;
    for (size_t k = 0; k < glyphs.size(); ++k) {
        if (lx[k] < 0) continue;
        int x0, y0, x1, y1;
        stbtt_GetGlyphBitmapBox(info, glyphs[k], scale, scale, &x0, &y0, &x1, &y1);
        bottom = std::max(bottom, baseline + ly[k] * line_h + y1 + outline);
    }
    const int tex_h = bottom;
    if (tex_h <= 0 || tex_h > 4096) return false;

    std::vector<uint8_t> coverage(static_cast<size_t>(tex_w) * tex_h, 0);
    std::vector<uint8_t> rgba(coverage.size() * 4, 0);
    for (size_t k = 0; k < glyphs.size(); ++k) {
        if (lx[k] < 0) continue;
        int gw = 0, gh = 0, xoff = 0, yoff = 0;
        uint8_t* bmp = stbtt_GetGlyphBitmap(info, scale, scale, glyphs[k], &gw, &gh, &xoff, &yoff);
        if (!bmp) continue;
        const int free_width = tex_w - outline * 2 - line_w[ly[k]];
        const int shift = align == "center" ? free_width / 2 : (align == "right" ? free_width : 0);
        const int dx0 = lx[k] + xoff + outline + shift;
        const int dy0 = baseline + ly[k] * line_h + yoff;
        for (int row = 0; row < gh; ++row) {
            const int dy = dy0 + row;
            if (dy < 0 || dy >= tex_h) continue;
            for (int col = 0; col < gw; ++col) {
                const int dx = dx0 + col;
                if (dx < 0 || dx >= tex_w) continue;
                auto& cov = coverage[static_cast<size_t>(dy) * tex_w + dx];
                cov = std::max(cov, bmp[row * gw + col]);
            }
        }
        stbtt_FreeBitmap(bmp, nullptr);
    }
    for (int y = 0; y < tex_h; ++y) for (int x = 0; x < tex_w; ++x) {
        const size_t offset = static_cast<size_t>(y) * tex_w + x;
        const float fill = coverage[offset] / 255.0f;
        uint8_t border = 0;
        if (outline) for (int oy = -outline; oy <= outline; ++oy)
            for (int ox = -outline; ox <= outline; ++ox) {
                const int xx = x + ox, yy = y + oy;
                if (xx >= 0 && xx < tex_w && yy >= 0 && yy < tex_h && ox * ox + oy * oy <= outline * outline)
                    border = std::max(border, coverage[static_cast<size_t>(yy) * tex_w + xx]);
            }
        const float edge = (border / 255.0f) * (1 - fill);
        const float alpha = fill + edge;
        if (!alpha) continue;
        for (int component = 0; component < 3; ++component) {
            const int shift = (2 - component) * 8;
            rgba[offset * 4 + component] = static_cast<uint8_t>(
                (((color >> shift) & 255) * fill + ((outline_color >> shift) & 255) * edge) / alpha);
        }
        rgba[offset * 4 + 3] = static_cast<uint8_t>(std::lround(alpha * 255));
    }

    const uint32_t tex = CreateTexture(rgba.data(), tex_w, tex_h);

    // upsert layer; message-layer default position = bottom-left
    for (auto &l : layers_) {
        if (l.id == id) {
            if (l.texture) glDeleteTextures(1, &l.texture);
            l.texture = tex;
            l.tex_w = tex_w; l.tex_h = tex_h;
            // The placeholder layer may carry a degenerate (0-sized) rect
            // from its ghost creation — the new raster defines the display
            // size, otherwise the quad collapses and nothing is drawn.
            l.w = (float)tex_w;
            l.h = (float)tex_h;
            l.content_x = number("left", 0);
            l.content_y = number("top", 0);
            Log(kLogInfo, "SetText: replaced " + id + " " +
                              std::to_string(tex_w) + "x" + std::to_string(tex_h));
            return true;
        }
    }
    Layer l;
    l.id = id;
    l.texture = tex;
    l.tex_w = tex_w; l.tex_h = tex_h;
    l.w = (float)tex_w; l.h = (float)tex_h;
    l.content_x = number("left", 0);
    l.content_y = number("top", 0);
    l.z = 100; // above scene layers
    layers_.push_back(l);
    Log(kLogInfo, "SetText: " + id + " " + std::to_string(tex_w) + "x" +
                      std::to_string(tex_h) + " '" + text.substr(0, 24) + "'");
    return true;
}

void Compositor::SetProps(const std::string &id,
                          const std::map<std::string, std::string> &attrs) {
    ++revision_;
    for (auto &l : layers_) {
        if (l.id != id) continue;
        for (const auto &kv : attrs) {
            if (kv.first == "x" || kv.first == "left") { l.x = std::stof(kv.second); l.own_pos = true; }
            else if (kv.first == "y" || kv.first == "top") { l.y = std::stof(kv.second); l.own_pos = true; }
            else if (kv.first == "w") l.w = std::stof(kv.second);
            else if (kv.first == "h") l.h = std::stof(kv.second);
            else if (kv.first == "alpha") {
                const float a = std::stof(kv.second);
                l.alpha = std::clamp(a / 255.0f, 0.0f, 1.0f);   // script uses 0-255
            }
            else if (kv.first == "anchorx") l.ax = std::stof(kv.second);
            else if (kv.first == "xscale") { const float v = std::stof(kv.second); l.sx = v / 100.0f; }
            else if (kv.first == "yscale") { const float v = std::stof(kv.second); l.sy = v / 100.0f; }
            else if (kv.first == "ownpos") l.own_pos = true;
            else if (kv.first == "anchory") l.ay = std::stof(kv.second);
            else if (kv.first == "visible") l.visible = (kv.second != "0");
            else if (kv.first == "z") l.z = std::stoi(kv.second);
            else if (kv.first == "draggable") l.draggable = (kv.second != "0");
            else if (kv.first == "dragarea") {
                // {left, top, right, bottom} — offsets in stage units
                if (std::sscanf(kv.second.c_str(), "%f,%f,%f,%f",
                                &l.drag_l, &l.drag_t, &l.drag_r, &l.drag_b) == 4) {
                    l.has_dragarea = true;
                }
            }
            else if (kv.first == "clip") {
                // "x,y,w,h" → normalized UV crop
                int cx = 0, cy = 0, cw = 0, chh = 0;
                if (std::sscanf(kv.second.c_str(), "%d,%d,%d,%d", &cx, &cy, &cw, &chh) == 4 &&
                    l.tex_w > 0 && l.tex_h > 0 && cw > 0 && chh > 0) {
                    l.u0 = (float)cx / l.tex_w;      l.v0 = (float)cy / l.tex_h;
                    l.u1 = (float)(cx + cw) / l.tex_w; l.v1 = (float)(cy + chh) / l.tex_h;
                    l.w = (float)cw;   // clip defines the displayed sub-image size
                    l.h = (float)chh;
                }
            }
        }
        l.z = 0;   // leading id number is the authoritative z
        return;
    }
    // lyprop may target a pure group layer never created by lyc — materialize
    // it as a texture-less holder so children inherit its transform.
    Layer g;
    g.id = id;
    g.visible = true;
    g.z = 0;
    layers_.push_back(g);
    SetProps(id, attrs);
}

void Compositor::DeleteLayer(const std::string &id) {
    ++revision_;
    // group delete: an id names the whole subtree (artemis groups layers as
    // "500.d.1.0", "500.z.*", ...; scripts delete the parent "500" only).
    const std::string prefix = id + ".";
    for (auto it = layers_.begin(); it != layers_.end();) {
        if (it->id == id ||
            it->id.compare(0, prefix.size(), prefix) == 0) {
            if (it->texture) glDeleteTextures(1, &it->texture);
            it = layers_.erase(it);
        } else {
            ++it;
        }
    }
}

void Compositor::ReleaseGl() {
    ++revision_;
    for (auto &l : layers_) {
        if (l.texture) glDeleteTextures(1, &l.texture);
    }
    layers_.clear();
    tweens_.clear();
    if (trans_rule_tex_) { glDeleteTextures(1, &trans_rule_tex_); trans_rule_tex_ = 0; }
    if (last_frame_tex_) { glDeleteTextures(1, &last_frame_tex_); last_frame_tex_ = 0; }
    if (scene_fbo_) { glDeleteFramebuffers(1, &scene_fbo_); scene_fbo_ = 0; }
    if (scene_tex_) { glDeleteTextures(1, &scene_tex_); scene_tex_ = 0; }
    if (prog_.program) { glDeleteProgram(prog_.program); prog_.program = 0; }
    if (tprog_.program) { glDeleteProgram(tprog_.program); tprog_.program = 0; }
    trans_active_ = false;
    trans_have_frame_ = false;
    gl_ready_ = false;
}

void Compositor::Shutdown() {
    ReleaseGl();
    delete static_cast<stbtt_fontinfo *>(font_info_);
    font_info_ = nullptr;
    font_data_.clear();
    font_path_.clear();
    font_ready_ = false;
    present_cb_ = nullptr;
}

void Compositor::Draw() {
    if (!gl_ready_) return;

    GLint target = 0, viewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &target);
    glGetIntegerv(GL_VIEWPORT, viewport);
    if (!scene_fbo_) {
        glGenTextures(1, &scene_tex_);
        glBindTexture(GL_TEXTURE_2D, scene_tex_);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, stage_w_, stage_h_, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glGenFramebuffers(1, &scene_fbo_);
        glBindFramebuffer(GL_FRAMEBUFFER, scene_fbo_);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, scene_tex_, 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            Log(kLogError, "compositor: scene framebuffer incomplete");
            glDeleteFramebuffers(1, &scene_fbo_); scene_fbo_ = 0;
            glDeleteTextures(1, &scene_tex_); scene_tex_ = 0;
            glBindFramebuffer(GL_FRAMEBUFFER, target);
            return;
        }
    }
    glBindFramebuffer(GL_FRAMEBUFFER, scene_fbo_);
    glViewport(0, 0, stage_w_, stage_h_);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    // sort by z (stable: preserve insertion order for equal z)
    std::vector<const Layer *> sorted;
    for (const auto &l : layers_) sorted.push_back(&l);
    std::stable_sort(sorted.begin(), sorted.end(),
                     [](const Layer *a, const Layer *b) {
                         const int c = ZCmp(a->id, b->id);
                         if (c != 0) return c < 0;   // ascending: lower z first
                         return SectionCount(a->id) < SectionCount(b->id);
                     });

    glUseProgram(prog_.program);
    glUniform2f(prog_.u_screen, (float)stage_w_, (float)stage_h_);
    glUniform1i(prog_.u_tex, 0);
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_BLEND);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    for (const Layer *l : sorted) {
        float ex, ey, ew, eh, ea; bool ev;
        EffectiveRect(*l, &ex, &ey, &ew, &eh, &ea, &ev);
        if (!ev || !l->texture) continue;
        glBindTexture(GL_TEXTURE_2D, l->texture);
        glUniform1f(prog_.u_alpha, ea);
        float x0 = ex, y0 = ey, x1 = ex + ew, y1 = ey + eh;
        // interleaved: x, y, u, v per vertex (triangle strip)
        float verts[16] = {
            x0, y0, l->u0, l->v0,   x1, y0, l->u1, l->v0,
            x0, y1, l->u0, l->v1,   x1, y1, l->u1, l->v1,
        };
        glVertexAttribPointer(prog_.a_pos, 2, GL_FLOAT, GL_FALSE, 16, verts);
        glEnableVertexAttribArray(prog_.a_pos);
        glVertexAttribPointer(prog_.a_uv, 2, GL_FLOAT, GL_FALSE, 16, verts + 2);
        glEnableVertexAttribArray(prog_.a_uv);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    // Device-side draw ground truth: every 300 frames dump what actually
    // rendered (drawn/total + first samples with effective rects) so layout
    // bugs are observable from logcat alone.
    static int diag_frames = 0;
    if (++diag_frames % 300 == 1) {
        int drawn = 0, ghost = 0;
        std::string sample;
        for (const Layer *l : sorted) {
            float dx, dy, da; bool dv;
            EffectiveRect(*l, &dx, &dy, &da, &dv);
            if (!dv) continue;
            if (!l->texture) { ++ghost; continue; }
            ++drawn;
            if (drawn <= 16)
                sample += " " + l->id + "(" + std::to_string((int)dx) + "," +
                          std::to_string((int)dy) + " " +
                          std::to_string((int)l->w) + "x" +
                          std::to_string((int)l->h) + " z" +
                          std::to_string(l->z) + ")";
        }
        Log(kLogInfo, "draw[" + std::to_string(diag_frames) + "]: drawn=" +
                          std::to_string(drawn) + " ghost=" +
                          std::to_string(ghost) + "/" +
                          std::to_string(sorted.size()) + sample);
    }
    glDisable(GL_BLEND);
    // Fade the previous scene out on top of the new state. The "from"
    // texture is captured once in BeginTransition (pbuffer still holds
    // the last Present). Copying the full stage every Draw was a GPU
    // sync we do not need for idle frames.
    DrawTransitionOverlay();
    glBindFramebuffer(GL_FRAMEBUFFER, target);
    glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
    glUseProgram(prog_.program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, scene_tex_);
    glUniform1f(prog_.u_alpha, 1);
    const float w = float(stage_w_), h = float(stage_h_);
    const float screen[16] = {0,0,0,1, w,0,1,1, 0,h,0,0, w,h,1,0};
    glVertexAttribPointer(prog_.a_pos, 2, GL_FLOAT, GL_FALSE, 16, screen);
    glEnableVertexAttribArray(prog_.a_pos);
    glVertexAttribPointer(prog_.a_uv, 2, GL_FLOAT, GL_FALSE, 16, screen + 2);
    glEnableVertexAttribArray(prog_.a_uv);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    // [flip]: the composed frame is now the presentation candidate
    if (present_cb_) present_cb_();
}

void Compositor::Init(int stage_w, int stage_h) {
    stage_w_ = stage_w;
    stage_h_ = stage_h;
    InitGl();
}

#else // host stubs — no GL; keep layer math (rects / z / hit-test) functional
      // so `artc drive` can trace and click real UI without a GPU.

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

bool Compositor::InitGl() { return false; }
// A non-zero fake handle keeps Layer::texture a valid "has pixels" flag for
// HitLayer/DumpRects; no GL object is created on the host.
constexpr uint32_t kHostTexture = 0xFFFFFFFFu;

uint32_t Compositor::CreateTexture(const uint8_t *, int, int) { return 0; }
bool Compositor::LoadImage(const std::string &id, const std::string &file) {
    ++revision_;
    if (!packs_) return false;
    static const char *kExtensions[] = {"", ".png", ".jpg", ".jpeg"};
    std::vector<uint8_t> bytes;
    std::string resolved;
    for (const char *ext : kExtensions) {
        resolved = file + ext;
        if (packs_->Read(resolved, bytes)) break;
    }
    if (bytes.empty()) {
        Log(kLogWarn, "lyc: image not found: " + file);
        return false;
    }
    int w = 0, h = 0, channels = 0;
    uint8_t *pixels = stbi_load_from_memory(bytes.data(), (int)bytes.size(),
                                            &w, &h, &channels, 4);
    if (!pixels) {
        Log(kLogWarn, "lyc: decode failed: " + file);
        return false;
    }
    stbi_image_free(pixels);
    for (auto &l : layers_) {
        if (l.id == id) {
            l.texture = kHostTexture;
            l.tex_w = w; l.tex_h = h;
            l.content_x = l.content_y = 0;
            if (l.w == 0) { l.w = (float)w; l.h = (float)h; }
            return true;
        }
    }
    Layer l;
    l.id = id;
    l.texture = kHostTexture;
    l.tex_w = w; l.tex_h = h;
    l.w = (float)w; l.h = (float)h;
    l.z = 0;
    layers_.push_back(l);
    return true;
}
void Compositor::SetProps(const std::string &id,
                          const std::map<std::string, std::string> &attrs) {
    ++revision_;
    for (auto &l : layers_) {
        if (l.id != id) continue;
        for (const auto &kv : attrs) {
            if (kv.first == "x" || kv.first == "left") { l.x = std::stof(kv.second); l.own_pos = true; }
            else if (kv.first == "y" || kv.first == "top") { l.y = std::stof(kv.second); l.own_pos = true; }
            else if (kv.first == "w") l.w = std::stof(kv.second);
            else if (kv.first == "h") l.h = std::stof(kv.second);
            else if (kv.first == "alpha") {
                const float a = std::stof(kv.second);
                l.alpha = std::clamp(a / 255.0f, 0.0f, 1.0f);
            }
            else if (kv.first == "anchorx") l.ax = std::stof(kv.second);
            else if (kv.first == "xscale") { const float v = std::stof(kv.second); l.sx = v / 100.0f; }
            else if (kv.first == "yscale") { const float v = std::stof(kv.second); l.sy = v / 100.0f; }
            else if (kv.first == "ownpos") l.own_pos = true;
            else if (kv.first == "anchory") l.ay = std::stof(kv.second);
            else if (kv.first == "visible") l.visible = (kv.second != "0");
            else if (kv.first == "z") l.z = std::stoi(kv.second);
            else if (kv.first == "draggable") l.draggable = (kv.second != "0");
            else if (kv.first == "dragarea") {
                if (std::sscanf(kv.second.c_str(), "%f,%f,%f,%f",
                                &l.drag_l, &l.drag_t, &l.drag_r, &l.drag_b) == 4) {
                    l.has_dragarea = true;
                }
            }
            else if (kv.first == "clip") {
                int cx = 0, cy = 0, cw = 0, chh = 0;
                if (std::sscanf(kv.second.c_str(), "%d,%d,%d,%d", &cx, &cy, &cw, &chh) == 4 &&
                    l.tex_w > 0 && l.tex_h > 0 && cw > 0 && chh > 0) {
                    l.u0 = (float)cx / l.tex_w;      l.v0 = (float)cy / l.tex_h;
                    l.u1 = (float)(cx + cw) / l.tex_w; l.v1 = (float)(cy + chh) / l.tex_h;
                    l.w = (float)cw;
                    l.h = (float)chh;
                }
            }
        }
        l.z = 0;
        return;
    }
    // texture-less ghost layer for pure transform holders
    Layer g;
    g.id = id;
    g.visible = true;
    g.z = 0;
    layers_.push_back(g);
    SetProps(id, attrs);
}
void Compositor::DeleteLayer(const std::string &id) {
    ++revision_;
    // group delete: an id names the whole subtree (artemis groups layers as
    // "500.d.1.0", "500.z.*", ...; scripts delete the parent "500" only).
    const std::string prefix = id + ".";
    for (auto it = layers_.begin(); it != layers_.end();) {
        if (it->id == id ||
            it->id.compare(0, prefix.size(), prefix) == 0) {
            it = layers_.erase(it);
        } else {
            ++it;
        }
    }
}
bool Compositor::LoadFont(const std::string &file) {
    Log(kLogInfo, "font (host, no raster): " + file);
    return false;
}
bool Compositor::SetText(const std::string &id, const std::string &text,
                         float size, uint32_t color, float wrapWidth,
                         const std::map<std::string, std::string>& style) {
    ++revision_;
    if (text.empty()) return false;
    (void)color;   // host mock ignores the baked-in color (no rasterization)
    (void)wrapWidth;
    // fake-texture message layer: width ~ proportional to glyph count
    const int tw = std::max(1, static_cast<int>(size * text.size()));
    const int th = std::max(1, static_cast<int>(size * 1.5f));
    for (auto &l : layers_) {
        if (l.id == id) {
            l.texture = kHostTexture;
            l.tex_w = tw; l.tex_h = th;
            l.w = (float)tw; l.h = (float)th;
            Log(kLogInfo, "SetText: replaced " + id + " " + std::to_string(tw) + "x" +
                              std::to_string(th) + " '" + text.substr(0, 24) + "'");
            return true;
        }
    }
    Layer l;
    l.id = id;
    l.texture = kHostTexture;
    l.tex_w = tw; l.tex_h = th;
    l.w = (float)tw; l.h = (float)th;
    l.x = 40.0f;
    l.y = (float)stage_h_ - (float)th - 60.0f;
    l.z = 100;
    layers_.push_back(l);
    Log(kLogInfo, "SetText: " + id + " " + std::to_string(tw) + "x" +
                      std::to_string(th) + " '" + text.substr(0, 24) + "'");
    return true;
}
void Compositor::Shutdown() { layers_.clear(); present_cb_ = nullptr; }
void Compositor::ReleaseGl() { ++revision_; layers_.clear(); tweens_.clear(); trans_active_ = false; gl_ready_ = false; }
void Compositor::CaptureFrame() {}
void Compositor::DrawTransitionOverlay() {}
bool Compositor::BeginTransition(double now_ms, int time_ms, const std::vector<uint8_t> &,
                                 int, int, int) {
    if (time_ms <= 0) return false;
    trans_start_ms_ = now_ms; trans_time_ms_ = time_ms; trans_active_ = true; ++revision_;
    return true;
}
void Compositor::Draw() {}
void Compositor::Init(int stage_w, int stage_h) {
    stage_w_ = stage_w;
    stage_h_ = stage_h;
}

#endif

} // namespace artc
