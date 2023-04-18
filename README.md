# ISPD23-Contest-Backend
Backend scripts for ISPD'23 Contest.

This repository includes the main daemon, which serves for
  1) file download and uploads via gdrive,
  2) initiating of various Innovus evaluation scripts,
  3) parsing of results and scoring,
  4) data management at server backend.
  
This repository also includes all Innovus scripts. This repository does not contain the benchmarks; see https://wp.nyu.edu/ispd23_contest/ for that.

Few notes to consider:
- Ignore the git submodules 1) ASAP7, 2) scripts/CUHK, and 3) ISPD22; they are only kept in here for simplicity of git repo management in our own git backend.
- The git submodule gdrive is needed.
  - However, the commit/ref in here is not available publicly, as that commit contains the GDrive credentials used in the contest.
  - What you want to do is to checkout the module on your own, ideally using the following commit which was working fine in our backend: https://github.com/carstentrink/gdrive/tree/d00c48ade4183c9fa08eae8336d2e91fab57adc0
  - Then, you want to put your own credentials in here: https://github.com/carstentrink/gdrive/blob/d00c48ade4183c9fa08eae8336d2e91fab57adc0/handlers_drive.go#L16
  - Then, compile and put/link the binary into scripts/gdrive/gdrive
- The git history has been rewritten, to remove all benchmark files, the gdrive binary, and some other files.
- IMPORTANT NOTE TO MYSELF: when updating this branch for any changes in the scripts, DO NOT use `git merge` (as that would bring back the re-rewritten history from our own git backend along with all the benchmark files) but rather use `git cherry-pick` for commits working on script files.
