#!/bin/bash
############################################################################
############################################################################
##
## Copyright 2017 International Business Machines
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE#2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions AND
## limitations under the License.
##
############################################################################
############################################################################

# if [ "$DDRI_USED" == "TRUE" ]; then
#   DDRI_FILTER="\-\- only for DDRI_USED!=TRUE"
# else
#   DDRI_FILTER="\-\- only for DDRI_USED=TRUE"
# fi

# if [ "$NVME_USED" == "TRUE" ]; then
#   NVME_FILTER="\-\- only for NVME_USED!=TRUE"
# else
#   NVME_FILTER="\-\- only for NVME_USED=TRUE"
# fi

for vhdtpl in *.vhd.mustache; do
  vhdfile=$(echo $vhdtpl | sed 's/vhd\.mustache$/vhd/')
  echo -e "\t                        generating $vhdfile"
  mustache config.yml $vhdtpl > $vhdfile
done

if [ ! -d $ACTION_ROOT/ip/action_ip_dir ]; then
	echo "                        Call create_action_ip.tcl to generate IPs"
	vivado -mode batch -source $ACTION_ROOT/ip/create_action_ip.tcl -notrace -nojournal -tclargs $ACTION_ROOT $FPGACHIP
fi
