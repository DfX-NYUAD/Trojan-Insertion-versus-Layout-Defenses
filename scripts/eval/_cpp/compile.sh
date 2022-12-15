#!/bin/bash

options="-std=c++11 -O3 -march=native"

g++ $options exploitable_regions.cpp -o ../exploitable_regions.bin
