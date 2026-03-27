#include <arpa/inet.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include <array>
#include <chrono>
#include <cerrno>
#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <variant>
#include <vector>

namespace {

constexpr uint32_t kFpgaRegBase = 0xFF000000;
constexpr uint32_t kFpgaRegSize = 0x01000000;
constexpr uint32_t kSocfpgaMgrAddress = 0xFF706000;
constexpr uint32_t kMgrGpoOffset = 0x10;
constexpr uint32_t kMgrGpiOffset = 0x14;

constexpr uint32_t kSpiStrobe = 1u << 17;
constexpr uint32_t kSpiAck = kSpiStrobe;
constexpr uint32_t kGpoUserMode = 0x80000000u;
constexpr uint32_t kSspiIoEnable = 1u << 20;

constexpr uint16_t kDbgRegGetCmd = 0x0044;
constexpr uint16_t kDbgRegSetCmd = 0x0045;

constexpr uint8_t kRegStatus = 1;
constexpr uint8_t kRegError = 2;
constexpr uint8_t kRegWarning = 3;
constexpr uint8_t kRegAccessMode = 4;
constexpr uint8_t kRegCommand = 5;
constexpr uint8_t kRegTarget = 6;
constexpr uint8_t kRegAddrLo = 7;
constexpr uint8_t kRegAddrHi = 8;
constexpr uint8_t kRegLengthLo = 9;
constexpr uint8_t kRegLengthHi = 10;
constexpr uint8_t kRegWdataLo = 11;
constexpr uint8_t kRegWdataHi = 12;
constexpr uint8_t kRegExecId = 13;
constexpr uint8_t kRegDoneId = 14;
constexpr uint8_t kRegDataBase = 16;

constexpr uint8_t kCmdPause = 0x01;
constexpr uint8_t kCmdResume = 0x02;
constexpr uint8_t kCmdSetAccessMode = 0x03;
constexpr uint8_t kCmdGetAccessMode = 0x04;
constexpr uint8_t kCmdGetTargetCaps = 0x05;
constexpr uint8_t kCmdRead8 = 0x10;
constexpr uint8_t kCmdRead16 = 0x11;
constexpr uint8_t kCmdRead32 = 0x12;
constexpr uint8_t kCmdWrite8 = 0x20;
constexpr uint8_t kCmdWrite16 = 0x21;
constexpr uint8_t kCmdWrite32 = 0x22;
constexpr uint8_t kCmdReadBlock = 0x30;
constexpr uint8_t kCmdSearchBytes = 0x31;

constexpr uint16_t kAccessModePaused = 0x0000;
constexpr uint16_t kAccessModeLive = 0x0001;

constexpr uint8_t kTargetMd68kRam = 0x01;
constexpr uint8_t kTargetSubcpuRam = 0x02;
constexpr uint8_t kTargetWordRam = 0x03;
constexpr uint8_t kTargetPrgRam = 0x04;
constexpr uint8_t kTargetBackupRam = 0x05;

constexpr uint16_t kCapLiveRead = 0x0001;
constexpr uint16_t kCapLiveWrite = 0x0002;
constexpr uint16_t kCapPausedRead = 0x0004;
constexpr uint16_t kCapPausedWrite = 0x0008;
constexpr uint16_t kCapCoherent = 0x0010;
constexpr uint16_t kCapArbitrated = 0x0020;
constexpr uint16_t kCapRawPhysical = 0x0040;

constexpr uint16_t kStatusBusy = 0x0001;
constexpr uint16_t kStatusDone = 0x0002;
constexpr uint16_t kStatusError = 0x0004;
constexpr uint16_t kStatusPaused = 0x0008;
constexpr uint16_t kStatusPauseWait = 0x0010;
constexpr uint16_t kStatusDataValid = 0x0080;

constexpr uint16_t kWarnNone = 0x0000;
constexpr uint16_t kWarnArbitratedValue = 0x0001;
constexpr uint16_t kWarnRawPhysicalMapping = 0x0002;

constexpr uint16_t kErrNone = 0x0000;
constexpr uint16_t kErrInvalidCmd = 0x0001;
constexpr uint16_t kErrInvalidTarget = 0x0002;
constexpr uint16_t kErrInvalidAddr = 0x0003;
constexpr uint16_t kErrNotPaused = 0x0004;
constexpr uint16_t kErrLiveUnsupported = 0x0005;
constexpr uint16_t kErrPausedUnsupported = 0x0006;
constexpr uint16_t kErrAlignment = 0x0007;
constexpr uint16_t kErrLength = 0x0008;
constexpr uint16_t kErrTransportBusy = 0x0009;
constexpr uint16_t kErrTargetBusy = 0x000A;
constexpr uint16_t kErrInvalidMode = 0x000B;

using JsonScalar = std::variant<std::string, int64_t, bool, std::vector<int64_t>>;

struct FlatJsonObject {
  std::unordered_map<std::string, JsonScalar> values;

  const JsonScalar* Find(const std::string& key) const {
    auto it = values.find(key);
    return it == values.end() ? nullptr : &it->second;
  }

