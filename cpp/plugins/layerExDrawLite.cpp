// layerExDrawLite — software subset of the layerExDraw (GdiPlus) plugin.
//
// The real plugin (layerex_draw/) is built on libgdiplus, which is not
// provisioned for OHOS. KAG/KAGEX games nevertheless `Plugins.link(
// "layerExDraw.dll")` and use `GdiPlus.Appearance` + `Layer.drawPolygon`
// & co. for UI chrome (frames, sliders, resize grips). This file provides
// the same TJS surface for the vector primitives, rasterized directly into
// the layer's 32bpp buffer with a scanline coverage filler. Text, images,
// gradients and hatch patterns are approximated (solid colour) or logged
// as unsupported instead of throwing, so scripts keep running.

#define NCB_MODULE_NAME TJS_W("layerExDraw.dll")

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

#include <spdlog/spdlog.h>

#include "ncbind.hpp"
#include "layerExBase.hpp"

namespace {

struct Pt {
    double x, y;
};

using Poly = std::vector<Pt>;

struct RectD {
    double x0 = 1e300, y0 = 1e300, x1 = -1e300, y1 = -1e300;
    void add(const Pt &p) {
        x0 = std::min(x0, p.x);
        y0 = std::min(y0, p.y);
        x1 = std::max(x1, p.x);
        y1 = std::max(y1, p.y);
    }
    void add(const RectD &r) {
        if(r.empty())
            return;
        x0 = std::min(x0, r.x0);
        y0 = std::min(y0, r.y0);
        x1 = std::max(x1, r.x1);
        y1 = std::max(y1, r.y1);
    }
    [[nodiscard]] bool empty() const { return x1 < x0 || y1 < y0; }
};

bool IsArrayVariant(const tTJSVariant &var) {
    if(var.Type() != tvtObject)
        return false;
    iTJSDispatch2 *obj = var.AsObjectNoAddRef();
    return obj != nullptr &&
        obj->IsInstanceOf(0, nullptr, nullptr, TJS_W("Array"), obj) == TJS_S_TRUE;
}

Pt ReadPoint(const tTJSVariant &var) {
    if(var.Type() != tvtObject)
        return { 0, 0 };
    ncbPropAccessor info(var);
    if(IsArrayVariant(var))
        return { info.getRealValue(0), info.getRealValue(1) };
    return { info.getRealValue(TJS_W("x")), info.getRealValue(TJS_W("y")) };
}

void ReadPoints(const tTJSVariant &var, Poly &out) {
    if(var.Type() != tvtObject)
        return;
    ncbPropAccessor info(var);
    const int n = info.GetArrayCount();
    for(int i = 0; i < n; ++i) {
        tTJSVariant p;
        if(info.checkVariant(i, p))
            out.push_back(ReadPoint(p));
    }
}

uint32_t AverageColor(uint32_t a, uint32_t b) {
    uint32_t r = 0;
    for(int s = 0; s < 32; s += 8) {
        const uint32_t ca = (a >> s) & 0xff, cb = (b >> s) & 0xff;
        r |= ((ca + cb) / 2) << s;
    }
    return r;
}

// Brush specs: an ARGB integer or a GdiPlus brush dictionary. Everything
// that is not a solid colour collapses to a representative solid colour.
uint32_t BrushColor(const tTJSVariant &spec) {
    if(spec.Type() != tvtObject)
        return (uint32_t)(tjs_int64)spec;
    ncbPropAccessor info(spec);
    const int type = info.getIntValue(TJS_W("type"), 0);
    switch(type) {
        case 1: // BrushTypeHatchFill
            return AverageColor(
                (uint32_t)info.getRealValue(TJS_W("foreColor"), 0xffffffff),
                (uint32_t)info.getRealValue(TJS_W("backColor"), 0xff000000));
        case 2: // BrushTypeTextureFill
            return 0xff808080;
        case 3: { // BrushTypePathGradient
            tTJSVariant colors;
            if(info.checkVariant(TJS_W("surroundColors"), colors) &&
               IsArrayVariant(colors)) {
                ncbPropAccessor arr(colors);
                if(arr.GetArrayCount() > 0)
                    return AverageColor(
                        (uint32_t)info.getRealValue(TJS_W("centerColor"),
                                                    0xffffffff),
                        (uint32_t)arr.getRealValue(0, 0xffffffff));
            }
            return (uint32_t)info.getRealValue(TJS_W("centerColor"), 0xffffffff);
        }
        case 4: // BrushTypeLinearGradient
            return AverageColor(
                (uint32_t)info.getRealValue(TJS_W("color1"), 0xffffffff),
                (uint32_t)info.getRealValue(TJS_W("color2"), 0xff000000));
        default:
            return (uint32_t)info.getRealValue(TJS_W("color"), 0xffffffff);
    }
}

// ---------------------------------------------------------------- Appearance

struct DrawStyle {
    bool pen = false;
    uint32_t argb = 0xffffffff;
    double width = 1.0;
    double ox = 0, oy = 0;
};

class LiteAppearance {
public:
    std::vector<DrawStyle> styles;

    void clear() { styles.clear(); }

    void addBrush(const tTJSVariant &spec, double ox, double oy) {
        DrawStyle s;
        s.pen = false;
        s.argb = BrushColor(spec);
        s.ox = ox;
        s.oy = oy;
        styles.push_back(s);
    }

