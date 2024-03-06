
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <getopt.h>
#include <string.h>
#include <unistd.h>
#include <math.h>

#include <sys/time.h>
#include <sys/mman.h>

typedef struct {
    uint64_t pfn : 55;
    unsigned int soft_dirty : 1;
    unsigned int file_page : 1;
    unsigned int swapped : 1;
    unsigned int present : 1;
} PagemapEntry;

/* Parse the pagemap entry for the given virtual address.
 *
 * @param[out] entry      the parsed entry
 * @param[in]  pagemap_fd file descriptor to an open /proc/pid/pagemap file
 * @param[in]  vaddr      virtual address to get entry for
 * @return 0 for success, 1 for failure
 */
int pagemap_get_entry(PagemapEntry *entry, int pagemap_fd, uintptr_t vaddr)
{
    size_t nread;
    ssize_t ret;
    uint64_t data;
    uintptr_t vpn;

    vpn = vaddr / sysconf(_SC_PAGE_SIZE);
    nread = 0;
    while (nread < sizeof(data)) {
        ret = pread(pagemap_fd, ((uint8_t*)&data) + nread, sizeof(data) - nread,
                vpn * sizeof(data) + nread);
        nread += ret;
        if (ret <= 0) {
            return 1;
        }
    }
    entry->pfn = data & (((uint64_t)1 << 55) - 1);
    entry->soft_dirty = (data >> 55) & 1;
    entry->file_page = (data >> 61) & 1;
    entry->swapped = (data >> 62) & 1;
    entry->present = (data >> 63) & 1;
    return 0;
}

/* Convert the given virtual address to physical using /proc/PID/pagemap.
 *
 * @param[out] paddr physical address
 * @param[in]  pid   process to convert for
 * @param[in] vaddr virtual address to get entry for
 * @return 0 for success, 1 for failure
 */
int virt_to_phys_user(uintptr_t *paddr, pid_t pid, uintptr_t vaddr)
{
    char pagemap_file[BUFSIZ];
    int pagemap_fd;

    snprintf(pagemap_file, sizeof(pagemap_file), "/proc/%ju/pagemap", (uintmax_t)pid);
    pagemap_fd = open(pagemap_file, O_RDONLY);
    if (pagemap_fd < 0) {
        return 1;
    }
    PagemapEntry entry;
    if (pagemap_get_entry(&entry, pagemap_fd, vaddr)) {
        return 1;
    }
    close(pagemap_fd);
    *paddr = (entry.pfn * sysconf(_SC_PAGE_SIZE)) + (vaddr % sysconf(_SC_PAGE_SIZE));
    return 0;
}

// function : get_millisecond
// description : get time in millisecond
static uint64_t get_millisecond () {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000 + (uint64_t)(tv.tv_usec / 1000);
}

uint64_t getopt_integer(char *optarg)
{
	int rc;
	uint64_t value;

	rc = sscanf(optarg, "0x%lx", &value);
	if (rc <= 0)
		rc = sscanf(optarg, "%lu", &value);
	//printf("sscanf() = %d, value = 0x%lx\n", rc, value);

	return value;
}

uint64_t find_max_phy_conti_mem(uintptr_t *paddr, uintptr_t* vaddr, void * buf, uint64_t buf_sz, uint64_t target_sz) {
    uintptr_t buf_phy_addr;
    uintptr_t conti_mem_start_paddr;
    uint64_t max_conti_mem_size = 0, conti_mem_size = 0;
    uintptr_t max_conti_mem_start_paddr=0, max_conti_mem_start_vaddr=0;
    uint8_t* buf_ptr = (uint8_t *) buf;
    
    virt_to_phys_user(&buf_phy_addr, getpid(), (uintptr_t) buf);
    conti_mem_start_paddr = buf_phy_addr;
    for(uint64_t i = 0; i < buf_sz; i++) {
    	virt_to_phys_user(&buf_phy_addr, getpid(), (uintptr_t ) &(buf_ptr[i]));
    	if ((conti_mem_start_paddr + conti_mem_size) != buf_phy_addr) {
    	    if (conti_mem_size > max_conti_mem_size) {
    	        max_conti_mem_size = conti_mem_size;
    	        max_conti_mem_start_paddr = conti_mem_start_paddr;
    	        max_conti_mem_start_vaddr = (uintptr_t) (buf + i - conti_mem_size);
    	        printf("Max Physically Continuous Memory: size=%ld paddr=%lx\n", max_conti_mem_size, max_conti_mem_start_paddr);
                if (max_conti_mem_size >= target_sz) break;
    	    }
    	    conti_mem_size = 0;
    	    conti_mem_start_paddr = buf_phy_addr;
    	}
    	conti_mem_size++;
    }
    *vaddr = max_conti_mem_start_vaddr;
    *paddr = max_conti_mem_start_paddr;
    return max_conti_mem_size;
}


#define  DMA_MAX_SIZE           0x10000000UL
#define  XDMA_CLK_FREQ          250000000
#define  AXIS_FRAME_SIZE        64
#define  DESC_ADDR_REG_ADDR      0
#define  PKT_BEAT_NUM_REG_ADDR   8
#define  PKT_NUM_REG_ADDR       12
#define  START_REG_ADDR         16
#define  H2C_CYCLE_COUNT_ADDR   20
#define  C2H_CYCLE_COUNT_ADDR   24
#define  AXIL_ADDR_BOUND        64

