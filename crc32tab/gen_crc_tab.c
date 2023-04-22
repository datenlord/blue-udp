#include <stdio.h>

int main(int argc, char** argv)
{
    const unsigned int polynomial = 0x04C11DB7; /* divisor is 32bit */
    unsigned int crc = 0x0; 
    unsigned char b;

	FILE *fp;
	char fname[64];
	char sline[64];
	int max_byte_offset = 36;
    unsigned int crc_tab[36][256];
	// init all tables first 
    for (int i = 0; i < max_byte_offset; i++) {
		printf("Generate 8-bit standard CRC-32 table with %d bytes offset\n", i);
		sprintf(fname, "crc32_tab_%d.txt", i);
		fp = fopen(fname, "w");

        for (int j = 0; j < 256; j++){
			b = j; 
			crc = 0;
            crc ^= (unsigned int)(b << 24);  //move byte into MSB of 32bit CRC 
            for (int k = 0; k < 8; k++) {
                if ((crc & 0x80000000) != 0){  //test for MSB = bit 31
                    crc = (unsigned int)((crc << 1) ^ polynomial);
                } else {
                	crc <<= 1;
                }
            }
			// evolve it now
            for (int k=0; k<i; k++) {
				b = 0;
                crc ^= (unsigned int)(b << 24);  //move byte into MSB of 32bit CRC 
                for (int p = 0; p < 8; p++) {
                    if ((crc & 0x80000000) != 0){  //test for MSB = bit 31 
                        crc = (unsigned int)((crc << 1) ^ polynomial);
                    } else {
                        crc <<= 1;
                    }
                }
            }

			fprintf(fp, "%08x\n", crc);
            crc_tab[i][j] = crc;
		}
		
		fclose(fp);
		printf("8-bit Lookup table for standard crc-32 with %d bytes offset is generated\n", i);
	}
    printf("%x\n", crc_tab[31][255]^crc_tab[30][255]^crc_tab[29][255]^crc_tab[28][255]);
	return 0;
}