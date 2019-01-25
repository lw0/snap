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

static uint64_t rnd64_state = 0x6c; // requires nonzero seed
static uint64_t rnd64()
{
    uint64_t x = rnd64_state;
    x^= x << 13;
    x^= x >> 7;
    x^= x << 17;
    rnd64_state = x;
    return x;
}

typedef struct _alloc_list {
  void * mem;
  uint32_t id;
  struct _alloc_list * next;
} AllocList;
static AllocList * alloc_list = NULL;
static int alloc_append(size_t size, uint32_t id) {
  AllocList * new = (AllocList *) malloc(sizeof(AllocList));
  if (new == NULL) {
    return 0;
  }

  void * mem = snap_malloc(size*64);
  if (mem == NULL) {
    free(new);
    return 0;
  }
  for (uint64_t i = 0; i < 8*size; ++i) {
    ((uint64_t*)mem)[i] = rnd64();
  }

  new->mem = mem;
  new->id = id;
  new->next = alloc_list;
  alloc_list = new;

  return 1;
}
static int alloc_get(uint32_t id, uint64_t * mem_addr) {
  AllocList * cur = alloc_list;
  while (cur != NULL) {
    if (cur->id == id) {
      (*mem_addr) = (uint64_t) (cur->mem);
      return 1;
    }
    cur = cur->next;
  }
  return 0;
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


static const char *version = GIT_VERSION;
static int verbose_level = 0;

static void action_write(struct snap_card* h, uint32_t addr, uint32_t data)
{
  int rc;

  rc = snap_mmio_write32(h, (uint64_t)addr, data);
  if (0 != rc)
      VERBOSE0("Error: MMIO Write @0x%08x\n", addr);
}
static uint32_t action_read(struct snap_card* h, uint32_t addr)
{
  int rc;
  uint32_t data;

  rc = snap_mmio_read32(h, (uint64_t)addr, &data);
  if (0 != rc)
      VERBOSE0("Error: MMIO Read @0x%08x\n", addr);
  return data;
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

static int interact(struct snap_card *hCard, int timeout) {
  char command;
  uint8_t shift;
  uint32_t addr;
  uint32_t id;
  uint32_t data32;
  uint64_t data64;
  uint64_t size;
  uint64_t mem_addr;
  int timeout_ovr;
  int rc = 0;

  int read = 0;
  while(read != EOF) {
    read = scanf("%c", &command);
    if (read == 1) {
      switch(command){
      case 'g':
        read = scanf("%x", &addr);
        if (read == 1) {
          data32 = action_read(hCard, addr);
          VERBOSE0("(0x%08x) => 0x%08x\n", addr, data32);
        } else {
          VERBOSE0("Invalid Get Command\n");
        }
        break;
      case 's':
        read = scanf("%x:%x", &addr, &data32);
        if (read == 2) {
          VERBOSE0("(0x%08x) <= 0x%08x\n", addr, data32);
          action_write(hCard, addr, data32);
        } else {
          VERBOSE0("Invalid Set Command\n");
        }
        break;
      case 'G':
        read = scanf("%x", &addr);
        if (read == 1) {
          data32 = action_read(hCard, addr+4);
          data64 = (((uint64_t)data32) << 32) | action_read(hCard, addr);
          VERBOSE0("(0x%08x) => 0x%016lx\n", addr, data64);
        } else {
          VERBOSE0("Invalid Get Command\n");
        }
        break;
      case 'S':
        read = scanf("%x:%lx", &addr, &data64);
        if (read == 2) {
          VERBOSE0("(0x%08x) <= 0x%016lx\n", addr, data64);
          data32 = data64 >> 32;
          action_write(hCard, addr+4, data32);
          data32 = data64 & 0xffffffff;
          action_write(hCard, addr, data32);
        } else {
          VERBOSE0("Invalid Set Command\n");
        }
        break;
      case 'A':
        read = scanf("%d:%lx", &id, &size);
        if (read == 2) {
          if (!alloc_append(size, id)) {
            VERBOSE0("Could not allocate %ld * 64 Byte buffer", size);
          }
        } else {
          VERBOSE0("Invalid Allocate Command\n");
        }
        break;
      case 'R':
        read = scanf("%x:%lx+A%u|%hhu", &addr, &data64, &id, &shift);
        if (read == 4) {
          if (alloc_get(id, &mem_addr)) {
            data64 += (mem_addr >> shift);
            data32 = (uint32_t)(data64 & 0xffffffff);
            VERBOSE0("(0x%08x) <= 0x%08x\n", addr, data32);
            action_write(hCard, addr, data32);
            addr += 4;
            data32 = (uint32_t)(data64 >> 32);
            VERBOSE0("(0x%08x) <= 0x%08x\n", addr, data32);
            action_write(hCard, addr, data32);
          } else {
            VERBOSE0("Unknown Allocation %x\n", id);
          }
        } else {
          VERBOSE0("Invalid Set Allocation Command\n");
        }
        break;
      case 'r':
        read = scanf("%u", &timeout_ovr);
        if (read == 1) {
          VERBOSE0("Action Start");
          if (timeout_ovr > 0) {
            rc = action_wait_idle(hCard, timeout_ovr);
          } else {
            rc = action_wait_idle(hCard, timeout);
          }
          VERBOSE0("Action Return Code %d", rc);
        } else {
          VERBOSE0("Invalid Run Command\n");
        }
        break;
      case 'q':
        read = EOF;
        break;
      case '\n':
        break;
      default:
        VERBOSE0("Unrecognized Command. Use 'q' to quit.\n");
      }
    } else {
        VERBOSE0("Unrecognized Command. Use 'q' to quit.\n");
    }
  }
  alloc_free();
  return rc;
}
static int do_action(struct snap_card *hCard, snap_action_flag_t flags, int timeout)
{
  int rc;
  struct snap_action * act;

  act = snap_attach_action(hCard, ACTION_TYPE_FOSIX, flags, 5*timeout);

  rc = interact(hCard, timeout);

  if (0 != snap_detach_action(act)) {
      VERBOSE0("Error: Can not detach Action: %x\n", ACTION_TYPE_FOSIX);
      rc |= 0x100;
  }
  return rc;
}

static void usage(const char *prog)
{
    VERBOSE0("Usage: %s\n"
        "    -h, --help                   Print usage information\n"
        "    -v, --verbose                Verbose mode\n"
        "    -C, --card <cardno>          Use card <cardno> for operation\n"
        "    -V, --version\n"
        "    -t, --timeout                Timeout after N sec (default 1 sec)\n"
        "    -I, --irq                    Enable ActionDoneInterrupt (default No Interrupts)\n"
        "    -S, --seed <value>           Use seed to generate pseudorandom data in allocated buffers\n"
        "\n"
        " Commands:\n"
        "    g<addr>                      Get Register <addr>\n"
        "    s<addr>:<value>              Set Register <addr> to <value> \n"
        "    G<addr>                      Get Registers <addr> and <addr>+4\n"
        "    S<addr>:<value>              Set Registers <addr> and <addr>+4 to <value> \n"
        "    A<id>:<size>                 Allocate Buffer of <size> * 64Bytes at <id>\n"
        "    M<addr>:<base>+A<id>|<shift> Set Registers <addr> and <addr>+4 to <base> offset by\n"
        "                                 Address of Allocation <id> shifted right by <shift> bits\n"
        "    r<sec>                       Run Action, Timeout after <sec> seconds, <sec>=0 uses default\n"
        "    q                            Quit Program\n"
        "\n"
        "\tTest Tool for Fosix Components\n"
        , prog);
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
            { "seed",     required_argument, NULL, 'S' },
            { 0,          no_argument,       NULL, 0   },
        };
        cmd = getopt_long(argc, argv, "C:S:g:s:a:t:IvVh",
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
        case 'S':   /* seed */
            rnd64_state = strtol(optarg, (char **)NULL, 0);
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
    return rc;
}
