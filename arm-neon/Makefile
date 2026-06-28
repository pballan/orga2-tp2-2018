# ************************************************************************* #
# Organización del Computador II — TP2 ARM NEON                             #
#                                                                           #
#   Makefile para compilación en ARM AArch64 con filtros NEON               #
#                                                                           #
#   Uso nativo (en ARM):                                                    #
#     make                                                                  #
#                                                                           #
#   Uso cross-compilation (desde x86):                                      #
#     make CC=aarch64-linux-gnu-gcc                                         #
#                                                                           #
# ************************************************************************* #

CC ?= gcc
CFLAGS = -ggdb -Wall -Wno-unused-parameter -Wextra -std=c99 -pedantic -march=armv8-a+simd -D_POSIX_C_SOURCE=199309L
# Para release:
# CFLAGS = -O3 -Wall -std=c99 -pedantic -march=armv8-a+simd

BUILD_DIR = build
BIN = tp2

FILTROS = edgeSobel tresColores cambiaColor efectoBayer

FILTROS_OBJ = $(addsuffix .o, $(FILTROS)) $(addsuffix _neon.o, $(FILTROS)) $(addsuffix _c.o, $(FILTROS))
LIBS_OBJS   = libbmp.o imagenes.o utils.o
MAIN_OBJS   = tp2.o cli.o
MAIN_OBJS_CON_PATH = $(addprefix $(BUILD_DIR)/, $(MAIN_OBJS))

OBJS = $(MAIN_OBJS) $(LIBS_OBJS) $(FILTROS_OBJ)
OBJS_CON_PATH = $(addprefix $(BUILD_DIR)/, $(OBJS))

.PHONY: all clean FORCE

all: $(BUILD_DIR)/$(BIN)

$(BUILD_DIR)/$(BIN): FORCE $(MAIN_OBJS_CON_PATH)
	$(CC) $(CFLAGS) $(OBJS_CON_PATH) -o $@ -lm

export CFLAGS
FORCE:
	make -C helper
	make -C filters

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $< -lm

clean:
	rm -fr $(BUILD_DIR)/*

test: all
	@echo "Testing tresColores..."
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i c -o img tresColores img/colores32.bmp > /dev/null
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i asm -o img tresColores img/colores32.bmp > /dev/null
	@cmp img/colores32.bmp.tresColores.C.bmp img/colores32.bmp.tresColores.ASM.bmp && echo "tresColores OK" || echo "tresColores FAILED"
	@echo "Testing efectoBayer..."
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i c -o img efectoBayer img/colores32.bmp > /dev/null
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i asm -o img efectoBayer img/colores32.bmp > /dev/null
	@cmp img/colores32.bmp.efectoBayer.C.bmp img/colores32.bmp.efectoBayer.ASM.bmp && echo "efectoBayer OK" || echo "efectoBayer FAILED"
	@echo "Testing edgeSobel..."
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i c -o img edgeSobel img/colores32.bmp > /dev/null
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i asm -o img edgeSobel img/colores32.bmp > /dev/null
	@cmp img/colores32.bmp.edgeSobel.C.bmp img/colores32.bmp.edgeSobel.ASM.bmp && echo "edgeSobel OK" || echo "edgeSobel FAILED"
	@echo "Testing cambiaColor..."
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i c -o img cambiaColor img/colores32.bmp 0 0 0 255 255 255 100 > /dev/null
	@qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./build/$(BIN) -i asm -o img cambiaColor img/colores32.bmp 0 0 0 255 255 255 100 > /dev/null
	@cmp img/colores32.bmp.cambiaColor.C.bmp img/colores32.bmp.cambiaColor.ASM.bmp && echo "cambiaColor OK" || echo "cambiaColor FAILED"
