#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

#include <up_forever/version.hpp>

#include <cstdint>
#include <string_view>

namespace {

  using namespace up_forever::version;

  constexpr uint64_t EXPECTED_NUMERIC =
      (static_cast<uint64_t>(MAJOR_) << 32U) | (static_cast<uint64_t>(MINOR_) << 16U) | static_cast<uint64_t>(PATCH_);

  static_assert(NAME_ == std::string_view{"up-forever"});
  static_assert(NUMERIC_ == EXPECTED_NUMERIC);
  static_assert(at_least(MAJOR_, MINOR_, PATCH_));

  TEST_CASE("version exposes generated project metadata") {
    CHECK(STR_ == std::string_view{"0.0.1"});
    CHECK(at_least(0, 0, 0));
  }

} // namespace
