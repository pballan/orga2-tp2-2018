# ************************************************************************* #
# Organización del Computador II — TP2 ARM NEON                             #
#                                                                           #
#   Makefile para filtros NEON (reemplazo de x86 ASM)                       #
#                                                                           #
# ************************************************************************* #

CC ?= gcc
CFLAGS = -ggdb -Wall -Wno-unused-parameter -Wextra -std=c99 -pedantic -march=armv8-a+simd
# Para release:
# CFLAGS = -O3 -Wall -std=c99 -pedantic -march=armv8-a+simd

BUILD_DIR = ../build

FILTROS = edgeSobel tresColores cambiaColor efectoBayer

# Cada filtro tiene: wrapper (.o), C ref (_c.o), NEON impl (_neon.o)
FILTROS_OBJ = $(addsuffix .o, $(FILTROS)) $(addsuffix _neon.o, $(FILTROS)) $(addsuffix _c.o, $(FILTROS))
FILTROS_OBJ_CON_PATH = $(addprefix $(BUILD_DIR)/, $(FILTROS_OBJ))

.PHONY: filtros clean

filtros: $(FILTROS_OBJ_CON_PATH)

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(FILTROS_OBJ_CON_PATH)
