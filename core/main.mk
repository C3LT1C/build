.PHONY: kernel
kernel:
	@echo "\033[32m Starting build \033[0m"
	$(if $(TARGET_REQUIRES_DTB), $(clear-dtb))
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PRODUCT_DEFCONFIG) > /dev/null
	make -j$(CORE_COUNT) -C $(PRODUCT_KERNEL_SOURCE) KBUILD_BUILD_USER=$(KBUILD_BUILD_USER) KBUILD_BUILD_HOST=$(KBUILD_BUILD_HOST) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

.PHONY: kernelclean
kernelclean:
	@echo "\033[32m Cleaning source \033[0m"
	make -C $(PRODUCT_KERNEL_SOURCE) mrproper > /dev/null
	@echo "Clearing device OUT dir . . . $(OUT_DIR)/$(RENDER_PRODUCT)"
	$(shell rm -rf $(OUT_DIR)/$(RENDER_PRODUCT)/*)

.PHONY: kernelclobber
kernelclobber: kernelclean
	@echo "\033[32m Full cleaning \033[0m"
	$(shell rm -rf $(OUT_DIR)/*)

.PHONY: buildzip
buildzip:
	$(mv-modules)
	$(cp-zip-files)
	$(if $(TARGET_REQUIRES_DTB), $(make_dtb))
	$(build-zip)

.PHONY: render
render:	kernel buildzip

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
