# Trojan Insertion versus Layout Defenses for Modern ICs: Red-versus-Blue Teaming in a Competitive Community Effort

## Context

This repository relates to our contest and benchmarking efforts for insertion of hardware Trojans (HTs) versus layout-level defenses.
The contest itself was initially introduced as *Advanced Security Closure of Physical Layouts* to the community; see https://wp.nyu.edu/ispd23_contest/ for more details.

The latest TCHES publication with all details can be found at https://tches.iacr.org/index.php/TCHES/article/view/11921.

If you find this framework and work in general useful for your research, please make sure to cite our papers:

```
@article{Trojan Insertion versus Layout Defenses for Modern ICs: Red-versus-Blue Teaming in a Competitive Community Effort_2024, volume={2025},  url={https://tches.iacr.org/index.php/TCHES/article/view/11921},  DOI={10.46586/tches.v2025.i1.37-77}, abstractNote={Hardware Trojans (HTs) are a longstanding threat to secure computation. Among different threat models, it is the fabrication-time insertion of additional malicious logic directly into the layout of integrated circuits (ICs) that constitutes the most versatile, yet challenging scenario, for both attackers and defenders.Here, we present a large-scale, first-of-its-kind community effort through red-versus-blue teaming that thoroughly explores this threat. Four independently competing blue teams of 23 IC designers in total had to analyze and fix vulnerabilities of representative IC layouts at the pre-silicon stage, whereas a red team of 3 experts in hardware security and IC design continuously pushed the boundaries of these defense efforts through different HTs and novel insertion techniques. Importantly, we find that, despite the blue teams’ commendable design efforts, even highly-optimized layouts retained at least some exploitable vulnerabilities.Our effort follows a real-world setting for a modern 7nm technology node and industrygrade tooling for IC design, all embedded into a fully-automated and extensible benchmarking framework. To ensure the relevance of this work, strict rules that adhere to real-world requirements for IC design and manufacturing were postulated by the organizers. For example, not a single violation for timing and design-rule checks were allowed for defense techniques. Besides, in an advancement over prior art, neither red nor blue teams were allowed to use any so-called fillers and spares for trivial attack or defense approaches.Finally, we release all methods and artifacts: the representative IC layouts and HTs, the devised attack and defense techniques, the evaluation metrics and setup, the technology setup and commercial-grade reference flow for IC design, the encompassing benchmarking framework, and all best results. This full release enables the community to continue exploring this important challenge for hardware security, in particular to focus on the urgent need for further advancements in defense strategies.}, number={1}, journal={IACR Transactions on Cryptographic Hardware and Embedded Systems}, year={2024}, month={Dec.}, pages={37--77} }

@inproceedings{10.1145/3569052.3578924,
author = {Eslami, Mohammad and Knechtel, Johann and Sinanoglu, Ozgur and Karri, Ramesh and Pagliarini, Samuel},
title = {Benchmarking Advanced Security Closure of Physical Layouts: {ISPD} 2023 Contest},
year = {2023},
doi = {10.1145/3569052.3578924},
abstract = {Computer-aided design (CAD) tools traditionally optimize "only'' for power, performance, and area (PPA). However, given the wide range of hardware-security threats that have emerged, future CAD flows must also incorporate techniques for designing secure and trustworthy integrated circuits (ICs). This is because threats that are not addressed during design time will inevitably be exploited in the field, where system vulnerabilities induced by ICs are almost impossible to fix. However, there is currently little experience for designing secure ICs within the CAD community.This contest seeks to actively engage with the community to close this gap. The theme is security closure of physical layouts, that is, hardening the physical layouts at design time against threats that are executed post-design time. Acting as security engineers, contest participants will proactively analyse and fix the vulnerabilities of benchmark layouts in a blue-team approach. Benchmarks and submissions are based on the generic DEF format and related files.This contest is focused on the threat of Trojans, with challenging aspects for physical design in general and for hindering Trojan insertion in particular. For one, layouts are based on the ASAP7 library and rules are strict, e.g., no DRC issues and no timing violations are allowed at all. In the alpha/qualifying round, submissions are evaluated using first-order metrics focused on exploitable placement and routing resources, whereas in the final round, submissions are thoroughly evaluated (red-teamed) through actual insertion of different Trojans.},
booktitle = {Proceedings of the 2023 International Symposium on Physical Design},
pages = {256--264},
keywords = {asap7, contest, hardware security, hardware trojans, physical design, security closure},
}
```

