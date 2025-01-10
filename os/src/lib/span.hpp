#pragma once

template <typename Type> class span {
  Type *const begin{};
  Type *const end{};

public:
  span() : begin{nullptr}, end{nullptr} {}

  span(Type *const span_begin, Type *const span_end)
      : begin{span_begin}, end{span_end} {}

  span(Type *const span_begin, size_t const size)
      : begin{span_begin}, end{span_begin + size} {}

  auto size() const -> size_t { return end - begin; }

  auto subspan(size_t const begin_index,
               size_t const end_index) const -> span<Type> {
    size_t const n = size();
    if (begin_index > n || end_index > n || begin_index > end_index) {
      return {};
    }
    return {begin + begin_index, begin + end_index};
  }

  auto subspan(Type const *const span_begin,
               Type const *const span_end) const -> span<Type> {
    if (span_begin > end || span_end > end || span_begin > span_end) {
      return {};
    }
    return {span_begin, span_end};
  }

  auto subspan_starting_at_index(size_t begin_index) const -> span<Type> {
    if (begin_index > size()) {
      return {};
    }
    return {begin + begin_index, end};
  }

  auto subspan_starting_at(Type *const span_begin) const -> span<Type> {
    if (span_begin > end || span_begin < begin) {
      return {};
    }
    return {span_begin, end};
  }

  auto subspan_ending_at(Type *const span_end) const -> span<Type> {
    if (span_end > end || span_end < begin) {
      return {};
    }
    return {begin, span_end};
  }

  auto for_each(callable_returns_void<Type> auto f) const -> void {
    for (Type *it = begin; it < end; ++it) {
      f(*it);
    }
  }

  auto for_each_ref(callable_returns_void<Type &> auto f) const -> void {
    for (Type *it = begin; it < end; ++it) {
      f(*it);
    }
  }

  auto
  for_each_const_ref(callable_returns_void<Type const &> auto f) const -> void {
    for (Type *it = begin; it < end; ++it) {
      f(*it);
    }
  }

  auto
  for_each_until_false(callable_returns_bool<Type> auto f) const -> Type * {
    Type *it = begin;
    for (; it < end; ++it) {
      if (!f(*it)) {
        return it;
      }
    }
    return it;
  }

  auto for_each_ref_until_false(callable_returns_bool<Type &> auto f) const
      -> Type * {
    Type *it = begin;
    for (; it < end; ++it) {
      if (!f(*it)) {
        return it;
      }
    }
    return it;
  }

  auto for_each_const_ref_until_false(
      callable_returns_bool<Type const &> auto f) const -> Type * {
    Type *it = begin;
    for (; it < end; ++it) {
      if (!f(*it)) {
        return it;
      }
    }
    return it;
  }
};
