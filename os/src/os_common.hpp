static char const *const hello =
    "welcome to adventure #4\r\n    type 'help'\r\n\r\n";

static char const *const ascii_art =
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

//
#include "lib/concepts.hpp"
//
#include "lib/span.hpp"
//
#include "lib/list.hpp"
//

using cstr = char const *;
using string = span<char>;

#include "lib/cursor_buffer.hpp"

using command_buffer = cursor_buffer<char, 160>;

static let safe_arrays = true;
static let char_backspace = '\x7f';
static let char_tab = '\t';
static let location_max_objects = 128u;
static let location_max_entities = 8u;
static let location_max_links = 6u;
static let entity_max_objects = 32u;

// note: defines are not stored in data segment thus gives a 20 B smaller binary
// #define char_backspace 0x7f
// #define char_tab 0x09
// #define location_max_objects 128
// #define location_max_entities 8
// #define location_max_links 6
// #define entity_max_objects 32

using name_t = cstr;
using location_id_t = uint8_t;
using link_id_t = uint8_t;
using entity_id_t = uint8_t;
using object_id_t = uint8_t;

struct object final {
  name_t name{};
};

struct entity final {
  name_t name{};
  location_id_t location{};
  list<object_id_t, entity_max_objects> objects{};
};

struct location_link final {
  link_id_t link{};
  location_id_t location{};
};

struct location final {
  name_t name{};
  list<location_link, location_max_links> links{};
  list<object_id_t, location_max_objects> objects{};
  list<entity_id_t, location_max_entities> entities{};
};

static object objects[] = {{}, {"notebook"}, {"mirror"}, {"lighter"}};

static entity entities[] = {{}, {"me", 1, {{2}, 1}}, {"u", 2, {}}};

static location locations[] = {
    {},
    {"roome", {{{1, 2}, {2, 3}, {4, 4}}, 3}, {}, {{1}, 1}},
    {"office", {{{3, 1}}, 1}, {{1, 3}, 2}, {{2}, 1}},
    {"bathroom"},
    {"kitchen", {{{2, 1}}, 1}, {}, {}}};

static cstr links[] = {"", "north", "east", "south", "west", "up", "down"};

// API
static auto entity_by_id(entity_id_t id) -> entity &;
static auto object_by_id(object_id_t id) -> object &;
static auto location_by_id(location_id_t id) -> location &;
static auto link_by_id(link_id_t id) -> cstr;
static auto uart_send_hex_uint32(uint32_t i, bool separate_half_words) -> void;
static auto uart_send_hex_byte(uint8_t ch) -> void;
static auto uart_send_hex_nibble(uint8_t nibble) -> void;
static auto print_help() -> void;
static auto print_location(location_id_t lid,
                           entity_id_t eid_excluded_from_output) -> void;
static auto action_inventory(entity_id_t eid) -> void;
static auto action_give(entity_id_t eid, string args) -> void;
static auto action_go(entity_id_t eid, link_id_t link_id) -> void;
static auto action_drop(entity_id_t eid, string args) -> void;
static auto action_take(entity_id_t eid, string args) -> void;
static auto input(command_buffer &cmd_buf) -> void;
static auto handle_input(entity_id_t eid, command_buffer &cmd_buf) -> void;
static auto sdcard_read_blocking(size_t sector, int8_t *buffer512B) -> void;
static auto sdcard_write_blocking(size_t sector, int8_t const *buffer512B)
    -> void;
static auto string_equals_cstr(string str, cstr s) -> bool;
static auto string_to_uint32(string str) -> uint32_t;
static auto string_print(string str) -> void;
struct string_next_word_return;
static auto string_next_word(string str) -> struct string_next_word_return;
//
// implemented in platform dependent source
//
static auto led_set(uint32_t bits) -> void;
static auto uart_send_cstr(cstr str) -> void;
static auto uart_send_char(char ch) -> void;
static auto uart_read_char() -> char;
static auto uart_send_move_back(size_t n) -> void;
static auto action_mem_test() -> void;
static auto action_sdcard_status() -> void;
static auto action_sdcard_read(string args) -> void;
static auto action_sdcard_write(string args) -> void;

extern "C" [[noreturn]] auto run() -> void {
  initiate_bss();
  // initiates bss section to zeros in freestanding build

  initiate_statics();
  // initiate statics in freestanding build

  led_set(0b0000);
  // turn on all leds

  uart_send_cstr(ascii_art);
  uart_send_cstr(hello);

  mut active_entity = entity_id_t{1};
  mut cmd_buf = command_buffer{};

  while (true) {
    mut &ent = entity_by_id(active_entity);
    print_location(ent.location, active_entity);
    uart_send_cstr(ent.name);
    uart_send_cstr(" > ");
    input(cmd_buf);
    uart_send_cstr("\r\n");
    handle_input(active_entity, cmd_buf);
    active_entity = active_entity == 1 ? 2 : 1;
  }
}

