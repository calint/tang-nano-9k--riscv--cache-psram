static const char *hello = "welcome to adventure #4\r\n    type 'help'\r\n\r\n";

static const char *ascii_art =
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

constexpr char CHAR_BACKSPACE = 0x7f;
constexpr int LOCATION_MAX_OBJECTS = 128;
constexpr int LOCATION_MAX_ENTITIES = 8;
constexpr int LOCATION_MAX_EXITS = 6;
constexpr int ENTITY_MAX_OBJECTS = 32;

void led_set(unsigned char bits);
void uart_send_str(const char *str);
void uart_send_char(char ch);
char uart_read_char();
void uart_send_hex_byte(char ch);
void uart_send_hex_nibble(char nibble);

using name_t = const char *;
using location_id_t = unsigned char;
using object_id_t = unsigned char;
using entity_id_t = unsigned char;
using direction_t = unsigned char;

struct input_buffer {
  char line[80];
  unsigned char ix;
};

struct object {
  name_t name;
};

static object objects[] = {{""}, {"notebook"}, {"mirror"}, {"lighter"}};

struct entity {
  name_t name;
  location_id_t location;
  object_id_t objects[ENTITY_MAX_OBJECTS];
};

static entity entities[] = {{"", 0, {0}}, {"me", 1, {2}}, {"u", 2, {0}}};

struct location {
  name_t name;
  object_id_t objects[LOCATION_MAX_OBJECTS];
  entity_id_t entities[LOCATION_MAX_ENTITIES];
  location_id_t exits[LOCATION_MAX_EXITS];
};

static location locations[] = {{"", {0}, {0}, {0}},
                               {"roome", {0}, {1}, {2, 3, 0, 4}},
                               {"office", {1, 3}, {2}, {0, 0, 1}},
                               {"bathroom", {0}, {0}, {0}},
                               {"kitchen", {0}, {0}, {0, 1}}};

static const char *exit_names[] = {"north", "east", "south",
                                   "west",  "up",   "down"};

void print_help();
void print_location(location_id_t lid, entity_id_t eid_exclude_from_output);
bool add_object_to_list(object_id_t list[], unsigned list_len, object_id_t oid);
void remove_object_from_list_by_index(object_id_t list[], unsigned ix);
bool add_entity_to_list(entity_id_t list[], unsigned list_len, entity_id_t eid);
void remove_entity_from_list_by_index(entity_id_t list[], unsigned ix);
void remove_entity_from_list(entity_id_t list[], unsigned list_len,
                             entity_id_t eid);
void action_inventory(entity_id_t eid);
void action_give(entity_id_t eid, name_t obj, name_t to_ent);
void action_go(entity_id_t eid, direction_t dir);
void action_drop(entity_id_t eid, name_t obj);
void action_take(entity_id_t eid, name_t obj);
void action_mem_test();
void input(input_buffer &buf);
void handle_input(entity_id_t eid, input_buffer &buf);
bool strings_equal(const char *s1, const char *s2);

