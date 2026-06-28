# ************************************************************************* #
# Organización del Computador II — TP2 ARM NEON                             #
#                                                                           #
#   Makefile para helpers                                                   #
#                                                                           #
# ************************************************************************* #

CC ?= gcc
CFLAGS ?= -ggdb -Wall -Wno-unused-parameter -Wextra -std=c99 -pedantic -march=armv8-a+simd

BUILD_DIR = ../build

LIBS_OBJS = libbmp.o imagenes.o utils.o
LIBS_OBJS_CON_PATH = $(addprefix $(BUILD_DIR)/, $(LIBS_OBJS))

.PHONY: helpers clean

helpers: $(LIBS_OBJS_CON_PATH)

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(LIBS_OBJS_CON_PATH)
