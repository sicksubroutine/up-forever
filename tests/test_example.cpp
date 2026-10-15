#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

#include <up_forever/example.hpp>

TEST_CASE("starter test exercises generated project code") {
  static_assert(up_forever::doubled(21) == 42);
  CHECK(up_forever::doubled(3) == 6);
}