int main (int argc, char *argv[]) {
    int   ret = -1;

    uint64_t millisecond;
    int   config_fd = -1;
    char *user_dev_name = "/dev/xdma0_user";
    void *local_buf = NULL;
    void *user_map = NULL;
    
    if (argc != 4) {
        printf("*** ERROR: invalid number of arguments\n");
        printf("Usage: %s <beat_num> <pkt_num> <monitor_mode>\n", argv[0]);
        printf("  beat_num     : number of AXIS beats(512-bit) in a packet\n");
        printf("  pkt_num      : number of packets to send\n");
        printf("  monitor_mode : 0=H2C, 1=C2H, 2=H2C+Loopback, 3=C2H+Loopback\n");
        goto close_and_clear;
    }

    uint64_t beat_num = getopt_integer(argv[1]);
    uint64_t pkt_size = beat_num * AXIS_FRAME_SIZE;
    uint64_t pkt_num = getopt_integer(argv[2]);
    uint64_t monitor_mode = getopt_integer(argv[3]); // 0: H2C, 1:C2H, 2: H2C+Loopback, 3: C2H+Loopback
    
    // allocate and lock local memory
    uint64_t alloc_size = 80 * 1024 * 1024;
    local_buf = malloc(alloc_size);
    mlock(local_buf, alloc_size);
    if (local_buf == NULL) {
        printf("*** ERROR: failed to allocate memory buffer\n");
        goto close_and_clear;
    }
    // init memory
    for (uint64_t i = 0; i < alloc_size; i++) {
        ((uint8_t *) local_buf)[i] = 0;
    }
    
    // find max physically continuous memory
    uint64_t offset = 70*1024 *1024;
    uintptr_t conti_mem_start_paddr, conti_mem_start_vaddr;
    uint64_t conti_mem_size = find_max_phy_conti_mem(&conti_mem_start_paddr, &conti_mem_start_vaddr, local_buf+offset, alloc_size-offset, pkt_num*pkt_size);
    printf("DMA Start Address = %lx\n", conti_mem_start_paddr);
    if (conti_mem_size < pkt_num * pkt_size) {
        printf("*** ERROR: failed to allocate pyhsically continuous memory\n");
        goto close_and_clear;
    }
    
    // write target memory
    uint8_t * buf_ptr = (uint8_t *) conti_mem_start_vaddr;
    for (int i = 0; i < pkt_num * pkt_size; i++) {
        if (i % AXIS_FRAME_SIZE == 0) {
            buf_ptr[i] = (i / AXIS_FRAME_SIZE) % beat_num;
        }
    }

    // open target device
    printf("** Open Config Device: %s\n", user_dev_name);
    config_fd = open(user_dev_name, O_RDWR);
    if (config_fd < 0) {
        printf("** ERROR: failed to open config device\n");
        goto close_and_clear;
    }
    
    // mmap
    user_map = mmap(NULL, AXIL_ADDR_BOUND, PROT_READ|PROT_WRITE, MAP_SHARED, config_fd, 0);
    if (user_map == (void *) -1) {
        printf("*** ERROR: target device mmap failed\n");
        goto close_and_clear;
    }
    
    // config and start monitor
    printf("** Start Configuration\n");
    millisecond = get_millisecond(); // get start time
    
    void* temp_map = user_map + DESC_ADDR_REG_ADDR;
    *((uint32_t *) temp_map) = conti_mem_start_paddr;
    temp_map += 4;
    *((uint32_t *) temp_map) = conti_mem_start_paddr >> 32;
    temp_map = user_map + PKT_BEAT_NUM_REG_ADDR;
    *((uint32_t *) temp_map) = beat_num;
    temp_map = user_map + PKT_NUM_REG_ADDR;
    *((uint32_t *) temp_map) = pkt_num;
    temp_map = user_map + START_REG_ADDR;
    *((uint32_t *) temp_map) = monitor_mode | (1 << 2); // Enable Addr Incr
    
    millisecond = get_millisecond() - millisecond; // get duration of DMA operation
    millisecond = (millisecond > 0) ? millisecond : 1;
    printf("** Complete Configuration %ld in %lu ms\n", monitor_mode | (1 << 2), millisecond);
    
    
    // wait for monitor to complete
    printf("** Wait for Monitor to Complete\n Enter any character to finish waiting\n");
    while (getchar() == -1){
        sleep(1);
    }
    
    // calculate bandwidth 
    char* mode_str = "H2C";
    temp_map = user_map + H2C_CYCLE_COUNT_ADDR;
    if (monitor_mode & 1) {
    	mode_str = "C2H";
    	temp_map = user_map + C2H_CYCLE_COUNT_ADDR;
    }
    uint32_t total_cycle = *((uint32_t *) temp_map);
    double bandwidth = ((pkt_size * pkt_num) * XDMA_CLK_FREQ);
    bandwidth = bandwidth/total_cycle;
    double bandwidth_10 = bandwidth/pow(10, 9);
    double bandwidth_2 = bandwidth/pow(2,30);
    
    // munmap
    if (munmap(user_map, AXIL_ADDR_BOUND) == -1) {
        printf("*** ERROR: Target device munmap failed\n");
        goto close_and_clear;
    }
    
    printf("** Performance Test Completed\n");
    printf("** Test Config: PKT Size=%ld bytes PKT Num=%ld Mode=%s\n", pkt_size, pkt_num, mode_str);
    printf("** Results: Cycle Number = %d Bandwidth = %f Gb/s/ %f Gb/s\n", total_cycle, bandwidth_2*8, bandwidth_10*8);
    
    ret = 0;
close_and_clear:
    if (local_buf != NULL) free(local_buf);
    if (config_fd >= 0)    close(config_fd);
    return ret;
}



