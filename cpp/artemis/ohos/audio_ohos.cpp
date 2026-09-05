// audio_ohos.cpp — OpenHarmony OHAudio backend for the Artemis compat engine.
//
// Mirrors the Android OpenSL ES design in upstream/src/audio/audio.cpp: one
// system renderer per active voice (the audio server mixes them), the whole
// ogg decoded up front with stb_vorbis to S16 PCM, a pull callback that
// copies from the PCM buffer and wraps around when the voice loops. Voices
// keep their native sample rate / channel count so no resampling is needed.
//
// Thread model: OHAudio invokes OnWriteData on its own server thread; the
// voice table is guarded by a mutex and every renderer is stopped before its
// PCM buffer is released, so the callback never sees a dangling pointer.
#include "audio/audio.h"

#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "log/logger.h"
#include "pack/pack_manager.h"

#define STB_VORBIS_NO_STDIO 1
#define STB_VORBIS_HEADER_ONLY
#include "stb_vorbis/stb_vorbis.c"   // -I upstream/third_party

#include <ohaudio/native_audiorenderer.h>
#include <ohaudio/native_audiostream_base.h>
#include <ohaudio/native_audiostreambuilder.h>

namespace artc {

namespace {

struct Voice {
    OH_AudioRenderer *renderer = nullptr;
    short *pcm = nullptr;          // interleaved S16, owned (malloc'd by stb_vorbis)
    size_t pcm_bytes = 0;
    size_t cursor = 0;             // byte offset of the next sample to hand out
    bool loop = false;
    std::atomic<bool> finished{false};
    std::mutex mutex;              // protects cursor (callback vs. Stop)
    int channels = 0;
    int sample_rate = 0;
    int vol1000 = 1000;
};

OH_AudioData_Callback_Result OnWriteData(OH_AudioRenderer *, void *user_data,
                                         void *audio_data, int32_t size) {
    auto *v = static_cast<Voice *>(user_data);
    auto *out = static_cast<uint8_t *>(audio_data);
    if (!v || size <= 0) return AUDIO_DATA_CALLBACK_RESULT_VALID;
    std::lock_guard<std::mutex> lk(v->mutex);
    size_t written = 0;
    const size_t want = static_cast<size_t>(size);
    while (written < want) {
        if (v->cursor >= v->pcm_bytes) {
            if (!v->loop) break;
            v->cursor = 0;
        }
        const size_t chunk = std::min(want - written, v->pcm_bytes - v->cursor);
        std::memcpy(out + written, reinterpret_cast<uint8_t *>(v->pcm) + v->cursor, chunk);
        v->cursor += chunk;
        written += chunk;
    }
    if (written < want) {
        std::memset(out + written, 0, want - written);
        v->finished = true;
    }
    return AUDIO_DATA_CALLBACK_RESULT_VALID;
}

float VolumeToGain(int vol1000) {
    if (vol1000 <= 0) return 0.0f;
    if (vol1000 >= 1000) return 1.0f;
    return static_cast<float>(vol1000) / 1000.0f;
}

void DestroyVoice(std::unique_ptr<Voice> &v) {
    if (!v) return;
    if (v->renderer) {
        OH_AudioRenderer_Stop(v->renderer);
        OH_AudioRenderer_Release(v->renderer);
        v->renderer = nullptr;
    }
    if (v->pcm) {
        free(v->pcm);
        v->pcm = nullptr;
    }
    v.reset();
}

} // namespace

struct Audio::Impl {
    PackManager *packs = nullptr;
    std::mutex mutex;
    std::map<std::string, std::unique_ptr<Voice>> voices;
    bool paused = false;
};

Audio::Audio() : impl_(new Impl) {}
Audio::~Audio() { Shutdown(); delete impl_; }

void Audio::Init(PackManager *packs) {
    impl_->packs = packs;
    Log(kLogInfo, "audio: OHAudio backend ready");
}

void Audio::Shutdown() {
    StopAll();
    impl_->packs = nullptr;
}

bool Audio::Play(const std::string &key, const std::string &file, bool loop, int vol) {
    std::vector<uint8_t> ogg;
    if (!impl_->packs || !impl_->packs->Read(file, ogg) || ogg.empty()) {
        Log(kLogWarn, "audio: ogg not found: " + file);
        return false;
    }
    int channels = 0, sample_rate = 0;
    short *pcm = nullptr;
    const int frames = stb_vorbis_decode_memory(ogg.data(), static_cast<int>(ogg.size()),
                                                &channels, &sample_rate, &pcm);
    if (frames <= 0 || !pcm || channels <= 0 || sample_rate <= 0) {
        Log(kLogWarn, "audio: vorbis decode failed: " + file);
        if (pcm) free(pcm);
        return false;
    }
    const size_t pcm_bytes = static_cast<size_t>(frames) * 2u * static_cast<size_t>(channels);
    if (pcm_bytes > (1u << 28)) {
        Log(kLogWarn, "audio: file too large to queue: " + file);
        free(pcm);
        return false;
    }

    auto voice = std::make_unique<Voice>();
    voice->pcm = pcm;
    voice->pcm_bytes = pcm_bytes;
    voice->loop = loop;
    voice->channels = channels;
    voice->sample_rate = sample_rate;
    voice->vol1000 = vol < 0 ? 0 : (vol > 1000 ? 1000 : vol);

    OH_AudioStreamBuilder *builder = nullptr;
    if (OH_AudioStreamBuilder_Create(&builder, AUDIOSTREAM_TYPE_RENDERER) != AUDIOSTREAM_SUCCESS ||
        !builder) {
        Log(kLogError, "audio: OH_AudioStreamBuilder_Create failed: " + file);
        free(pcm);
        return false;
    }
    OH_AudioStreamBuilder_SetSamplingRate(builder, sample_rate);
    OH_AudioStreamBuilder_SetChannelCount(builder, channels);
    OH_AudioStreamBuilder_SetSampleFormat(builder, AUDIOSTREAM_SAMPLE_S16LE);
    OH_AudioStreamBuilder_SetEncodingType(builder, AUDIOSTREAM_ENCODING_TYPE_RAW);
    OH_AudioStreamBuilder_SetLatencyMode(builder, AUDIOSTREAM_LATENCY_MODE_NORMAL);
    OH_AudioStreamBuilder_SetRendererInfo(builder, AUDIOSTREAM_USAGE_GAME);
    OH_AudioStreamBuilder_SetRendererWriteDataCallback(builder, OnWriteData, voice.get());
    OH_AudioRenderer *renderer = nullptr;
    const OH_AudioStream_Result gen = OH_AudioStreamBuilder_GenerateRenderer(builder, &renderer);
    OH_AudioStreamBuilder_Destroy(builder);
    if (gen != AUDIOSTREAM_SUCCESS || !renderer) {
        Log(kLogError, "audio: GenerateRenderer failed (" + std::to_string(static_cast<int>(gen)) +
                           "): " + file);
        free(pcm);
        return false;
    }
    voice->renderer = renderer;
    OH_AudioRenderer_SetVolume(renderer, VolumeToGain(voice->vol1000));

    {
        std::lock_guard<std::mutex> lk(impl_->mutex);
        auto it = impl_->voices.find(key);
        if (it != impl_->voices.end()) {
            DestroyVoice(it->second);   // replace an existing voice on this key
            impl_->voices.erase(it);
        }
        if (!impl_->paused) OH_AudioRenderer_Start(renderer);
        impl_->voices[key] = std::move(voice);
    }

    Log(kLogInfo, "audio: play " + key + " " + file + " [" + std::to_string(channels) +
                      "ch " + std::to_string(sample_rate) + "Hz " +
                      std::to_string(pcm_bytes >> 10) + "KiB] loop=" + std::to_string(loop) +
                      " vol=" + std::to_string(vol));
    return true;
}

void Audio::Stop(const std::string &key) {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    auto it = impl_->voices.find(key);
    if (it == impl_->voices.end()) return;
    DestroyVoice(it->second);
    impl_->voices.erase(it);
}

bool Audio::IsPlaying(const std::string &key) const {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    auto it = impl_->voices.find(key);
    if (it == impl_->voices.end() || !it->second) return false;
    return it->second->loop || !it->second->finished.load();
}

void Audio::StopAll() {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    for (auto &kv : impl_->voices) DestroyVoice(kv.second);
    impl_->voices.clear();
}

void Audio::SetVolume(const std::string &key, int vol) {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    auto it = impl_->voices.find(key);
    if (it == impl_->voices.end() || !it->second) return;
    it->second->vol1000 = vol < 0 ? 0 : (vol > 1000 ? 1000 : vol);
    if (it->second->renderer)
        OH_AudioRenderer_SetVolume(it->second->renderer, VolumeToGain(it->second->vol1000));
}

void Audio::PauseAll() {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    impl_->paused = true;
    for (auto &kv : impl_->voices)
        if (kv.second && kv.second->renderer) OH_AudioRenderer_Pause(kv.second->renderer);
}

void Audio::ResumeAll() {
    std::lock_guard<std::mutex> lk(impl_->mutex);
    impl_->paused = false;
    for (auto &kv : impl_->voices)
        if (kv.second && kv.second->renderer && !kv.second->finished)
            OH_AudioRenderer_Start(kv.second->renderer);
}

} // namespace artc
