#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <vector>
namespace artc {
struct SavedCommand {
    std::string name;
    std::map<std::string,std::string> attrs;
};
struct NativeSave {
    std::map<std::string,std::string> variables;
    std::vector<SavedCommand> layers;
    std::map<std::string,std::vector<SavedCommand>> text;
};
// BOWS v1003: zlib envelope around CSerializer data plus its field directory.
// This is an importer. It does not claim that a compatibility save can be
// exported to an original engine, nor discard/overwrite unknown native fields.
// Outputs are replaced only after the entire supported structure validates.
bool DecodeNativeSave(const std::vector<uint8_t>& file, NativeSave& out, std::string& error);
}