    void addPen(const tTJSVariant &spec, const tTJSVariant &widthOrOption,
                double ox, double oy) {
        DrawStyle s;
        s.pen = true;
        s.argb = BrushColor(spec);
        if(widthOrOption.Type() == tvtObject) {
            ncbPropAccessor info(widthOrOption);
            s.width = info.getRealValue(TJS_W("width"), 1.0);
        } else if(widthOrOption.Type() != tvtVoid) {
            s.width = (double)widthOrOption;
        }
        if(s.width <= 0)
            s.width = 1.0;
        s.ox = ox;
        s.oy = oy;
        styles.push_back(s);
    }
};

tjs_error AppearanceAddBrush(tTJSVariant *, tjs_int numparams,
                             tTJSVariant **param, iTJSDispatch2 *objthis) {
    auto *self = ncbInstanceAdaptor<LiteAppearance>::GetNativeInstance(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    const double ox = numparams > 1 ? (double)*param[1] : 0.0;
    const double oy = numparams > 2 ? (double)*param[2] : 0.0;
    self->addBrush(*param[0], ox, oy);
    return TJS_S_OK;
}

tjs_error AppearanceAddPen(tTJSVariant *, tjs_int numparams,
                           tTJSVariant **param, iTJSDispatch2 *objthis) {
    auto *self = ncbInstanceAdaptor<LiteAppearance>::GetNativeInstance(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    tTJSVariant width;
    if(numparams > 1)
        width = *param[1];
    const double ox = numparams > 2 ? (double)*param[2] : 0.0;
    const double oy = numparams > 3 ? (double)*param[3] : 0.0;
    self->addPen(*param[0], width, ox, oy);
    return TJS_S_OK;
}

// ---------------------------------------------------------------- Font (stub)

class LiteFont {
public:
    LiteFont(const tjs_char *family, float emSize, int style) :
        familyName(family ? family : TJS_W("")), emSize(emSize), style(style) {}

    ttstr familyName;
    float emSize;
    int style;
    bool forceSelfPathDraw = false;

    [[nodiscard]] ttstr getFamilyName() const { return familyName; }
    void setFamilyName(const tjs_char *v) { familyName = v; }
    [[nodiscard]] float getEmSize() const { return emSize; }
    void setEmSize(float v) { emSize = v; }
    [[nodiscard]] int getStyle() const { return style; }
    void setStyle(int v) { style = v; }
    [[nodiscard]] bool getForceSelfPathDraw() const { return forceSelfPathDraw; }
    void setForceSelfPathDraw(bool v) { forceSelfPathDraw = v; }
    [[nodiscard]] float getAscent() const { return emSize * 0.88f; }
    [[nodiscard]] float getDescent() const { return emSize * 0.12f; }
    [[nodiscard]] float getAscentLeading() const { return 0; }
    [[nodiscard]] float getDescentLeading() const { return 0; }
    [[nodiscard]] float getLineSpacing() const { return emSize * 1.2f; }
};

// ---------------------------------------------------------------- Path

// Records the same primitives as Layer.draw*; `Layer.drawPath(app, path)`
// replays them. Stored already flattened to polygons.
class LitePath {
public:
    std::vector<Poly> figures;
    std::vector<bool> closed;
    Poly current;
    bool currentOpen = false;

    void startFigure() {
        flush(false);
        currentOpen = true;
    }
    void closeFigure() { flush(true); }
    void flush(bool close) {
        if(!current.empty()) {
            figures.push_back(current);
            closed.push_back(close);
        }
        current.clear();
        currentOpen = false;
    }
    void add(const Poly &poly, bool close) {
        if(currentOpen) {
            current.insert(current.end(), poly.begin(), poly.end());
            if(close)
                flush(true);
        } else {
            figures.push_back(poly);
            closed.push_back(close);
        }
    }
};

// ---------------------------------------------------------------- geometry

void FlattenBezier(const Pt &p0, const Pt &p1, const Pt &p2, const Pt &p3,
                   Poly &out) {
    constexpr int kSegs = 24;
    for(int i = 1; i <= kSegs; ++i) {
        const double t = (double)i / kSegs, u = 1 - t;
        const double b0 = u * u * u, b1 = 3 * u * u * t, b2 = 3 * u * t * t,
                     b3 = t * t * t;
        out.push_back({ b0 * p0.x + b1 * p1.x + b2 * p2.x + b3 * p3.x,
                        b0 * p0.y + b1 * p1.y + b2 * p2.y + b3 * p3.y });
    }
}

// GDI+ arc on the ellipse inscribed in (x, y, w, h); angles in degrees,
// clockwise with y pointing down.
void FlattenArc(double x, double y, double w, double h, double startDeg,
                double sweepDeg, Poly &out) {
    const double cx = x + w / 2, cy = y + h / 2, rx = w / 2, ry = h / 2;
    const int segs = std::max(8, (int)(std::fabs(sweepDeg) / 4.0));
    for(int i = 0; i <= segs; ++i) {
        const double a = (startDeg + sweepDeg * i / segs) * M_PI / 180.0;
        out.push_back({ cx + rx * std::cos(a), cy + ry * std::sin(a) });
    }
}

// Catmull-Rom style cardinal spline through the points (GDI+ DrawCurve).
void FlattenCurve(const Poly &pts, double tension, bool closed, Poly &out) {
    const size_t n = pts.size();
    if(n < 2) {
        out = pts;
        return;
    }
    auto at = [&](long i) -> const Pt & {
        if(closed) {
            i = ((i % (long)n) + (long)n) % (long)n;
        } else {
            i = std::clamp<long>(i, 0, (long)n - 1);
        }
        return pts[(size_t)i];
    };
    const long segs = closed ? (long)n : (long)n - 1;
    const double s = (1.0 - tension) / 2.0;
    out.push_back(pts[0]);
    for(long i = 0; i < segs; ++i) {
        const Pt &p0 = at(i - 1), &p1 = at(i), &p2 = at(i + 1), &p3 = at(i + 2);
        for(int k = 1; k <= 12; ++k) {
            const double t = k / 12.0, t2 = t * t, t3 = t2 * t;
            const double h1 = 2 * t3 - 3 * t2 + 1, h2 = -2 * t3 + 3 * t2,
                         h3 = t3 - 2 * t2 + t, h4 = t3 - t2;
            const double m1x = s * (p2.x - p0.x), m1y = s * (p2.y - p0.y);
            const double m2x = s * (p3.x - p1.x), m2y = s * (p3.y - p1.y);
            out.push_back({ h1 * p1.x + h2 * p2.x + h3 * m1x + h4 * m2x,
                            h1 * p1.y + h2 * p2.y + h3 * m1y + h4 * m2y });
        }
    }
}

// Widen a polyline into quads (one per segment) plus square joints; drawn
// with the non-zero rule so overlaps merge instead of double-blending.
void StrokeToPolys(const Poly &pts, bool closed, double width,
                   std::vector<Poly> &out) {
    const double hw = std::max(0.5, width / 2.0);
    const size_t n = pts.size();
    if(n == 0)
        return;
    if(n == 1) {
        const Pt &p = pts[0];
        out.push_back({ { p.x - hw, p.y - hw },
                        { p.x + hw, p.y - hw },
                        { p.x + hw, p.y + hw },
                        { p.x - hw, p.y + hw } });
        return;
    }
    const size_t segs = closed ? n : n - 1;
    for(size_t i = 0; i < segs; ++i) {
        const Pt &a = pts[i], &b = pts[(i + 1) % n];
        double dx = b.x - a.x, dy = b.y - a.y;
        const double len = std::hypot(dx, dy);
        if(len < 1e-9)
            continue;
        dx /= len;
        dy /= len;
        const double nx = -dy * hw, ny = dx * hw;
        out.push_back({ { a.x + nx, a.y + ny },
                        { b.x + nx, b.y + ny },
                        { b.x - nx, b.y - ny },
                        { a.x - nx, a.y - ny } });
    }
    if(hw > 1.0) {
        // joint caps so thick corners do not show notches
        const size_t joints = closed ? n : n - 2;
        for(size_t i = 0; i < joints; ++i) {
            const Pt &p = pts[(i + 1) % n];
            out.push_back({ { p.x - hw, p.y - hw },
                            { p.x + hw, p.y - hw },
                            { p.x + hw, p.y + hw },
                            { p.x - hw, p.y + hw } });
        }
    }
}

// ---------------------------------------------------------------- raster

struct Edge {
    double x0, y0, x1, y1;
    int dir;
};

inline void BlendPixel(uint32_t *p, uint32_t src, double cov) {
    const double sa = ((src >> 24) & 0xff) / 255.0 * cov;
    if(sa <= 0.0)
        return;
    const uint32_t d = *p;
    const double da = ((d >> 24) & 0xff) / 255.0;
    const double oa = sa + da * (1.0 - sa);
    if(oa <= 0.0) {
        *p = 0;
        return;
    }
    uint32_t out = (uint32_t)std::lround(oa * 255.0) << 24;
    for(int s = 0; s < 24; s += 8) {
        const double sc = (src >> s) & 0xff, dc = (d >> s) & 0xff;
        const double oc = (sc * sa + dc * da * (1.0 - sa)) / oa;
        out |= (uint32_t)std::clamp((long)std::lround(oc), 0L, 255L) << s;
    }
    *p = out;
}

class LayerExDrawLite : public layerExBase {
public:
    explicit LayerExDrawLite(DispatchT obj) : layerExBase(obj) {}

    bool updateWhenDraw = true;
    int smoothingMode = 0;
    int textRenderingHint = 0;
    bool textWarned = false;

    [[nodiscard]] bool getUpdateWhenDraw() const { return updateWhenDraw; }
    void setUpdateWhenDraw(bool v) { updateWhenDraw = v; }
    [[nodiscard]] int getSmoothingMode() const { return smoothingMode; }
    void setSmoothingMode(int v) { smoothingMode = v; }
    [[nodiscard]] int getTextRenderingHint() const { return textRenderingHint; }
    void setTextRenderingHint(int v) { textRenderingHint = v; }

    // Transforms are accepted and ignored (identity).
    void resetTransform() {}
    void resetViewTransform() {}

    void clear(uint32_t argb) {
        if(!_buffer)
            return;
        for(int y = 0; y < _clipHeight; ++y) {
            auto *row = reinterpret_cast<uint32_t *>(
                _buffer + (size_t)(_clipTop + y) * _pitch) + _clipLeft;
            std::fill(row, row + _clipWidth, argb);
        }
        if(updateWhenDraw)
            redraw();
    }

    // Fill `polys` (already offset) with one colour. evenOdd selects the
    // fill rule; strokes use non-zero so their pieces union.
    void FillPolys(const std::vector<Poly> &polys, uint32_t argb, bool evenOdd,
                   RectD &bounds) {
        if(!_buffer || ((argb >> 24) & 0xff) == 0)
            return;
        std::vector<Edge> edges;
        RectD box;
        for(const Poly &poly : polys) {
            const size_t n = poly.size();
            if(n < 2)
                continue;
            for(size_t i = 0; i < n; ++i) {
                const Pt &a = poly[i], &b = poly[(i + 1) % n];
                box.add(a);
                if(a.y == b.y)
                    continue;
                if(a.y < b.y)
                    edges.push_back({ a.x, a.y, b.x, b.y, 1 });
                else
                    edges.push_back({ b.x, b.y, a.x, a.y, -1 });
            }
        }
        if(edges.empty())
            return;
        bounds.add(box);

        const int clipX0 = _clipLeft, clipX1 = _clipLeft + _clipWidth;
        const int clipY0 = _clipTop, clipY1 = _clipTop + _clipHeight;
        const int y0 = std::max(clipY0, (int)std::floor(box.y0));
        const int y1 = std::min(clipY1 - 1, (int)std::ceil(box.y1));
        if(y0 > y1)
            return;
        const int x0 = std::max(clipX0, (int)std::floor(box.x0) - 1);
        const int x1 = std::min(clipX1 - 1, (int)std::ceil(box.x1) + 1);
        if(x0 > x1)
            return;
        const int spanW = x1 - x0 + 1;

        constexpr int kSub = 4;
        const double subCov = 1.0 / kSub;
        std::vector<double> cov((size_t)spanW);
        struct Cross {
            double x;
            int dir;
        };
        std::vector<Cross> xs;

        for(int y = y0; y <= y1; ++y) {
            std::fill(cov.begin(), cov.end(), 0.0);
            bool any = false;
            for(int s = 0; s < kSub; ++s) {
                const double sy = y + (s + 0.5) / kSub;
                xs.clear();
                for(const Edge &e : edges) {
                    if(sy < e.y0 || sy >= e.y1)
                        continue;
                    const double t = (sy - e.y0) / (e.y1 - e.y0);
                    xs.push_back({ e.x0 + (e.x1 - e.x0) * t, e.dir });
                }
                if(xs.size() < 2)
                    continue;
                std::sort(xs.begin(), xs.end(),
                          [](const Cross &a, const Cross &b) { return a.x < b.x; });
                int winding = 0;
                for(size_t i = 0; i + 1 < xs.size(); ++i) {
                    winding += evenOdd ? 1 : xs[i].dir;
                    const bool inside = evenOdd ? (winding & 1) : (winding != 0);
                    if(!inside)
                        continue;
                    double xa = std::max(xs[i].x, (double)x0);
                    double xb = std::min(xs[i + 1].x, (double)x1 + 1.0);
                    if(xb <= xa)
                        continue;
                    any = true;
                    int ia = (int)std::floor(xa), ib = (int)std::floor(xb);
                    if(ia == ib) {
                        cov[(size_t)(ia - x0)] += (xb - xa) * subCov;
                        continue;
                    }
                    cov[(size_t)(ia - x0)] += (ia + 1 - xa) * subCov;
                    for(int px = ia + 1; px < ib && px <= x1; ++px)
                        cov[(size_t)(px - x0)] += subCov;
                    if(ib <= x1)
                        cov[(size_t)(ib - x0)] += (xb - ib) * subCov;
                }
            }
            if(!any)
                continue;
            auto *row = reinterpret_cast<uint32_t *>(_buffer + (size_t)y * _pitch);
            for(int i = 0; i < spanW; ++i) {
                const double c = std::min(1.0, cov[(size_t)i]);
                if(c > 0.001)
                    BlendPixel(row + x0 + i, argb, c);
            }
        }
    }

    // Apply every brush/pen in `app` to the shape.
    RectD DrawShape(const LiteAppearance *app, const Poly &outline, bool closed) {
        RectD bounds;
        if(!app || outline.empty())
            return bounds;
        for(const DrawStyle &st : app->styles) {
            Poly shifted;
            shifted.reserve(outline.size());
            for(const Pt &p : outline)
                shifted.push_back({ p.x + st.ox, p.y + st.oy });
            if(st.pen) {
                std::vector<Poly> pieces;
                StrokeToPolys(shifted, closed, st.width, pieces);
                FillPolys(pieces, st.argb, false, bounds);
            } else if(closed) {
                FillPolys({ shifted }, st.argb, true, bounds);
            }
        }
        return bounds;
    }

    RectD DrawShapes(const LiteAppearance *app, const std::vector<Poly> &outlines,
                     const std::vector<bool> &closedFlags) {
        RectD bounds;
        for(size_t i = 0; i < outlines.size(); ++i)
            bounds.add(DrawShape(app, outlines[i],
                                 i < closedFlags.size() ? closedFlags[i] : true));
        return bounds;
    }

    void Finish(const RectD &bounds) {
        if(!updateWhenDraw || bounds.empty())
            return;
        tTVPRect rc((tjs_int)std::floor(bounds.x0) - 1,
                    (tjs_int)std::floor(bounds.y0) - 1,
                    (tjs_int)std::ceil(bounds.x1) + 2,
                    (tjs_int)std::ceil(bounds.y1) + 2);
        rc.left = std::max<tjs_int>(rc.left, _clipLeft);
        rc.top = std::max<tjs_int>(rc.top, _clipTop);
        rc.right = std::min<tjs_int>(rc.right, _clipLeft + _clipWidth);
        rc.bottom = std::min<tjs_int>(rc.bottom, _clipTop + _clipHeight);
        if(rc.right > rc.left && rc.bottom > rc.top)
            _this->Update(rc);
    }
};

// RectF result as a dictionary (x/y/width/height + left/top/right/bottom).
void PutRect(tTJSVariant *result, const RectD &r) {
    if(!result)
        return;
    iTJSDispatch2 *dict = TJSCreateDictionaryObject();
    if(!dict)
        return;
    const bool ok = !r.empty();
    const double x = ok ? r.x0 : 0, y = ok ? r.y0 : 0;
    const double w = ok ? r.x1 - r.x0 : 0, h = ok ? r.y1 - r.y0 : 0;
    auto put = [&](const tjs_char *k, double v) {
        tTJSVariant tv(v);
        dict->PropSet(TJS_MEMBERENSURE, k, nullptr, &tv, dict);
    };
    put(TJS_W("x"), x);
    put(TJS_W("y"), y);
    put(TJS_W("width"), w);
    put(TJS_W("height"), h);
    put(TJS_W("left"), x);
    put(TJS_W("top"), y);
    put(TJS_W("right"), x + w);
    put(TJS_W("bottom"), y + h);
    *result = tTJSVariant(dict, dict);
    dict->Release();
}

LayerExDrawLite *Self(iTJSDispatch2 *objthis) {
    auto *obj = ncbInstanceAdaptor<LayerExDrawLite>::GetNativeInstance(objthis);
    if(!obj) {
        obj = new LayerExDrawLite(objthis);
        ncbInstanceAdaptor<LayerExDrawLite>::SetNativeInstance(objthis, obj);
    }
    obj->reset();
    return obj;
}

const LiteAppearance *AppearanceArg(tTJSVariant *v) {
    if(!v || v->Type() != tvtObject)
        return nullptr;
    return ncbInstanceAdaptor<LiteAppearance>::GetNativeInstance(
        v->AsObjectNoAddRef());
}

double Num(tTJSVariant **param, tjs_int numparams, int i, double def = 0) {
    return i < numparams ? (double)*param[i] : def;
}

// --- Layer.drawXxx raw callbacks -----------------------------------------

tjs_error L_drawPolygon(tTJSVariant *result, tjs_int numparams,
                        tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts;
    ReadPoints(*param[1], pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, true);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawLines(tTJSVariant *result, tjs_int numparams,
                      tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts;
    ReadPoints(*param[1], pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, false);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawLine(tTJSVariant *result, tjs_int numparams,
                     tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 5)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts{ { Num(param, numparams, 1), Num(param, numparams, 2) },
              { Num(param, numparams, 3), Num(param, numparams, 4) } };
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, false);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

Poly RectPoly(double x, double y, double w, double h) {
    return { { x, y }, { x + w, y }, { x + w, y + h }, { x, y + h } };
}

tjs_error L_drawRectangle(tTJSVariant *result, tjs_int numparams,
                          tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 5)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    const RectD b = self->DrawShape(
        AppearanceArg(param[0]),
        RectPoly(Num(param, numparams, 1), Num(param, numparams, 2),
                 Num(param, numparams, 3), Num(param, numparams, 4)),
        true);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawRectangles(tTJSVariant *result, tjs_int numparams,
                           tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    RectD b;
    if(param[1]->Type() == tvtObject) {
        ncbPropAccessor arr(*param[1]);
        const int n = arr.GetArrayCount();
        for(int i = 0; i < n; ++i) {
            tTJSVariant r;
            if(!arr.checkVariant(i, r) || r.Type() != tvtObject)
                continue;
            ncbPropAccessor info(r);
            Poly poly = IsArrayVariant(r)
                ? RectPoly(info.getRealValue(0), info.getRealValue(1),
                           info.getRealValue(2), info.getRealValue(3))
                : RectPoly(info.getRealValue(TJS_W("x")),
                           info.getRealValue(TJS_W("y")),
                           info.getRealValue(TJS_W("width")),
                           info.getRealValue(TJS_W("height")));
            b.add(self->DrawShape(AppearanceArg(param[0]), poly, true));
        }
    }
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawEllipse(tTJSVariant *result, tjs_int numparams,
                        tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 5)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts;
    FlattenArc(Num(param, numparams, 1), Num(param, numparams, 2),
               Num(param, numparams, 3), Num(param, numparams, 4), 0, 360, pts);
    if(!pts.empty())
        pts.pop_back(); // duplicate of the first point
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, true);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawArc(tTJSVariant *result, tjs_int numparams,
                    tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 7)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts;
    FlattenArc(Num(param, numparams, 1), Num(param, numparams, 2),
               Num(param, numparams, 3), Num(param, numparams, 4),
               Num(param, numparams, 5), Num(param, numparams, 6), pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, false);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawPie(tTJSVariant *result, tjs_int numparams,
                    tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 7)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    const double x = Num(param, numparams, 1), y = Num(param, numparams, 2);
    const double w = Num(param, numparams, 3), h = Num(param, numparams, 4);
    Poly pts{ { x + w / 2, y + h / 2 } };
    FlattenArc(x, y, w, h, Num(param, numparams, 5), Num(param, numparams, 6),
               pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, true);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawBezier(tTJSVariant *result, tjs_int numparams,
                       tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 9)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly pts{ { Num(param, numparams, 1), Num(param, numparams, 2) } };
    FlattenBezier(pts[0], { Num(param, numparams, 3), Num(param, numparams, 4) },
                  { Num(param, numparams, 5), Num(param, numparams, 6) },
                  { Num(param, numparams, 7), Num(param, numparams, 8) }, pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, false);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

void BeziersToPoly(const Poly &ctrl, Poly &out) {
    if(ctrl.empty())
        return;
    out.push_back(ctrl[0]);
    for(size_t i = 0; i + 3 < ctrl.size(); i += 3)
        FlattenBezier(ctrl[i], ctrl[i + 1], ctrl[i + 2], ctrl[i + 3], out);
}

tjs_error L_drawBeziers(tTJSVariant *result, tjs_int numparams,
                        tTJSVariant **param, iTJSDispatch2 *objthis) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly ctrl, pts;
    ReadPoints(*param[1], ctrl);
    BeziersToPoly(ctrl, pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, false);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error DrawCurveImpl(tTJSVariant *result, tjs_int numparams,
                        tTJSVariant **param, iTJSDispatch2 *objthis,
                        bool closed, int tensionIndex) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    Poly ctrl, pts;
    ReadPoints(*param[1], ctrl);
    const double tension = Num(param, numparams, tensionIndex, 0.5);
    FlattenCurve(ctrl, tension, closed, pts);
    const RectD b = self->DrawShape(AppearanceArg(param[0]), pts, closed);
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_drawCurve(tTJSVariant *r, tjs_int n, tTJSVariant **p,
                      iTJSDispatch2 *o) {
    return DrawCurveImpl(r, n, p, o, false, 99);
}
tjs_error L_drawCurve2(tTJSVariant *r, tjs_int n, tTJSVariant **p,
                       iTJSDispatch2 *o) {
    return DrawCurveImpl(r, n, p, o, false, 2);
}
tjs_error L_drawCurve3(tTJSVariant *r, tjs_int n, tTJSVariant **p,
                       iTJSDispatch2 *o) {
    return DrawCurveImpl(r, n, p, o, false, 4);
}
tjs_error L_drawClosedCurve(tTJSVariant *r, tjs_int n, tTJSVariant **p,
                            iTJSDispatch2 *o) {
    return DrawCurveImpl(r, n, p, o, true, 99);
}
tjs_error L_drawClosedCurve2(tTJSVariant *r, tjs_int n, tTJSVariant **p,
                             iTJSDispatch2 *o) {
    return DrawCurveImpl(r, n, p, o, true, 2);
}

tjs_error L_drawPath(tTJSVariant *result, tjs_int numparams, tTJSVariant **param,
                     iTJSDispatch2 *objthis) {
    if(numparams < 2)
        return TJS_E_BADPARAMCOUNT;
    auto *self = Self(objthis);
    RectD b;
    if(param[1]->Type() == tvtObject) {
        auto *path = ncbInstanceAdaptor<LitePath>::GetNativeInstance(
            param[1]->AsObjectNoAddRef());
        if(path) {
            LitePath copy = *path;
            copy.flush(copy.currentOpen);
            b = self->DrawShapes(AppearanceArg(param[0]), copy.figures, copy.closed);
        }
    }
    self->Finish(b);
    PutRect(result, b);
    return TJS_S_OK;
}

tjs_error L_clear(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                  iTJSDispatch2 *objthis) {
    auto *self = Self(objthis);
    self->clear(numparams > 0 ? (uint32_t)(tjs_int64)*param[0] : 0u);
    return TJS_S_OK;
}

// Transforms: accepted, ignored.
tjs_error L_noopTransform(tTJSVariant *, tjs_int, tTJSVariant **,
                          iTJSDispatch2 *) {
    return TJS_S_OK;
}

// Text / image entry points: not available without libgdiplus. Return an
// empty rect so callers that only lay out by the result keep running.
tjs_error L_unsupported(tTJSVariant *result, tjs_int, tTJSVariant **,
                        iTJSDispatch2 *objthis) {
    auto *self = Self(objthis);
    if(!self->textWarned) {
        self->textWarned = true;
        spdlog::warn("layerExDraw: text/image drawing is not available in "
                     "this build; call ignored");
    }
    PutRect(result, RectD{});
    return TJS_S_OK;
}

// --- GdiPlus.Path raw callbacks -----------------------------------------

LitePath *PathSelf(iTJSDispatch2 *objthis) {
    return ncbInstanceAdaptor<LitePath>::GetNativeInstance(objthis);
}

tjs_error P_drawPolygon(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                        iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    Poly pts;
    ReadPoints(*param[0], pts);
    self->add(pts, true);
    return TJS_S_OK;
}

tjs_error P_drawLines(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                      iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    Poly pts;
    ReadPoints(*param[0], pts);
    self->add(pts, false);
    return TJS_S_OK;
}

tjs_error P_drawLine(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                     iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 4)
        return TJS_E_BADPARAMCOUNT;
    self->add({ { Num(param, numparams, 0), Num(param, numparams, 1) },
                { Num(param, numparams, 2), Num(param, numparams, 3) } },
              false);
    return TJS_S_OK;
}

tjs_error P_drawRectangle(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                          iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 4)
        return TJS_E_BADPARAMCOUNT;
    self->add(RectPoly(Num(param, numparams, 0), Num(param, numparams, 1),
                       Num(param, numparams, 2), Num(param, numparams, 3)),
              true);
    return TJS_S_OK;
}

tjs_error P_drawEllipse(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                        iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 4)
        return TJS_E_BADPARAMCOUNT;
    Poly pts;
    FlattenArc(Num(param, numparams, 0), Num(param, numparams, 1),
               Num(param, numparams, 2), Num(param, numparams, 3), 0, 360, pts);
    if(!pts.empty())
        pts.pop_back();
    self->add(pts, true);
    return TJS_S_OK;
}

tjs_error P_drawArc(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                    iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 6)
        return TJS_E_BADPARAMCOUNT;
    Poly pts;
    FlattenArc(Num(param, numparams, 0), Num(param, numparams, 1),
               Num(param, numparams, 2), Num(param, numparams, 3),
               Num(param, numparams, 4), Num(param, numparams, 5), pts);
    self->add(pts, false);
    return TJS_S_OK;
}

