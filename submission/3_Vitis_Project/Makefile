# Makefile for Zynq-7000 Standalone Baremetal FFT DMA Application
# Target: ARM Cortex-A9 (Xilinx arm-none-eabi-gcc)

CC = arm-none-eabi-gcc
CFLAGS = -Wall -O2 -c -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard
LDFLAGS = -Wl,-T -Wl,src/lscript.ld -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard

OBJS = src/main.o src/xaxidma_fft.o
TARGET = fft_dma_app.elf

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	@echo "Build successful: $(TARGET)"

%.o: %.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f src/*.o $(TARGET)