  std::optional<std::string> GetString(const std::string& key) const {
    const JsonScalar* value = Find(key);
    if (!value || !std::holds_alternative<std::string>(*value)) return std::nullopt;
    return std::get<std::string>(*value);
  }

  std::optional<int64_t> GetInt(const std::string& key) const {
    const JsonScalar* value = Find(key);
    if (!value || !std::holds_alternative<int64_t>(*value)) return std::nullopt;
    return std::get<int64_t>(*value);
  }

  std::optional<bool> GetBool(const std::string& key) const {
    const JsonScalar* value = Find(key);
    if (!value || !std::holds_alternative<bool>(*value)) return std::nullopt;
    return std::get<bool>(*value);
  }

  std::optional<std::vector<int64_t>> GetIntArray(const std::string& key) const {
    const JsonScalar* value = Find(key);
    if (!value || !std::holds_alternative<std::vector<int64_t>>(*value)) return std::nullopt;
    return std::get<std::vector<int64_t>>(*value);
  }
};

struct TargetSpec {
  const char* name;
  uint8_t id;
  const char* alias_of;
  const char* note;
};

constexpr std::array<TargetSpec, 5> kTargets{{
    {"md68k_ram", kTargetMd68kRam, nullptr, "Genesis main 68k work RAM"},
    {"subcpu_ram", kTargetSubcpuRam, "prgram", "Aliases Sega CD PRG-RAM in this core"},
    {"wordram", kTargetWordRam, nullptr, "Physical Word RAM banks, not logical remaps"},
    {"prgram", kTargetPrgRam, nullptr, "Sega CD PRG-RAM"},
    {"backup_ram", kTargetBackupRam, nullptr, "Sega CD backup RAM"},
}};

std::string Trim(const std::string& value) {
  size_t begin = 0;
  while (begin < value.size() && std::isspace(static_cast<unsigned char>(value[begin]))) {
    ++begin;
  }
  size_t end = value.size();
  while (end > begin && std::isspace(static_cast<unsigned char>(value[end - 1]))) {
    --end;
  }
  return value.substr(begin, end - begin);
}

std::string JsonEscape(const std::string& value) {
  std::string out;
  out.reserve(value.size() + 8);
  for (unsigned char ch : value) {
    switch (ch) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (ch < 0x20) {
          char buf[7];
          std::snprintf(buf, sizeof(buf), "\\u%04x", ch);
          out += buf;
        } else {
          out.push_back(static_cast<char>(ch));
        }
    }
  }
  return out;
}

bool ParseInteger(const std::string& text, int64_t& value) {
  if (text.empty()) return false;
  char* end = nullptr;
  errno = 0;
  long long parsed = 0;
  if (text.size() > 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X')) {
    parsed = std::strtoll(text.c_str(), &end, 16);
  } else {
    parsed = std::strtoll(text.c_str(), &end, 10);
  }
  if (errno || !end || *end) return false;
  value = static_cast<int64_t>(parsed);
  return true;
}

void SkipWs(const std::string& text, size_t& pos) {
  while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos]))) ++pos;
}

bool ParseJsonString(const std::string& text, size_t& pos, std::string& out, std::string& error) {
  if (pos >= text.size() || text[pos] != '"') {
    error = "expected string";
    return false;
  }
  ++pos;
  out.clear();
  while (pos < text.size()) {
    char ch = text[pos++];
    if (ch == '"') return true;
    if (ch == '\\') {
      if (pos >= text.size()) {
        error = "unterminated escape";
        return false;
      }
      char esc = text[pos++];
      switch (esc) {
        case '\\': out.push_back('\\'); break;
        case '"': out.push_back('"'); break;
        case 'n': out.push_back('\n'); break;
        case 'r': out.push_back('\r'); break;
        case 't': out.push_back('\t'); break;
        default:
          error = "unsupported escape";
          return false;
      }
    } else {
      out.push_back(ch);
    }
  }
  error = "unterminated string";
  return false;
}

bool ParseJsonArray(const std::string& text, size_t& pos, std::vector<int64_t>& out, std::string& error) {
  if (pos >= text.size() || text[pos] != '[') {
    error = "expected array";
    return false;
  }
  ++pos;
  out.clear();

  while (true) {
    SkipWs(text, pos);
    if (pos >= text.size()) {
      error = "unterminated array";
      return false;
    }
    if (text[pos] == ']') {
      ++pos;
      return true;
    }

    size_t start = pos;
    while (pos < text.size() && text[pos] != ',' && text[pos] != ']') ++pos;
    std::string token = Trim(text.substr(start, pos - start));
    int64_t parsed = 0;
    if (!ParseInteger(token, parsed)) {
      error = "arrays may only contain integers";
      return false;
    }
    out.push_back(parsed);

    SkipWs(text, pos);
    if (pos >= text.size()) {
      error = "unterminated array";
      return false;
    }
    if (text[pos] == ',') {
      ++pos;
      continue;
    }
    if (text[pos] == ']') {
      ++pos;
      return true;
    }

    error = "expected ',' or ']'";
    return false;
  }
}