static auto string_equals_cstr(string const str, cstr s) -> bool {
  mut e = str.for_each_until_false([&s](let ch) {
    if (*s != '\0' && *s == ch) {
      ++s;
      return true;
    }
    return false;
  });
  return *s == '\0' && str.is_at_end(e);
}

static auto string_print(string const str) -> void {
  str.for_each([](let ch) { uart_send_char(ch); });
}

struct string_next_word_return {
  string word{};
  string rem{};
};

static auto string_next_word(string const str)
    -> struct string_next_word_return {
  mut ce = str.for_each_until_false([](let ch) { return ch != ' '; });
  let word = str.subspan_ending_at(ce);
  let rem = str.subspan_starting_at(ce);
  let rem_trimmed = rem.subspan_starting_at(
      rem.for_each_until_false([](let ch) { return ch == ' '; }));
  return {word, rem_trimmed};
}

static auto
handle_input(entity_id_t const eid, command_buffer &cmd_buf) -> void {

  let line = cmd_buf.span();
  let w1 = string_next_word(line);
  let cmd = w1.word;
  let args = w1.rem;

  if (string_equals_cstr(cmd, "help")) {
    print_help();
  } else if (string_equals_cstr(cmd, "i")) {
    action_inventory(eid);
    uart_send_cstr("\r\n");
  } else if (string_equals_cstr(cmd, "t")) {
    action_take(eid, args);
  } else if (string_equals_cstr(cmd, "d")) {
    action_drop(eid, args);
  } else if (string_equals_cstr(cmd, "n")) {
    action_go(eid, 1);
  } else if (string_equals_cstr(cmd, "e")) {
    action_go(eid, 2);
  } else if (string_equals_cstr(cmd, "s")) {
    action_go(eid, 3);
  } else if (string_equals_cstr(cmd, "w")) {
    action_go(eid, 4);
  } else if (string_equals_cstr(cmd, "g")) {
    action_give(eid, args);
  } else if (string_equals_cstr(cmd, "m")) {
    action_mem_test();
  } else if (string_equals_cstr(cmd, "sds")) {
    action_sdcard_status();
  } else if (string_equals_cstr(cmd, "sdr")) {
    action_sdcard_read(args);
  } else if (string_equals_cstr(cmd, "sdw")) {
    action_sdcard_write(args);
  } else if (string_equals_cstr(cmd, "q")) {
    exit(0);
  } else {
    uart_send_cstr("not understood\r\n\r\n");
  }
}

static auto print_location(location_id_t const lid,
                           entity_id_t const eid_excluded_from_output) -> void {
  let &loc = location_by_id(lid);
  uart_send_cstr("u r in ");
  uart_send_cstr(loc.name);
  uart_send_cstr("\r\nu c: ");

  // print objects at location
  {
    mut counter = 0;
    loc.objects.for_each([&counter](let id) {
      if (counter++) {
        uart_send_cstr(", ");
      }
      uart_send_cstr(object_by_id(id).name);
    });
    if (!counter) {
      uart_send_cstr("nothing");
    }
    uart_send_cstr("\r\n");
  }

  // print entities in location
  {
    mut counter = 0;
    loc.entities.for_each([&counter, eid_excluded_from_output](let id) {
      if (id == eid_excluded_from_output) {
        return;
      }
      if (counter++) {
        uart_send_cstr(", ");
      }
      uart_send_cstr(entity_by_id(id).name);
    });
    if (counter != 0) {
      uart_send_cstr(" is here\r\n");
    }
  }

  // print links from location
  {
    uart_send_cstr("exits: ");
    let &lse = loc.links;
    mut counter = 0;
    lse.for_each([&counter](let &lnk) {
      if (counter++) {
        uart_send_cstr(", ");
      }
      uart_send_cstr(link_by_id(lnk.link));
    });
    if (counter == 0) {
      uart_send_cstr("none");
    }
    uart_send_cstr("\r\n");
  }
}

static auto action_inventory(entity_id_t const eid) -> void {
  uart_send_cstr("u have: ");
  mut counter = 0;
  entity_by_id(eid).objects.for_each([&counter](let id) {
    if (counter++) {
      uart_send_cstr(", ");
    }
    uart_send_cstr(object_by_id(id).name);
  });
  if (counter == 0) {
    uart_send_cstr("nothing");
  }
  uart_send_cstr("\r\n");
}