## Content

This repository includes the benchmarking framework, which covers
  1) data management;
  2) design and security evaluation, including insertion of HTs; and
  3) parsing of results and scoring.
  
This repository does *not* contain
(a) the benchmarks, the HTs, and the ASAP7 technology setup, nor
(b) the best results from the contest, nor
(c) the defense techniques, nor
(d) the reference flow for physical design.

For (a), (b), and (c), see https://drive.google.com/drive/folders/10GJ5hX0BQupwqv1WMtitarsEuEE_Y-vV?usp=sharing; for (d), see
https://github.com/Centre-for-Hardware-Security/asap7_reference_design. More details on which item/artifact to use how are described throughout this README.

Few non-essential notes on the branches in this repository -- feel free to skip ahead.
The `main` branch of this repository contains a revised standalone version of the framework, which is tailored to be run locally and up-to-date. That branch is the one you want.
Consider the branch `gh_backend` as FYI only.
That branch contains the full framework, including the backend's web interface used during the contest itself, although again in some tailored version meant to be run locally.
Not all latest edits are reflected in that branch.

## Requirements

You need commercially licensed tools for physical design from Cadence, namely Innovus and Conformal/LEC.

Regarding Innovus, we have tested the framework (as well as the reference flow for physical design) for different versions, namely
for 17.10, 18.10, 19.11, 20.11, 21.11, and 21.13. We found that results can vary across these versions. 
The version for the contest was 21.13-s100_1 -- if possible, use the very same or at least a similar version (21.x) for reproducibility of the published results.
Note that one evaluation command in particular (`report_route -include_regular_routes -track_utilization`) seems only supported from 21.13 onward, and *not* for 21.11, 21.12 etc.
Please also see [Configuration](#configuration) further below for that specific issue.

For Conformal/LEC, the official version for the contest was 22.10-s300. We have not tested other versions, but we would expect that results generated by this
tool are less sensitive, if at all, regarding different versions (as the related script and its underlying assessments are not complex at all).

To get the framework up and running, you need this repository as well as item (a) from [Content](#content); see also [Folder Setup](#folder-setup) for more related details on
handling of that item (a).
The items (b), (c), and (d) are optional (i.e., not needed for operation of the framework as such), but it is highly recommended to look at these items the moment you want to pursue
your on follow-up research for defenses. Note that (c) and (d) both come with their own dedicated README and instructions.

## Alternative Access

If you do not have access to the commercial tools listed in [Requirements](#requirements), you can also get access to the framework used during the contest itself. This access will
be in the same form as in the contest, i.e., you can upload your hardened layouts and receive back scores and HT-infested layouts.
(However, you will not be given access to the actual backend itself.)
See https://wp.nyu.edu/ispd23_contest/evaluation/#platform for more details and drop us an email at ispd23_contest@nyu.edu -- from a Google account --
so that we can provide you with access to your dedicated Google Drive as access point.

For that alternative option, you do *not* need to follow the [Setup and Operation](#setup-and-operation) but the instructions given at
https://wp.nyu.edu/ispd23_contest/evaluation/#platform.
	
Some non-essential remarks here.
For the reference flow and the defense techniques provided via the external link given in [Content](#content), these are also implemented using Cadence Innovus. Thus, you
would need to pull your own efforts if you want to transfer and extend those for open-source tools. However, there should be a good number of codes and tools online that support
ASAP7, the open-source technology library of choice for this effort.

## Setup and Operation

### Folder Setup

Within the same local root folder where you've cloned this repository into, you need to unzip the archives `benchmarks_HTs_ASAP7.zip` and `data_skeleton.zip` obtained from
https://drive.google.com/drive/folders/10GJ5hX0BQupwqv1WMtitarsEuEE_Y-vV?usp=sharing

Once done, the root folder structures should look like this (only partially shown here, namely till level 4):
```
	benchmarks
	└── _release
	    ├── README
	    ├── _AIC -> _final/
	    ├── _EXT -> _final/
	    ├── _ASAP7
	    │   ├── gds
	    │   ├── lef
	    │   ├── lib
	    │   ├── qrc
	    │   ├── README
	    │   └── techlef
	    └── _final
	        ├── aes
	        ├── camellia
	        ├── cast
	        ├── misty
	        ├── seed
	        └── sha256
	data
	├── AIC
	│   ├── CUEDA
	│   │   ├── aes
	│   │   ├── camellia
	│   │   ├── cast
	│   │   ├── misty
	│   │   ├── seed
	│   │   └── sha256
	│   ├── FDUEDA
	│   │   ├── aes
	│   │   ├── camellia
	│   │   ├── cast
	│   │   ├── misty
	│   │   ├── seed
	│   │   └── sha256
	│   └── NTHU-TCLAB
	│       ├── aes
	│       ├── camellia
	│       ├── cast
	│       ├── misty
	│       ├── seed
	│       └── sha256
	└── EXT
	    ├── CUEDA
	    │   ├── aes
	    │   ├── camellia
	    │   ├── cast
	    │   ├── misty
	    │   ├── seed
	    │   └── sha256
	    ├── FDUEDA
	    │   ├── aes
	    │   ├── camellia
	    │   ├── cast
	    │   ├── misty
	    │   ├── seed
	    │   └── sha256
	    └── NTHU-TCLAB
	        ├── aes
	        ├── camellia
	        ├── cast
	        ├── misty
	        ├── seed
	        └── sha256
	scripts
	├── eval
	│   ├── checks
	│   │   ├── check_pins.sh
	│   │   ├── check_rails_stylus.tcl
	│   │   ├── checks.tcl
	│   │   ├── check_stripes_area_stylus.tcl
	│   │   ├── check_stripes_coors_stylus.tcl
	│   │   ├── check_stripes_set2set_stylus.tcl
	│   │   ├── check_stripes_width_stylus.tcl
	│   │   └── lec.do
	│   ├── des
	│   │   ├── mmmc.tcl
	│   │   ├── PPA.AIC.tcl
	│   │   └── PPA.EXT.tcl
	│   ├── scores
	│   │   └── scores.sh
	│   └── sec
	│       ├── 1st_order
	│       └── ECO_TI
	└── gdrive
	    ├── ISPD23_daemon_procedures.sh
	    ├── ISPD23_daemon.settings
	    ├── ISPD23_daemon.sh
	    └── ISPD23_daemon_wrapper.sh
```

Some notes on the data skeleton.

1)	The main folders within `data/` are representative of the top-3 teams from the contest. You can just reuse any one or multiple of these folders, but
do *not* create your own folders; they won't be operated on (unless you revise `scripts/gdrive/ISPD23_daemon_procedures.sh` for the lines with `google_team_folders[]=`).

2)	The use of the 3rd-level subfolders (`backup_work` etc) is explained in [Data In](#data-in) and [Data Out](#data-out) further below.

3)	While the data skeleton would also be automatically initialized by the daemon, using the one provided here is still helpful, especially for beginners of the framework, as
	having the skeleton ready helps avoiding hiccups during data arrangement; see also [Operation](#operation) further below on that.

### Compilation

Compile the C++ code for pre-attack security evaluation considering exploitable regions:
```
cd scripts/eval/sec/1st_order/_cpp/
./compile.sh
cd -
```

Address compilation issues for your local C++ setup, if any.

### Configuration

Configure the daemon through the following steps.

1)	Required. File `scripts/gdrive/ISPD23_daemon.settings`.
	Revise line 32: `local_root_folder="/data/nyu_projects/ISPD23"`
	with your local path you've cloned the repository into.

2)	Required. File `scripts/gdrive/ISPD23_daemon.settings`.
	Check all the lines that start with `alias call_*`. Revise for your local installation of the design tools, if needed.

3)	Optional. File `scripts/gdrive/ISPD23_daemon.settings`.
	Revise line 13: `round="AIC"`
	for the desired operation. The available options are AIC (short for as in contest) or EXT (short for extended techniques). Please see the TCHES paper listed in
	[Context](#context) for more details.

4)	Optional. Files `scripts/eval/sec/ECO_TI/TI_wrapper.*.sh`.
	Revise lines 20, 21: `max_current_runs_*`
	according to the number and type of Innovus licenses available at your end. These settings dictate how many ECO runs for HT insertion are operated in parallel.
	
	Note that
	`max_current_runs_aes` mandates / only works with Innovus (invs) licenses, whereas `max_current_runs_default` works with both VDI (vdi) and Innovus (invs) licenses and
	automatically picks whatever licenses are free. Also note that these settings are "per design run", i.e., by default up-to 6 parallel ECO runs are allowed per evaluation job -- for
	the latter, the upper limit for parallel processing is configured in the file `scripts/gdrive/ISPD23_daemon.settings`, line 22: `max_parallel_runs=8`.

In case you are *not* using the official Innovus version 21.13 (or onward), you will experience failures for one command, namely `report_route -include_regular_routes -track_utilization`. If that is the case, you need to take the following steps.

1)	Comment out the corresponding line for `report_route -include_regular_routes -track_utilization` in `scripts/eval/checks/checks.tcl`.

