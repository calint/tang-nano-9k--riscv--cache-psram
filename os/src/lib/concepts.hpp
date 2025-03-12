#pragma once

template <typename T, typename U> struct is_same {
  static constexpr bool value = false;
};

template <typename T> struct is_same<T, T> {
  static constexpr bool value = true;
};

template <typename T, typename U>
concept is_same_v = is_same<T, U>::value;

template <typename Func, typename Arg>
concept callable_returns_bool = requires(Func f, Arg arg) {
  { f(arg) } -> is_same_v<bool>;
};

template <typename Func, typename Arg>
concept callable_returns_void = requires(Func f, Arg arg) {
  { f(arg) } -> is_same_v<void>;
};