static auto action_take(entity_id_t const eid, string const args) -> void {
  if (args.is_empty()) {
    uart_send_cstr("take what\r\n\r\n");
    return;
  }

  mut &ent = entity_by_id(eid);
  mut &lso = location_by_id(ent.location).objects;
  let pos = lso.for_each_until_false([&args](let id) {
    if (string_equals_cstr(args, object_by_id(id).name)) {
      return false;
    }
    return true;
  });
  if (lso.is_at_end(pos)) {
    string_print(args);
    uart_send_cstr(" not here\r\n\r\n");
    return;
  }

  // ? lso.at extra lookup
  if (ent.objects.add(lso.at(pos))) {
    lso.remove_at(pos);
  }
}

static auto action_drop(entity_id_t const eid, string const args) -> void {
  if (args.size() == 0) {
    uart_send_cstr("drop what\r\n\r\n");
    return;
  }

  mut &ent = entity_by_id(eid);
  mut &lso = ent.objects;
  let pos = lso.for_each_until_false([&args](let id) {
    if (string_equals_cstr(args, object_by_id(id).name)) {
      return false;
    }
    return true;
  });
  if (lso.is_at_end(pos)) {
    uart_send_cstr("u don't have ");
    string_print(args);
    uart_send_cstr("\r\n\r\n");
    return;
  }

  // ? lso.at extra lookup
  if (location_by_id(ent.location).objects.add(lso.at(pos))) {
    lso.remove_at(pos);
  }
}

static auto action_go(entity_id_t const eid, link_id_t const link_id) -> void {
  mut &ent = entity_by_id(eid);

  // find link in entity location
  mut &loc = location_by_id(ent.location);
  let lnk_pos = loc.links.for_each_until_false([link_id](let &lnk) {
    if (lnk.link == link_id) {
      return false;
    }
    return true;
  });
  if (loc.links.is_at_end(lnk_pos)) {
    uart_send_cstr("cannot go there\r\n\r\n");
    return;
  }

  // move entity
  let lnk = loc.links.at(lnk_pos); // ? extra lookup
  if (location_by_id(lnk.location).entities.add(eid)) {
    loc.entities.remove(eid);
    ent.location = lnk.location;
  }
}

static auto action_give(entity_id_t const eid, string const args) -> void {
  let w1 = string_next_word(args);
  let obj_nm = w1.word;
  if (obj_nm.is_empty()) {
    uart_send_cstr("give what\r\n\r\n");
    return;
  }

  let w2 = string_next_word(w1.rem);
  let to_ent_nm = w2.word;
  if (to_ent_nm.is_empty()) {
    uart_send_cstr("give to whom\r\n\r\n");
    return;
  }

  mut &from_entity = entity_by_id(eid);
  // find 'to' entity in location
  let &loc = location_by_id(from_entity.location);
  let &lse = loc.entities;
  let to_pos = lse.for_each_until_false([&to_ent_nm](let id) {
    if (string_equals_cstr(to_ent_nm, entity_by_id(id).name)) {
      return false;
    }
    return true;
  });
  if (lse.is_at_end(to_pos)) {
    string_print(to_ent_nm);
    uart_send_cstr(" is not here\r\n\r\n");
    return;
  }

  // get 'to' entity
  // ? lse.at, entity_by_id extra lookup
  mut &to_entity = entity_by_id(lse.at(to_pos));
  // find object to give
  let obj_pos = from_entity.objects.for_each_until_false([&obj_nm](let id) {
    if (string_equals_cstr(obj_nm, object_by_id(id).name)) {
      return false;
    }
    return true;
  });
  if (from_entity.objects.is_at_end(obj_pos)) {
    string_print(obj_nm);
    uart_send_cstr(" not in inventory\r\n\r\n");
    return;
  }

  // transfer object
  // ? from_entity.objects.at extra lookup
  if (to_entity.objects.add(from_entity.objects.at(obj_pos))) {
    from_entity.objects.remove_at(obj_pos);
  }
}

static auto action_sdcard_read(string const args) -> void {
  let w1 = string_next_word(args);
  if (w1.word.is_empty()) {
    uart_send_cstr("<sector>\r\n");
    return;
  }
  let sector = string_to_uint32(w1.word);
  int8_t buf[512];
  sdcard_read_blocking(sector, buf);
  for (mut i = 0u; i < sizeof(buf); ++i) {
    uart_send_char(buf[i]);
  }
  uart_send_cstr("\r\n");
}

static auto action_sdcard_write(string const args) -> void {
  let w1 = string_next_word(args);
  if (w1.word.is_empty()) {
    uart_send_cstr("<sector> <text>\r\n");
    return;
  }
  int8_t buf[512]{};
  mut *buf_ptr = buf;
  w1.rem.for_each([&buf_ptr](char const ch) {
    *buf_ptr = ch;
    ++buf_ptr;
  });
  size_t const sector = string_to_uint32(w1.word);
  sdcard_write_blocking(sector, buf);
}