2)	In `scripts/eval/scores`, run `mv scores.sh.wo_routing scores.sh`.

	Note that this will disable the routing-related metrics and scoring is also revised to ignore these metrics. Thus, the scoring won't be directly comparable anymore with those from the released datasets, but the overall trends are still similar (as only this scoring component is turned off).

### Data In

To put runs into the backend, arrange data through the following steps. See a full example toward the end of that subsection.

1)	Choose the correct root folder for data input.
	First, depending on the mode you want to run, either consider `data/AIC` or `data/EXT`. Second, as indicated in [Folder Setup](#folder-setup), you can
	freely pick from any of the skeleton subfolder(s) in there, whereas you should *not* create your own (unless you revise the related code in the daemon).
	Third, pick the folder matching the benchmark you are working on. Finally, choose the `downloads` subfolder.

	For example, for the AIC mode on sha256, you could pick `data/AIC/CUEDA/sha256/downloads` as root folder.

2)	Within that root folder data input, init new subfolders for each run. It is good practice to use unique IDs for these subfolders, e.g., `run_001`. (However, it is
	not mandatory -- in case subfolders with the same name are used again later on, the daemon will avoid conflicts for the data backup by extending the folder names with respective timestamps.)

	For example, for the AIC mode on sha256, you could generate
	`data/AIC/CUEDA/sha256/downloads/run_001`
	and
	`data/AIC/CUEDA/sha256/downloads/run_002`.

