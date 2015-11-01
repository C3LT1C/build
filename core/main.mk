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
		$(clear_boot-ramdisk)

.PHONY: printcompletion
printcompletion:
	$(hide) md5sum ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME) | sed 's\./Zip-Files/$(RENDER_PRODUCT)/\\' > ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME).md5
	@echo
	@echo "=-=-=-= Complete =-=-=-="
	@echo "\033[32m ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME) built successful\033[0m"
	@echo "md5: `cat ./Zip-Files/$(RENDER_PRODUCT)/$(PACKAGE_TARGET_NAME).md5 | cut -d ' ' -f 1`"

build_type := $(filter kernel anykernel bootimg,$(TARGET_BUILD_VARIANT))
ifeq ($(build_type),anykernel)
.PHONY: render
render:	kernel buildzip printcompletion
endif
ifeq ($(build_type),bootimg)
.PHONY: render
render:	kernel buildbootimg buildzip printcompletion
endif
ifeq ($(build_type),kernel)
.PHONY: render
render:	kernel
	@echo
	@echo "=-=-=-= Complete =-=-=-="
	@echo "\033[32m $(OUT_DIR)/$(RENDER_PRODUCT)/zImage built successful\033[0m"
endif

BUILD_SYSTEM := $(TOPDIR)build/core

ifneq ($(dont_bother),true)
subdir_makefiles := \
		$(shell build/tools/findleaves.py --prune=.repo --prune=.git $(PWD) Android.mk)
$(foreach mk, $(subdir_makefiles), $(eval include $(mk)))
endif

# Figure out where we are.
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUT_DIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef

include $(BUILD_SYSTEM)/definitions.mk
include $(BUILD_SYSTEM)/dumpvar.mk
include $(BUILD_SYSTEM)/envsetup.mk

# ---------------------------------------------------------------
# figure out the output directories

ifeq (,$(strip $(OUT_DIR)))
ifeq (,$(strip $(OUT_DIR_COMMON_BASE)))
ifneq ($(TOPDIR),)
OUT_DIR := $(TOPDIR)out
else
OUT_DIR := $(CURDIR)/out
endif
else
OUT_DIR := $(OUT_DIR_COMMON_BASE)/$(notdir $(PWD))
endif
endif

ifeq ($(ARCH),arm64)
ifeq ($(build_type),bootimg)
	TARGET_ZIMAGE := Image.gz
else
	TARGET_ZIMAGE := Image
endif
else
	TARGET_ZIMAGE := zImage
endif

 ZIMAGE := arch/$(ARCH)/boot/$(TARGET_ZIMAGE)
