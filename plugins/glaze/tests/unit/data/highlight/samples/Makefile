# Build rules
CC ?= cc
CFLAGS := -O2 -Wall
SRC = $(wildcard src/*.c)
OBJ = $(SRC:.c=.o)

.PHONY: all clean

all: app

app: $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	$(RM) $(OBJ) app