3)	For the new subfolder(s), put the design files you want to have evaluated. You must put both the DEF file and the Verilog netlist file. You must put only 1 pair of DEF and Verilog file
	in each subfolder -- use separate subfolders for multiple runs. The naming of the DEF and Verilog files does not matter.

To get started,
you could run the benchmark design files as is, to obtain the baseline references. Continuing the above example, you would want to:
`cp benchmarks/_release/_final/sha256/design.{def,v} data/AIC/CUEDA/sha256/downloads/run_001/`.
Next, you could reproduce the full results documented in our TCHES paper listed in [Context](#context). For that, you need to obtain the best results/layouts from the external link given in
[Content](#content).

**Full Example:**
As indicated, you can arrange multiple runs at once. For example, to run all benchmarks through baseline evaluation, you could do:
```
for bench in $(ls benchmarks/_release/_final/); do
	mkdir data/AIC/CUEDA/$bench/downloads/run_001/
	cp benchmarks/_release/_final/$bench/design.{def,v} data/AIC/CUEDA/$bench/downloads/run_001/
done
```

### Operation

Start the daemon, preferably from another independent bash session:
```
cd scripts/gdrive/
./ISPD23_daemon_wrapper.sh
```

Few important notes here.

1)	Handle this as an actual daemon; keep it going as long as some runs are still working. Otherwise, if you interrupt it during some
	runs, you need to kill any lingering processes (innovus, lec, TI_init.\*.sh, TI_wrapper.\*.sh), and also cleanup the related work directories manually. For the latter, this means to identify all the corresponding
    subfolders in the `data/*/*/*/work` folders for all teams and all benchmarks that the daemon had been working on at the time of interrupting.

2)	When seeking to push more runs into the download folders, it's better to first pause (Ctrl Z) or stop (Ctrl C) the daemon, then arrange the new data, and finally continue/restart the daemon.
	Either way (pausing or stopping the daemon), it's best to do so only once the daemon has finished all ongoing runs.
	
	FYI, that approach is important because, unlike the
	daemon version for the actual contest backend, this tailored version for local operation is more "fragile" in terms of data management, as we're bypassing the procedures handling
	data downloads and instead directly push files into the system. While this is not an issue as such, there can be easily race conditions: whenever the daemon checks
	for new downloads, it will right away arrange these files into the processing queue, and the moment your (manual) data arrangement is not done yet, any incomplete set of files
	would result in processing errors, and you'd have to redo all the concerned runs.