tjs_error P_drawPie(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                    iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 6)
        return TJS_E_BADPARAMCOUNT;
    const double x = Num(param, numparams, 0), y = Num(param, numparams, 1);
    const double w = Num(param, numparams, 2), h = Num(param, numparams, 3);
    Poly pts{ { x + w / 2, y + h / 2 } };
    FlattenArc(x, y, w, h, Num(param, numparams, 4), Num(param, numparams, 5),
               pts);
    self->add(pts, true);
    return TJS_S_OK;
}

tjs_error P_drawBeziers(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                        iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    Poly ctrl, pts;
    ReadPoints(*param[0], ctrl);
    BeziersToPoly(ctrl, pts);
    self->add(pts, false);
    return TJS_S_OK;
}

tjs_error P_drawBezier(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                       iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 8)
        return TJS_E_BADPARAMCOUNT;
    Poly pts{ { Num(param, numparams, 0), Num(param, numparams, 1) } };
    FlattenBezier(pts[0], { Num(param, numparams, 2), Num(param, numparams, 3) },
                  { Num(param, numparams, 4), Num(param, numparams, 5) },
                  { Num(param, numparams, 6), Num(param, numparams, 7) }, pts);
    self->add(pts, false);
    return TJS_S_OK;
}

tjs_error PathCurveImpl(tjs_int numparams, tTJSVariant **param,
                        iTJSDispatch2 *objthis, bool closed, int tensionIndex) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1)
        return TJS_E_BADPARAMCOUNT;
    Poly ctrl, pts;
    ReadPoints(*param[0], ctrl);
    FlattenCurve(ctrl, Num(param, numparams, tensionIndex, 0.5), closed, pts);
    self->add(pts, closed);
    return TJS_S_OK;
}

