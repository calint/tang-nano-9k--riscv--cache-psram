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

using int8_t = char;
using uint8_t = unsigned char;
using int16_t = short;
using uint16_t = unsigned short;
using int32_t = int;
using uint32_t = unsigned int;
using int64_t = long long;
using uint64_t = unsigned long long;

using name_t = char const *;
using location_id_t = uint8_t;
using object_id_t = uint8_t;
using entity_id_t = uint8_t;
using direction_t = uint8_t;

constexpr char CHAR_BACKSPACE = 0x7f;
constexpr uint32_t LOCATION_MAX_OBJECTS = 128;
constexpr uint32_t LOCATION_MAX_ENTITIES = 8;
constexpr uint32_t LOCATION_MAX_EXITS = 6;
constexpr uint32_t ENTITY_MAX_OBJECTS = 32;

static auto strings_equal(char const *s1, char const *s2) -> bool;

static auto string_copy(char const *src, uint32_t src_len, char *dst) -> void {
  while (src_len--) {
    *dst++ = *src++;
  }
}

class command_buffer final {
  char line_[80]{};
  uint8_t ix_{};
  uint8_t end_{};

public:
  auto insert(char ch) -> bool {
    if (end_ == sizeof(line_) - 1) {
      return false;
    }

    if (ix_ == end_) {
      line_[ix_] = ch;
      ++ix_;
      ++end_;
      return true;
    }

    ++end_;
    for (uint32_t i = end_; i > ix_; --i) {
      line_[i] = line_[i - 1];
    }
    line_[ix_] = ch;
    ++ix_;
    return true;
  }

  auto backspace() -> bool {
    if (ix_ == 0) {
      return false;
    }

    if (ix_ == end_) {
      --end_;
      --ix_;
      return true;
    }

    for (uint32_t i = ix_ - 1; i < end_; ++i) {
      line_[i] = line_[i + 1];
    }
    --ix_;
    --end_;
    return true;
  }

  auto del() -> void {
    if (ix_ == end_) {
      return;
    }

    for (uint32_t i = ix_ + 1; i < end_; ++i) {
      line_[i - 1] = line_[i];
    }
    --end_;
  }

  auto reset() -> void { ix_ = end_ = 0; }

  auto set_eos() -> void { line_[end_] = '\0'; }

  auto is_full() -> bool { return end_ == sizeof(line_) - 1; }

  auto move_cursor_left() -> bool {
    if (ix_ == 0) {
      return false;
    }

    --ix_;
    return true;
  }

  auto move_cursor_right() -> bool {
    if (ix_ == end_) {
      return false;
    }

    ++ix_;
    return true;
  }

  auto send_from_index_to_end(void (*f)(char)) -> void {
    for (uint32_t i = ix_; i < end_; ++i) {
      f(line_[i]);
    }
  }

  auto characters_after_cursor() -> uint32_t { return end_ - ix_; }

  auto line() -> char * { return line_; }

  auto input_length() -> uint32_t { return end_; }
};

class command_history final {
  char history_[8][80]{};
  uint8_t ix_ = 0;

public:
  auto add_if_not_same_as_last(char const *buf,
                               uint32_t const buf_len) -> void {
    if (ix_ == 0) {
      string_copy(buf, buf_len, history_[ix_]);
      return;
    }

    if (strings_equal(history_[ix_], buf)) {
      return;
    }

    ++ix_;
    string_copy(buf, buf_len, history_[ix_]);
  }
};

struct object {
  name_t name{};
};

static object objects[] = {{""}, {"notebook"}, {"mirror"}, {"lighter"}};

struct entity {
  name_t name{};
  location_id_t location{};
  object_id_t objects[ENTITY_MAX_OBJECTS]{};
};

static entity entities[] = {{"", 0, {0}}, {"me", 1, {2}}, {"u", 2, {0}}};

struct location {
  name_t name{};
  object_id_t objects[LOCATION_MAX_OBJECTS]{};
  entity_id_t entities[LOCATION_MAX_ENTITIES]{};
  location_id_t exits[LOCATION_MAX_EXITS]{};
};

static location locations[] = {{"", {0}, {0}, {0}},
                               {"roome", {0}, {1}, {2, 3, 0, 4}},
                               {"office", {1, 3}, {2}, {0, 0, 1}},
                               {"bathroom", {0}, {0}, {0}},
                               {"kitchen", {0}, {0}, {0, 1}}};

static char const *exit_names[] = {"north", "east", "south",
                                   "west",  "up",   "down"};

