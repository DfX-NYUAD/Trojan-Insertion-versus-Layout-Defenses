#!/bin/bash

## NOTE deprecated; while this is needed to catches and correctly parses the instance names for issues like 'Inst a10_S4_0_S_0/g20958's vertical pin AO32x1_ASAP7_75t_SL/Y is not
## aligned with correct track', these issues should actually not be addressed/fixed for the teams' submissions but rather ignored
#grep "Inst " $1 | awk '{print $2}' | sed "s/'s//g" > $1".parsed"

grep "Inst " $1 | grep -v "is not aligned with correct track" | awk '{print $2}' > $1".parsed"
