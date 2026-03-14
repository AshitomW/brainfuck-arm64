AS = as
LD = ld
SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
MACOS_SDK_VERSION := $(shell xcrun --sdk macosx --show-sdk-version)

ASFLAGS = -arch arm64
LDFLAGS = -arch arm64 \
          -platform_version macos $(MACOS_SDK_VERSION) $(MACOS_SDK_VERSION) \
          -L $(SDK_PATH)/usr/lib \
          -lSystem \
          -syslibroot $(SDK_PATH)

SRC_DIR = src
BUILD_DIR = build
TARGET = bf

.PHONY: all clean test

all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/bf.o: $(SRC_DIR)/bf.s
	$(AS) $(ASFLAGS) -o $@ $<

$(TARGET): $(BUILD_DIR)/bf.o
	$(LD) $(LDFLAGS) -o $@ $<



clean:
	rm -rf $(BUILD_DIR) $(TARGET)

install: $(TARGET)
	cp $(TARGET) /usr/local/bin/

uninstall: 
	rm -f /usr/local/bin/$(TARGET)


test: $(TARGET)
	@echo "=== Test 1: Hello World ==="
	@./$(TARGET) examples/hello.bf
	@echo "=== All tests passed ==="
