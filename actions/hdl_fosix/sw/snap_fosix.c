/*
 * Copyright 2017 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <malloc.h>
#include <unistd.h>
#include <sys/time.h>
#include <getopt.h>
#include <ctype.h>

#include <libsnap.h>
#include <snap_hls_if.h>
#include <snap_tools.h>
#include <snap_s_regs.h>

#include "snap_fosix.h"

#define VERBOSE0(fmt, ...) do {         \
        printf(fmt, ## __VA_ARGS__);    \
} while (0)

#define VERBOSE1(fmt, ...) do {         \
    if (verbose_level > 0)          \
        printf(fmt, ## __VA_ARGS__);    \
} while (0)

#define VERBOSE2(fmt, ...) do {         \
    if (verbose_level > 1)          \
        printf(fmt, ## __VA_ARGS__);    \
} while (0)


#define VERBOSE3(fmt, ...) do {         \
    if (verbose_level > 2)          \
        printf(fmt, ## __VA_ARGS__);    \
} while (0)

#define VERBOSE4(fmt, ...) do {         \
    if (verbose_level > 3)          \
        printf(fmt, ## __VA_ARGS__);    \
} while (0)

typedef struct _alloc_list {
  void * mem;
  struct _alloc_list * next;
} AllocList;
static AllocList * alloc_list = NULL;
static void * alloc_append(size_t size) {
  AllocList * new = (AllocList *) malloc(sizeof(AllocList));
  if (new == NULL) {
    return NULL;
  }

  void * mem = snap_malloc(size);
  if (mem == NULL) {
    free(new);
    return NULL;
  }

  new->mem = mem;
  new->next = alloc_list;
  alloc_list = new;
  return mem;
}
static void alloc_free() {
  AllocList * cur = alloc_list;
  AllocList * nxt = NULL;
  while (cur != NULL) {
    nxt = cur->next;
    free(cur->mem);
    free(cur);
    cur = nxt;
  }
}

typedef struct _config_list {
  uint32_t addr;
  uint32_t data;
  struct _config_list * next;
} ConfigList;
static ConfigList * config_list = NULL;
static int config_append(uint32_t addr, uint32_t data) {
  ConfigList * new = (ConfigList *) malloc(sizeof(ConfigList));
  if (new == NULL) {
    return 0;
  }

  new->addr = addr;
  new->data = data;
  new->next = config_list;
  config_list = new;
  return 1;
}
static void config_free() {
  AllocList * cur = alloc_list;
  AllocList * nxt = NULL;
  while (cur != NULL) {
    nxt = cur->next;
    free(cur);
    cur = nxt;
  }
}

static const char *version = GIT_VERSION;
static int verbose_level = 0;

/* Action or Kernel Write and Read are 32 bit MMIO */
static void action_write(struct snap_card* h, uint32_t addr, uint32_t data)
{
    int rc;

    VERBOSE2("action_write((0x%x) <- 0x%x);", addr, data);
    rc = snap_mmio_write32(h, (uint64_t)addr, data);
    if (0 != rc)
        VERBOSE0("Write MMIO 32 Err\n");
    return;
}

static int action_wait_idle(struct snap_card* h, int timeout)
{
  int rc = 0;

  /* FIXME Use struct snap_action and not struct snap_card */
  snap_action_start((void*)h);

  /* Wait for Action to go back to Idle */
  rc = snap_action_completed((void*)h, NULL, timeout);
  if (rc) rc = 0;   /* Good */
  else rc = ETIME;  /* Timeout */
  if (0 != rc)
      VERBOSE0("%s Timeout Error\n", __func__);
  return rc;
}

static int do_action(struct snap_card *hCard, snap_action_flag_t flags, int timeout)
{
  int rc;
  struct snap_action * act;

  act = snap_attach_action(hCard, ACTION_TYPE_FOSIX, flags, 5 * timeout);
  if (NULL == act) {
      VERBOSE0("Error: Can not attach Action: %x\n", ACTION_TYPE_FOSIX);
      VERBOSE0("       Try to run snap_main tool\n");
      return 0x100;
  }

  for (ConfigList * it = config_list; it != NULL; it = it->next) {
    action_write(hCard, it->addr, it->data);
  }

  rc = action_wait_idle(hCard, timeout);
  if (0 != snap_detach_action(act)) {
      VERBOSE0("Error: Can not detach Action: %x\n", ACTION_TYPE_FOSIX);
      rc |= 0x100;
  }
  return rc;
}

static void usage(const char *prog)
{
    VERBOSE0("Usage: %s\n"
        "    -h, --help                        print usage information\n"
        "    -v, --verbose                     verbose mode\n"
        "    -C, --card <cardno>               use card <cardno> for operation\n"
        "    -V, --version\n"
        "    -t, --timeout                     timeout after N sec (default 1 sec)\n"
        "    -I, --irq                         enable ActionDoneInterrupt (default No Interrupts)\n"
        "    -s, --set <addr>:<value>          Set Config Register <addr> to <value> \n"
        "    -a, --alloc <addr>:<size>[+<off>] Allocate Buffer of <size> * 64Bytes,\n"
        "                                      Set Config Register <addr> to lower half and\n"
        "                                      Config Register <addr>+4 to upper half of\n"
        "                                      buffer address + <off>\n"
        "\tTest Tool for Fosix Components\n"
        , prog);
}

