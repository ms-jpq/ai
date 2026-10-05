# S6

## Job Definition

```tree
JOBS/<service>/
├── run.sh
├── env/
│   └── S9_ON_UNIT_INACTIVE_SEC
└── data/launch/
    └── <instance> -> <request>/
```

```tree
STATE/
├── services/<service>/
│   ├── data/
│   │   ├── launch/
│   │   └── .exited/
│   ├── template/
│   ├── instance/
│   │   └── <instance> -> ../instances/<instance>/
│   └── instances/
│       └── <instance>/
│           ├── env/S9_ON_UNIT_INACTIVE_SEC
│           └── data/
│               ├── .run
│               └── launch -> <request>/
├── live/
│   ├── s6.log
│   └── <service>/<instance>/
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       └── log
├── dead/<service>/<instance>/
│   ├── latest-succ -> <timestamp>/
│   └── <timestamp>/
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       ├── log
│       ├── exit_status
│       └── signal
└── failed/<service>/<instance>/
    ├── latest -> <timestamp>/
    └── <timestamp> -> ../../../dead/<service>/<instance>/<timestamp>/
```

---

## Dataflow

```tree
JOBS/
├── <producer-1>/
│   └── run.sh
├── <producer-2>/
│   └── run.sh
└── <consumer>/
    ├── run.sh
    └── data/wants/
        ├── <producer-1> -> ../../../<producer-1>/
        └── <producer-2> -> ../../../<producer-2>/
```

```tree
STATE/
├── services/<consumer>/
│   ├── data/launch/<hash(def, inputs)> -> <inputs>/
│   ├── template/
│   ├── instance/<hash(def, inputs)> -> ../instances/<hash(def, inputs)>/
│   └── instances/<hash(def, inputs)>/data/launch -> <inputs>/
└── live/<consumer>/<hash(def, inputs)>/
    ├── inputs/
    │   ├── .job.sum
    │   ├── <producer-1> -> ../telemetry/1-<producer-1>/outputs/<row-1>/
    │   └── <producer-2> -> ../telemetry/2-<producer-2>/outputs/<row-2>/
    ├── outputs/<row>/
    │   └── .job.sum
    ├── telemetry/
    │   ├── 1-<producer-1> -> ../../../../dead/<producer-1>/<instance>/<timestamp>/
    │   └── 2-<producer-2> -> ../../../../dead/<producer-2>/<instance>/<timestamp>/
    └── log
```

```tree
STATE/graph/
├── topology/
│   ├── wants/<consumer>/
│   │   ├── .job.sum
│   │   ├── <producer-1>
│   │   └── <producer-2>
│   └── wanted-by/
│       ├── <producer-1>/<consumer> -> ../../wants/<consumer>/
│       └── <producer-2>/<consumer> -> ../../wants/<consumer>/
└── cartesian-inputs/<consumer>/<hash(def, inputs)>/
    ├── <producer-1> -> ../../../../dead/<producer-1>/<instance>/<timestamp>/outputs/<row-1>/
    └── <producer-2> -> ../../../../dead/<producer-2>/<instance>/<timestamp>/outputs/<row-2>/
```
