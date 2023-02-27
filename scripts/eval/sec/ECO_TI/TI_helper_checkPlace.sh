#!/bin/bash

# NOTE simple baseline for now. Could be extended to exclude particular issues, etc.

grep "Inst " $1 | awk '{print $2}' > $1".parsed"