tjs_error P_drawCurve(tTJSVariant *, tjs_int n, tTJSVariant **p, iTJSDispatch2 *o) {
    return PathCurveImpl(n, p, o, false, 99);
}
tjs_error P_drawCurve2(tTJSVariant *, tjs_int n, tTJSVariant **p, iTJSDispatch2 *o) {
    return PathCurveImpl(n, p, o, false, 1);
}
tjs_error P_drawCurve3(tTJSVariant *, tjs_int n, tTJSVariant **p, iTJSDispatch2 *o) {
    return PathCurveImpl(n, p, o, false, 3);
}
tjs_error P_drawClosedCurve(tTJSVariant *, tjs_int n, tTJSVariant **p,
                            iTJSDispatch2 *o) {
    return PathCurveImpl(n, p, o, true, 99);
}
tjs_error P_drawClosedCurve2(tTJSVariant *, tjs_int n, tTJSVariant **p,
                             iTJSDispatch2 *o) {
    return PathCurveImpl(n, p, o, true, 1);
}

tjs_error P_drawRectangles(tTJSVariant *, tjs_int numparams, tTJSVariant **param,
                           iTJSDispatch2 *objthis) {
    auto *self = PathSelf(objthis);
    if(!self)
        return TJS_E_NATIVECLASSCRASH;
    if(numparams < 1 || param[0]->Type() != tvtObject)
        return TJS_E_BADPARAMCOUNT;
    ncbPropAccessor arr(*param[0]);
    const int n = arr.GetArrayCount();
    for(int i = 0; i < n; ++i) {
        tTJSVariant r;
        if(!arr.checkVariant(i, r) || r.Type() != tvtObject)
            continue;
        ncbPropAccessor info(r);
        self->add(IsArrayVariant(r)
                      ? RectPoly(info.getRealValue(0), info.getRealValue(1),
                                 info.getRealValue(2), info.getRealValue(3))
                      : RectPoly(info.getRealValue(TJS_W("x")),
                                 info.getRealValue(TJS_W("y")),
                                 info.getRealValue(TJS_W("width")),
                                 info.getRealValue(TJS_W("height"))),
                  true);
    }
    return TJS_S_OK;
}

