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
│   ├── data/launch/<hash> -> <source-inputs>/
│   ├── template/
│   ├── instance/<hash> -> ../instances/<hash>/
│   └── instances/<hash>/data/launch -> <source-inputs>/
└── live/<consumer>@<hash>/
    ├── inputs/
    │   ├── <producer-1> -> ../telemetry/1-<producer-1>@<hash>/outputs/<row-1>/
    │   └── <producer-2> -> ../telemetry/2-<producer-2>@<hash>/outputs/<row-2>/
    ├── outputs/<row>/
    ├── telemetry/
    │   ├── 1-<producer-1>@<hash> -> ../../../dead/<producer-1>/<hash>.<timestamp>/
    │   └── 2-<producer-2>@<hash> -> ../../../dead/<producer-2>/<hash>.<timestamp>/
    └── log
```

```tree
STATE/graph/
├── sources/
│   ├── <producer-1>/<hash> -> <source-inputs-1>/
│   └── <producer-2>/<hash> -> <source-inputs-2>/
├── completed/<consumer>/<hash> -> ../../../dead/<consumer>/<hash>.<timestamp>/
├── pending/<service>/<instance> -> ../../../live/<service>@<instance>/
├── wanted-by -> topology/wanted-by/
├── topology -> .topology.<revision>/
├── .topology.<revision>/
│   ├── jobs/<consumer> -> JOBS/<consumer>/
│   ├── wants/<consumer>/
│   │   ├── <producer-1>
│   │   └── <producer-2>
│   ├── wanted-by/
│   │   ├── <producer-1>/<consumer> -> JOBS/<consumer>/
│   │   └── <producer-2>/<consumer> -> JOBS/<consumer>/
│   ├── definitions/<consumer>
│   └── services -> ../../services/
├── definitions/<consumer>/<hash>
└── cartesian/<consumer>/<hash>/
    ├── <producer-1> -> ../../../../dead/<producer-1>/<hash>.<timestamp>/outputs/<row-1>/
    └── <producer-2> -> ../../../../dead/<producer-2>/<hash>.<timestamp>/outputs/<row-2>/
```