3)  The expected behaviour for data management by the daemon is as follows. First, for all teams and all benchmarks, it checks for new subfolders in the related `data/*/*/*/downloads` folders. Second, it initializes corresponding
    subfolders in the `data/*/*/*/work` folders for all these new "downloads". (As indicated above, we don't have actual downloads here, but rather push directly into the same queue-like file structure that handles downloads.)
    While doing so, the daemon also clears/deletes the related subfolders from the `downloads` folders.
    Third, once the processing is done -- irrespective of whether any error(s) had occurred or not -- corresponding subfolders are initialized in the `data/*/*/*/backup_work` folders, which contain all important outputs as well
    as all work files, the latter separately as zip archive (see also below, [Data Out](#data-out), for more details).
    As before, the daemon also automatically clears/deletes all the subfolders from the `work` folders. This implies that the daemon does *not* support picking up processing of interrupted runs. (FYI, while doing so would
    be possible, and is actually supported at least in parts by the way the daemon keeps track of all processing steps through status files, it is not overly robust across all possible scenarios or rather incomplete
    states that could arise during interruptions.)

### Data Out

Once the daemon has finished some run, you can access the results in the corresponding `data/*/*/*/backup_work` folder. Continuing the above example, you would find the results for the
baseline runs in `data/AIC/CUEDA/$bench/backup_work/run_001/`.

Few notes for organization of the result files. For interpretation, please also refer to our TCHES paper listed in [Context](#context).

1)	In case it exists, check `reports/errors.rpt` for any processing errors at your end (apart from the scoring errors for EXT that can be ignored; see point 3. below).

2)	For AIC, all results are summarized in `reports/scores.rpt`. This file contains all the metrics (for both the baseline and the submission) and the scoring. More extended views -- but no further relevant data beyond that
	already included in `scores.rpt` -- are covered by the various files in `reports/`. See also the README files in `benchmarks/_release/_final/$bench/README` for detailed descriptions of the various files.

3)	Similarly, for EXT, all results are summarized in `scores.rpt.failed`. *Importantly, unlike the filename suggests, all metrics described in there are valid.*
	Note that this file is normally declared as "failed" only because the scoring scheme
	proposed for AIC was not extended for EXT; the related computations fail.
	However, for EXT, we actually do not care about the scoring, but rather about the detailed insights provided by all the metrics.
	Again, please also refer to our TCHES paper for better understanding.
	
	In short, ignore the scoring in `reports/scores.rpt.failed` but focus on the valid raw metrics. Also ignore errors reported on scoring in `reports/errors.rpt`.

4)	In the main folders, i.e., the parents of the `reports/` folders, you can find further technical details. One further level up, the corresponding zip files contain all the
	work files, including all HT-infested layouts, and all log files.
	
	For beginners, it is recommended to focus only on the `reports/scores.rpt` files and possibly other report files, whereas all these
	technical details should only be of interest for advanced users which may also aim for their own follow-up research on layout defenses vs HT insertion.

### Debugging

While the daemon and all related scripts have been developed and revised carefully over many months, there may still occur some hiccups during operation, especially on other server environments and for first-time users.
Also, while each and every issue will be specific, consider these general guidelines toward debugging. If you're still stuck, feel free to reach out to ispd23_contest@nyu.edu.

1)  First and foremost, make sure you've carefully gone through *all* instructions above. We understand this is quite a bit to read through and may seem overly complex at first, but the daemon and all its processing stages are
    also complex by construction, so this all requires some efforts for clear understanding by the user as well.

2)  The main interface for tracking the daemon is its terminal: the daemon keeps printing out all steps, and (through the `ISPD23_daemon_wrapper.sh` script) all these steps are also logged into the `ISPD23.log*` files,
    with `ISPD23.log` being the most recent log file, whereas others with numbered suffixes are the backups from prior runs.

    Keep an eye for any errors in here. Note that majors errors would be printed directly at any point they occur, and without the `ISPD23` prefix. For example, the exemplary snippet below indicates that the both the
    design checks and the PPA evaluation failed for some run (but *not* necessarily for the run of camellia show here for that snippet).
