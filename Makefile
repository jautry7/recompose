BUILD_DIR := ../Build
SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
CLANG := $(shell xcrun --find clang)
OBJC_FLAGS := -fobjc-arc -fblocks -isysroot $(SDK_PATH)

PROTOTYPE_TOOLS := \
	$(BUILD_DIR)/coreui-icon-extract \
	$(BUILD_DIR)/icon-recreate

RESEARCH_TOOLS := \
	$(BUILD_DIR)/coreui-probe \
	$(BUILD_DIR)/coreui-catalog-inspect \
	$(BUILD_DIR)/iconcomposer-runtime-probe \
	$(BUILD_DIR)/icon-schema-candidates \
	$(BUILD_DIR)/icon-schema-phase2 \
	$(BUILD_DIR)/icon-schema-phase3

.PHONY: all prototype research

all: prototype research

prototype: $(PROTOTYPE_TOOLS)

research: $(RESEARCH_TOOLS)

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/coreui-icon-extract: Sources/Prototype/coreui-icon-extract.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation -framework CoreGraphics -framework ImageIO $< -o $@

$(BUILD_DIR)/icon-recreate: Sources/Prototype/icon-recreate.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@

$(BUILD_DIR)/coreui-probe: Tools/Research/coreui-probe.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@

$(BUILD_DIR)/coreui-catalog-inspect: Tools/Research/coreui-catalog-inspect.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation -framework CoreGraphics $< -o $@

$(BUILD_DIR)/iconcomposer-runtime-probe: Tools/Research/iconcomposer-runtime-probe.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@

$(BUILD_DIR)/icon-schema-candidates: Tools/Research/icon-schema-candidates.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@

$(BUILD_DIR)/icon-schema-phase2: Tools/Research/icon-schema-phase2.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@

$(BUILD_DIR)/icon-schema-phase3: Tools/Research/icon-schema-phase3.m | $(BUILD_DIR)
	$(CLANG) $(OBJC_FLAGS) -framework Foundation $< -o $@
