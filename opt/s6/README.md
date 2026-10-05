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
│   └── <service>@<instance>/
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       └── log
├── dead/<service>/
│   ├── <instance>.latest-succ -> <instance>.<timestamp>/
│   └── <instance>.<timestamp>/
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       ├── log
│       ├── exit_status
│       └── signal
└── failed/<service>/<instance>.<timestamp> -> ../../dead/<service>/<instance>.<timestamp>/
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
└── live/<consumer>@<hash(def, inputs)>/
    ├── inputs/
    │   ├── .job.sum
    │   ├── <producer-1> -> ../telemetry/1-<producer-1>@<instance>/outputs/<row-1>/
    │   └── <producer-2> -> ../telemetry/2-<producer-2>@<instance>/outputs/<row-2>/
    ├── outputs/<row>/
    ├── telemetry/
    │   ├── 1-<producer-1>@<instance> -> ../../../dead/<producer-1>/<instance>.<timestamp>/
    │   └── 2-<producer-2>@<instance> -> ../../../dead/<producer-2>/<instance>.<timestamp>/
    └── log
```

```tree
STATE/graph/
├── indices/
│   ├── sources/
│   │   ├── <producer-1>/<instance> -> <source-inputs-1>/
│   │   └── <producer-2>/<instance> -> <source-inputs-2>/
│   └── dead/<consumer>/<hash(def, inputs)> -> ../../../../dead/<consumer>/<hash(def, inputs)>.<timestamp>/
├── topology -> .topology.<revision>/
├── .topology.<revision>/
│   ├── jobs/<consumer> -> JOBS/<consumer>/
│   ├── wants/<consumer>/
│   │   ├── .job.sum
│   │   ├── <producer-1>
│   │   └── <producer-2>
│   └── services -> ../../services/
└── cartesian/<consumer>/<hash(def, inputs)>/
    ├── .job.sum
    ├── <producer-1> -> ../../../../dead/<producer-1>/<instance>.<timestamp>/outputs/<row-1>/
    └── <producer-2> -> ../../../../dead/<producer-2>/<instance>.<timestamp>/outputs/<row-2>/
```