```
    ISPD23 -- 5)  Time stamp: 1735587860
    ISPD23 -- 5)
    ISPD23 -- 5) Sleeping ...
    grep: checks.log*: No such file or directory
    grep: PPA.log*: No such file or directory
    grep: checks.log*: No such file or directory
    grep: PPA.log*: No such file or directory

    ISPD23 -- 2)  [ AIC -- CUEDA      -- camellia -- 001 ]:  LEC design checks done; all passed.
    ISPD23 -- 2)  [ AIC -- CUEDA      -- camellia -- 001 ]:  Innovus design checks done; all passed.
```

    Imporantly, note that the root-cause of this failure is not discernable from that high-level log. Thus, once you observe any errors like that, you want to study the related log files in more detail. Also, as
    indicated above, you'd need to first identify the actual run that is failing; since the daemon operates on multiple runs in parallel, you cannot go just by the point/time where the error shows up in the log file.
    Instead, you want to see the final status of the runs in the daemon's log -- lines like below tell you which run exactly went wrong.
```
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]: Checking work folder "/CHES_25_ARTIFACTS/first/Trojan-Insertion-versus-Layout-Defenses/data/AIC/CUEDA/seed/work/run_002"
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  Innovus PPA evaluation: failed
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  Innovus design checks: failed
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  LEC design checks: failed
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  Innovus Trojan insertion: done
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  Computing scores ...
	ISPD23 -- 3)  [ AIC -- CUEDA      -- seed     -- 002 ]:  Backup work folder to "/CHES_25_ARTIFACTS/first/Trojan-Insertion-versus-Layout-Defenses/data/AIC/CUEDA/seed/backup_work/run_002.zip" ...
```
    Finally, also note that not all error-related keywords indicate actual issues. For example, any particular HT insertion run may fail for tough layouts, i.e., for layouts with competitive defense implementations that hinder
    HT insertion altogether. Such cases would be reported as follows, where, again, the statement that "some failure occurred" does *not* imply an actual error occurred in the backend.
```
	ISPD23 -- 2)  [ AIC -- CUEDA      -- camellia -- 001 ]:  Innovus Trojan insertion, some failure occurred for Trojan "camellia_burn_random", TI mode "adv".
```

3)  The main interface for data management is the subfolders' structure starting from `data`. Please also recall the overall folder structure outlined in [Folder Setup](#folder-setup).

    As indicated above, the daemon handles this structure automatically as follows: any input data -- that must be organized into dedicated `downloads` subfolders as described in [Data In](#data-in) -- is initialized into dedicated
    `work` subfolders, which are in turn moved over to `backup_work` subfolders once done. Irrespective of whether error(s) occurred or not, the daemon would automatically clean/delete the `downloads` and `work`
    subfolders -- unless the daemon is interrupted; then, this cleanup *must* be done manually, in order to prevent hiccups for incomplete runs when restarting the daemon.

    With that in mind, any specific error requires investigating the errors.rpt and the log files for the particular process that failed. Please revisit [Data Out](#data-out) for more details on where these files
    are found.


## Future Directions

Once you're firm with the framework and all, you may want to use this for future work as follows.

- You may want to customize the evaluation procedures. The related scripts are found within `scripts/eval`, whereas their use/invocation are embedded throughout `scripts/gdrive/ISPD23_daemon_procedures.sh`. For example, you could
comment out the LEC call in `start_eval()` if you want to experiment for HT insertion with more relaxed constraints. For that particular example, you would also want to comment out `parse_lec_checks` within `check_eval()`.

- You may want to customize the HTs themselves. Toward that end, you'd need to revise the trj files in `benchmarks/_release/_final/*/TI` as well as the script `scripts/eval/sec/ECO_TI/TI_init_netlist.tcl`. The
former files contain the actual HT logic, whereas the latter script takes care of the integration of the HT logic into the layout files under attack.

- You may want to experiment with the ECO-based HT insertion. Toward that end, you'd need to revise the scripts `scripts/eval/sec/ECO_TI/TI.{AIC,EXT}.tcl`. Not all approaches/directions might be fruitful, e.g., we
are aware that the more aggressive modes try for layout optimization that is not well supported in various versions of Innovus; see https://wp.nyu.edu/ispd23_contest/qa/#ASAP7 Q1 for more details on that.

- You may want to explore more advanced defense techniques; this would probably become the most challenging exercise. Please also refer to our TCHES paper listed in [Context](#context) and the other artifacts listed in
[Content](#content) for some starting points toward that end.
