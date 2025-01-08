static char const *hello = "welcome to adventure #4\r\n    type 'help'\r\n\r\n";

static char const *ascii_art =
    "                                  oOo.o.\r\n"
    "         frameless osca          oOo.oOo\r\n"
    "      __________________________  .oOo.\r\n"
    "     O\\        -_   .. \\    ___ \\   ||\r\n"
    "    O  \\                \\   \\ \\\\ \\ //\\\\\r\n"
    "   o   /\\    risc-v      \\   \\|\\\\ \\\r\n"
    "  .   //\\\\    fpga        \\   ||   \\\r\n"
    "   .  \\\\/\\\\    overview    \\  \\_\\   \\\r\n"
    "    .  \\\\//\\________________\\________\\\r\n"
    "     .  \\/_/, \\\\\\--\\\\..\\\\ - /\\_____  /\r\n"
    "      .  \\ \\ . \\\\\\__\\\\__\\\\./ / \\__/ /\r\n"
    "       .  \\ \\ , \\    \\\\ ///./ ,/./ /\r\n"
    "        .  \\ \\___\\ sticky notes / /\r\n"
    "         .  \\/\\________________/ /\r\n"
    "    ./\\.  . / /                 /\r\n"
    "    /--\\   .\\/_________________/\r\n"
    "         ___.                 .\r\n"
    "        |o o|. . . . . . . . .\r\n"
    "        /| |\\ . .\r\n"
    "    ____       . .\r\n"
    "   |O  O|       . .\r\n"
    "   |_ -_|        . .\r\n"
    "    /||\\\r\n"
    "      ___\r\n"
    "     /- -\\\r\n"
    "    /\\_-_/\\\r\n"
    "      | |\r\n"
    "\r\n";

using name_t = char const *;
using location_id_t = uint8_t;
using object_id_t = uint8_t;
using entity_id_t = uint8_t;
using direction_t = uint8_t;

static constexpr char CHAR_BACKSPACE = 0x7f;
static constexpr char CHAR_TAB = 0x09;
static constexpr size_t LOCATION_MAX_OBJECTS = 128;
static constexpr size_t LOCATION_MAX_ENTITIES = 8;
static constexpr size_t LOCATION_MAX_EXITS = 6;
static constexpr size_t ENTITY_MAX_OBJECTS = 32;

// note: defines are not stored in data segment thus gives a slightly smaller
// binary. in this case 20 B smaller
// #define CHAR_BACKSPACE 0x7f
// #define CHAR_TAB 0x09
// #define LOCATION_MAX_OBJECTS 128
// #define LOCATION_MAX_ENTITIES 8
// #define LOCATION_MAX_EXITS 6
// #define ENTITY_MAX_OBJECTS 32

template <typename T, typename U> struct is_same {
  static constexpr bool value = false;
};

template <typename T> struct is_same<T, T> {
  static constexpr bool value = true;
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

  auto command_line() -> char * { return line_; }

  auto input_length() const -> size_t { return end_; }
};

template <class Type, unsigned Size> class list final {
public:
  Type data[Size]{};
  size_t len{};

  auto add(Type elem) -> bool {
    if (len == Size - 1) {
      return false;
    }
    data[len] = elem;
    ++len;
    return true;
  }

  auto remove(Type elem) -> bool {
    for (size_t i = 0; i < len; ++i) {
      if (data[i] != elem) {
        continue;
      }
      --len;
      for (size_t j = i; j < len; ++j) {
        data[j] = data[j + 1];
      }
      return true;
    }
    return false;
  }

  auto remove_at_index(size_t ix) -> bool {
    if (len == 0 || ix >= len) {
      return false;
    }
    --len;
    for (size_t i = ix; i < len; ++i) {
      data[i] = data[i + 1];
    }
    return true;
  }

  auto at(size_t const ix) const -> Type {
    if (ix < len) {
      return data[ix];
    }
    return {};
  }

  auto length() const -> size_t { return len; }

  auto
  for_each_until_false(callable_returns_bool<Type> auto &&f) const -> void {
    for (size_t i = 0; i < len; ++i) {
      if (!f(data[i])) {
        return;
      }
    }
  }
};

struct object final {
  name_t name{};
};

static object objects[] = {{}, {"notebook"}, {"mirror"}, {"lighter"}};

struct entity final {
  name_t name{};
  location_id_t location{};
  list<object_id_t, ENTITY_MAX_OBJECTS> objects{};
};

static entity entities[] = {{}, {"me", 1, {{2}, 1}}, {"u", 2, {}}};