bool ParseJsonValue(const std::string& text, size_t& pos, JsonScalar& out, std::string& error) {
  SkipWs(text, pos);
  if (pos >= text.size()) {
    error = "missing value";
    return false;
  }

  if (text[pos] == '"') {
    std::string parsed;
    if (!ParseJsonString(text, pos, parsed, error)) return false;
    out = parsed;
    return true;
  }

  if (text[pos] == '[') {
    std::vector<int64_t> parsed;
    if (!ParseJsonArray(text, pos, parsed, error)) return false;
    out = parsed;
    return true;
  }

  size_t start = pos;
  while (pos < text.size() && text[pos] != ',' && text[pos] != '}') ++pos;
  std::string token = Trim(text.substr(start, pos - start));
  if (token == "true") {
    out = true;
    return true;
  }
  if (token == "false") {
    out = false;
    return true;
  }

  int64_t parsed = 0;
  if (!ParseInteger(token, parsed)) {
    error = "unsupported value";
    return false;
  }
  out = parsed;
  return true;
}

bool ParseFlatJsonObject(const std::string& text, FlatJsonObject& out, std::string& error) {
  out.values.clear();
  size_t pos = 0;
  SkipWs(text, pos);
  if (pos >= text.size() || text[pos] != '{') {
    error = "expected object";
    return false;
  }
  ++pos;

  while (true) {
    SkipWs(text, pos);
    if (pos >= text.size()) {
      error = "unterminated object";
      return false;
    }
    if (text[pos] == '}') {
      ++pos;
      SkipWs(text, pos);
      if (pos != text.size()) {
        error = "trailing data";
        return false;
      }
      return true;
    }

    std::string key;
    if (!ParseJsonString(text, pos, key, error)) return false;
    SkipWs(text, pos);
    if (pos >= text.size() || text[pos] != ':') {
      error = "expected ':'";
      return false;
    }
    ++pos;

    JsonScalar value;
    if (!ParseJsonValue(text, pos, value, error)) return false;
    out.values[key] = value;

    SkipWs(text, pos);
    if (pos >= text.size()) {
      error = "unterminated object";
      return false;
    }
    if (text[pos] == ',') {
      ++pos;
      continue;
    }
    if (text[pos] == '}') {
      ++pos;
      SkipWs(text, pos);
      if (pos != text.size()) {
        error = "trailing data";
        return false;
      }
      return true;
    }

    error = "expected ',' or '}'";
    return false;
  }
}

std::string BoolJson(bool value) {
  return value ? "true" : "false";
}

std::string ErrorName(uint16_t code) {
  switch (code) {
    case kErrNone: return "none";
    case kErrInvalidCmd: return "invalid_cmd";
    case kErrInvalidTarget: return "invalid_target";
    case kErrInvalidAddr: return "invalid_addr";
    case kErrNotPaused: return "not_paused";
    case kErrLiveUnsupported: return "live_unsupported";
    case kErrPausedUnsupported: return "paused_unsupported";
    case kErrAlignment: return "alignment";
    case kErrLength: return "length";
    case kErrTransportBusy: return "transport_busy";
    case kErrTargetBusy: return "target_busy";
    case kErrInvalidMode: return "invalid_mode";
    default: return "unknown";
  }
}

std::string WarningName(uint16_t code) {
  switch (code) {
    case kWarnNone: return "none";
    case kWarnArbitratedValue: return "arbitrated_current_value";
    case kWarnRawPhysicalMapping: return "raw_physical_mapping";
    default: return "unknown";
  }
}

std::string AccessModeName(uint16_t mode) {
  switch (mode) {
    case kAccessModePaused: return "paused";
    case kAccessModeLive: return "live";
    default: return "unknown";
  }
}

std::optional<uint16_t> AccessModeFromString(const std::string& value) {
  if (value == "paused") return kAccessModePaused;
  if (value == "live") return kAccessModeLive;
  return std::nullopt;
}

std::optional<TargetSpec> FindTargetByName(const std::string& name) {
  for (const auto& target : kTargets) {
    if (name == target.name) return target;
  }
  return std::nullopt;
}

std::string RawPhysicalNoteForTarget(uint8_t target_id) {
  if (target_id == kTargetWordRam) {
    return "Addresses are physical Word RAM bytes: 0x00000-0x1FFFF bank 0, 0x20000-0x3FFFF bank 1.";
  }
  return "";
}

class FpgaIo {
 public:
  ~FpgaIo() {
    if (map_base_) munmap(const_cast<uint32_t*>(map_base_), kFpgaRegSize);
    if (mem_fd_ >= 0) close(mem_fd_);
  }

