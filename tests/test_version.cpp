#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest.h>

#include <up_forever/version.hpp>

#include <cstdint>
#include <string>

using up_forever::Version;

static_assert(Version::name == "up_forever");
static_assert(Version::numeric == ((uint64_t{Version::major} << 32U) | (uint64_t{Version::minor} << 16U) | uint64_t{Version::patch}));
static_assert(Version::at_least(Version::major, Version::minor, Version::patch));
static_assert(Version::at_least(0));
static_assert(!Version::at_least(static_cast<uint16_t>(Version::major + 1)));

TEST_CASE("the version strings agree with the numbers") {
  const std::string expected = std::to_string(Version::major) + "." + std::to_string(Version::minor) + "." + std::to_string(Version::patch);
  CHECK(Version::version == expected);
  CHECK(Version::full_string == std::string(Version::name) + " v" + expected);
}
