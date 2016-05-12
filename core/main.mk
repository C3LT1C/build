BUILD_SYSTEM := $(TOPDIR)build/core
include $(BUILD_SYSTEM)/definitions.mk
include $(BUILD_SYSTEM)/dumpvar.mk
include $(BUILD_SYSTEM)/envsetup.mk

ARCH := $(shell find $(ANDROID_BUILD_TOP)/$(PRODUCT_KERNEL_SOURCE) -name $(PRODUCT_DEFCONFIG) | sed 's\'$(ANDROID_BUILD_TOP)/$(PRODUCT_KERNEL_SOURCE)'\\' | sed 's\arch*.\\' | sed 's\configs.*\\' | sed -r 's\[/]\\g' )

ifeq ($(TARGET_ZIMAGE),)
ifeq (arm64,$(ARCH))
  TARGET_ZIMAGE := Image
endif
ifeq (arm,$(ARCH))
  TARGET_ZIMAGE := zImage
endif
endif

.PHONY: kernel
kernel:
	$(info =-=-=-= Starting build =-=-=-=)
	$(info Target Arch: $(ARCH))
	$(info Target Source: $(PRODUCT_KERNEL_SOURCE))
	$(info Target Toolchain: $(CROSS_COMPILE))
	$(if $(TARGET_REQUIRES_DTB), $(clear-dtb) $(info Building requires DTB: True),)
	$(info =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=)
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PRODUCT_DEFCONFIG) > /dev/null
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) $(if $(EXTRAVERSION), EXTRAVERSION=$(EXTRAVERSION)) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)
	$(cp-zimage)
	@echo "\033[32m Copied $(PRODUCT_KERNEL_SOURCE)/arch/$(ARCH)/boot/$(TARGET_ZIMAGE) to $(OUT_DIR)/$(BLACK_PRODUCT) \033[0m"

.PHONY: kernelclean
kernelclean:
	@echo "\033[32m Cleaning source \033[0m"
	make -C $(PRODUCT_KERNEL_SOURCE) mrproper > /dev/null
	@echo "Clearing device repacking dir: $(OUT_DIR)/$(BLACK_PRODUCT)"
	$(shell rm -rf $(OUT_DIR)/$(BLACK_PRODUCT)/*)

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
	@echo "\033[32m $(OUT_DIR)/$(BLACK_PRODUCT)/$(TARGET_ZIMAGE) built successful\033[0m"
else
	$(hide) md5sum ./Zip-Files/$(BLACK_PRODUCT)/$(PACKAGE_TARGET_NAME) | sed 's\./Zip-Files/$(BLACK_PRODUCT)/\\' > ./Zip-Files/$(BLACK_PRODUCT)/$(PACKAGE_TARGET_NAME).md5
	@echo
	@echo "\033[32m ./Zip-Files/$(BLACK_PRODUCT)/$(PACKAGE_TARGET_NAME) built successful\033[0m"
	@echo "md5: `cat ./Zip-Files/$(BLACK_PRODUCT)/$(PACKAGE_TARGET_NAME).md5 | cut -d ' ' -f 1`"
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

.PHONY: black
black:	$(build_type_args)