static int handle_set_option(char * option) {
  char * str = option;
  uint32_t addr;
  uint32_t value;
  addr = (uint32_t)strtoul(str, &str, 0);
  if (*str != ':') {
    VERBOSE0("Invalid --set option: \"%s\"", option);
    return 0;
  }
  ++str;
  value = (uint32_t)strtoul(str, &str, 0);
  if (*str != '\0') {
    VERBOSE0("Invalid --set option: \"%s\"", option);
    return 0;
  }
  return config_append(addr, value);
}

static int handle_alloc_option(char * option) {
  char * str = option;
  uint32_t addr;
  uint64_t size;
  uint64_t off = 0;
  addr = (uint32_t)strtoul(str, &str, 0);
  if (*str != ':') {
    VERBOSE0("Invalid --set option: \"%s\"", option);
    return 0;
  }
  ++str;
  size = (uint64_t)strtoul(str, &str, 0);
  if (*str == '+') {
    ++str;
    off = (uint32_t)strtoul(str, &str, 0);
  }
  if (*str != '\0') {
    VERBOSE0("Invalid --set option: \"%s\"", option);
    return 0;
  }

  void * mem = alloc_append(64*size);
  if (mem == NULL) {
    VERBOSE0("Could not allocate %ld * 64 Byte buffer", size);
    return 0;
  }

  uint64_t mem_addr = ((uint64_t)mem) + off;
  return config_append(addr,   (uint32_t)(mem_addr & 0xffffffff)) &&
         config_append(addr+4, (uint32_t)(mem_addr >> 32));
}

int main(int argc, char *argv[])
{
    int cmd;
    int cardNumber = 0;
    int timeout = 60;
    snap_action_flag_t flags = 0;
    while (1) {
        int option_index = 0;
        static struct option long_options[] = {
            { "card",     required_argument, NULL, 'C' },
            { "verbose",  no_argument,       NULL, 'v' },
            { "help",     no_argument,       NULL, 'h' },
            { "version",  no_argument,       NULL, 'V' },
            { "timeout",  required_argument, NULL, 't' },
            { "irq",      no_argument,       NULL, 'I' },
            { "set",      required_argument, NULL, 's' },
            { "alloc",    required_argument, NULL, 'a' },
            { 0,          no_argument,       NULL, 0   },
        };
        cmd = getopt_long(argc, argv, "C:s:a:t:IvVh",
            long_options, &option_index);
        if (cmd == -1)  /* all params processed ? */
            break;
        switch (cmd) {
        case 'v':   /* verbose */
            verbose_level++;
            break;
        case 'V':   /* version */
            VERBOSE0("%s\n", version);
            exit(EXIT_SUCCESS);;
        case 'h':   /* help */
            usage(argv[0]);
            exit(EXIT_SUCCESS);;
        case 'C':   /* card */
            cardNumber = strtol(optarg, (char **)NULL, 0);
            break;
        case 't':  /* timeout */
            timeout = strtol(optarg, (char **)NULL, 0); /* in sec */
            break;
        case 'I':      /* irq */
            flags = SNAP_ACTION_DONE_IRQ | SNAP_ATTACH_IRQ;
            break;
        case 's':  /* set */
            handle_set_option(optarg);
            break;
        case 'a':  /* alloc */
            handle_alloc_option(optarg);
            break;
        default:
            usage(argv[0]);
            exit(EXIT_FAILURE);
        }
    }

    if (cardNumber > 4) {
        VERBOSE0("Invalid card");
        usage(argv[0]); exit(1);
    }

    /* Open Card*/
    char device[64];
    struct snap_card *hCard;
    sprintf(device, "/dev/cxl/afu%d.0s", cardNumber);
    VERBOSE2("Open Card: %d device: %s\n", cardNumber, device);
    hCard = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);
    if (NULL == hCard) {
        VERBOSE0("ERROR: Can not Open (%s)\n", device);
        errno = ENODEV;
        perror("ERROR");
        return -1;
    }

    /* Read Card Info */
    char card_name[16];
    uint64_t cir;

    snap_card_ioctl(hCard, GET_CARD_NAME, (unsigned long)&card_name);
    VERBOSE1("SNAP on %s", card_name);

    snap_mmio_read64(hCard, SNAP_S_CIR, &cir);
    VERBOSE1("Start of Action: Card Handle: %p Context: %d\n", hCard,
        (int)(cir & 0x1ff));

    int rc = 1;
    rc = do_action(hCard, flags, timeout);

    // Unmap AFU MMIO registers, if previously mapped
    VERBOSE2("Free Card Handle: %p\n", hCard);
    snap_card_free(hCard);

    VERBOSE1("End of Test rc: %d\n", rc);
    alloc_free();
    config_free();
    return rc;
}