// implemented in platform dependent source
static auto led_set(uint8_t bits) -> void;
static auto uart_send_str(char const *str) -> void;
static auto uart_send_char(char ch) -> void;
static auto uart_read_char() -> char;
static auto uart_send_hex_byte(char ch) -> void;
static auto uart_send_hex_nibble(char nibble) -> void;
static auto uart_send_move_back(uint32_t n) -> void;

// API
static auto print_help() -> void;
static auto print_location(location_id_t lid,
                           entity_id_t eid_exclude_from_output) -> void;
static auto add_object_to_list(object_id_t list[], uint32_t list_len,
                               object_id_t oid) -> bool;
static auto remove_object_from_list_by_index(object_id_t list[],
                                             uint32_t ix) -> void;
static auto add_entity_to_list(entity_id_t list[], uint32_t list_len,
                               entity_id_t eid) -> bool;
static auto remove_entity_from_list_by_index(entity_id_t list[],
                                             uint32_t ix) -> void;
static auto remove_entity_from_list(entity_id_t list[], uint32_t list_len,
                                    entity_id_t eid) -> void;
static auto action_inventory(entity_id_t eid) -> void;
static auto action_give(entity_id_t eid, name_t obj, name_t to_ent) -> void;
static auto action_go(entity_id_t eid, direction_t dir) -> void;
static auto action_drop(entity_id_t eid, name_t obj) -> void;
static auto action_take(entity_id_t eid, name_t obj) -> void;
static auto input(command_buffer &buf) -> void;
static auto handle_input(entity_id_t eid, command_buffer &buf) -> void;
static auto action_mem_test() -> void;

extern "C" auto run() -> void {
  startup_init_bss();
  // initiates bss section to zeros

  led_set(0);
  // turn all leds on

  entity_id_t active_entity = 1;
  command_buffer inbuf{};

  uart_send_str(ascii_art);
  uart_send_str(hello);

  while (true) {
    entity const &ent = entities[active_entity];
    print_location(ent.location, active_entity);
    uart_send_str(ent.name);
    uart_send_str(" > ");
    input(inbuf);
    uart_send_str("\r\n");
    handle_input(active_entity, inbuf);
    if (active_entity == 1)
      active_entity = 2;
    else
      active_entity = 1;
  }
}

static auto handle_input(entity_id_t eid, command_buffer &buf) -> void {
  char const *words[8];
  char *ptr = buf.line();
  uint32_t nwords = 0;
  while (true) {
    words[nwords++] = ptr;
    while (*ptr && *ptr != ' ') {
      ptr++;
    }
    if (!*ptr)
      break;
    *ptr = '\0';
    ptr++;
    if (nwords == sizeof(words) / sizeof(char const *)) {
      uart_send_str("too many words, some ignored\r\n\r\n");
      break;
    }
  }
  for (uint32_t i = 0; i < nwords; i++) {
    uart_send_str(words[i]);
    uart_send_str("\r\n");
  }
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
  } else {
    uart_send_str("not understood\r\n\r\n");
  }
}

static auto print_location(location_id_t lid,
                           entity_id_t eid_exclude_from_output) -> void {
  location const &loc = locations[lid];
  uart_send_str("u r in ");
  uart_send_str(loc.name);
  uart_send_str("\r\nu c: ");

  // print objects in location
  bool add_list_sep = false;
  object_id_t const *lso = loc.objects;
  for (uint32_t i = 0; i < LOCATION_MAX_OBJECTS; i++) {
    object_id_t const oid = lso[i];
    if (!oid)
      break;
    if (add_list_sep) {
      uart_send_str(", ");
    } else {
      add_list_sep = true;
    }
    uart_send_str(objects[oid].name);
  }
  if (!add_list_sep) {
    uart_send_str("nothing");
  }
  uart_send_str("\r\n");

  // print entities in location
  add_list_sep = false;
  entity_id_t const *lse = loc.entities;
  for (uint32_t i = 0; i < LOCATION_MAX_ENTITIES; i++) {
    entity_id_t const eid = lse[i];
    if (!eid)
      break;
    if (eid == eid_exclude_from_output)
      continue;
    if (add_list_sep) {
      uart_send_str(", ");
    } else {
      add_list_sep = true;
    }
    uart_send_str(entities[eid].name);
  }
  if (add_list_sep) {
    uart_send_str(" is here\r\n");
  }

  // print exits from location
  add_list_sep = false;
  uart_send_str("exits: ");
  for (uint32_t i = 0; i < LOCATION_MAX_EXITS; i++) {
    if (!loc.exits[i])
      continue;
    if (add_list_sep) {
      uart_send_str(", ");
    } else {
      add_list_sep = true;
    }
    uart_send_str(exit_names[i]);
  }
  if (!add_list_sep) {
    uart_send_str("none");
  }
  uart_send_str("\r\n");
}