struct location final {
  name_t name{};
  list<object_id_t, LOCATION_MAX_OBJECTS> objects{};
  list<entity_id_t, LOCATION_MAX_ENTITIES> entities{};
  list<location_id_t, LOCATION_MAX_EXITS> exits{};
};

static location locations[] = {
    {},
    {"roome", {}, {{1}, 1}, {{2, 3, 0, 4}, 4}},
    {"office", {{1, 3}, 2}, {{2}, 1}, {{0, 0, 1}, 3}},
    {"bathroom"},
    {"kitchen", {}, {}, {{0, 1}, 2}}};

static char const *exit_names[] = {"north", "east", "south",
                                   "west",  "up",   "down"};

// implemented in platform dependent source
static auto led_set(int32_t bits) -> void;
static auto uart_send_str(char const *str) -> void;
static auto uart_send_char(char ch) -> void;
static auto uart_read_char() -> char;
static auto uart_send_hex_byte(char ch) -> void;
static auto uart_send_hex_nibble(char nibble) -> void;
static auto uart_send_move_back(size_t n) -> void;
static auto action_mem_test() -> void;
static auto action_sdcard_test() -> void;
static auto action_sdcard_status() -> void;

// API
static auto print_help() -> void;
static auto print_location(location_id_t const lid,
                           entity_id_t const eid_exclude_from_output) -> void;
static auto action_inventory(entity_id_t const eid) -> void;
static auto action_give(entity_id_t const eid, name_t const obj_nm,
                        name_t const to_ent_nm) -> void;
static auto action_go(entity_id_t const eid, direction_t const dir) -> void;
static auto action_drop(entity_id_t const eid, name_t const obj_nm) -> void;
static auto action_take(entity_id_t const eid, name_t const obj_nm) -> void;
static auto input(command_buffer &cmd_buf) -> void;
static auto handle_input(entity_id_t const eid,
                         command_buffer &cmd_buf) -> void;
static auto strings_equal(char const *s1, char const *s2) -> bool;
static auto string_copy(char const *src, size_t src_len, char *dst) -> void;
static auto sdcard_read_blocking(size_t sector, int8_t *buffer512B) -> void;

extern "C" [[noreturn]] auto run() -> void {
  initiate_bss();
  // initiates bss section to zeros in freestanding build

  initiate_statics();
  // initiate statics in freestanding build

  led_set(0b0000);
  // turn on all leds

  uart_send_str(ascii_art);
  uart_send_str(hello);

  entity_id_t active_entity = 1;
  command_buffer cmd_buf{};

  while (true) {
    entity const &ent = entities[active_entity];
    print_location(ent.location, active_entity);
    uart_send_str(ent.name);
    uart_send_str(" > ");
    input(cmd_buf);
    uart_send_str("\r\n");
    handle_input(active_entity, cmd_buf);
    active_entity = active_entity == 1 ? 2 : 1;
  }
}

static auto handle_input(entity_id_t const eid,
                         command_buffer &cmd_buf) -> void {
  char const *words[8];
  char *ptr = cmd_buf.command_line();
  size_t nwords = 0;
  while (true) {
    words[nwords] = ptr;
    ++nwords;
    while (*ptr && *ptr != ' ') {
      ++ptr;
    }
    if (!*ptr) {
      break;
    }
    *ptr = '\0';
    ++ptr;
    if (nwords == sizeof(words) / sizeof(char const *)) {
      uart_send_str("too many words, some ignored\r\n\r\n");
      break;
    }
  }
  // for (size_t i = 0; i < nwords; i++) {
  //   uart_send_str(words[i]);
  //   uart_send_str("\r\n");
  // }
  if (strings_equal(words[0], "help")) {
    print_help();
  } else if (strings_equal(words[0], "i")) {
    action_inventory(eid);
    uart_send_str("\r\n");
  } else if (strings_equal(words[0], "t")) {
    if (nwords < 2) {
      uart_send_str("take what\r\n\r\n");
      return;
    }
    action_take(eid, words[1]);
  } else if (strings_equal(words[0], "d")) {
    if (nwords < 2) {
      uart_send_str("drop what\r\n\r\n");
      return;
    }
    action_drop(eid, words[1]);
  } else if (strings_equal(words[0], "n")) {
    action_go(eid, 0);
  } else if (strings_equal(words[0], "e")) {
    action_go(eid, 1);
  } else if (strings_equal(words[0], "s")) {
    action_go(eid, 2);
  } else if (strings_equal(words[0], "w")) {
    action_go(eid, 3);
  } else if (strings_equal(words[0], "g")) {
    if (nwords < 2) {
      uart_send_str("give what\r\n\r\n");
      return;
    }
    if (nwords < 3) {
      uart_send_str("give to whom\r\n\r\n");
      return;
    }
    action_give(eid, words[1], words[2]);
  } else if (strings_equal(words[0], "m")) {
    action_mem_test();
  } else if (strings_equal(words[0], "sdp")) {
    action_sdcard_test();
  } else if (strings_equal(words[0], "sds")) {
    action_sdcard_status();
  } else if (strings_equal(words[0], "q")) {
    exit(0);
  } else {
    uart_send_str("not understood\r\n\r\n");
  }
}

