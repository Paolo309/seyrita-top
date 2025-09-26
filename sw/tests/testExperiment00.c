// Tests the dummy accelerator and the "light" integration of snitch runtime

#include "offload.h"
#include "soc_addr_map.h"
#include <regs/soc_ctrl.h>
#include <stdint.h>
#include "snitch.h"

static uint32_t *clintPointer = (uint32_t *)CLINT_CTRL_BASE;

// static uint32_t *snitch_input = (uint32_t *)(HYPERRAM_BASE+0x100);
static uint32_t *snitch_input = (uint32_t *)(CLUSTER_2_BASE+0x50);
static uint32_t *snitch_output = (uint32_t *)(CLUSTER_2_BASE + 0x100);


void clusterTrapHandler() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    volatile uint32_t *interruptTarget = clintPointer + hartId;
    *interruptTarget = 0;
    return;
}


uint32_t test_accelerator() {
    volatile uint32_t *dummy_accel_base = (volatile uint32_t *)(DUMMY_HW_ACCEL_BASE);
    volatile uint32_t *accel_result = (volatile uint32_t *)(DUMMY_HW_ACCEL_BASE);

    *dummy_accel_base = *snitch_input; // computation started (1000 cycles in snitch)

    uint32_t res;
    
    do {
        res = *accel_result;
    } while (res == -1); // wait (busy) for computation to finish

    *snitch_output = res;

    return res << 1;
}

uint32_t get_cluster_idx() {
    return snrt_cluster_idx() << 1;
}

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setupInterruptHandler(clusterTrapHandler);

    setAllClusterReset(regPtr, 0);
    setAllClusterClockGating(regPtr, 0);

    // test accelerator on a cluster
    int cluster = 2;
    *snitch_input = 0xC0FFEE;
    uint32_t expected_result = *snitch_input * 2;

    offloadToCluster(test_accelerator, cluster);
    uint32_t snitchRetVal = waitForCluster(cluster);
    
    // test get cluster id
    offloadToCluster(get_cluster_idx, cluster);
    uint32_t retClusterIdx = waitForCluster(cluster);

    setClusterClockGating(regPtr, cluster, 1);
    setClusterReset(regPtr, cluster, 0);

    // ---

    uint32_t retCode = 0;
    if (snitchRetVal != ((expected_result << 1) | 1))
        retCode |= 1;
    if (*snitch_output != expected_result)
        retCode |= 2;
    if (retClusterIdx != ((cluster << 1) | 1))
        retCode |= 4;

    return retCode;
}