static auto action_inventory(entity_id_t eid) -> void {
  uart_send_str("u have: ");
  bool add_list_sep = false;
  object_id_t const *lso = entities[eid].objects;
  for (uint32_t i = 0; i < ENTITY_MAX_OBJECTS; i++) {
    object_id_t const oid = lso[i];
    if (!oid)
      break;
    if (add_list_sep) {
      uart_send_str(", ");
    } else {
      add_list_sep = true;
    }
    uart_send_str(objects[oid].name);
  }
  if (!add_list_sep) {
    uart_send_str("nothing");
  }
  uart_send_str("\r\n");
}

static auto remove_object_from_list_by_index(object_id_t list[],
                                             uint32_t ix) -> void {
  object_id_t *ptr = &list[ix];
  while (true) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

static auto add_object_to_list(object_id_t list[], uint32_t list_len,
                               object_id_t oid) -> bool {
  // list_len - 1 since last element has to be 0
  for (uint32_t i = 0; i < list_len - 1; i++) {
    if (list[i])
      continue;
    list[i] = oid;
    list[i + 1] = 0;
    return true;
  }
  uart_send_str("space full\r\n");
  return false;
}

static auto add_entity_to_list(entity_id_t list[], uint32_t list_len,
                               entity_id_t eid) -> bool {
  // list_len - 1 since last element has to be 0
  for (uint32_t i = 0; i < list_len - 1; i++) {
    if (list[i])
      continue;
    list[i] = eid;
    list[i + 1] = 0;
    return true;
  }
  uart_send_str("location full\r\n");
  return false;
}

static auto remove_entity_from_list(entity_id_t list[], uint32_t list_len,
                                    entity_id_t eid) -> void {
  // list_len - 1 since last element has to be 0
  for (uint32_t i = 0; i < list_len - 1; i++) {
    if (list[i] != eid)
      continue;
    // list_len - 1 since last element has to be 0
    for (uint32_t j = i; j < list_len - 1; j++) {
      list[j] = list[j + 1];
      if (!list[j])
        return;
    }
  }
  uart_send_str("entity not here\r\n");
}

static auto remove_entity_from_list_by_index(entity_id_t list[],
                                             uint32_t ix) -> void {
  entity_id_t *ptr = &list[ix];
  while (true) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

static auto action_take(entity_id_t eid, name_t obj) -> void {
  entity &ent = entities[eid];
  object_id_t *lso = locations[ent.location].objects;
  for (uint32_t i = 0; i < LOCATION_MAX_OBJECTS; i++) {
    object_id_t const oid = lso[i];
    if (!oid)
      break;
    if (!strings_equal(objects[oid].name, obj))
      continue;
    if (add_object_to_list(ent.objects, ENTITY_MAX_OBJECTS, oid)) {
      remove_object_from_list_by_index(lso, i);
    }
    return;
  }
  uart_send_str(obj);
  uart_send_str(" not here\r\n\r\n");
}

static auto action_drop(entity_id_t eid, name_t obj) -> void {
  entity &ent = entities[eid];
  object_id_t *lso = ent.objects;
  for (uint32_t i = 0; i < ENTITY_MAX_OBJECTS; i++) {
    object_id_t const oid = lso[i];
    if (!oid)
      break;
    if (!strings_equal(objects[oid].name, obj))
      continue;
    if (add_object_to_list(locations[ent.location].objects,
                           LOCATION_MAX_OBJECTS, oid)) {
      remove_object_from_list_by_index(lso, i);
    }
    return;
  }
  uart_send_str("u don't have ");
  uart_send_str(obj);
  uart_send_str("\r\n\r\n");
}

static auto action_go(entity_id_t eid, direction_t dir) -> void {
  entity &ent = entities[eid];
  location &loc = locations[ent.location];
  location_id_t const to = loc.exits[dir];
  if (!to) {
    uart_send_str("cannot go there\r\n\r\n");
    return;
  }
  if (add_entity_to_list(locations[to].entities, LOCATION_MAX_ENTITIES, eid)) {
    remove_entity_from_list(loc.entities, LOCATION_MAX_ENTITIES, eid);
    ent.location = to;
  }
}

static auto action_give(entity_id_t eid, name_t obj, name_t to_ent) -> void {
  entity &ent = entities[eid];
  location const &loc = locations[ent.location];
  entity_id_t const *lse = loc.entities;
  for (uint32_t i = 0; i < LOCATION_MAX_ENTITIES; i++) {
    if (!lse[i])
      break;
    entity &to = entities[lse[i]];
    if (!strings_equal(to.name, to_ent))
      continue;
    object_id_t *lso = ent.objects;
    for (uint32_t j = 0; j < ENTITY_MAX_OBJECTS; j++) {
      object_id_t const oid = lso[j];
      if (!oid)
        break;
      if (!strings_equal(objects[oid].name, obj))
        continue;
      if (add_object_to_list(to.objects, ENTITY_MAX_OBJECTS, oid)) {
        remove_object_from_list_by_index(lso, j);
      }
      return;
    }
    uart_send_str(obj);
    uart_send_str(" not in inventory\r\n\r\n");
    return;
  }
  uart_send_str(to_ent);
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
// note: must specify initializer or the binary section the variable
//        is placed in does not get initialized, assumes OS zero initializes
//         it, however the FPGA memory copied from flash is 0xff by default
static auto input_escape_sequence_clear() -> void {
  for (uint32_t i = 0; i < sizeof(input_escape_sequence); ++i) {
    input_escape_sequence[i] = '0';
  }
}
static auto input(command_buffer &buf) -> void {
  buf.reset();
  while (true) {
    char const ch = uart_read_char();
    if (ch == 0x1B) {
      // escape sequence
      input_escape_sequence[0] = 0x1B;
      continue;
    }
    if (input_escape_sequence[0] == 0x1B) {
      // is in escape sequence
      if (ch == 0x5B) {
        // in escape sequence: 0x1B 0x5B
        // note: sent by linux terminal
        input_escape_sequence[1] = 0x5B;
        continue;
      }
      if (input_escape_sequence[1] == 0x5B) {
        // in escape sequence: 0x1B 0x5B
        if (ch == 0x44) {
          // in escape sequence: 0x1B 0x5B 0x44
          // arrow left
          if (buf.move_cursor_left()) {
            uart_send_char(0x1B);
            uart_send_char(0x5B);
            uart_send_char(0x44);
          }
          input_escape_sequence_clear();
          continue;
        }
        if (ch == 0x43) {
          // in escape sequence:0x1B 0x5B 0x43
          // arrow right
          if (buf.move_cursor_right()) {
            uart_send_char(0x1B);
            uart_send_char(0x5B);
            uart_send_char(0x43);
          }
          input_escape_sequence_clear();
          continue;
        }
        if (ch == 0x33) {
          // in escape sequence:0x1B 0x5B 0x33
          input_escape_sequence[2] = 0x33;
          continue;
        }
        if (input_escape_sequence[2] == 0x33) {
          // in escape sequence: 0x1B 0x5B 0x33
          if (ch == 0x7e) {
            // escape sequence 0x1B 0x5B 0x33 0x7E
            // delete
            buf.del();
            buf.send_from_index_to_end([](char c) { uart_send_char(c); });
            uart_send_char(' ');
            uart_send_move_back(buf.characters_after_cursor() + 1);
          }
          input_escape_sequence_clear();
          continue;
        }
        // unrecognized escape sequence; reset
        input_escape_sequence_clear();
        continue;
      }
    }
    if (ch == CHAR_BACKSPACE) {
      if (buf.backspace()) {
        uart_send_char(ch);
        buf.send_from_index_to_end([](char c) { uart_send_char(c); });
        uart_send_char(' ');
        uart_send_move_back(buf.characters_after_cursor() + 1);
        // +1 to compensate for the ' ' that erases the trailing output
      }
    } else if (ch == CHAR_CARRIAGE_RETURN || buf.is_full()) {
      buf.set_eos();
      return;
    } else {
      uart_send_char(ch);
      buf.insert(ch);
      buf.send_from_index_to_end([](char const c) { uart_send_char(c); });
      uart_send_move_back(buf.characters_after_cursor());
    }
    led_set(~uint8_t(buf.input_length()));
  }
}

static auto strings_equal(char const *s1, char const *s2) -> bool {
  while (true) {
    if (*s1 - *s2)
      return false;
    if (!*s1 && !*s2)
      return true;
    s1++;
    s2++;
  }
}

static auto uart_send_hex_byte(char const ch) -> void {
  uart_send_hex_nibble((ch & 0xf0) >> 4);
  uart_send_hex_nibble(ch & 0x0f);
}

static auto uart_send_hex_nibble(char const nibble) -> void {
  if (nibble < 10) {
    uart_send_char('0' + nibble);
  } else {
    uart_send_char('A' + (nibble - 10));
  }
}
