#include "archive_api.h"

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <mutex>
#include <set>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>

#include <Common/MyCom.h>
#include <Common/UTFConvert.h>
#include <Windows/PropVariant.h>
#include <7zip/Archive/IArchive.h>
#include <7zip/IPassword.h>

extern "C" HRESULT GetNumberOfFormats(UInt32* count);
extern "C" HRESULT GetHandlerProperty2(UInt32 index, PROPID property, PROPVARIANT* value);
extern "C" HRESULT CreateArchiver(const GUID* clsid, const GUID* iid, void** object);

namespace {
namespace fs = std::filesystem;
using NWindows::NCOM::CPropVariant;
constexpr uint64_t kMaxExpandedBytes = 512ULL * 1024 * 1024 * 1024;
constexpr uint32_t kMaxEntries = 250000;
const char* Wire(const char* error);
[[noreturn]] void ThrowIo();

struct Job {
  std::mutex mutex;
  std::atomic<bool> cancelled{false};
  krkr_archive_status status{1, 0, 0, 0, {}, {}};
  std::string root, source, destination, password;
  uint32_t codepage = 65001;
  std::thread worker;
  void Check() const { if (cancelled) throw std::runtime_error("cancelled"); }
  void Error(const std::string& error) {
    std::lock_guard<std::mutex> lock(mutex);
    if (!status.error[0]) std::snprintf(status.error, sizeof(status.error), "%s", Wire(error.c_str()));
  }
};

const char* Wire(const char* error) {
  static const char* kCodes[] = {
      "cancelled", "busy", "invalid_name", "outside_root", "protected_directory",
      "unsupported_link", "not_found", "conflict", "recursive_target", "trash_corrupt",
      "permission_denied", "no_space", "read_only", "password_required", "wrong_password",
      "missing_volume", "unsupported_format", "unsupported_method", "corrupt_archive",
      "invalid_encoding", "unsafe_archive_path", "archive_limit", "game_running",
      "unsupported_platform", "failed"};
  for (const char* code : kCodes) {
    if (std::strcmp(error, code) == 0) return code;
  }
  return "failed";
}

[[noreturn]] void ThrowIo() {
  switch (errno) {
    case ENOSPC:
#ifdef EDQUOT
    case EDQUOT:
#endif
      throw std::runtime_error("no_space");
    case EROFS:
      throw std::runtime_error("read_only");
    case EEXIST:
      throw std::runtime_error("conflict");
    case ENOENT:
      throw std::runtime_error("not_found");
    case ENAMETOOLONG:
      throw std::runtime_error("invalid_name");
    case EACCES:
    case EPERM:
      throw std::runtime_error("permission_denied");
    default:
      throw std::runtime_error("failed");
  }
}

std::string Utf8(const wchar_t* value) {
  AString converted;
  ConvertUnicodeToUTF8(UString(value ? value : L""), converted);
  return std::string(converted.Ptr(), converted.Len());
}

UString Unicode(const std::string& value) {
  UString converted;
  if (!ConvertUTF8ToUnicode(AString(value.c_str()), converted)) throw std::runtime_error("invalid_encoding");
  return converted;
}

std::string Lower(std::string value) {
  for (char& c : value) if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
  return value;
}

// Walk relative components from an already opened authorized root using
// O_NOFOLLOW. A concurrent rename/symlink cannot redirect an extraction out of
// that root. Returned descriptors own their references to the directories.
struct Fd {
  int value = -1;
  explicit Fd(int fd = -1) : value(fd) {}
  ~Fd() { if (value >= 0) close(value); }
  Fd(const Fd&) = delete;
  Fd& operator=(const Fd&) = delete;
};

std::vector<std::string> Parts(const std::string& raw) {
  if (raw.empty() || raw.front() == '/' || raw.front() == '\\' || raw.find('\0') != std::string::npos)
    throw std::runtime_error("unsafe_archive_path");
  std::string path = raw;
  std::replace(path.begin(), path.end(), '\\', '/');
  std::vector<std::string> result;
  size_t start = 0;
  while (start < path.size()) {
    const auto end = path.find('/', start);
    const auto part = path.substr(start, end == std::string::npos ? end : end - start);
    if (part == ".." || part.find(':') != std::string::npos || part.size() > 255 ||
        Lower(part) == ".krkr-manager" || std::any_of(part.begin(), part.end(), [](unsigned char c) { return c < 32; }))
      throw std::runtime_error("unsafe_archive_path");
    if (!part.empty() && part != ".") result.push_back(part);
    if (end == std::string::npos) break;
    start = end + 1;
  }
  if (result.empty()) throw std::runtime_error("unsafe_archive_path");
  return result;
}

int Walk(int root, const std::vector<std::string>& parts, size_t count, bool create) {
  int current = dup(root);
  if (current < 0) throw std::runtime_error("permission_denied");
  for (size_t i = 0; i < count; ++i) {
    if (create && mkdirat(current, parts[i].c_str(), 0700) != 0 && errno != EEXIST) {
      close(current); ThrowIo();
    }
    const int next = openat(current, parts[i].c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    close(current);
    if (next < 0) ThrowIo();
    current = next;
  }
  return current;
}

std::string Relative(const std::string& root, const std::string& path) {
  const auto base = fs::path(root).lexically_normal();
  const auto value = fs::path(path).lexically_normal();
  const auto relative = value.lexically_relative(base).generic_string();
  if (!base.is_absolute() || !value.is_absolute() || relative.empty() || relative == ".")
    throw std::runtime_error("outside_root");
  // Task directories intentionally contain .krkr-manager. This check is for
  // host-provided paths; archive-controlled names use the stricter Parts().
  if (relative == ".." || relative.rfind("../", 0) == 0 || relative.front() == '/')
    throw std::runtime_error("outside_root");
  return relative;
}

std::vector<std::string> HostParts(const std::string& relative) {
  std::vector<std::string> parts;
  for (const auto& part : fs::path(relative)) {
    const auto name = part.string();
    if (name == ".." || name == "." || name.empty()) throw std::runtime_error("outside_root");
    parts.push_back(name);
  }
  return parts;
}

class Input final : public IInStream, public CMyUnknownImp {
  Z7_COM_UNKNOWN_IMP_2(IInStream, ISequentialInStream)
public:
  explicit Input(Job& job, int fd) : Input(job, std::vector<int>{fd}) {}
  Input(Job& job, std::vector<int> handles) : job(job), handles(std::move(handles)) {
    for (int fd : this->handles) {
      struct stat st{};
      if (fstat(fd, &st) || !S_ISREG(st.st_mode)) {
        for (int owned : this->handles) close(owned);
        throw std::runtime_error("unsupported_format");
      }
      sizes.push_back(static_cast<uint64_t>(st.st_size));
      length += sizes.back();
    }
  }
  ~Input() { for (int fd : handles) close(fd); }
  Job& job;
  std::vector<int> handles;
  std::vector<uint64_t> sizes;
  uint64_t position = 0, length = 0;
  STDMETHOD(Read)(void* data, UInt32 size, UInt32* processed) noexcept override {
    if (processed) *processed = 0;
    if (job.cancelled) return E_ABORT;
    if (position >= length || size == 0) return S_OK;
    uint64_t offset = position;
    size_t part = 0;
    while (part < sizes.size() && offset >= sizes[part]) offset -= sizes[part++];
    if (part == sizes.size()) return E_FAIL;
    const auto wanted = static_cast<size_t>(std::min<uint64_t>(size, sizes[part] - offset));
    ssize_t result;
    do { result = pread(handles[part], data, wanted, static_cast<off_t>(offset)); } while (result < 0 && errno == EINTR);
    if (result <= 0) return E_FAIL;
    position += result;
    if (processed) *processed = static_cast<UInt32>(result);
    return S_OK;
  }
  STDMETHOD(Seek)(Int64 offset, UInt32 origin, UInt64* position) noexcept override {
    if (job.cancelled) return E_ABORT;
    if (origin > 2) return E_INVALIDARG;
    const auto base = origin == 0 ? 0 : origin == 1 ? this->position : length;
    if ((offset < 0 && static_cast<uint64_t>(-(offset + 1)) + 1 > base) ||
        (offset > 0 && static_cast<uint64_t>(offset) > UINT64_MAX - base)) return E_INVALIDARG;
    this->position = base + offset;
    if (position) *position = this->position;
    return S_OK;
  }
};

// .7z.001 / .zip.001 are byte-split streams, not nested archives. Join them
// virtually with bounded reads; never allocate the whole archive in memory.
std::vector<int> OpenParts(int parent, const std::string& name) {
  std::vector<int> handles;
  try {
    const auto dot = name.find_last_of('.');
    const bool numeric = dot != std::string::npos && name.size() - dot == 4 &&
      std::all_of(name.begin() + dot + 1, name.end(), [](char c) { return c >= '0' && c <= '9'; });
    if (!numeric) {
      const int fd = openat(parent, name.c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
      if (fd < 0) ThrowIo();
      return {fd};
    }
    const std::string prefix = name.substr(0, dot + 1);
    unsigned maximum = 0;
    DIR* dir = fdopendir(dup(parent));
    if (!dir) throw std::runtime_error("permission_denied");
    while (auto* entry = readdir(dir)) {
      const std::string candidate = entry->d_name;
      if (candidate.size() == prefix.size() + 3 && candidate.rfind(prefix, 0) == 0 &&
          std::all_of(candidate.begin() + prefix.size(), candidate.end(), [](char c) { return c >= '0' && c <= '9'; }))
        maximum = std::max(maximum, static_cast<unsigned>(std::stoul(candidate.substr(prefix.size()))));
    }
    closedir(dir);
    if (!maximum) throw std::runtime_error("missing_volume");
    for (unsigned part = 1; part <= maximum; ++part) {
      char suffix[4]; std::snprintf(suffix, sizeof(suffix), "%03u", part);
      const int fd = openat(parent, (prefix + suffix).c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
      if (fd < 0) throw std::runtime_error("missing_volume");
      handles.push_back(fd);
    }
    return handles;
  } catch (...) { for (int fd : handles) close(fd); throw; }
}

class Output final : public ISequentialOutStream, public CMyUnknownImp {
  Z7_COM_UNKNOWN_IMP_1(ISequentialOutStream)
public:
  Output(Job& job, int fd) : job(job), fd(fd) {}
  ~Output() { if (fd >= 0) close(fd); }
  Job& job;
  int fd;
  STDMETHOD(Write)(const void* data, UInt32 size, UInt32* processed) noexcept override {
    if (processed) *processed = 0;
    if (job.cancelled) return E_ABORT;
    {
      std::lock_guard<std::mutex> lock(job.mutex);
      if (job.status.completed + size > kMaxExpandedBytes) {
        job.Error("archive_limit");
        return E_ABORT;
      }
    }
    ssize_t count;
    do { count = write(fd, data, size); } while (count < 0 && errno == EINTR);
    if (count < 0) {
      try { ThrowIo(); } catch (const std::exception& error) { job.Error(error.what()); }
      return E_FAIL;
    }
    if (processed) *processed = static_cast<UInt32>(count);
    std::lock_guard<std::mutex> lock(job.mutex);
    job.status.completed += count;
    return S_OK;
  }
};

class OpenCallback final : public IArchiveOpenCallback, public IArchiveOpenVolumeCallback,
                           public ICryptoGetTextPassword, public CMyUnknownImp {
public:
  Z7_COM_UNKNOWN_IMP_3(IArchiveOpenCallback, IArchiveOpenVolumeCallback, ICryptoGetTextPassword)
public:
  OpenCallback(Job& job, int directory, std::string name) : job(job), directory(directory), name(std::move(name)) {}
  Job& job;
  int directory;
  std::string name;
  bool requestedPassword = false;
  bool missingVolume = false;
  STDMETHOD(SetTotal)(const UInt64*, const UInt64*) noexcept override { return job.cancelled ? E_ABORT : S_OK; }
  STDMETHOD(SetCompleted)(const UInt64*, const UInt64*) noexcept override { return job.cancelled ? E_ABORT : S_OK; }
  STDMETHOD(CryptoGetTextPassword)(BSTR* value) noexcept override {
    requestedPassword = true;
    if (job.cancelled || job.password.empty()) return E_ABORT;
    try { *value = SysAllocString(Unicode(job.password)); return *value ? S_OK : E_OUTOFMEMORY; }
    catch (...) { return E_FAIL; }
  }
  STDMETHOD(GetProperty)(PROPID property, PROPVARIANT* value) noexcept override {
    try {
      CPropVariant result;
      if (property == kpidName) result = Unicode(name);
      else if (property == kpidIsDir) result = false;
      result.Detach(value);
      return S_OK;
    } catch (...) { return E_FAIL; }
  }
  STDMETHOD(GetStream)(const wchar_t* requested, IInStream** stream) noexcept override {
    *stream = nullptr;
    try {
      job.Check();
      const auto parts = Parts(Utf8(requested));
      if (parts.size() != 1) return E_INVALIDARG;
      const int fd = openat(directory, parts[0].c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
      if (fd < 0) { missingVolume = true; return S_FALSE; }
      struct stat st{};
      if (fstat(fd, &st) || !S_ISREG(st.st_mode)) { close(fd); return E_FAIL; }
      CMyComPtr<IInStream> result = new Input(job, fd);
      *stream = result.Detach();
      return S_OK;
    } catch (...) { return E_ABORT; }
  }
};

struct Entry { std::string name; bool directory; };

class ExtractCallback final : public IArchiveExtractCallback, public ICryptoGetTextPassword,
                              public CMyUnknownImp {
public:
  Z7_COM_UNKNOWN_IMP_2(IArchiveExtractCallback, ICryptoGetTextPassword)
public:
  ExtractCallback(Job& job, int destination, const std::vector<Entry>& entries)
      : job(job), destination(destination), entries(entries) {}
  Job& job;
  int destination;
  const std::vector<Entry>& entries;
  bool failed = false;
  STDMETHOD(SetTotal)(UInt64) noexcept override { return job.cancelled ? E_ABORT : S_OK; }
  STDMETHOD(SetCompleted)(const UInt64*) noexcept override { return job.cancelled ? E_ABORT : S_OK; }
  STDMETHOD(PrepareOperation)(Int32) noexcept override { return job.cancelled ? E_ABORT : S_OK; }
  STDMETHOD(CryptoGetTextPassword)(BSTR* value) noexcept override {
    if (job.cancelled || job.password.empty()) { job.Error("password_required"); return E_ABORT; }
    try { *value = SysAllocString(Unicode(job.password)); return *value ? S_OK : E_OUTOFMEMORY; }
    catch (...) { return E_FAIL; }
  }
  STDMETHOD(GetStream)(UInt32 index, ISequentialOutStream** stream, Int32 mode) noexcept override {
    *stream = nullptr;
    try {
      job.Check();
      if (mode != NArchive::NExtract::NAskMode::kExtract) return S_OK;
      const auto& entry = entries.at(index);
      const auto parts = Parts(entry.name);
      {
        std::lock_guard<std::mutex> lock(job.mutex);
        std::snprintf(job.status.current, sizeof(job.status.current), "%s", entry.name.c_str());
      }
      Fd parent(Walk(destination, parts, entry.directory ? parts.size() : parts.size() - 1, true));
      if (entry.directory) return S_OK;
      const int fd = openat(parent.value, parts.back().c_str(), O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
      if (fd < 0) ThrowIo();
      CMyComPtr<ISequentialOutStream> output = new Output(job, fd);
      *stream = output.Detach();
      return S_OK;
    } catch (const std::exception& error) { job.Error(error.what()); failed = true; return E_ABORT; }
  }
  STDMETHOD(SetOperationResult)(Int32 result) noexcept override {
    using namespace NArchive::NExtract::NOperationResult;
    if (result != kOK) {
      failed = true;
      job.Error(result == kWrongPassword ? "wrong_password" : result == kUnsupportedMethod ? "unsupported_method" : "corrupt_archive");
      return E_ABORT;
    }
    std::lock_guard<std::mutex> lock(job.mutex);
    ++job.status.files;
    return job.cancelled ? E_ABORT : S_OK;
  }
};

std::string SingleRegularChild(const std::string& directory) {
  std::string found;
  DIR* dir = opendir(directory.c_str());
  if (!dir) ThrowIo();
  while (auto* entry = readdir(dir)) {
    const std::string name = entry->d_name;
    if (name == "." || name == "..") continue;
    const std::string path = directory + "/" + name;
    struct stat st{};
    if (lstat(path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
      closedir(dir);
      return {};
    }
    if (!found.empty()) {
      closedir(dir);
      return {};
    }
    found = path;
  }
  closedir(dir);
  return found;
}

void Extract(Job& job, int layer = 0) {
  job.Check();
  Unicode(job.source); Unicode(job.destination); Unicode(job.password);
  Fd root(open(job.root.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
  if (root.value < 0) ThrowIo();
  const auto sourceParts = HostParts(Relative(job.root, job.source));
  Fd parent(Walk(root.value, sourceParts, sourceParts.size() - 1, false));
  Fd destination(Walk(root.value, HostParts(Relative(job.root, job.destination)), HostParts(Relative(job.root, job.destination)).size(), false));
  CMyComPtr<IInStream> input = new Input(job, OpenParts(parent.value, sourceParts.back()));
  auto* openState = new OpenCallback(job, parent.value, sourceParts.back());
  CMyComPtr<IArchiveOpenCallback> openCallback = openState;
  CMyComPtr<IInArchive> archive;
  UInt32 count = 0;
  GetNumberOfFormats(&count);
  std::string format;
  // Recognize contents rather than relying on a renamed extension. Skip disk
  // images and executable installers; this is an archive manager, not a mounter.
  const std::set<std::string> allowed = {"7z", "zip", "rar", "rar5", "tar", "gzip", "bzip2", "xz", "zstd", "cab", "arj", "lzh", "cpio", "ar", "z"};
  for (UInt32 i = 0; i < count; ++i) {
    job.Check();
    CPropVariant name, cls;
    GetHandlerProperty2(i, NArchive::NHandlerPropID::kName, &name);
    if (name.vt != VT_BSTR || !allowed.count(Lower(Utf8(name.bstrVal)))) continue;
    GetHandlerProperty2(i, NArchive::NHandlerPropID::kClassID, &cls);
    if (cls.vt != VT_BSTR || SysStringByteLen(cls.bstrVal) != sizeof(GUID)) continue;
    CMyComPtr<IInArchive> candidate;
    if (CreateArchiver(reinterpret_cast<const GUID*>(cls.bstrVal), &IID_IInArchive, reinterpret_cast<void**>(&candidate)) != S_OK) continue;
    CMyComPtr<ISetProperties> properties;
    if (candidate.QueryInterface(IID_ISetProperties, &properties) == S_OK && Lower(Utf8(name.bstrVal)) == "zip") {
      const wchar_t* names[] = {L"cp"}; CPropVariant cp; cp = static_cast<UInt32>(job.codepage);
      properties->SetProperties(names, &cp, 1);
    }
    input->Seek(0, 0, nullptr);
    const UInt64 scan = 1 << 20;
    if (candidate->Open(input, &scan, openCallback) == S_OK) {
      archive = candidate; format = Utf8(name.bstrVal); break;
    }
    candidate->Close();
    if (openState->requestedPassword) throw std::runtime_error(job.password.empty() ? "password_required" : "wrong_password");
  }
  if (!archive) throw std::runtime_error(openState->missingVolume ? "missing_volume" : "unsupported_format");
  UInt32 entriesCount = 0;
  if (archive->GetNumberOfItems(&entriesCount) != S_OK || entriesCount > kMaxEntries)
    throw std::runtime_error("archive_limit");
  std::vector<Entry> entries;
  std::set<std::string> names;
  uint64_t total = 0;
  for (UInt32 i = 0; i < entriesCount; ++i) {
    job.Check();
    CPropVariant path, isDir, size, link, hardLink, posix;
    archive->GetProperty(i, kpidPath, &path);
    archive->GetProperty(i, kpidIsDir, &isDir);
    archive->GetProperty(i, kpidSize, &size);
    archive->GetProperty(i, kpidSymLink, &link);
    archive->GetProperty(i, kpidHardLink, &hardLink);
    archive->GetProperty(i, kpidPosixAttrib, &posix);
    if (link.vt == VT_BSTR || hardLink.vt == VT_BSTR ||
        (posix.vt == VT_UI4 && (posix.ulVal & S_IFMT) != 0 && !S_ISREG(posix.ulVal) && !S_ISDIR(posix.ulVal)))
      throw std::runtime_error("unsupported_link");
    std::string name = path.vt == VT_BSTR ? Utf8(path.bstrVal) : fs::path(sourceParts.back()).stem().string();
    const auto parts = Parts(name);
    name.clear();
    for (const auto& part : parts) { if (!name.empty()) name += '/'; name += part; }
    if (!names.insert(Lower(name)).second) throw std::runtime_error("conflict");
    const uint64_t bytes = size.vt == VT_UI8 ? size.uhVal.QuadPart : size.vt == VT_UI4 ? size.ulVal : 0;
    if (bytes > kMaxExpandedBytes - total) throw std::runtime_error("archive_limit");
    total += bytes;
    entries.push_back({name, isDir.vt == VT_BOOL && isDir.boolVal != VARIANT_FALSE});
  }
  { std::lock_guard<std::mutex> lock(job.mutex); job.status.total = total; }
  auto* extractState = new ExtractCallback(job, destination.value, entries);
  CMyComPtr<IArchiveExtractCallback> callback = extractState;
  const HRESULT result = archive->Extract(nullptr, static_cast<UInt32>(-1), false, callback);
  archive->Close();
  job.Check();
  if (result != S_OK || extractState->failed) throw std::runtime_error("corrupt_archive");
  const std::set<std::string> wrappers = {"gzip", "bzip2", "xz", "zstd"};
  if (layer == 0 && wrappers.count(Lower(format))) {
    const auto nested = SingleRegularChild(job.destination);
    const auto lower = Lower(nested);
    if (!nested.empty() && lower.size() >= 4 &&
        lower.compare(lower.size() - 4, 4, ".tar") == 0) {
      const auto original = job.source;
      job.source = nested;
      Extract(job, 1);
      job.source = original;
      if (unlink(nested.c_str()) != 0 && errno != ENOENT) ThrowIo();
    }
  }
}
}  // namespace

extern "C" void* krkr_archive_start(const char* root, const char* source, const char* destination,
                                    const char* password, uint32_t codepage) {
  if (!root || !source || !destination) return nullptr;
  auto* job = new Job();
  try {
    job->root = root; job->source = source; job->destination = destination;
    job->password = password ? password : ""; job->codepage = codepage;
    job->worker = std::thread([job] {
      try { Extract(*job); std::lock_guard<std::mutex> lock(job->mutex); job->status.state = 2; }
      catch (const std::exception& error) { job->Error(error.what()); std::lock_guard<std::mutex> lock(job->mutex); job->status.state = job->cancelled ? 4 : 3; }
      catch (...) { job->Error("failed"); std::lock_guard<std::mutex> lock(job->mutex); job->status.state = 3; }
      volatile char* secret = job->password.empty() ? nullptr : &job->password[0];
      for (size_t i = 0; i < job->password.size(); ++i) secret[i] = 0;
    });
    return job;
  } catch (...) { delete job; return nullptr; }
}
extern "C" void krkr_archive_poll(void* handle, krkr_archive_status* status) {
  if (!handle || !status) return;
  auto& job = *static_cast<Job*>(handle);
  std::lock_guard<std::mutex> lock(job.mutex); *status = job.status;
}
extern "C" void krkr_archive_cancel(void* handle) { if (handle) static_cast<Job*>(handle)->cancelled = true; }
extern "C" void krkr_archive_destroy(void* handle) {
  if (!handle) return;
  auto* job = static_cast<Job*>(handle); job->cancelled = true;
  if (job->worker.joinable()) job->worker.join(); delete job;
}