extern "C" void run() {

  led_set(0); // turn all leds on

  unsigned char active_entity = 1;
  input_buffer inbuf;
  inbuf.ix = 0;

  uart_send_str(ascii_art);
  uart_send_str(hello);

  while (1) {
    const entity *ent = &entities[active_entity];
    print_location(ent->location, active_entity);
    uart_send_str(ent->name);
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

void handle_input(entity_id_t eid, input_buffer &buf) {
  const char *words[8];
  char *ptr = buf.line;
  unsigned nwords = 0;
  while (1) {
    words[nwords++] = ptr;
    while (*ptr && *ptr != ' ') {
      ptr++;
    }
    if (!*ptr)
      break;
    *ptr = 0;
    ptr++;
    if (nwords == sizeof(words) / sizeof(const char *)) {
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

void print_location(location_id_t lid, entity_id_t eid_exclude_from_output) {
  const location *loc = &locations[lid];
  uart_send_str("u r in ");
  uart_send_str(loc->name);
  uart_send_str("\r\nu c: ");

  // print objects in location
  bool add_list_sep = false;
  const object_id_t *lso = loc->objects;
  for (unsigned i = 0; i < LOCATION_MAX_OBJECTS; i++) {
    const object_id_t oid = lso[i];
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
  const entity_id_t *lse = loc->entities;
  for (unsigned i = 0; i < LOCATION_MAX_ENTITIES; i++) {
    const entity_id_t eid = lse[i];
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
    if (!loc->exits[i])
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

void action_inventory(entity_id_t eid) {
  uart_send_str("u have: ");
  bool add_list_sep = false;
  const object_id_t *lso = entities[eid].objects;
  for (unsigned i = 0; i < ENTITY_MAX_OBJECTS; i++) {
    const object_id_t oid = lso[i];
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

void remove_object_from_list_by_index(object_id_t list[], unsigned ix) {
  object_id_t *ptr = &list[ix];
  while (1) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

bool add_object_to_list(object_id_t list[], unsigned list_len,
                        object_id_t oid) {
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

bool add_entity_to_list(entity_id_t list[], unsigned list_len,
                        entity_id_t eid) {
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

void remove_entity_from_list(entity_id_t list[], unsigned list_len,
                             entity_id_t eid) {
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

void remove_entity_from_list_by_index(entity_id_t list[], unsigned ix) {
  entity_id_t *ptr = &list[ix];
  while (1) {
    *ptr = *(ptr + 1);
    if (!*ptr)
      return;
    ptr++;
  }
}

void action_take(entity_id_t eid, name_t obj) {
  entity *ent = &entities[eid];
  object_id_t *lso = locations[ent->location].objects;
  for (unsigned i = 0; i < LOCATION_MAX_OBJECTS; i++) {
    const object_id_t oid = lso[i];
    if (!oid)
      break;
    if (!strings_equal(objects[oid].name, obj))
      continue;
    if (add_object_to_list(ent->objects, ENTITY_MAX_OBJECTS, oid)) {
      remove_object_from_list_by_index(lso, i);
    }
    return;
  }
  uart_send_str(obj);
  uart_send_str(" not here\r\n\r\n");
}

void action_drop(entity_id_t eid, name_t obj) {
  entity *ent = &entities[eid];
  object_id_t *lso = ent->objects;
  for (unsigned i = 0; i < ENTITY_MAX_OBJECTS; i++) {
    const object_id_t oid = lso[i];
    if (!oid)
      break;
    if (!strings_equal(objects[oid].name, obj))
      continue;
    if (add_object_to_list(locations[ent->location].objects,
                           LOCATION_MAX_OBJECTS, oid)) {
      remove_object_from_list_by_index(lso, i);
    }
    return;
  }
  uart_send_str("u don't have ");
  uart_send_str(obj);
  uart_send_str("\r\n\r\n");
}

void action_go(entity_id_t eid, direction_t dir) {
  entity *ent = &entities[eid];
  location *loc = &locations[ent->location];
  const location_id_t to = loc->exits[dir];
  if (!to) {
    uart_send_str("cannot go there\r\n\r\n");
    return;
  }
  if (add_entity_to_list(locations[to].entities, LOCATION_MAX_ENTITIES, eid)) {
    remove_entity_from_list(loc->entities, LOCATION_MAX_ENTITIES, eid);
    ent->location = to;
  }
}

void action_give(entity_id_t eid, name_t obj, name_t to_ent) {
  entity *ent = &entities[eid];
  const location *loc = &locations[ent->location];
  const entity_id_t *lse = loc->entities;
  for (unsigned i = 0; i < LOCATION_MAX_ENTITIES; i++) {
    if (!lse[i])
      break;
    entity *to = &entities[lse[i]];
    if (!strings_equal(to->name, to_ent))
      continue;
    object_id_t *lso = ent->objects;
    for (unsigned j = 0; j < ENTITY_MAX_OBJECTS; j++) {
      const object_id_t oid = lso[j];
      if (!oid)
        break;
      if (!strings_equal(objects[oid].name, obj))
        continue;
      if (add_object_to_list(to->objects, ENTITY_MAX_OBJECTS, oid)) {
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

void print_help() {
  uart_send_str(
      "\r\ncommand:\r\n  n: go north\r\n  e: go east\r\n  s: go south\r\n  w: "
      "go west\r\n  i: "
      "display inventory\r\n  t <object>: take object\r\n  d <object>: drop "
      "object\r\n  g <object> <entity>: give object to entity\r\n  help: this "
      "message\r\n\r\n");
}

void input(input_buffer &buf) {
  while (1) {
    const char ch = uart_read_char();
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

bool strings_equal(const char *s1, const char *s2) {
  while (1) {
    if (*s1 - *s2)
      return false;
    if (!*s1 && !*s2)
      return true;
    s1++;
    s2++;
  }
}

void uart_send_hex_byte(const char ch) {
  uart_send_hex_nibble((ch & 0xf0) >> 4);
  uart_send_hex_nibble(ch & 0x0f);
}

void uart_send_hex_nibble(const char nibble) {
  if (nibble < 10) {
    uart_send_char('0' + nibble);
  } else {
    uart_send_char('A' + (nibble - 10));
  }
}