  bool Initialize(std::string& error) {
    mem_fd_ = open("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC);
    if (mem_fd_ < 0) {
      error = "unable to open /dev/mem";
      return false;
    }

    void* mapped = mmap(nullptr, kFpgaRegSize, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd_, kFpgaRegBase);
    if (mapped == MAP_FAILED) {
      error = "unable to mmap FPGA register space";
      close(mem_fd_);
      mem_fd_ = -1;
      return false;
    }

    map_base_ = static_cast<volatile uint32_t*>(mapped);
    WriteGpo(0);
    return true;
  }

  void SetIoSelected(bool enabled) {
    uint32_t gpo = gpo_copy_ | kGpoUserMode;
    WriteGpo(enabled ? (gpo | kSspiIoEnable) : (gpo & ~kSspiIoEnable));
  }

  bool SpiWord(uint16_t word, uint16_t& result, std::string& error) {
    uint32_t gpo = (gpo_copy_ & ~(0xFFFFu | kSpiStrobe)) | word;
    WriteGpo(gpo);
    WriteGpo(gpo | kSpiStrobe);

    auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(100);
    while (true) {
      int gpi = ReadGpi();
      if (gpi < 0) {
        error = "FPGA not ready";
        return false;
      }
      if (gpi & kSpiAck) break;
      if (std::chrono::steady_clock::now() > deadline) {
        error = "SPI acknowledge timeout";
        return false;
      }
    }

    WriteGpo(gpo);

    while (true) {
      int gpi = ReadGpi();
      if (gpi < 0) {
        error = "FPGA not ready";
        return false;
      }
      if (!(gpi & kSpiAck)) {
        result = static_cast<uint16_t>(gpi);
        return true;
      }
      if (std::chrono::steady_clock::now() > deadline) {
        error = "SPI release timeout";
        return false;
      }
    }
  }

 private:
  volatile uint32_t* RegisterPtr(uint32_t address) {
    uint32_t offset = (address - kFpgaRegBase) >> 2;
    return const_cast<volatile uint32_t*>(map_base_ + offset);
  }

  void WriteGpo(uint32_t value) {
    gpo_copy_ = value;
    *RegisterPtr(kSocfpgaMgrAddress + kMgrGpoOffset) = value;
  }

  int ReadGpi() const {
    uint32_t offset = ((kSocfpgaMgrAddress + kMgrGpiOffset) - kFpgaRegBase) >> 2;
    return static_cast<int>(map_base_[offset]);
  }

  int mem_fd_ = -1;
  volatile uint32_t* map_base_ = nullptr;
  uint32_t gpo_copy_ = 0;
};

struct MailboxResult {
  bool transport_ok = false;
  bool ok = false;
  uint16_t status = 0;
  uint16_t error = kErrNone;
  uint16_t warning = kWarnNone;
  uint16_t access_mode = kAccessModePaused;
  uint16_t exec_id = 0;
  std::array<uint16_t, 16> data{};
  std::string transport_error;
};

class DebugMailbox {
 public:
  bool Initialize(std::string& error) {
    return io_.Initialize(error);
  }

  bool GetStatus(uint16_t& status, std::string& error) {
    std::lock_guard<std::mutex> lock(mutex_);
    return ReadRegLocked(kRegStatus, status, error);
  }

  bool ReadActiveAccessMode(uint16_t& mode, std::string& error) {
    std::lock_guard<std::mutex> lock(mutex_);
    return ReadRegLocked(kRegAccessMode, mode, error);
  }

