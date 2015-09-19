.PHONY: nothing
nothing:
	@echo "\033[32m Starting build \033[0m"

BUILD_SYSTEM := $(TOPDIR)build/core

include $(BUILD_SYSTEM)/envsetup.mk

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
