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

constexpr uint8_t CHAR_BACKSPACE = 0x7f;
constexpr uint32_t LOCATION_MAX_OBJECTS = 128;
constexpr uint32_t LOCATION_MAX_ENTITIES = 8;
constexpr uint32_t LOCATION_MAX_EXITS = 6;
constexpr uint32_t ENTITY_MAX_OBJECTS = 32;

struct input_buffer {
  char line[80]{};
  uint8_t ix{};
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
auto led_set(uint8_t bits) -> void;
auto uart_send_str(char const *str) -> void;
auto uart_send_char(char ch) -> void;
auto uart_read_char() -> char;
auto uart_send_hex_byte(char ch) -> void;
auto uart_send_hex_nibble(char nibble) -> void;

// API
auto print_help() -> void;
auto print_location(location_id_t lid,
                    entity_id_t eid_exclude_from_output) -> void;
auto add_object_to_list(object_id_t list[], uint32_t list_len,
                        object_id_t oid) -> bool;
auto remove_object_from_list_by_index(object_id_t list[], uint32_t ix) -> void;
auto add_entity_to_list(entity_id_t list[], uint32_t list_len,
                        entity_id_t eid) -> bool;
auto remove_entity_from_list_by_index(entity_id_t list[], uint32_t ix) -> void;
auto remove_entity_from_list(entity_id_t list[], uint32_t list_len,
                             entity_id_t eid) -> void;
auto action_inventory(entity_id_t eid) -> void;
auto action_give(entity_id_t eid, name_t obj, name_t to_ent) -> void;
auto action_go(entity_id_t eid, direction_t dir) -> void;
auto action_drop(entity_id_t eid, name_t obj) -> void;
auto action_take(entity_id_t eid, name_t obj) -> void;
auto input(input_buffer &buf) -> void;
auto handle_input(entity_id_t eid, input_buffer &buf) -> void;
auto strings_equal(char const *s1, char const *s2) -> bool;
auto action_mem_test() -> void;

extern "C" auto run() -> void {

  led_set(0); // turn all leds on

  entity_id_t active_entity = 1;
  input_buffer inbuf{};

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

auto handle_input(entity_id_t eid, input_buffer &buf) -> void {
  char const *words[8];
  char *ptr = buf.line;
  unsigned nwords = 0;
  while (true) {
    words[nwords++] = ptr;
    while (*ptr && *ptr != ' ') {
      ptr++;
    }
    if (!*ptr)
      break;
    *ptr = 0;
    ptr++;
    if (nwords == sizeof(words) / sizeof(char const *)) {
      uart_send_str("too many words, some ignored\r\n\r\n");
      break;
    }
  }
  //  for (unsigned i = 0; i < nwords; i++) {
  //    uart_send_str(words[i]);
  //    uart_send_str("\r\n");
  //  }
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

auto print_location(location_id_t lid,
                    entity_id_t eid_exclude_from_output) -> void {
  location const &loc = locations[lid];
  uart_send_str("u r in ");
  uart_send_str(loc.name);
  uart_send_str("\r\nu c: ");

  // print objects in location
  bool add_list_sep = false;
  object_id_t const *lso = loc.objects;
  for (unsigned i = 0; i < LOCATION_MAX_OBJECTS; i++) {
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
  for (unsigned i = 0; i < LOCATION_MAX_ENTITIES; i++) {
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
  for (unsigned i = 0; i < LOCATION_MAX_EXITS; i++) {
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

auto action_inventory(entity_id_t eid) -> void {
  uart_send_str("u have: ");
  bool add_list_sep = false;
  object_id_t const *lso = entities[eid].objects;
  for (unsigned i = 0; i < ENTITY_MAX_OBJECTS; i++) {
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

auto remove_object_from_list_by_index(object_id_t list[], unsigned ix) -> void {
  object_id_t *ptr = &list[ix];
  while (true) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

auto add_object_to_list(object_id_t list[], unsigned list_len,
                        object_id_t oid) -> bool {
  // list_len - 1 since last element has to be 0
  for (unsigned i = 0; i < list_len - 1; i++) {
    if (list[i])
      continue;
    list[i] = oid;
    list[i + 1] = 0;
    return true;
  }
  uart_send_str("space full\r\n");
  return false;
}

auto add_entity_to_list(entity_id_t list[], unsigned list_len,
                        entity_id_t eid) -> bool {
  // list_len - 1 since last element has to be 0
  for (unsigned i = 0; i < list_len - 1; i++) {
    if (list[i])
      continue;
    list[i] = eid;
    list[i + 1] = 0;
    return true;
  }
  uart_send_str("location full\r\n");
  return false;
}

auto remove_entity_from_list(entity_id_t list[], unsigned list_len,
                             entity_id_t eid) -> void {
  // list_len - 1 since last element has to be 0
  for (unsigned i = 0; i < list_len - 1; i++) {
    if (list[i] != eid)
      continue;
    // list_len - 1 since last element has to be 0
    for (unsigned j = i; j < list_len - 1; j++) {
      list[j] = list[j + 1];
      if (!list[j])
        return;
    }
  }
  uart_send_str("entity not here\r\n");
}

auto remove_entity_from_list_by_index(entity_id_t list[], unsigned ix) -> void {
  entity_id_t *ptr = &list[ix];
  while (true) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

auto action_take(entity_id_t eid, name_t obj) -> void {
  entity &ent = entities[eid];
  object_id_t *lso = locations[ent.location].objects;
  for (unsigned i = 0; i < LOCATION_MAX_OBJECTS; i++) {
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

auto action_drop(entity_id_t eid, name_t obj) -> void {
  entity &ent = entities[eid];
  object_id_t *lso = ent.objects;
  for (unsigned i = 0; i < ENTITY_MAX_OBJECTS; i++) {
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

auto action_go(entity_id_t eid, direction_t dir) -> void {
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

auto action_give(entity_id_t eid, name_t obj, name_t to_ent) -> void {
  entity &ent = entities[eid];
  location const &loc = locations[ent.location];
  entity_id_t const *lse = loc.entities;
  for (unsigned i = 0; i < LOCATION_MAX_ENTITIES; i++) {
    if (!lse[i])
      break;
    entity &to = entities[lse[i]];
    if (!strings_equal(to.name, to_ent))
      continue;
    object_id_t *lso = ent.objects;
    for (unsigned j = 0; j < ENTITY_MAX_OBJECTS; j++) {
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

auto print_help() -> void {
  uart_send_str(
      "\r\ncommand:\r\n  n: go north\r\n  e: go east\r\n  s: go south\r\n  w: "
      "go west\r\n  i: "
      "display inventory\r\n  t <object>: take object\r\n  d <object>: drop "
      "object\r\n  g <object> <entity>: give object to entity\r\n  help: this "
      "message\r\n\r\n");
}

auto input(input_buffer &buf) -> void {
  while (true) {
    char const ch = uart_read_char();
    // uart_send_hex_byte(ch);
    // uart_send_char(' ');
    // continue;
    if (ch == CHAR_BACKSPACE) {
      if (buf.ix > 0) {
        buf.ix--;
        uart_send_char(ch);
      }
    } else if (ch == CHAR_CARRIAGE_RETURN || buf.ix == sizeof(buf.line) - 1) {
      // -1 since last char must be 0
      buf.line[buf.ix] = 0;
      buf.ix = 0;
      return;
    } else {
      buf.line[buf.ix] = ch;
      buf.ix++;
      uart_send_char(ch);
    }
    led_set(~buf.ix);
  }
}

auto strings_equal(char const *s1, char const *s2) -> bool {
  while (true) {
    if (*s1 - *s2)
      return false;
    if (!*s1 && !*s2)
      return true;
    s1++;
    s2++;
  }
}

auto uart_send_hex_byte(char const ch) -> void {
  uart_send_hex_nibble((ch & 0xf0) >> 4);
  uart_send_hex_nibble(ch & 0x0f);
}

auto uart_send_hex_nibble(char const nibble) -> void {
  if (nibble < 10) {
    uart_send_char('0' + nibble);
  } else {
    uart_send_char('A' + (nibble - 10));
  }
}