  MailboxResult RunCommand(uint8_t command,
                           uint8_t target,
                           uint32_t address,
                           uint32_t length,
                           uint32_t value,
                           std::optional<uint16_t> staged_mode,
                           int timeout_ms,
                           const std::vector<uint8_t>* window_data = nullptr) {
    std::lock_guard<std::mutex> lock(mutex_);
    MailboxResult result;

    uint16_t status = 0;
    if (!ReadRegLocked(kRegStatus, status, result.transport_error)) return result;
    if (status & kStatusBusy) {
      result.transport_ok = true;
      result.status = status;
      result.error = kErrTransportBusy;
      return result;
    }

    if (staged_mode.has_value() && !WriteRegLocked(kRegAccessMode, *staged_mode, result.transport_error)) return result;
    if (!WriteRegLocked(kRegCommand, command, result.transport_error)) return result;
    if (!WriteRegLocked(kRegTarget, target, result.transport_error)) return result;
    if (!WriteRegLocked(kRegAddrLo, static_cast<uint16_t>(address), result.transport_error)) return result;
    if (!WriteRegLocked(kRegAddrHi, static_cast<uint16_t>(address >> 16), result.transport_error)) return result;
    if (!WriteRegLocked(kRegLengthLo, static_cast<uint16_t>(length), result.transport_error)) return result;
    if (!WriteRegLocked(kRegLengthHi, static_cast<uint16_t>(length >> 16), result.transport_error)) return result;
    if (!WriteRegLocked(kRegWdataLo, static_cast<uint16_t>(value), result.transport_error)) return result;
    if (!WriteRegLocked(kRegWdataHi, static_cast<uint16_t>(value >> 16), result.transport_error)) return result;
    if (window_data) {
      for (size_t index = 0; index < result.data.size(); ++index) {
        uint16_t word = 0;
        size_t byte_index = index << 1;
        if (byte_index < window_data->size()) {
          word |= static_cast<uint16_t>((*window_data)[byte_index]) << 8;
        }
        if ((byte_index + 1) < window_data->size()) {
          word |= static_cast<uint16_t>((*window_data)[byte_index + 1]);
        }
        if (!WriteRegLocked(static_cast<uint8_t>(kRegDataBase + index), word, result.transport_error)) {
          return result;
        }
      }
    }

    uint16_t exec_id = next_exec_id_++;
    if (!next_exec_id_) ++next_exec_id_;
    result.exec_id = exec_id;

    if (!WriteRegLocked(kRegExecId, exec_id, result.transport_error)) return result;

    auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
    uint16_t done_id = 0;
    while (true) {
      if (!ReadRegLocked(kRegStatus, result.status, result.transport_error)) return result;
      if (!ReadRegLocked(kRegDoneId, done_id, result.transport_error)) return result;
      if ((result.status & kStatusDone) && done_id == exec_id) break;
      if (std::chrono::steady_clock::now() > deadline) {
        result.transport_error = "mailbox command timeout";
        return result;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    if (!ReadRegLocked(kRegError, result.error, result.transport_error)) return result;
    if (!ReadRegLocked(kRegWarning, result.warning, result.transport_error)) return result;
    if (!ReadRegLocked(kRegAccessMode, result.access_mode, result.transport_error)) return result;

    if (result.status & kStatusDataValid) {
      for (size_t index = 0; index < result.data.size(); ++index) {
        if (!ReadRegLocked(static_cast<uint8_t>(kRegDataBase + index), result.data[index], result.transport_error)) {
          return result;
        }
      }
    }

    result.transport_ok = true;
    result.ok = !(result.status & kStatusError) && result.error == kErrNone;
    return result;
  }

  MailboxResult QueryTargetCaps(uint8_t target, int timeout_ms) {
    return RunCommand(kCmdGetTargetCaps, target, 0, 0, 0, std::nullopt, timeout_ms);
  }

 private:
  bool ReadRegLocked(uint8_t reg, uint16_t& value, std::string& error) {
    io_.SetIoSelected(true);
    uint16_t discard = 0;
    bool ok = io_.SpiWord(kDbgRegGetCmd, discard, error) &&
              io_.SpiWord(reg, discard, error) &&
              io_.SpiWord(0, value, error);
    io_.SetIoSelected(false);
    return ok;
  }

  bool WriteRegLocked(uint8_t reg, uint16_t value, std::string& error) {
    io_.SetIoSelected(true);
    uint16_t discard = 0;
    bool ok = io_.SpiWord(kDbgRegSetCmd, discard, error) &&
              io_.SpiWord(reg, discard, error) &&
              io_.SpiWord(value, discard, error);
    io_.SetIoSelected(false);
    return ok;
  }

  FpgaIo io_;
  std::mutex mutex_;
  uint16_t next_exec_id_ = 1;
};

std::string CapabilityJson(uint16_t caps, const TargetSpec& target) {
  std::ostringstream out;
  out << "{"
      << "\"supports_live_read\":" << BoolJson(caps & kCapLiveRead) << ','
      << "\"supports_live_write\":" << BoolJson(caps & kCapLiveWrite) << ','
      << "\"supports_paused_read\":" << BoolJson(caps & kCapPausedRead) << ','
      << "\"supports_paused_write\":" << BoolJson(caps & kCapPausedWrite) << ','
      << "\"coherence\":\""
      << JsonEscape((caps & kCapCoherent) ? "coherent_snapshot"
                                          : (caps & kCapArbitrated) ? "arbitrated_current_value"
                                                                    : (caps & kCapRawPhysical) ? "raw_physical_mapping"
                                                                                               : "unspecified")
      << "\"";
  if (target.alias_of) {
    out << ",\"alias_of\":\"" << JsonEscape(target.alias_of) << "\"";
  }
  if (target.note) {
    out << ",\"note\":\"" << JsonEscape(target.note) << "\"";
  }
  std::string raw_note = RawPhysicalNoteForTarget(target.id);
  if (!raw_note.empty()) {
    out << ",\"raw_addressing\":\"" << JsonEscape(raw_note) << "\"";
  }
  out << "}";
  return out.str();
}

std::vector<uint8_t> DecodeBytes(const MailboxResult& result, size_t count) {
  std::vector<uint8_t> bytes;
  bytes.reserve(count);
  for (size_t index = 0; index < count; ++index) {
    uint16_t word = result.data[index >> 1];
    bytes.push_back(static_cast<uint8_t>((index & 1) ? (word & 0xFF) : (word >> 8)));
  }
  return bytes;
}

std::string BytesJson(const std::vector<uint8_t>& bytes) {
  std::ostringstream out;
  out << "[";
  for (size_t index = 0; index < bytes.size(); ++index) {
    if (index) out << ",";
    out << static_cast<unsigned int>(bytes[index]);
  }
  out << "]";
  return out.str();
}

std::string BaseResultJson(const MailboxResult& result) {
  std::ostringstream out;
  out << "\"executed_mode\":\"" << JsonEscape(AccessModeName(result.access_mode)) << "\""
      << ",\"paused\":" << BoolJson(result.status & kStatusPaused)
      << ",\"pause_wait\":" << BoolJson(result.status & kStatusPauseWait);
  if (result.warning != kWarnNone) {
    out << ",\"warning\":\"" << JsonEscape(WarningName(result.warning)) << "\"";
  }
  return out.str();
}

std::string JsonErrorResponse(const std::string& message,
                              std::optional<std::string> code = std::nullopt) {
  std::ostringstream out;
  out << "{\"ok\":false,\"error\":\"" << JsonEscape(message) << "\"";
  if (code.has_value()) {
    out << ",\"error_code\":\"" << JsonEscape(*code) << "\"";
  }
  out << "}";
  return out.str();
}

std::string MailboxFailureJson(const MailboxResult& result) {
  if (!result.transport_ok) {
    return JsonErrorResponse(result.transport_error.empty() ? "transport failure" : result.transport_error,
                             "transport");
  }

  std::ostringstream out;
  out << "{\"ok\":false,\"error\":\"" << JsonEscape(ErrorName(result.error)) << "\""
      << ",\"error_code\":\"" << JsonEscape(ErrorName(result.error)) << "\"";
  if (result.warning != kWarnNone) {
    out << ",\"warning\":\"" << JsonEscape(WarningName(result.warning)) << "\"";
  }
  out << "," << BaseResultJson(result) << "}";
  return out.str();
}

std::string SuccessJson(const std::string& body) {
  return std::string("{\"ok\":true,") + body + "}";
}

std::string HandleRequest(DebugMailbox& mailbox, const std::string& line, int timeout_ms) {
  FlatJsonObject request;
  std::string parse_error;
  if (!ParseFlatJsonObject(line, request, parse_error)) {
    return JsonErrorResponse("invalid json: " + parse_error, "invalid_json");
  }

  auto command = request.GetString("cmd");
  if (!command.has_value()) {
    return JsonErrorResponse("missing cmd", "invalid_request");
  }

  if (*command == "pause") {
    MailboxResult result = mailbox.RunCommand(kCmdPause, 0, 0, 0, 0, std::nullopt, timeout_ms);
    if (!result.ok) return MailboxFailureJson(result);
    return SuccessJson(BaseResultJson(result));
  }

  if (*command == "resume") {
    MailboxResult result = mailbox.RunCommand(kCmdResume, 0, 0, 0, 0, std::nullopt, timeout_ms);
    if (!result.ok) return MailboxFailureJson(result);
    return SuccessJson(BaseResultJson(result));
  }

  if (*command == "set_access_mode") {
    auto mode_name = request.GetString("mode");
    if (!mode_name.has_value()) {
      return JsonErrorResponse("missing mode", "invalid_request");
    }
    auto mode = AccessModeFromString(*mode_name);
    if (!mode.has_value()) {
      return JsonErrorResponse("unsupported mode", "invalid_mode");
    }

    MailboxResult result = mailbox.RunCommand(kCmdSetAccessMode, 0, 0, 0, 0, mode, timeout_ms);
    if (!result.ok) return MailboxFailureJson(result);
    return SuccessJson(std::string("\"access_mode\":\"") + JsonEscape(AccessModeName(result.access_mode)) +
                       "\"," + BaseResultJson(result));
  }

  if (*command == "get_access_mode") {
    MailboxResult result = mailbox.RunCommand(kCmdGetAccessMode, 0, 0, 0, 0, std::nullopt, timeout_ms);
    if (!result.ok) return MailboxFailureJson(result);
    uint16_t mode = result.data[0];
    return SuccessJson(std::string("\"access_mode\":\"") + JsonEscape(AccessModeName(mode)) + "\"");
  }

  if (*command == "get_target_caps") {
    auto target_name = request.GetString("target");
    if (target_name.has_value()) {
      auto target = FindTargetByName(*target_name);
      if (!target.has_value()) return JsonErrorResponse("unknown target", "invalid_target");
      MailboxResult result = mailbox.QueryTargetCaps(target->id, timeout_ms);
      if (!result.ok) return MailboxFailureJson(result);
      return SuccessJson(std::string("\"target\":\"") + JsonEscape(target->name) +
                         "\",\"caps\":" + CapabilityJson(result.data[0], *target));
    }

    std::ostringstream caps_json;
    caps_json << "\"targets\":{";
    bool first = true;
    for (const auto& target : kTargets) {
      MailboxResult result = mailbox.QueryTargetCaps(target.id, timeout_ms);
      if (!result.ok) return MailboxFailureJson(result);
      if (!first) caps_json << ",";
      first = false;
      caps_json << "\"" << JsonEscape(target.name) << "\":" << CapabilityJson(result.data[0], target);
    }
    caps_json << "}";
    return SuccessJson(caps_json.str());
  }

  if (*command == "search_bytes") {
    auto target_name = request.GetString("target");
    auto address = request.GetInt("addr");
    auto search_length = request.GetInt("length");
    auto maybe_data = request.GetIntArray("data");
    if (!target_name.has_value() || !address.has_value() || !search_length.has_value() || !maybe_data.has_value()) {
      return JsonErrorResponse("missing target, addr, length, or data", "invalid_request");
    }
    if (*address < 0) {
      return JsonErrorResponse("addr must be non-negative", "invalid_request");
    }
    if (*search_length <= 0) {
      return JsonErrorResponse("length must be positive", "invalid_request");
    }

    auto target = FindTargetByName(*target_name);
    if (!target.has_value()) {
      return JsonErrorResponse("unknown target", "invalid_target");
    }

    std::vector<uint8_t> bytes;
    bytes.reserve(maybe_data->size());
    for (int64_t value : *maybe_data) {
      if (value < 0 || value > 255) {
        return JsonErrorResponse("data bytes must be in range 0..255", "invalid_request");
      }
      bytes.push_back(static_cast<uint8_t>(value));
    }
    if (bytes.empty() || bytes.size() > 32) {
      return JsonErrorResponse("data must contain between 1 and 32 bytes", "invalid_request");
    }

    MailboxResult result = mailbox.RunCommand(
        kCmdSearchBytes,
        target->id,
        static_cast<uint32_t>(*address),
        static_cast<uint32_t>(*search_length),
        static_cast<uint32_t>(bytes.size()),
        std::nullopt,
        timeout_ms,
        &bytes);
    if (!result.ok) return MailboxFailureJson(result);

    std::ostringstream body;
    body << "\"target\":\"" << JsonEscape(target->name) << "\""
         << ",\"addr\":" << static_cast<uint32_t>(*address)
         << ",\"length\":" << static_cast<uint32_t>(*search_length)
         << ",\"pattern_length\":" << bytes.size()
         << ",\"data\":" << BytesJson(bytes)
         << ",\"found\":" << BoolJson(result.status & kStatusDataValid)
         << "," << BaseResultJson(result);
    if (result.status & kStatusDataValid) {
      uint32_t match_addr = static_cast<uint32_t>(result.data[0]) |
                            (static_cast<uint32_t>(result.data[1]) << 16);
      body << ",\"match_addr\":" << match_addr;
    }
    return SuccessJson(body.str());
  }

  uint8_t mailbox_command = 0;
  size_t result_bytes = 0;
  bool is_write = false;
  if (*command == "read8") {
    mailbox_command = kCmdRead8;
    result_bytes = 1;
  } else if (*command == "read16") {
    mailbox_command = kCmdRead16;
    result_bytes = 2;
  } else if (*command == "read32") {
    mailbox_command = kCmdRead32;
    result_bytes = 4;
  } else if (*command == "write8") {
    mailbox_command = kCmdWrite8;
    is_write = true;
  } else if (*command == "write16") {
    mailbox_command = kCmdWrite16;
    is_write = true;
  } else if (*command == "write32") {
    mailbox_command = kCmdWrite32;
    is_write = true;
  } else if (*command == "read_block") {
    mailbox_command = kCmdReadBlock;
  } else {
    return JsonErrorResponse("unsupported cmd", "invalid_cmd");
  }

  auto target_name = request.GetString("target");
  auto address = request.GetInt("addr");
  if (!target_name.has_value() || !address.has_value()) {
    return JsonErrorResponse("missing target or addr", "invalid_request");
  }
  if (*address < 0) {
    return JsonErrorResponse("addr must be non-negative", "invalid_request");
  }

  auto target = FindTargetByName(*target_name);
  if (!target.has_value()) {
    return JsonErrorResponse("unknown target", "invalid_target");
  }

  uint32_t length = 0;
  uint32_t value = 0;
  if (*command == "read_block") {
    auto read_length = request.GetInt("length");
    if (!read_length.has_value() || *read_length <= 0) {
      return JsonErrorResponse("missing length", "invalid_request");
    }
    length = static_cast<uint32_t>(*read_length);
    result_bytes = length;
  } else if (is_write) {
    auto maybe_value = request.GetInt("value");
    if (!maybe_value.has_value() || *maybe_value < 0) {
      return JsonErrorResponse("missing value", "invalid_request");
    }
    value = static_cast<uint32_t>(*maybe_value);
  }

  MailboxResult result = mailbox.RunCommand(
      mailbox_command, target->id, static_cast<uint32_t>(*address), length, value, std::nullopt, timeout_ms);
  if (!result.ok) return MailboxFailureJson(result);

  std::ostringstream body;
  body << "\"target\":\"" << JsonEscape(target->name) << "\""
       << ",\"addr\":" << static_cast<uint32_t>(*address) << ","
       << BaseResultJson(result);

  if (!is_write) {
    std::vector<uint8_t> bytes = DecodeBytes(result, result_bytes);
    if (mailbox_command == kCmdRead8) {
      body << ",\"value\":" << static_cast<unsigned int>(bytes[0]);
    } else if (mailbox_command == kCmdRead16) {
      body << ",\"value\":" << ((static_cast<uint32_t>(bytes[0]) << 8) | bytes[1]);
    } else if (mailbox_command == kCmdRead32) {
      uint32_t word = (static_cast<uint32_t>(bytes[0]) << 24) |
                      (static_cast<uint32_t>(bytes[1]) << 16) |
                      (static_cast<uint32_t>(bytes[2]) << 8) |
                      static_cast<uint32_t>(bytes[3]);
      body << ",\"value\":" << word;
    } else {
      body << ",\"length\":" << bytes.size() << ",\"data\":" << BytesJson(bytes);
    }
  }

  return SuccessJson(body.str());
}

void SetSocketTimeouts(int fd, int timeout_ms) {
  timeval timeout{};
  timeout.tv_sec = timeout_ms / 1000;
  timeout.tv_usec = (timeout_ms % 1000) * 1000;
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
}

void ServeClient(int client_fd, DebugMailbox& mailbox, int timeout_ms) {
  SetSocketTimeouts(client_fd, timeout_ms);
  FILE* stream = fdopen(client_fd, "r+");
  if (!stream) {
    close(client_fd);
    return;
  }

  char* line = nullptr;
  size_t capacity = 0;
  while (getline(&line, &capacity, stream) != -1) {
    std::string request = Trim(line);
    if (request.empty()) continue;
    std::string response = HandleRequest(mailbox, request, timeout_ms);
    std::fprintf(stream, "%s\n", response.c_str());
    std::fflush(stream);
  }

  free(line);
  fclose(stream);
}

bool RunServer(DebugMailbox& mailbox, const std::string& bind_host, int port, int timeout_ms, std::string& error) {
  addrinfo hints{};
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_PASSIVE;

  addrinfo* results = nullptr;
  std::string port_text = std::to_string(port);
  int gai = getaddrinfo(bind_host.c_str(), port_text.c_str(), &hints, &results);
  if (gai != 0) {
    error = std::string("getaddrinfo failed: ") + gai_strerror(gai);
    return false;
  }

  int listen_fd = -1;
  for (addrinfo* entry = results; entry; entry = entry->ai_next) {
    listen_fd = socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
    if (listen_fd < 0) continue;

    int reuse = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    if (bind(listen_fd, entry->ai_addr, entry->ai_addrlen) == 0 && listen(listen_fd, 4) == 0) {
      break;
    }

    close(listen_fd);
    listen_fd = -1;
  }
  freeaddrinfo(results);

  if (listen_fd < 0) {
    error = "unable to bind listening socket";
    return false;
  }

  std::cerr << "mcd_debugd listening on " << bind_host << ":" << port << std::endl;
  while (true) {
    int client_fd = accept(listen_fd, nullptr, nullptr);
    if (client_fd < 0) {
      if (errno == EINTR) continue;
      error = "accept failed";
      close(listen_fd);
      return false;
    }
    std::thread(ServeClient, client_fd, std::ref(mailbox), timeout_ms).detach();
  }
}

void PrintUsage(const char* program) {
  std::cout
      << "Usage:\n"
      << "  " << program << " --stdio [--timeout-ms N]\n"
      << "  " << program << " --command '<json>' [--timeout-ms N]\n"
      << "  " << program << " [--bind HOST|--listen-all] [--port N] [--timeout-ms N]\n";
}

}  // namespace

int main(int argc, char** argv) {
  std::string bind_host = "127.0.0.1";
  int port = 24512;
  int timeout_ms = 750;
  bool stdio_mode = false;
  std::optional<std::string> single_command;

  for (int index = 1; index < argc; ++index) {
    std::string arg = argv[index];
    if (arg == "--bind" && index + 1 < argc) {
      bind_host = argv[++index];
    } else if (arg == "--listen-all") {
      bind_host = "0.0.0.0";
    } else if (arg == "--port" && index + 1 < argc) {
      port = std::atoi(argv[++index]);
    } else if (arg == "--timeout-ms" && index + 1 < argc) {
      timeout_ms = std::atoi(argv[++index]);
    } else if (arg == "--stdio") {
      stdio_mode = true;
    } else if (arg == "--command" && index + 1 < argc) {
      single_command = argv[++index];
    } else if (arg == "--help" || arg == "-h") {
      PrintUsage(argv[0]);
      return 0;
    } else {
      std::cerr << "Unknown argument: " << arg << std::endl;
      PrintUsage(argv[0]);
      return 2;
    }
  }

  DebugMailbox mailbox;
  std::string error;
  if (!mailbox.Initialize(error)) {
    std::cerr << "mcd_debugd: " << error << std::endl;
    return 1;
  }

  if (single_command.has_value()) {
    std::cout << HandleRequest(mailbox, *single_command, timeout_ms) << std::endl;
    return 0;
  }

  if (stdio_mode) {
    std::string line;
    while (std::getline(std::cin, line)) {
      line = Trim(line);
      if (line.empty()) continue;
      std::cout << HandleRequest(mailbox, line, timeout_ms) << std::endl;
    }
    return 0;
  }

  if (!RunServer(mailbox, bind_host, port, timeout_ms, error)) {
    std::cerr << "mcd_debugd: " << error << std::endl;
    return 1;
  }

  return 0;
}
