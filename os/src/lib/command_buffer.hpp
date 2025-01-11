#pragma once

class command_buffer final {
  char line_[80]{};
  uint8_t cursor_{};
  uint8_t end_{};

public:
  auto insert(char const ch) -> bool {
    if (end_ == sizeof(line_) - 1) {
      return false;
    }

    if (cursor_ == end_) {
      line_[cursor_] = ch;
      ++cursor_;
      ++end_;
      return true;
    }

    ++end_;
    for (size_t i = end_; i > cursor_; --i) {
      line_[i] = line_[i - 1];
    }
    line_[cursor_] = ch;
    ++cursor_;
    return true;
  }

  auto backspace() -> bool {
    if (cursor_ == 0) {
      return false;
    }

    if (cursor_ == end_) {
      --end_;
      --cursor_;
      return true;
    }

    for (size_t i = cursor_ - 1; i < end_; ++i) {
      line_[i] = line_[i + 1];
    }
    --cursor_;
    --end_;
    return true;
  }

  auto del() -> void {
    if (cursor_ == end_) {
      return;
    }

    for (size_t i = cursor_ + 1; i < end_; ++i) {
      line_[i - 1] = line_[i];
    }
    --end_;
  }

  auto reset() -> void { cursor_ = end_ = 0; }

  auto set_eos() -> void { line_[end_] = '\0'; }

  auto is_full() const -> bool { return end_ == sizeof(line_) - 1; }

  auto move_cursor_left() -> bool {
    if (cursor_ == 0) {
      return false;
    }
    --cursor_;
    return true;
  }

  auto move_cursor_right() -> bool {
    if (cursor_ == end_) {
      return false;
    }
    ++cursor_;
    return true;
  }

  auto apply_on_chars_from_cursor_to_end(
      callable_returns_void<char> auto &&f) const -> void {
    for (size_t i = cursor_; i < end_; ++i) {
      f(line_[i]);
    }
  }

  auto characters_after_cursor() const -> size_t { return end_ - cursor_; }

  auto input_length() const -> size_t { return end_; }

  auto string() -> string { return {line_, input_length()}; };
};
