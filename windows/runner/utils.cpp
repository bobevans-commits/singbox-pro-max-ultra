#include "utils.h"

#include <flutter/windows/flutter_windows_plugin.h>
#include <windows.h>

#include <shobjidl_core.h>

#include <algorithm>
#include <string>
#include <vector>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    freopen_s(&unused, "CONOUT$", "w", stdout);
    freopen_s(&unused, "CONOUT$", "w", stderr);
    std::cout.clear();
    std::cerr.clear();
  }
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length =
      ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, -1,
                            nullptr, 0, nullptr, nullptr) -
      1;
  if (target_length == 0) {
    return std::string();
  }
  std::string utf8_string;
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, -1, &utf8_string[0],
      target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  int target_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            utf8_string.length(), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  int converted_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), &utf16_string[0], target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }
  ::LocalFree(argv);

  return command_line_arguments;
}

std::wstring GetExecutablePath() {
  wchar_t buffer[MAX_PATH];
  unsigned int length = ::GetModuleFileName(nullptr, buffer, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(buffer, length);
}