// GdiPlus static helpers: no private fonts in this build.
tjs_error G_addPrivateFont(tTJSVariant *, tjs_int, tTJSVariant **, iTJSDispatch2 *) {
    return TJS_S_OK;
}
tjs_error G_getFontList(tTJSVariant *result, tjs_int, tTJSVariant **,
                        iTJSDispatch2 *) {
    if(result) {
        iTJSDispatch2 *arr = TJSCreateArrayObject();
        *result = tTJSVariant(arr, arr);
        arr->Release();
    }
    return TJS_S_OK;
}

class GdiPlusLite {}; // namespace holder for constants and subclasses

} // namespace

// ---------------------------------------------------------------- bindings

NCB_REGISTER_SUBCLASS(LiteAppearance) {
    NCB_CONSTRUCTOR(());
    NCB_METHOD(clear);
    NCB_METHOD_RAW_CALLBACK(addBrush, AppearanceAddBrush, 0);
    NCB_METHOD_RAW_CALLBACK(addPen, AppearanceAddPen, 0);
}

NCB_REGISTER_SUBCLASS(LiteFont) {
    NCB_CONSTRUCTOR((const tjs_char *, float, int));
    NCB_PROPERTY(familyName, getFamilyName, setFamilyName);
    NCB_PROPERTY(emSize, getEmSize, setEmSize);
    NCB_PROPERTY(style, getStyle, setStyle);
    NCB_PROPERTY(forceSelfPathDraw, getForceSelfPathDraw, setForceSelfPathDraw);
    NCB_PROPERTY_RO(ascent, getAscent);
    NCB_PROPERTY_RO(descent, getDescent);
    NCB_PROPERTY_RO(ascentLeading, getAscentLeading);
    NCB_PROPERTY_RO(descentLeading, getDescentLeading);
    NCB_PROPERTY_RO(lineSpacing, getLineSpacing);
}

