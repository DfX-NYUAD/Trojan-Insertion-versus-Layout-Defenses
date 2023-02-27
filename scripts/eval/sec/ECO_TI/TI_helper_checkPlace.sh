#!/bin/bash

# NOTE we want to explicitly ignore issues for vertical pin alignment -- these arise from different innovus version's handling of tracks, more specifically from using Innovus 21 in
# the backend versus use of an older version by the participants. See also https://github.com/Centre-for-Hardware-Security/asap7_reference_design/blob/main/scripts/innovus.tcl for
# lines marked 'this series of commands makes innovus 21 happy :)' but note that we _cannot_ use these commands here in the backend when loading up the design for evaluation, as
# that would purge placement and routing altogether
#
# NOTE the .* to match any number of chars between for the wildcard
grep "Inst " $1 | grep -v "vertical pin .* is not aligned with correct track" | awk '{print $2}' > $1".parsed"
