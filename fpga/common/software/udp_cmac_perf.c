
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <getopt.h>
#include <string.h>

#include <sys/time.h>

// function : dev_read
// description : read data from device to local memory (buffer), (i.e. device-to-host)
// parameter :
//       dev_fd : device instance
//       addr   : source address in the device
//       buffer : buffer base pointer
//       size   : data size
// return:
//       int : 0=success,  -1=failed
int dev_read (int dev_fd, uint64_t addr, void *buffer, uint64_t size) {
    if (addr) {
        if ( addr != lseek(dev_fd, addr, SEEK_SET) )                             // seek
            return -1;                                                           // seek failed
    }
    if ( size != read(dev_fd, buffer, size) )                                    // read device to buffer
        return -1;                                                               // read failed
    return 0;
}

// function : dev_write
// description : write data from local memory (buffer) to device, (i.e. host-to-device)
// parameter :
//       dev_fd : device instance
//       addr   : target address in the device
//       buffer : buffer base pointer
//       size   : data size
// return:
//       int : 0=success,  -1=failed
int dev_write (int dev_fd, uint64_t addr, void *buffer, uint64_t size) {
    if (addr) {
        if ( addr != lseek(dev_fd, addr, SEEK_SET) )                             // seek
            return -1;                                                           // seek failed        
    }

    if ( size != write(dev_fd, buffer, size) )                                   // write device from buffer
        return -1;                                                               // write failed
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


#define  DMA_MAX_SIZE   0x10000000UL
#define  TRANS_SIZE     64



int main (int argc, char *argv[]) {
    int   ret = -1;

    uint64_t address = 0;
    uint64_t millisecond;
    char *dev_name = "/dev/xdma0_h2c_0";

    void *buffer = NULL;
    int   dev_fd = -1;
    
    // Parse Parameters
    uint64_t frame_num = getopt_integer(argv[1]);
    uint64_t interval = getopt_integer(argv[2]);
    uint64_t duration = getopt_integer(argv[3]);
    printf("** Monitor Configuration:\n");
    printf("   Packet Size: %lu * 512-bit AXIS frames\n", frame_num);
    printf("   Interval   : %lu cycles\n", interval);
    printf("   Duration   : %lu cycles\n", duration);

    // allocate local memory (buffer)
    buffer = malloc(TRANS_SIZE);
    if (buffer == NULL) {
        printf("*** ERROR: failed to allocate memory buffer\n");
        goto close_and_clear;
    }
    uint64_t *buffer_ptr = (uint64_t *) buffer;
    buffer_ptr[0] = (frame_num | (interval << 32));
    buffer_ptr[1] = duration;

    // open target device
    dev_fd = open(dev_name, O_RDWR);
    if (dev_fd < 0) {
        printf("** ERROR: failed to open device %s\n", dev_name);
        goto close_and_clear;
    }

    printf("** Start Configuration\n");
    printf("** Device Name: %s\n", dev_name);

    millisecond = get_millisecond(); // get start time of DMA operation
    if (dev_write(dev_fd, address, buffer, TRANS_SIZE)) {
        printf("** ERROR: failed to configure performance monitor");
        goto close_and_clear;
    }            

    millisecond = get_millisecond() - millisecond; // get duration of DMA operation
    millisecond = (millisecond > 0) ? millisecond : 1;
    printf("** Complete Configuration in %lu ms\n", millisecond);
    ret = 0;

close_and_clear:
    if (buffer != NULL) free(buffer);
    if (dev_fd >= 0)    close(dev_fd);
    return ret;
}