NCB_REGISTER_SUBCLASS(LitePath) {
    NCB_CONSTRUCTOR(());
    NCB_METHOD(startFigure);
    NCB_METHOD(closeFigure);
    NCB_METHOD_RAW_CALLBACK(drawArc, P_drawArc, 0);
    NCB_METHOD_RAW_CALLBACK(drawPie, P_drawPie, 0);
    NCB_METHOD_RAW_CALLBACK(drawBezier, P_drawBezier, 0);
    NCB_METHOD_RAW_CALLBACK(drawBeziers, P_drawBeziers, 0);
    NCB_METHOD_RAW_CALLBACK(drawClosedCurve, P_drawClosedCurve, 0);
    NCB_METHOD_RAW_CALLBACK(drawClosedCurve2, P_drawClosedCurve2, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve, P_drawCurve, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve2, P_drawCurve2, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve3, P_drawCurve3, 0);
    NCB_METHOD_RAW_CALLBACK(drawEllipse, P_drawEllipse, 0);
    NCB_METHOD_RAW_CALLBACK(drawLine, P_drawLine, 0);
    NCB_METHOD_RAW_CALLBACK(drawLines, P_drawLines, 0);
    NCB_METHOD_RAW_CALLBACK(drawPolygon, P_drawPolygon, 0);
    NCB_METHOD_RAW_CALLBACK(drawRectangle, P_drawRectangle, 0);
    NCB_METHOD_RAW_CALLBACK(drawRectangles, P_drawRectangles, 0);
}

