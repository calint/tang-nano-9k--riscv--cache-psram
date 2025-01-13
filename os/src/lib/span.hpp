#pragma once

static bool constexpr safe_span = true;

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

  span(Type *const begin, Type *const end) : begin_{begin}, end_{end} {
    if constexpr (safe_span) {
      if (begin_ > end_) {
        begin_ = end_ = nullptr;
      }
    }
  }

  span(Type *const begin, size_t const size)
      : begin_{begin}, end_{begin + size} {}

  auto size() const -> size_t { return size_t(end_ - begin_); }

  auto is_at_end(position const t) const -> bool { return t.ptr == end_; }

  auto is_null() const -> bool { return begin_ = nullptr && end_ == nullptr; }

  auto is_empty() const -> bool { return begin_ == end_; }

  auto subspan_starting_at(position const pos) const -> span<Type> {
    if constexpr (safe_span) {
      if (pos.ptr > end_ || pos.ptr < begin_) {
        return {};
      }
    }
    return {pos.ptr, end_};
  }

  auto subspan_ending_at(position const pos) const -> span<Type> {
    if constexpr (safe_span) {
      if (pos.ptr > end_ || pos.ptr < begin_) {
        return {};
      }
    }
    return {begin_, pos.ptr};
  }

  auto for_each(callable_returns_void<Type> auto &&f) const -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto for_each_ref(callable_returns_void<Type &> auto &&f) const -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto for_each_const_ref(callable_returns_void<Type const &> auto &&f) const
      -> void {
    for (Type *it = begin_; it < end_; ++it) {
      f(*it);
    }
  }

  auto for_each_until_false(callable_returns_bool<Type> auto &&f) const
      -> position {
    Type *it = begin_;
    for (; it < end_; ++it) {
      if (!f(*it)) {
        return {it};
      }
    }
    return {it};
  }

  auto for_each_ref_until_false(callable_returns_bool<Type &> auto &&f) const
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
      callable_returns_bool<Type const &> auto &&f) const -> position {
    Type *it = begin_;
    for (; it < end_; ++it) {
      if (!f(*it)) {
        return {it};
      }
    }
    return {it};
  }
};
