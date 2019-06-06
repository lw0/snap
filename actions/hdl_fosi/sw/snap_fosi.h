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

#ifndef __SNAP_FOSIX_H__
#define __SNAP_FOSIX_H__

/*
 * This makes it obvious that we are influenced by HLS details ...
 * The ACTION control bits are defined in the following file.
 */
#include <snap_hls_if.h>

/* Header file for SNAP Framework example code */
#define ACTION_TYPE_FOSIX       0x0000006c

#define ACTION_SRC_LOW          0x40
#define ACTION_SRC_HIGH         0x44
#define ACTION_SRC_COUNT        0x48
#define ACTION_SRC_BURST        0x4c

#define ACTION_DST_LOW          0x50
#define ACTION_DST_HIGH         0x54
#define ACTION_DST_COUNT        0x58
#define ACTION_DST_BURST        0x5c

#endif	/* __SNAP_FOSIX_H__ */
