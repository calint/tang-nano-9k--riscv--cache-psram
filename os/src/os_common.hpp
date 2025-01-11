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

#define let auto const
#define mut auto

#include "lib/concepts.hpp"
//
#include "lib/span.hpp"
//
#include "lib/list.hpp"
//
#include "lib/command_buffer.hpp"

using string = span<char>;
using name_t = char const *;
using location_id_t = uint8_t;
using object_id_t = uint8_t;
using entity_id_t = uint8_t;
using direction_t = uint8_t;

static let CHAR_BACKSPACE = '\x7f';
static let CHAR_TAB = '\x09';
static let LOCATION_MAX_OBJECTS = 128u;
static let LOCATION_MAX_ENTITIES = 8u;
static let LOCATION_MAX_EXITS = 6u;
static let ENTITY_MAX_OBJECTS = 32u;

// note: defines are not stored in data segment thus gives a slightly smaller
// binary. in this case 20 B smaller
// #define CHAR_BACKSPACE 0x7f
// #define CHAR_TAB 0x09
// #define LOCATION_MAX_OBJECTS 128
// #define LOCATION_MAX_ENTITIES 8
// #define LOCATION_MAX_EXITS 6
// #define ENTITY_MAX_OBJECTS 32
//

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
static auto action_sdcard_status() -> void;
static auto action_sdcard_test_read(string arg) -> void;
static auto action_sdcard_test_write(string arg) -> void;

// API
static auto print_help() -> void;
static auto print_location(location_id_t lid,
                           entity_id_t eid_exclude_from_output) -> void;
static auto action_inventory(entity_id_t eid) -> void;
static auto action_give(entity_id_t eid, string args) -> void;
static auto action_go(entity_id_t eid, direction_t dir) -> void;
static auto action_drop(entity_id_t eid, string args) -> void;
static auto action_take(entity_id_t eid, string args) -> void;
static auto input(command_buffer &cmd_buf) -> void;
static auto handle_input(entity_id_t eid, command_buffer &cmd_buf) -> void;
static auto sdcard_read_blocking(size_t sector, int8_t *buffer512B) -> void;
static auto sdcard_write_blocking(size_t sector,
                                  int8_t const *buffer512B) -> void;
static auto cstr_equals(char const *s1, char const *s2) -> bool;
static auto cstr_copy(char const *src, size_t src_len, char *dst) -> void;
static auto cstr_copy(char const *str, char *buf) -> char *;

extern "C" [[noreturn]] auto run() -> void {
  initiate_bss();
  // initiates bss section to zeros in freestanding build

  initiate_statics();
  // initiate statics in freestanding build

  led_set(0b0000);
  // turn on all leds

  uart_send_str(ascii_art);
  uart_send_str(hello);

  mut active_entity = entity_id_t{1};
  mut cmd_buf = command_buffer{};

  while (true) {
    mut &ent = entities[active_entity];
    print_location(ent.location, active_entity);
    uart_send_str(ent.name);
    uart_send_str(" > ");
    input(cmd_buf);
    uart_send_str("\r\n");
    handle_input(active_entity, cmd_buf);
    active_entity = active_entity == 1 ? 2 : 1;
  }
}

static auto string_equals_cstr(string const span, char const *str) -> bool {
  mut e = span.for_each_until_false([&str](char const ch) {
    if (*str && *str == ch) {
      ++str;
      return true;
    }
    return false;
  });
  return span.is_end_of_span(e) && *str == '\0';
}

static auto string_print(string const span) -> void {
  span.for_each([](char const ch) { uart_send_char(ch); });
}

typedef struct string_next_word_return {
  string word{};
  string rem{};
} string_next_word_return;

static auto string_next_word(string const spn) -> string_next_word_return {
  mut ce = spn.for_each_until_false(
      [](char const ch) { return ch != ' ' && ch != '\0'; });
  let word = spn.subspan_ending_at(ce);
  let rem = spn.subspan_starting_at(ce);
  let rem_trimmed = rem.subspan_starting_at(
      rem.for_each_until_false([](char const ch) { return ch == ' '; }));
  return {word, rem_trimmed};
}

static auto handle_input(entity_id_t const eid,
                         command_buffer &cmd_buf) -> void {

  let line = cmd_buf.span();
  let w1 = string_next_word(line);
  let cmd = w1.word;
  let args = w1.rem;

  if (string_equals_cstr(cmd, "help")) {
    print_help();
  } else if (string_equals_cstr(cmd, "i")) {
    action_inventory(eid);
    uart_send_str("\r\n");
  } else if (string_equals_cstr(cmd, "t")) {
    action_take(eid, args);
  } else if (string_equals_cstr(cmd, "d")) {
    action_drop(eid, args);
  } else if (string_equals_cstr(cmd, "n")) {
    action_go(eid, 0);
  } else if (string_equals_cstr(cmd, "e")) {
    action_go(eid, 1);
  } else if (string_equals_cstr(cmd, "s")) {
    action_go(eid, 2);
  } else if (string_equals_cstr(cmd, "w")) {
    action_go(eid, 3);
  } else if (string_equals_cstr(cmd, "g")) {
    action_give(eid, args);
  } else if (string_equals_cstr(cmd, "m")) {
    action_mem_test();
  } else if (string_equals_cstr(cmd, "sds")) {
    action_sdcard_status();
  } else if (string_equals_cstr(cmd, "sdr")) {
    action_sdcard_test_read(args);
  } else if (string_equals_cstr(cmd, "sdw")) {
    action_sdcard_test_write(args);
  } else if (string_equals_cstr(cmd, "q")) {
    exit(0);
  } else {
    uart_send_str("not understood\r\n\r\n");
  }
}