static auto print_location(location_id_t const lid,
                           entity_id_t const eid_exclude_from_output) -> void {
  location &loc = locations[lid];
  uart_send_str("u r in ");
  uart_send_str(loc.name);
  uart_send_str("\r\nu c: ");

  // print objects at location
  {
    uint32_t counter = 0;
    loc.objects.for_each_until_false([&](object_id_t const id) {
      if (counter++) {
        uart_send_str(", ");
      }
      uart_send_str(objects[id].name);
      return true;
    });
    if (!counter) {
      uart_send_str("nothing");
    }
    uart_send_str("\r\n");
  }

  // print entities in location
  {
    uint32_t counter = 0;
    loc.entities.for_each_until_false([&](location_id_t const id) {
      if (id == eid_exclude_from_output) {
        return true;
      }
      if (counter++) {
        uart_send_str(", ");
      }
      uart_send_str(entities[id].name);
      return true;
    });
    if (counter != 0) {
      uart_send_str(" is here\r\n");
    }
  }

  // print exits from location
  {
    uint32_t counter = 0;
    uart_send_str("exits: ");
    auto &lse = loc.exits;
    size_t const n = lse.length();
    for (size_t i = 0; i < n; ++i) {
      if (!lse.at(i)) {
        continue;
      }
      if (counter++) {
        uart_send_str(", ");
      }
      uart_send_str(exit_names[i]);
    }
    if (counter == 0) {
      uart_send_str("none");
    }
    uart_send_str("\r\n");
  }
}

static auto action_inventory(entity_id_t const eid) -> void {
  uart_send_str("u have: ");
  uint32_t counter = 0;
  entities[eid].objects.for_each_until_false([&](object_id_t const id) {
    if (counter++) {
      uart_send_str(", ");
    }
    uart_send_str(objects[id].name);
    return true;
  });
  if (counter == 0) {
    uart_send_str("nothing");
  }
  uart_send_str("\r\n");
}

static auto action_take(entity_id_t const eid, name_t const obj_nm) -> void {
  entity &ent = entities[eid];
  auto &lso = locations[ent.location].objects;
  size_t const n = lso.length();
  for (size_t i = 0; i < n; ++i) {
    object_id_t const oid = lso.at(i);
    if (!strings_equal(objects[oid].name, obj_nm)) {
      continue;
    }
    if (ent.objects.add(oid)) {
      lso.remove_at_index(i);
    }
    return;
  }
  uart_send_str(obj_nm);
  uart_send_str(" not here\r\n\r\n");
}

static auto action_drop(entity_id_t const eid, name_t const obj_nm) -> void {
  entity &ent = entities[eid];
  auto &lso = ent.objects;
  size_t const n = lso.length();
  for (size_t i = 0; i < n; ++i) {
    object_id_t const oid = lso.at(i);
    if (!strings_equal(objects[oid].name, obj_nm)) {
      continue;
    }
    if (locations[ent.location].objects.add(oid)) {
      lso.remove_at_index(i);
    }
    return;
  }
  uart_send_str("u don't have ");
  uart_send_str(obj_nm);
  uart_send_str("\r\n\r\n");
}

static auto action_go(entity_id_t const eid, direction_t const dir) -> void {
  entity &ent = entities[eid];
  location &loc = locations[ent.location];
  location_id_t const to = loc.exits.at(dir);
  if (!to) {
    uart_send_str("cannot go there\r\n\r\n");
    return;
  }
  if (locations[to].entities.add(eid)) {
    loc.entities.remove(eid);
    ent.location = to;
  }
}

