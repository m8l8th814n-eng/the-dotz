CC      := gcc
CFLAGS  := -O2 -Wall -Wextra $(shell pkg-config --cflags libpulse-simple)
LDFLAGS := $(shell pkg-config --libs libpulse-simple) -lm

TARGET  := visualnumber
SRC     := visualnumber.c

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

.PHONY: clean run
clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)
