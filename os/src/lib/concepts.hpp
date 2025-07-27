#pragma once

template <typename T, typename U> struct is_same {
    static bool constexpr value = false;
};

template <typename T> struct is_same<T, T> {
    static bool constexpr value = true;
};

template <typename T, typename U>
concept same_as = is_same<T, U>::value;

template <typename Func, typename Arg>
concept callable_returns_bool = requires(Func f, Arg arg) {
    { f(arg) } -> same_as<bool>;
};

template <typename Func, typename Arg>
concept callable_returns_void = requires(Func f, Arg arg) {
    { f(arg) } -> same_as<void>;
};