NCB_REGISTER_CLASS_DIFFER(GdiPlus, GdiPlusLite) {
    // Status
    Variant("Ok", 0);
    Variant("GenericError", 1);
    Variant("InvalidParameter", 2);
    Variant("OutOfMemory", 3);
    Variant("ObjectBusy", 4);
    Variant("InsufficientBuffer", 5);
    Variant("NotImplemented", 6);
    Variant("Win32Error", 7);
    Variant("WrongState", 8);
    Variant("Aborted", 9);
    Variant("FileNotFound", 10);
    Variant("ValueOverflow", 11);
    Variant("AccessDenied", 12);
    Variant("UnknownImageFormat", 13);
    Variant("FontFamilyNotFound", 14);
    Variant("FontStyleNotFound", 15);
    Variant("NotTrueTypeFont", 16);
    Variant("UnsupportedGdiplusVersion", 17);
    Variant("GdiplusNotInitialized", 18);
    Variant("PropertyNotFound", 19);
    Variant("PropertyNotSupported", 20);

    Variant("FontStyleRegular", 0);
    Variant("FontStyleBold", 1);
    Variant("FontStyleItalic", 2);
    Variant("FontStyleBoldItalic", 3);
    Variant("FontStyleUnderline", 4);
    Variant("FontStyleStrikeout", 8);

    Variant("BrushTypeSolidColor", 0);
    Variant("BrushTypeHatchFill", 1);
    Variant("BrushTypeTextureFill", 2);
    Variant("BrushTypePathGradient", 3);
    Variant("BrushTypeLinearGradient", 4);

    Variant("DashCapFlat", 0);
    Variant("DashCapRound", 2);
    Variant("DashCapTriangle", 3);

    Variant("DashStyleSolid", 0);
    Variant("DashStyleDash", 1);
    Variant("DashStyleDot", 2);
    Variant("DashStyleDashDot", 3);
    Variant("DashStyleDashDotDot", 4);
    Variant("DashStyleCustom", 5);

    Variant("LineCapFlat", 0);
    Variant("LineCapSquare", 1);
    Variant("LineCapRound", 2);
    Variant("LineCapTriangle", 3);
    Variant("LineCapNoAnchor", 0x10);
    Variant("LineCapSquareAnchor", 0x11);
    Variant("LineCapRoundAnchor", 0x12);
    Variant("LineCapDiamondAnchor", 0x13);
    Variant("LineCapArrowAnchor", 0x14);
    Variant("LineCapCustom", 0xff);
    Variant("LineCapAnchorMask", 0xf0);

    Variant("LineJoinMiter", 0);
    Variant("LineJoinBevel", 1);
    Variant("LineJoinRound", 2);
    Variant("LineJoinMiterClipped", 3);

    Variant("PenAlignmentCenter", 0);
    Variant("PenAlignmentInset", 1);

    Variant("FillModeAlternate", 0);
    Variant("FillModeWinding", 1);

    Variant("HatchStyleHorizontal", 0);
    Variant("HatchStyleVertical", 1);
    Variant("HatchStyleForwardDiagonal", 2);
    Variant("HatchStyleBackwardDiagonal", 3);
    Variant("HatchStyleCross", 4);
    Variant("HatchStyleDiagonalCross", 5);
    Variant("HatchStyle05Percent", 6);
    Variant("HatchStyle10Percent", 7);
    Variant("HatchStyle20Percent", 8);
    Variant("HatchStyle25Percent", 9);
    Variant("HatchStyle30Percent", 10);
    Variant("HatchStyle40Percent", 11);
    Variant("HatchStyle50Percent", 12);
    Variant("HatchStyle60Percent", 13);
    Variant("HatchStyle70Percent", 14);
    Variant("HatchStyle75Percent", 15);
    Variant("HatchStyle80Percent", 16);
    Variant("HatchStyle90Percent", 17);
    Variant("HatchStyleLightDownwardDiagonal", 18);
    Variant("HatchStyleLightUpwardDiagonal", 19);
    Variant("HatchStyleDarkDownwardDiagonal", 20);
    Variant("HatchStyleDarkUpwardDiagonal", 21);
    Variant("HatchStyleWideDownwardDiagonal", 22);
    Variant("HatchStyleWideUpwardDiagonal", 23);
    Variant("HatchStyleLightVertical", 24);
    Variant("HatchStyleLightHorizontal", 25);
    Variant("HatchStyleNarrowVertical", 26);
    Variant("HatchStyleNarrowHorizontal", 27);
    Variant("HatchStyleDarkVertical", 28);
    Variant("HatchStyleDarkHorizontal", 29);
    Variant("HatchStyleDashedDownwardDiagonal", 30);
    Variant("HatchStyleDashedUpwardDiagonal", 31);
    Variant("HatchStyleDashedHorizontal", 32);
    Variant("HatchStyleDashedVertical", 33);
    Variant("HatchStyleSmallConfetti", 34);
    Variant("HatchStyleLargeConfetti", 35);
    Variant("HatchStyleZigZag", 36);
    Variant("HatchStyleWave", 37);
    Variant("HatchStyleDiagonalBrick", 38);
    Variant("HatchStyleHorizontalBrick", 39);
    Variant("HatchStyleWeave", 40);
    Variant("HatchStylePlaid", 41);
    Variant("HatchStyleDivot", 42);
    Variant("HatchStyleDottedGrid", 43);
    Variant("HatchStyleDottedDiamond", 44);
    Variant("HatchStyleShingle", 45);
    Variant("HatchStyleTrellis", 46);
    Variant("HatchStyleSphere", 47);
    Variant("HatchStyleSmallGrid", 48);
    Variant("HatchStyleSmallCheckerBoard", 49);
    Variant("HatchStyleLargeCheckerBoard", 50);
    Variant("HatchStyleOutlinedDiamond", 51);
    Variant("HatchStyleSolidDiamond", 52);
    Variant("HatchStyleTotal", 0x35);
    Variant("HatchStyleLargeGrid", 4);
    Variant("HatchStyleMin", 0);
    Variant("HatchStyleMax", 52);

    Variant("WrapModeTile", 0);
    Variant("WrapModeTileFlipX", 1);
    Variant("WrapModeTileFlipY", 2);
    Variant("WrapModeTileFlipXY", 3);
    Variant("WrapModeClamp", 4);

    Variant("LinearGradientModeHorizontal", 0);
    Variant("LinearGradientModeVertical", 1);
    Variant("LinearGradientModeForwardDiagonal", 2);
    Variant("LinearGradientModeBackwardDiagonal", 3);

    Variant("MatrixOrderPrepend", 0);
    Variant("MatrixOrderAppend", 1);

    Variant("StringAlignmentNear", 0);
    Variant("StringAlignmentCenter", 1);
    Variant("StringAlignmentFar", 2);

    Variant("SmoothingModeInvalid", -1);
    Variant("SmoothingModeDefault", 0);
    Variant("SmoothingModeHighSpeed", 1);
    Variant("SmoothingModeHighQuality", 2);
    Variant("SmoothingModeNone", 3);
    Variant("SmoothingModeAntiAlias", 4);

    Variant("TextRenderingHintSystemDefault", 0);
    Variant("TextRenderingHintSingleBitPerPixelGridFit", 1);
    Variant("TextRenderingHintSingleBitPerPixel", 2);
    Variant("TextRenderingHintAntiAliasGridFit", 3);
    Variant("TextRenderingHintAntiAlias", 4);
    Variant("TextRenderingHintClearTypeGridFit", 5);

    NCB_METHOD_RAW_CALLBACK(addPrivateFont, G_addPrivateFont, 0);
    NCB_METHOD_RAW_CALLBACK(getFontList, G_getFontList, 0);

    NCB_SUBCLASS(Font, LiteFont);
    NCB_SUBCLASS(Appearance, LiteAppearance);
    NCB_SUBCLASS(Path, LitePath);
}

