BUILD_DIR := build
SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
CLANG := $(shell xcrun --find clang)
OBJC_FLAGS := -fobjc-arc -fblocks -isysroot $(SDK_PATH)

TOOLS := \
	$(BUILD_DIR)/coreui-icon-extract \
	$(BUILD_DIR)/icon-recreate

.PHONY: all

all: $(TOOLS)

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/coreui-icon-extract: src/coreui-icon-extract.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation -framework CoreGraphics -framework ImageIO $< -o $@

$(BUILD_DIR)/icon-recreate: src/icon-recreate.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@
