# Finding $SNAP_ROOT
ifndef SNAP_ROOT
# check if we are in hw folder of an action (three directories below snap root)
ifneq ("$(wildcard ../../../../../ActionTypes.md)","")
SNAP_ROOT=$(abspath ../../../../../)
else
$(info You are not building your software from the default directory (/path/to/snap/actions/<action_name>/sw) or specified a wrong $$SNAP_ROOT.)
$(error Please make sure that $$SNAP_ROOT is set up correctly.)
endif
endif

SOLUTION_NAME ?= hls_filter_sln
SOLUTION_DIR ?= hls_filter_sln

srcs += hls_filter.cpp

WRAPPER ?= hls_filter

# If you have the action code outside of the default snap directory structure, 
# change to /path/to/snap/actions/hls.mk
include $(SNAP_ROOT)/actions/hls.mk