NCB_GET_INSTANCE_HOOK(LayerExDrawLite) {
    NCB_INSTANCE_GETTER(objthis) {
        ClassT *obj = GetNativeInstance(objthis);
        if(!obj) {
            obj = new ClassT(objthis);
            SetNativeInstance(objthis, obj);
        }
        obj->reset();
        return obj;
    }
    ~NCB_GET_INSTANCE_HOOK_CLASS() {}
};

NCB_ATTACH_CLASS_WITH_HOOK(LayerExDrawLite, Layer) {
    NCB_PROPERTY(updateWhenDraw, getUpdateWhenDraw, setUpdateWhenDraw);
    NCB_PROPERTY(smoothingMode, getSmoothingMode, setSmoothingMode);
    NCB_PROPERTY(textRenderingHint, getTextRenderingHint, setTextRenderingHint);

    NCB_METHOD_RAW_CALLBACK(setViewTransform, L_noopTransform, 0);
    NCB_METHOD(resetViewTransform);
    NCB_METHOD_RAW_CALLBACK(rotateViewTransform, L_noopTransform, 0);
    NCB_METHOD_RAW_CALLBACK(scaleViewTransform, L_noopTransform, 0);
    NCB_METHOD_RAW_CALLBACK(translateViewTransform, L_noopTransform, 0);
    NCB_METHOD_RAW_CALLBACK(setTransform, L_noopTransform, 0);
    NCB_METHOD(resetTransform);
    NCB_METHOD_RAW_CALLBACK(rotateTransform, L_noopTransform, 0);
    NCB_METHOD_RAW_CALLBACK(scaleTransform, L_noopTransform, 0);
    NCB_METHOD_RAW_CALLBACK(translateTransform, L_noopTransform, 0);

    NCB_METHOD_RAW_CALLBACK(clear, L_clear, 0);
    NCB_METHOD_RAW_CALLBACK(drawPath, L_drawPath, 0);
    NCB_METHOD_RAW_CALLBACK(drawArc, L_drawArc, 0);
    NCB_METHOD_RAW_CALLBACK(drawPie, L_drawPie, 0);
    NCB_METHOD_RAW_CALLBACK(drawBezier, L_drawBezier, 0);
    NCB_METHOD_RAW_CALLBACK(drawBeziers, L_drawBeziers, 0);
    NCB_METHOD_RAW_CALLBACK(drawClosedCurve, L_drawClosedCurve, 0);
    NCB_METHOD_RAW_CALLBACK(drawClosedCurve2, L_drawClosedCurve2, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve, L_drawCurve, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve2, L_drawCurve2, 0);
    NCB_METHOD_RAW_CALLBACK(drawCurve3, L_drawCurve3, 0);
    NCB_METHOD_RAW_CALLBACK(drawEllipse, L_drawEllipse, 0);
    NCB_METHOD_RAW_CALLBACK(drawLine, L_drawLine, 0);
    NCB_METHOD_RAW_CALLBACK(drawLines, L_drawLines, 0);
    NCB_METHOD_RAW_CALLBACK(drawPolygon, L_drawPolygon, 0);
    NCB_METHOD_RAW_CALLBACK(drawRectangle, L_drawRectangle, 0);
    NCB_METHOD_RAW_CALLBACK(drawRectangles, L_drawRectangles, 0);

    NCB_METHOD_RAW_CALLBACK(drawPathString, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(drawString, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(measureString, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(measureStringInternal, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(drawImage, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(drawImageRect, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(drawImageStretch, L_unsupported, 0);
    NCB_METHOD_RAW_CALLBACK(drawImageAffine, L_unsupported, 0);
}
