BUILD_SYSTEM := $(TOPDIR)build/core

include $(BUILD_SYSTEM)/definitions.mk
include $(BUILD_SYSTEM)/dumpvar.mk
include $(BUILD_SYSTEM)/envsetup.mk

.PHONY: kernel
kernel:
	@echo "\033[32m Starting build \033[0m"
	$(if $(TARGET_REQUIRES_DTB), $(clear-dtb))
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PRODUCT_DEFCONFIG) > /dev/null
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) $(if $(EXTRAVERSION), EXTRAVERSION=$(EXTRAVERSION)) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)
	$(cp-zimage)
	@echo "\033[32m Copied $(PRODUCT_KERNEL_SOURCE)/$(ZIMAGE) to $(OUT_DIR)/$(RENDER_PRODUCT) \033[0m"

.PHONY: kernelclean
kernelclean:
	@echo "\033[32m Cleaning source \033[0m"
	make -C $(PRODUCT_KERNEL_SOURCE) mrproper > /dev/null
	@echo "Clearing device repacking dir: $(OUT_DIR)/$(RENDER_PRODUCT)"
	$(shell rm -rf $(OUT_DIR)/$(RENDER_PRODUCT)/*)

.PHONY: kernelclobber
kernelclobber:
	$(clear-all-sources)
	$(shell rm -rf $(OUT_DIR)/*)
	@echo "\033[32m Full cleaning complete \033[0m"

.PHONY: buildzip
buildzip:
	$(mv-modules)
	$(if $(TARGET_REQUIRES_DTB), $(make_dtb))
	$(if $(ZIP_FILES_DIR), $(cp-zip-files))
	$(build-zip)

.PHONY: buildbootimg
buildbootimg:
		$(make_ramdisk)
		$(make_boot)
		$(if $(TARGET_REQUIRES_DTB), $(clear-dtb))
		$(clear_boot-ramdisk)

.PHONY: printcompletion
printcompletion:
ifeq ($(build_type),kernel)
	@echo
	@echo "=-=-=-= Complete =-=-=-="
	@echo "\033[32m $(OUT_DIR)/$(RENDER_PRODUCT)/zImage built successful\033[0m"
else
	$(hide) md5sum ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME) | sed 's\./Zip-Files/$(RENDER_PRODUCT)/\\' > ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME).md5
	@echo
	@echo "=-=-=-= Complete =-=-=-="
	@echo "\033[32m ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME) built successful\033[0m"
	@echo "md5: `cat ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME).md5 | cut -d ' ' -f 1`"
endif

build_type := $(filter kernel anykernel bootimg,$(TARGET_BUILD_VARIANT))

build_type_args := kernel
ifeq ($(build_type),bootimg)
build_type_args += $(build_type_args) buildbootimg buildzip printcompletion
endif
ifeq ($(build_type),anykernel)
build_type_args += $(build_type_args) buildzip printcompletion
endif
ifeq ($(build_type),kernel)
build_type_args += $(build_type_args) printcompletion
endif

.PHONY: render
render:	$(build_type_args)
