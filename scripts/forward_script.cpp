/* Launcher shim: exec a Python script through a known-good interpreter without
baking either path into the script itself. Lets scripts/ drop the venv
shebang that made them unrunnable anywhere but one machine — the build system
supplies the paths, so CI and a dev box get the same binary from the same
source. Mirrors the pattern used in iamgarden. */

#include <cstdio>
#include <filesystem>
#include <print>
#include <string_view>
#include <unistd.h>
#include <vector>

#if !defined(PROJECT_PYTHON_PATH)
#define PROJECT_PYTHON_PATH ""
#endif
#if !defined(PROJECT_SCRIPT_PATH)
#define PROJECT_SCRIPT_PATH ""
#endif

constexpr std::string_view PATH_TO_PYTHON = PROJECT_PYTHON_PATH;
constexpr std::string_view PATH_TO_SCRIPT = PROJECT_SCRIPT_PATH;

int main(int argc, char* argv[]) {
  if (PATH_TO_PYTHON.empty()) {
    std::print(stderr, "PROJECT_PYTHON_PATH must be defined by the build system");
    return 1;
  }
  if (PATH_TO_SCRIPT.empty()) {
    std::print(stderr, "PROJECT_SCRIPT_PATH must be defined by the build system");
    return 1;
  }

  if (!std::filesystem::exists(PATH_TO_PYTHON)) {
    std::print(stderr, "Error: Python interpreter not found at {}\n", PATH_TO_PYTHON);
    return 1;
  }
  if (!std::filesystem::exists(PATH_TO_SCRIPT)) {
    std::print(stderr, "Error: script not found at {}\n", PATH_TO_SCRIPT);
    return 1;
  }

  std::vector<char*> args = {const_cast<char*>(PATH_TO_PYTHON.data()), const_cast<char*>(PATH_TO_SCRIPT.data())};
  for (int i = 1; i < argc; ++i) args.push_back(argv[i]);
  args.push_back(nullptr);

  execvp(args[0], args.data());
  // Only reached if exec failed — otherwise this process is already gone.
  perror("execvp");
  return 1;
}