static auto print_help() -> void {
  uart_send_cstr(
      "\r\ncommand:\r\n  n: go north\r\n  e: go east\r\n  s: go south\r\n  "
      "w: go west\r\n  i: display inventory\r\n  t <object>: take object\r\n  "
      "d <object>: drop object\r\n  g <object> <entity>: give object to "
      "entity\r\n  sdr <sector>: read sector from SD card\r\n  sdw <sector> "
      "<text>: write sector to SD card\r\n  help: this message\r\n\r\n");
}

static auto input(command_buffer &cmd_buf) -> void {
  enum class input_state { NORMAL, ESCAPE, ESCAPE_BRACKET };
  mut state = input_state::NORMAL;
  mut escape_sequence_parameter = 0;

  cmd_buf.reset();
  while (true) {
    let ch = uart_read_char();
    led_set(uint32_t(~ch));
    switch (state) {
    case input_state::NORMAL:
      if (ch == 0x1B) {
        state = input_state::ESCAPE;
      } else if (ch == char_backspace) {
        if (cmd_buf.backspace()) {
          uart_send_char(ch);
          cmd_buf.apply_on_elements_from_cursor_to_end(
              [](let c) { uart_send_char(c); });
          uart_send_char(' ');
          uart_send_move_back(cmd_buf.elements_after_cursor_count() + 1);
        }
      } else if (ch == char_carriage_return || cmd_buf.is_full()) {
        cmd_buf.set_terminator();
        return;
      } else {
        uart_send_char(ch);
        cmd_buf.insert(ch);
        cmd_buf.apply_on_elements_from_cursor_to_end(
            [](let c) { uart_send_char(c); });
        uart_send_move_back(cmd_buf.elements_after_cursor_count());
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
            uart_send_cstr("\x1B[D");
          }
          break;

        case 'C': // arrow right
          if (cmd_buf.move_cursor_right()) {
            uart_send_cstr("\x1B[C");
          }
          break;

        case '~': // delete
          if (escape_sequence_parameter == 3) {
            // delete key
            cmd_buf.del();
            cmd_buf.apply_on_elements_from_cursor_to_end(
                [](let c) { uart_send_char(c); });
            uart_send_char(' ');
            uart_send_move_back(cmd_buf.elements_after_cursor_count() + 1);
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

static auto string_to_uint32(string const str) -> uint32_t {
  mut num = 0u;
  str.for_each_until_false([&num](let ch) {
    if (ch <= '0' || ch >= '9') {
      return false;
    }
    num = num * 10 + uint32_t(ch - '0');
    return true;
  });
  return num;
}

static auto uart_send_hex_uint32(uint32_t const i,
                                 bool const separate_half_words) -> void {
  uart_send_hex_byte(uint8_t(i >> 24));
  uart_send_hex_byte(uint8_t(i >> 16));
  if (separate_half_words) {
    uart_send_char(':');
  }
  uart_send_hex_byte(uint8_t(i >> 8));
  uart_send_hex_byte(uint8_t(i));
}

static auto uart_send_hex_byte(uint8_t const ch) -> void {
  uart_send_hex_nibble(ch >> 4);
  uart_send_hex_nibble(ch & 0x0f);
}

static auto uart_send_hex_nibble(uint8_t const nibble) -> void {
  if (nibble < 10) {
    uart_send_char('0' + char(nibble));
  } else {
    uart_send_char('A' + char(nibble - 10));
  }
}

static auto uart_send_move_back(size_t const n) -> void {
  for (mut i = 0u; i < n; ++i) {
    uart_send_char('\b');
  }
}

static auto entity_by_id(entity_id_t const id) -> entity & {
  if constexpr (safe_arrays) {
    if (id >= sizeof(entities) / sizeof(entity)) {
      return entities[0];
    }
  }
  return entities[id];
}

static auto object_by_id(object_id_t const id) -> object & {
  if constexpr (safe_arrays) {
    if (id >= sizeof(objects) / sizeof(object)) {
      return objects[0];
    }
  }
  return objects[id];
}

static auto location_by_id(location_id_t const id) -> location & {
  if constexpr (safe_arrays) {
    if (id >= sizeof(locations) / sizeof(location)) {
      return locations[0];
    }
  }
  return locations[id];
}

static auto link_by_id(link_id_t const id) -> cstr {
  if constexpr (safe_arrays) {
    if (id >= sizeof(links) / sizeof(cstr)) {
      return links[0];
    }
  }
  return links[id];
}
