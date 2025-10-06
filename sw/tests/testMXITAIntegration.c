// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include <offload.h>
#include <soc_addr_map.h>
#include <stdint.h>

// static uint32_t *clintPointer = (uint32_t *)CLINT_CTRL_BASE;

// void clusterTrapHandler() {
//     uint8_t hartId;
//     asm("csrr %0, mhartid" : "=r"(hartId)::);
//
//     volatile uint32_t *interruptTarget = clintPointer + hartId;
//     *interruptTarget = 0;
//     return;
// }

int main() {
    // setupInterruptHandler(clusterTrapHandler);

    volatile uint8_t *clockGatingRegPtr = (volatile uint8_t *)SOC_CTRL_BASE;

    setClusterReset(clockGatingRegPtr, 2, 0);
    setClusterClockGating(clockGatingRegPtr, 2, 0);

    volatile uint8_t *cluPtr_0 = (volatile uint8_t *)CLUSTER_2_BASE;
    *cluPtr_0 = 0x2A;
    volatile uint8_t result_0 = *cluPtr_0;

    volatile uint32_t *cluPtr_1 = (volatile uint32_t *)CLUSTER_2_BASE;
    *cluPtr_1 = 0xDEADBEEF;
    volatile uint32_t result_1 = *cluPtr_1;

    setClusterClockGating(clockGatingRegPtr, 2, 1);
    setClusterReset(clockGatingRegPtr, 2, 0);

    uint32_t ret_code = 0;
    ret_code |= (result_0 != 0x2A);
    ret_code |= ((result_1 != 0xDEADBEEF) << 1);

    return ret_code;
}