static auto action_give(entity_id_t const eid, name_t const obj_nm,
                        name_t const to_ent_nm) -> void {
  entity &ent = entities[eid];
  location &loc = locations[ent.location];
  auto &lse = loc.entities;
  size_t const n = lse.length();
  for (size_t i = 0; i < n; ++i) {
    entity &to = entities[lse.at(i)];
    if (!strings_equal(to.name, to_ent_nm)) {
      continue;
    }
    auto &lso = ent.objects;
    size_t const m = lso.length();
    for (size_t j = 0; j < m; j++) {
      object_id_t const oid = lso.at(j);
      if (!strings_equal(objects[oid].name, obj_nm)) {
        continue;
      }
      if (to.objects.add(oid)) {
        lso.remove_at_index(j);
      }
      return;
    }
    uart_send_str(obj_nm);
    uart_send_str(" not in inventory\r\n\r\n");
    return;
  }
  uart_send_str(to_ent_nm);
  uart_send_str(" is not here\r\n\r\n");
}

static auto print_help() -> void {
  uart_send_str(
      "\r\ncommand:\r\n  n: go north\r\n  e: go east\r\n  s: go south\r\n  w: "
      "go west\r\n  i: "
      "display inventory\r\n  t <object>: take object\r\n  d <object>: drop "
      "object\r\n  g <object> <entity>: give object to entity\r\n  help: this "
      "message\r\n\r\n");
}

static char input_escape_sequence[8];
static auto input_escape_sequence_clear() -> void {
  for (size_t i = 0; i < sizeof(input_escape_sequence); ++i) {
    input_escape_sequence[i] = '\0';
  }
}

enum class input_state { NORMAL, ESCAPE, ESCAPE_BRACKET };

static auto input(command_buffer &cmd_buf) -> void {
  cmd_buf.reset();
  input_state state = input_state::NORMAL;
  int escape_sequence_parameter = 0;

  while (true) {
    char const ch = uart_read_char();
    led_set(~ch);
    switch (state) {
    case input_state::NORMAL:
      if (ch == 0x1B) {
        state = input_state::ESCAPE;
      } else if (ch == CHAR_BACKSPACE) {
        if (cmd_buf.backspace()) {
          uart_send_char(ch);
          cmd_buf.apply_on_chars_from_cursor_to_end(
              [](char const c) { uart_send_char(c); });
          uart_send_char(' ');
          uart_send_move_back(cmd_buf.characters_after_cursor() + 1);
        }
      } else if (ch == CHAR_CARRIAGE_RETURN || cmd_buf.is_full()) {
        cmd_buf.set_eos();
        return;
      } else {
        uart_send_char(ch);
        cmd_buf.insert(ch);
        cmd_buf.apply_on_chars_from_cursor_to_end(
            [](char const c) { uart_send_char(c); });
        uart_send_move_back(cmd_buf.characters_after_cursor());
      }
      break;

    case input_state::ESCAPE:
      if (ch == 0x5B) {
        state = input_state::ESCAPE_BRACKET;
      } else {
        state = input_state::NORMAL;
      }
      break;

    case input_state::ESCAPE_BRACKET:
      if (ch >= '0' && ch <= '9') {
        escape_sequence_parameter = escape_sequence_parameter * 10 + (ch - '0');
      } else {
        switch (ch) {
        case 'D': // arrow left
          if (cmd_buf.move_cursor_left()) {
            uart_send_str("\x1B[D");
          }
          break;

        case 'C': // arrow right
          if (cmd_buf.move_cursor_right()) {
            uart_send_str("\x1B[C");
          }
          break;

        case '~': // delete
          if (escape_sequence_parameter == 3) {
            // delete key
            cmd_buf.del();
            cmd_buf.apply_on_chars_from_cursor_to_end(
                [](char c) { uart_send_char(c); });
            uart_send_char(' ');
            uart_send_move_back(cmd_buf.characters_after_cursor() + 1);
          }
          break;

        default:
          break;
        }

        state = input_state::NORMAL;
        escape_sequence_parameter = 0;
      }
      break;
    }
  }
}

static auto strings_equal(char const *s1, char const *s2) -> bool {
  while (true) {
    if (*s1 != *s2) {
      return false;
    }
    if (!*s1 && !*s2) {
      return true;
    }
    ++s1;
    ++s2;
  }
}

static auto string_copy(char const *src, size_t src_len, char *dst) -> void {
  while (src_len--) {
    *dst++ = *src++;
  }
}

static auto uart_send_hex_byte(char const ch) -> void {
  uart_send_hex_nibble(ch >> 4);
  uart_send_hex_nibble(ch & 0x0f);
}

static auto uart_send_hex_nibble(char const nibble) -> void {
  if (nibble < 10) {
    uart_send_char('0' + nibble);
  } else {
    uart_send_char('A' + (nibble - 10));
  }
}

static auto uart_send_move_back(size_t const n) -> void {
  for (size_t i = 0; i < n; ++i) {
    uart_send_char('\b');
  }
}
