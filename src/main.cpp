#include <up_forever/version.hpp>

#include <iostream>
#include <string_view>

int main(int argc, char* argv[]) {
  if (argc == 2 && std::string_view{argv[1]} == "version") {
    std::cout << up_forever::version::STR_ << '\n';
    return 0;
  }

  std::cout << "Up Forever is forged and ready. 🔨\n";
  return 0;
}
