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

static const char *version = GIT_VERSION;
static int verbose_level = 0;

/* Action or Kernel Write and Read are 32 bit MMIO */
static void action_write(struct snap_card* h, uint32_t addr, uint32_t data)
{
    int rc;

    rc = snap_mmio_write32(h, (uint64_t)addr, data);
    if (0 != rc)
        VERBOSE0("Write MMIO 32 Err\n");
    return;
}

/*
 *  Start Action and wait for Idle.
 */
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


static void configure_action(struct snap_card* h,
        uint64_t dstAdr, uint32_t dstCount, uint8_t dstBurst,
        uint64_t srcAdr, uint32_t srcCount, uint8_t srcBurst)
{
    uint64_t addr;

    VERBOSE1(" configure_action(0x%lx, 0x%x, 0x%hhx,\n0x%lx, 0x%x, 0x%hhx) ",
             dstAdr, dstCount, dstBurst,
             srcAdr, srcCount, srcBurst);
    addr = (uint64_t)dstAdr;
    action_write(h, ACTION_DST_LOW,   (uint32_t)(addr & 0xffffffff));
    action_write(h, ACTION_DST_HIGH,  (uint32_t)(addr >> 32));
    action_write(h, ACTION_DST_COUNT, (uint32_t)(dstCount));
    action_write(h, ACTION_DST_BURST, (uint32_t)(srcBurst));
    addr = (uint64_t)srcAdr;
    action_write(h, ACTION_SRC_LOW,   (uint32_t)(addr & 0xffffffff));
    action_write(h, ACTION_SRC_HIGH,  (uint32_t)(addr >> 32));
    action_write(h, ACTION_SRC_COUNT, (uint32_t)(srcCount));
    action_write(h, ACTION_SRC_BURST, (uint32_t)(srcBurst));
    return;
}

static int do_action(struct snap_card *hCard,
            snap_action_flag_t flags, int timeout,
            uint64_t dstAdr, uint32_t dstCount, uint8_t dstBurst,
            uint64_t srcAdr, uint32_t srcCount, uint8_t srcBurst)
{
    int rc;
    struct snap_action * act;

    act = snap_attach_action(hCard, ACTION_TYPE_FOSIX, flags, 5 * timeout);
    if (NULL == act) {
        VERBOSE0("Error: Can not attach Action: %x\n", ACTION_TYPE_FOSIX);
        VERBOSE0("       Try to run snap_main tool\n");
        return 0x100;
    }
    configure_action(hCard, dstAdr, dstCount, dstBurst, srcAdr, srcCount, srcBurst);
    rc = action_wait_idle(hCard, timeout);
    if (0 != snap_detach_action(act)) {
        VERBOSE0("Error: Can not detach Action: %x\n", ACTION_TYPE_FOSIX);
        rc |= 0x100;
    }
    return rc;
}

static int execute_test(struct snap_card* hCard, snap_action_flag_t flags, int timeout,
            uint32_t count, uint8_t dstBurst, uint8_t srcBurst)
{
    int rc;
    void *src = NULL;
    void *dst = NULL;
    unsigned long alloc_size;

    rc = 0;
    /* Number of bytes */
    alloc_size = (unsigned long)count * 64;
    if (0 == alloc_size) {
        VERBOSE0("Empty Transfer of %ld Bytes (%d blocks)", alloc_size, count);
        return 1;
    }

    /* Allocate Host Src Buffer */
    src = snap_malloc(alloc_size);
    if (src == NULL) {
        VERBOSE0("Could not allocate source buffer.");
        return 1;
    }

    VERBOSE1("  From Host: %p Size: 0x%llx", src, (long long)alloc_size);
    /* Allocate Host Dst Buffer */
    dst = snap_malloc(alloc_size);
    if (dst == NULL) {
        free(src);
        return 1;
    }
    VERBOSE1("  To Host:   %p timeout: %d sec\n", dst, timeout);

    rc = do_action(hCard, flags, timeout,
                   (uint64_t)dst, count, dstBurst,
                   (uint64_t)src, count, srcBurst);
    VERBOSE1("  rc = %d", rc);
    free(src);
    free(dst);

    return rc;
}

static void usage(const char *prog)
{
    VERBOSE0("Usage: %s\n"
        "    -h, --help           print usage information\n"
        "    -v, --verbose        verbose mode\n"
        "    -C, --card <cardno>  use this card for operation\n"
        "    -V, --version\n"
        "    -t, --timeout        Timeout after N sec (default 1 sec)\n"
        "    -I, --irq            Enable Action Done Interrupt (default No Interrupts)\n"
        "    -s, --size           Transfer Size in 64 Byte Blocks\n"
        "    -b, --rdBurst        Maximum Read Burst Length in 64 Byte Blocks\n"
        "    -B, --wrBurst        Maximum Write Burst Length in 64 Byte Blocks\n"
        "\tTest Tool for Fosix Components\n"
        , prog);
}

int main(int argc, char *argv[])
{
    int cmd;
    int cardNumber = 0;
    int timeout = 60;
    snap_action_flag_t flags = 0;
    uint32_t count = 0;
    uint32_t srcBurst = 64;
    uint32_t dstBurst = 64;
    while (1) {
        int option_index = 0;
        static struct option long_options[] = {
            { "card",     required_argument, NULL, 'C' },
            { "verbose",  no_argument,       NULL, 'v' },
            { "help",     no_argument,       NULL, 'h' },
            { "version",  no_argument,       NULL, 'V' },
            { "timeout",  required_argument, NULL, 't' },
            { "irq",      no_argument,       NULL, 'I' },
            { "size",     required_argument, NULL, 's' },
            { "rdBurst",  required_argument, NULL, 'b' },
            { "wrBurst",  required_argument, NULL, 'B' },
            { 0,          no_argument,       NULL, 0   },
        };
        cmd = getopt_long(argc, argv, "C:s:b:B:t:IvVh",
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
        case 's':  /* size */
            count = strtol(optarg, (char **)NULL, 0);
            break;
        case 'b':  /* read burst */
            srcBurst = strtol(optarg, (char **)NULL, 0);
            break;
        case 'B':  /* write burst */
            dstBurst = strtol(optarg, (char **)NULL, 0);
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
    if (count == 0) {
        VERBOSE0("Invalid size");
        usage(argv[0]); exit(1);
    }
    if (srcBurst == 0 || srcBurst > 64) {
        VERBOSE0("Invalid rdBurst");
        usage(argv[0]); exit(1);
    }
    if (dstBurst == 0 || dstBurst > 64) {
        VERBOSE0("Invalid wrBurst");
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
    rc = execute_test(hCard, flags, timeout, count, dstBurst, srcBurst);

    // Unmap AFU MMIO registers, if previously mapped
    VERBOSE2("Free Card Handle: %p\n", hCard);
    snap_card_free(hCard);

    VERBOSE1("End of Test rc: %d\n", rc);
    return rc;
}
