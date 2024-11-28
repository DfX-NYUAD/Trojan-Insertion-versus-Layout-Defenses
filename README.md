# Trojan Insertion versus Layout Defenses for Modern ICs: Red-versus-Blue Teaming in a Competitive Community Effort

## Context
This repository relates to our contest and benchmarking efforts which were initially introduced as *Advanced Security Closure of Physical Layouts* at https://wp.nyu.edu/ispd23_contest/.

The latest TCHES publication with all details can be found at https://eprint.iacr.org/2024/1440.

## Content
This repository includes the benchmarking framework, which covers
  1) data management;
  2) design and security evaluation, including HT insertion; and
  3) parsing of results and scoring.
  
This repository does neither contain the benchmarks, the HTs, the technology setup, nor the reference flow for physical design; see
https://drive.google.com/drive/folders/10GJ5hX0BQupwqv1WMtitarsEuEE_Y-vV?usp=sharing and https://github.com/Centre-for-Hardware-Security/asap7_reference_design for all these parts.

The `main` branch of this repository contains a revised standalone version of the framework, which is tailored to be run locally. The branch `gh_backend` contains the full framework,
including the web interface's backend used during the contest itself; consider this branch as FYI only.