static auto print_location(location_id_t const lid,
                           entity_id_t const eid_exclude_from_output) -> void {
  mut &loc = locations[lid];
  uart_send_str("u r in ");
  uart_send_str(loc.name);
  uart_send_str("\r\nu c: ");

  // print objects at location
  {
    mut counter = 0;
    loc.objects.for_each_until_false([&counter](object_id_t const id) {
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
    mut counter = 0;
    loc.entities.for_each_until_false(
        [&counter, eid_exclude_from_output](location_id_t const id) {
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
    mut counter = 0;
    uart_send_str("exits: ");
    mut &lse = loc.exits;
    let n = lse.length();
    for (mut i = 0u; i < n; ++i) {
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
  mut counter = 0;
  entities[eid].objects.for_each_until_false([&counter](object_id_t const id) {
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

static auto action_take(entity_id_t const eid, string const args) -> void {
  if (args.size() == 0) {
    uart_send_str("take what\r\n\r\n");
    return;
  }
  mut &ent = entities[eid];
  mut &lso = locations[ent.location].objects;
  let n = lso.length();
  for (mut i = 0u; i < n; ++i) {
    let oid = lso.at(i);
    if (!string_equals_cstr(args, objects[oid].name)) {
      continue;
    }
    if (ent.objects.add(oid)) {
      lso.remove_at_index(i);
    }
    return;
  }
  string_print(args);
  uart_send_str(" not here\r\n\r\n");
}

static auto action_drop(entity_id_t const eid, string const args) -> void {
  if (args.size() == 0) {
    uart_send_str("drop what\r\n\r\n");
    return;
  }
  mut &ent = entities[eid];
  mut &lso = ent.objects;
  let n = lso.length();
  for (mut i = 0u; i < n; ++i) {
    let oid = lso.at(i);
    if (!string_equals_cstr(args, objects[oid].name)) {
      continue;
    }
    if (locations[ent.location].objects.add(oid)) {
      lso.remove_at_index(i);
    }
    return;
  }
  uart_send_str("u don't have ");
  string_print(args);
  uart_send_str("\r\n\r\n");
}

static auto action_go(entity_id_t const eid, direction_t const dir) -> void {
  mut &ent = entities[eid];
  mut &loc = locations[ent.location];
  let to = loc.exits.at(dir);
  if (!to) {
    uart_send_str("cannot go there\r\n\r\n");
    return;
  }
  if (locations[to].entities.add(eid)) {
    loc.entities.remove(eid);
    ent.location = to;
  }
}

static auto action_give(entity_id_t const eid, string args) -> void {
  let w1 = string_next_word(args);
  let obj_nm = w1.word;
  if (obj_nm.is_empty()) {
    uart_send_str("give what\r\n\r\n");
    return;
  }

  let w2 = string_next_word(w1.rem);
  let to_ent_nm = w2.word;
  if (to_ent_nm.is_empty()) {
    uart_send_str("give to whom\r\n\r\n");
    return;
  }

  mut &ent = entities[eid];
  let &loc = locations[ent.location];
  let &lse = loc.entities;
  let n = lse.length();
  for (mut i = 0u; i < n; ++i) {
    mut &to = entities[lse.at(i)];
    if (!string_equals_cstr(to_ent_nm, to.name)) {
      continue;
    }
    mut &lso = ent.objects;
    let m = lso.length();
    for (mut j = 0u; j < m; j++) {
      let oid = lso.at(j);
      if (!string_equals_cstr(obj_nm, objects[oid].name)) {
        continue;
      }
      if (to.objects.add(oid)) {
        lso.remove_at_index(j);
      }
      return;
    }
    string_print(obj_nm);
    uart_send_str(" not in inventory\r\n\r\n");
    return;
  }
  string_print(to_ent_nm);
  uart_send_str(" is not here\r\n\r\n");
}

static auto print_help() -> void {
  uart_send_str(
      "\r\ncommand:\r\n  n: go north\r\n  e: go east\r\n  s: go south\r\n  w: "
      "go west\r\n  i: "
      "display inventory\r\n  t <object>: take object\r\n  d <object>: drop "
      "object\r\n  g <object> <entity>: give object to entity\r\n  sdr "
      "<sector>: read from SD card sector\r\n  sdw <sector> <text>: write to "
      "SD card sector\r\n  help: this "
      "message\r\n\r\n");
}

static char input_escape_sequence[8];
static auto input_escape_sequence_clear() -> void {
  for (mut i = 0u; i < sizeof(input_escape_sequence); ++i) {
    input_escape_sequence[i] = '\0';
  }
}

enum class input_state { NORMAL, ESCAPE, ESCAPE_BRACKET };

static auto input(command_buffer &cmd_buf) -> void {
  cmd_buf.reset();
  mut state = input_state::NORMAL;
  mut escape_sequence_parameter = 0;

  while (true) {
    let ch = uart_read_char();
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

static auto cstr_equals(char const *s1, char const *s2) -> bool {
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

static auto cstr_copy(char const *src, size_t src_len, char *dst) -> void {
  while (src_len--) {
    *dst++ = *src++;
  }
}

static auto cstr_copy(char const *str, char *buf) -> char * {
  while (*str) {
    *buf = *str;
    ++buf;
    ++str;
  }
  return buf;
}

static auto string_to_uint32(string str) -> uint32_t {
  mut num = 0u;
  str.for_each_until_false([&num](char const ch) {
    if (ch <= '0' || ch >= '9') {
      return false;
    }
    num = num * 10 + uint32_t(ch - '0');
    return true;
  });
  return num;
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
  for (mut i = 0u; i < n; ++i) {
    uart_send_char('\b');
  }
}
