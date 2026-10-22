CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
LDFLAGS ?= -static
INC     := -I../exploit/common

SRCS    := bench_netlink.c ../exploit/common/namespace_setup.c ../exploit/common/netlink_helpers.c
BIN     := bench_netlink

all: $(BIN)

$(BIN): $(SRCS)
	$(CC) $(CFLAGS) $(INC) $(LDFLAGS) -o $@ $(SRCS)

clean:
	rm -f $(BIN)

.PHONY: all clean
