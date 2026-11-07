CC = gcc
CFLAGS = -O2 -Wall -Iinclude
LDFLAGS = -lm

SRCS = src/fft_float_ref.c src/twiddle_gen.c src/fft_r22sdf_fixed.c src/main.c
TARGET = fft_sim

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f $(TARGET) $(TARGET).exe *.o
