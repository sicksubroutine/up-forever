#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest.h>

#include <up_forever/build_info.hpp>

#include <cstddef>
#include <string_view>

using up_forever::Build;

namespace {
  // '#' stands for any digit; every other character in the mask has to match exactly.
  constexpr bool Matches(std::string_view text, std::string_view mask) {
    if (text.size() != mask.size()) return false;
    for (size_t i = 0; i < mask.size(); ++i) {
      const bool ok = mask[i] == '#' ? (text[i] >= '0' && text[i] <= '9') : text[i] == mask[i];
      if (!ok) return false;
    }
    return true;
  }

  constexpr int Hour(std::string_view stamp) { return (stamp[11] - '0') * 10 + (stamp[12] - '0'); }
} // namespace

static_assert(Matches(Build::date, "####-##-## ##:##:##"), "date is UTC, 24-hour");
static_assert(Hour(Build::date) <= 23);
static_assert(Matches(Build::date_actual, "####-##-## ##:##:## AM") || Matches(Build::date_actual, "####-##-## ##:##:## PM"),
              "date_actual is local, 12-hour with AM/PM");
static_assert(Hour(Build::date_actual) >= 1 && Hour(Build::date_actual) <= 12);

static_assert(!(Build::Policy::Debug() && Build::Policy::Release()), "a build can't be both");
static_assert(Build::Policy::Config() != "", "an empty $<CONFIG> should read as None");

TEST_CASE("the configuration matches what CMake built") {
#if defined(NDEBUG)
  CHECK_FALSE(Build::Policy::Debug());
#else
  CHECK(Build::Policy::Config() != "Release");
#endif
  CHECK((Build::Policy::Debug() || Build::Policy::Release() || Build::Policy::Config() == "None"));
}

TEST_CASE("the git commit is captured in a repository") {
  // up-forever is built from its own git checkout, so there is always a commit to find.
  CHECK(Build::git_sha != "unknown");
  CHECK(Build::git_sha.size() == 12);
}
