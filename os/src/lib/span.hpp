#pragma once

bool constexpr safe_span = true;

template <typename Type> class span {
  Type *begin_{};
  Type *end_{};

public:
  class position {
    friend class span;
    Type *ptr{};
    position(Type *p) : ptr{p} {}
  };

  span() : begin_{nullptr}, end_{nullptr} {}

  span(Type *const span_begin, Type *const span_end)
      : begin_{span_begin}, end_{span_end} {}

  span(Type *const span_begin, size_t const size)
      : begin_{span_begin}, end_{span_begin + size} {}

  auto size() const -> size_t {
    return size_t(end_ - begin_);
  } // ? what if end<begin

  auto subspan(size_t const begin_index,
               size_t const end_index) const -> span<Type> {
    size_t const n = size();
    if constexpr (safe_span) {
      if (begin_index > n || end_index > n || begin_index > end_index) {
        return {};
      }
    }
    return {begin_ + begin_index, begin_ + end_index};
  }

  auto subspan(Type *const span_begin,
               Type *const span_end) const -> span<Type> {
    if constexpr (safe_span) {
      if (span_begin > end_ || span_end > end_ || span_begin > span_end) {
        return {};
      }
    }
    return {span_begin, span_end};
  }

  auto subspan_starting_at_index(size_t begin_index) const -> span<Type> {
    if constexpr (safe_span) {
      if (begin_index > size()) {
        return {};
      }
    }
    return {begin_ + begin_index, end_};
  }

  auto subspan_starting_at(position const pos) const -> span<Type> {
    if constexpr (safe_span) {
      if (pos.ptr > end_ || pos.ptr < begin_) {
        return {};
      }
    }
    return {pos.ptr, end_};
  }

  auto subspan_ending_at_index(size_t const end_index) const -> span<Type> {
    if constexpr (safe_span) {
      if (end_index > size()) {
        return {};
      }
    }
    return {begin_, end_index};
  }

  auto subspan_ending_at(position const pos) const -> span<Type> {
    if constexpr (safe_span) {
      if (pos.ptr > end_ || pos.ptr < begin_) {
        return {};
      }
    }
    return {begin_, pos.ptr};
  }

  auto for_each(callable_returns_void<Type> auto f) const -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto for_each_ref(callable_returns_void<Type &> auto f) const -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto
  for_each_const_ref(callable_returns_void<Type const &> auto f) const -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto
  for_each_until_false(callable_returns_bool<Type> auto f) const -> position {
    Type *it = begin_;
    for (; it < end_; ++it) {
      if (!f(*it)) {
        return {it};
      }
    }
    return {it};
  }

  auto for_each_ref_until_false(callable_returns_bool<Type &> auto f) const
      -> position {
    Type *it = begin_;
    for (; it < end_; ++it) {
      if (!f(*it)) {
        return {it};
      }
    }
    return {it};
  }

  auto for_each_const_ref_until_false(
      callable_returns_bool<Type const &> auto f) const -> position {
    Type *it = begin_;
    for (; it < end_; ++it) {
      if (!f(*it)) {
        return {it};
      }
    }
    return {it};
  }

  auto is_within_span(position const pos) const -> bool {
    return pos.ptr >= begin_ && pos.ptr <= end_;
  }

  auto is_end_of_span(position const t) const -> bool { return t.ptr == end_; }

  auto is_null() const -> bool { return begin_ = nullptr && end_ == nullptr; }

  auto is_empty() const -> bool { return begin_ == end_; }
};
