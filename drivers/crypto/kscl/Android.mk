###
### kscl.ko
###
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE       := kscl.ko
LOCAL_MODULE_CLASS := DLKM
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_PATH  := $(TARGET_OUT)/lib/modules
KSCL_BUILD_DIR     := $(OUT)/kscl
KSCL_LOCAL_DIR     := $(LOCAL_PATH)

include $(BUILD_SYSTEM)/base_rules.mk

ANDROID_N_OR_LATER := $(shell if [ "$(PLATFORM_SDK_VERSION)" -ge "24" ] ; then echo "true"; fi)

ifeq ($(ANDROID_N_OR_LATER),true)
  ifeq ($(strip $(SOMC_PLATFORM)),tone)
    TARGET_KERNEL_SOURCE := kernel/msm-3.18
  else ifeq ($(strip $(SOMC_PLATFORM)),yoshino)
    TARGET_KERNEL_SOURCE := kernel/msm-4.4
  else
    TARGET_KERNEL_SOURCE := kernel
  endif
else
  TARGET_KERNEL_SOURCE := kernel
endif

# Simply copy the kernel module from where the kernel build system
# created it to the location where the Android build system expects it.
# If LOCAL_MODULE_DEBUG_ENABLE is set, strip debug symbols. So that,
# the final images generated by ABS will have the stripped version of
# the modules
ifeq ($(findstring msm-4.4,$(TARGET_KERNEL_SOURCE)),msm-4.4)
  MODULE_SIGN_FILE := $(OUT)/obj/KERNEL_OBJ/scripts/sign-file
  MODSECKEY := $(OUT)/obj/KERNEL_OBJ/certs/signing_key.pem
  MODPUBKEY := $(OUT)/obj/KERNEL_OBJ/certs/signing_key.x509
else
  MODULE_SIGN_FILE := perl $(TOP_DIR)./$(TARGET_KERNEL_SOURCE)/scripts/sign-file
  MODSECKEY := $(OUT)/obj/KERNEL_OBJ/signing_key.priv
  MODPUBKEY := $(OUT)/obj/KERNEL_OBJ/signing_key.x509
endif

$(LOCAL_BUILT_MODULE): $(KSCL_BUILD_DIR)/$(LOCAL_MODULE) | $(ACP)
	@sh -c "\
	   KMOD_SIG_ALL=`cat $(OUT)/obj/KERNEL_OBJ/.config | grep CONFIG_MODULE_SIG_ALL | cut -d'=' -f2`; \
	   KMOD_SIG_HASH=`cat $(OUT)/obj/KERNEL_OBJ/.config | grep CONFIG_MODULE_SIG_HASH | cut -d'=' -f2 | sed 's/\"//g'`; \
	   if [ \"\$$KMOD_SIG_ALL\" = \"y\" ] && [ -n \"\$$KMOD_SIG_HASH\" ]; then \
	      echo \"Signing kernel module: \" `basename $<`; \
	      cp $< $<.unsigned; \
	      $(MODULE_SIGN_FILE) \$$KMOD_SIG_HASH $(MODSECKEY) $(MODPUBKEY) $<; \
	   fi; \
	"
	$(transform-prebuilt-to-target)

# Workaround for build error of mm command.
# KERNEL_CROSS_COMPILE and KERNEL_ARCH are empty when execute mm command.
# So, copied Define from kernel/AndroidKernel.mk to use mm command.
#
# WARNING!!!
# Check KERNEL_CROSS_COMPILE, KERNEL_ARCH and KERNEL_FLAGS value when platform is updated.
# This two value may be different on other platform.
TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifeq ($(filter %64,$(TARGET_KERNEL_ARCH)),)
  KERNEL_CROSS_COMPILE := arm-eabi-
  KERNEL_ARCH := arm
  KERNEL_FLAGS :=
else
  KERNEL_CROSS_COMPILE := $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
  KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
  KERNEL_CFLAGS := KCFLAGS=-mno-android
endif

$(KSCL_BUILD_DIR)/$(LOCAL_MODULE): $(TARGET_PREBUILT_INT_KERNEL) $(KSCL_LOCAL_DIR)
	$(hide) mkdir -p $(KSCL_BUILD_DIR) && \
	cp -f $(KSCL_LOCAL_DIR)/Makefile $(KSCL_LOCAL_DIR)/*.c $(KSCL_LOCAL_DIR)/*.h $(KSCL_BUILD_DIR) && \
	make -s -C $(TARGET_KERNEL_SOURCE) O=$(OUT)/obj/KERNEL_OBJ M=$(KSCL_BUILD_DIR) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_CFLAGS) modules
