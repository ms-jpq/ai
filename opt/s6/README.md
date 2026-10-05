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
├── dead/<service>/<instance>.<timestamp>/
│   ├── inputs/
│   ├── outputs/
│   ├── telemetry/
│   ├── log
│   ├── exit_status
│   └── signal
└── failed/<service>/<instance>.<timestamp> -> ../../dead/<service>/<instance>.<timestamp>/
```

---

## Dataflow

```tree
JOBS/
├── <producer-1>/
│   ├── run.sh
│   └── data/launch/<hash-1> -> <source-inputs-1>/
├── <producer-2>/
│   ├── run.sh
│   └── data/launch/<hash-2> -> <source-inputs-2>/
└── <consumer>/
    ├── run.sh
    └── data/wants/
        ├── <producer-1> -> ../../../<producer-1>/
        └── <producer-2> -> ../../../<producer-2>/
```

```tree
STATE/
├── graph/
│   ├── sources/
│   │   ├── <producer-1>/<hash-1> -> <source-inputs-1>/
│   │   └── <producer-2>/<hash-2> -> <source-inputs-2>/
│   ├── latest/
│   │   ├── <producer-1>/<hash-1> -> ../../../dead/<producer-1>/<hash-1>.<timestamp>/
│   │   ├── <producer-2>/<hash-2> -> ../../../dead/<producer-2>/<hash-2>.<timestamp>/
│   │   └── <consumer>/<hash> -> ../../../dead/<consumer>/<hash>.<timestamp>/
│   ├── completed/<consumer>/<hash> -> ../../../dead/<consumer>/<hash>.<timestamp>/
│   ├── pending/<service>/<instance> -> ../../../live/<service>@<instance>/
│   ├── wanted-by -> topology/wanted-by/
│   ├── topology -> .topology.<revision>/
│   ├── .topology.<revision>/
│   │   ├── jobs/<consumer> -> JOBS/<consumer>/
│   │   ├── wants/<consumer>/
│   │   │   ├── <producer-1>
│   │   │   └── <producer-2>
│   │   ├── wanted-by/
│   │   │   ├── <producer-1>/<consumer> -> JOBS/<consumer>/
│   │   │   └── <producer-2>/<consumer> -> JOBS/<consumer>/
│   │   ├── definitions/<consumer>
│   │   └── services -> ../../services/
│   ├── definitions/<consumer>/<hash>
│   └── cartesian/<consumer>/<hash>/
│       ├── <producer-1> -> ../../../../dead/<producer-1>/<hash-1>.<timestamp>/outputs/<item-1>/
│       └── <producer-2> -> ../../../../dead/<producer-2>/<hash-2>.<timestamp>/outputs/<item-2>/
├── services/<consumer>/
│   ├── data/launch/<hash> -> ../../../../graph/cartesian/<consumer>/<hash>/
│   ├── template/
│   ├── instance/<hash> -> ../instances/<hash>/
│   └── instances/<hash>/data/launch -> <the same input directory>/
├── live/<consumer>@<hash>/
│   ├── inputs -> ../../graph/cartesian/<consumer>/<hash>/
│   ├── outputs/<item>/
│   ├── telemetry/
│   │   ├── 1-<producer-1>@<hash-1> -> <completed producer record>/
│   │   └── 2-<producer-2>@<hash-2> -> <completed producer record>/
│   └── log
└── dead/<consumer>/<hash>.<timestamp>/
    ├── inputs -> ../../../graph/cartesian/<consumer>/<hash>/
    ├── outputs/<item>/
    ├── telemetry/
    │   ├── 1-<producer-1>@<hash-1> -> <completed producer record>/
    │   └── 2-<producer-2>@<hash-2> -> <completed producer record>/
    ├── log
    ├── exit_status
    └── signal
```
