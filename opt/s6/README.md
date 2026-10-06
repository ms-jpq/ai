# S6

## Job Definition

```tree
JOBS/<service>/
├── run.sh
├── env/
│   └── S9_ON_UNIT_INACTIVE_SEC
└── data/.s9/launch/
    └── <instance> -> <arg1>/
```

```tree
STATE/
├── services/<service>/
│   ├── data/.s9/
│   │   ├── launch/
│   │   └── inputs.sum
│   ├── template/data/.s9/
│   │   ├── source -> <pinned-job>/
│   │   └── defs.sum
│   ├── instance/
│   │   └── <instance> -> ../instances/<instance>/
│   └── instances/
│       └── <instance>/
│           ├── env/S9_ON_UNIT_INACTIVE_SEC
│           └── data/
│               ├── .s9/
│               │   ├── source -> <pinned-job>/
│               │   ├── defs.sum
│               │   ├── pgid
│               │   ├── attempt
│               │   ├── launch -> <arg1>/
│               │   └── died -> ../../../../../../dead/<service>/<instance>/<timestamp>/
│               └── .run
├── live/
│   ├── s6.log
│   └── <service>/<instance>/
│       ├── .s9/record
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       └── log
├── dead/<service>/<instance>/
│   ├── latest-succ -> <timestamp>/
│   └── <timestamp>/
│       ├── .s9/outputs.sum/<row>
│       ├── inputs/
│       ├── outputs/
│       ├── telemetry/
│       ├── log
│       ├── exit_status
│       └── signal
└── fail/<service>/<instance>/
    ├── latest -> <timestamp>/
    └── <timestamp> -> ../../../dead/<service>/<instance>/<timestamp>/
```

---

## Dataflow

- **`wants/=producer` — keyed join:** all `=` dependencies must supply the same output row name. Unmatched keys produce no execution.

- **`wants/producer` — Cartesian product:** every row combines with every eligible row from the other dependencies, including any matched groups.

```tree
JOBS/
├── <producer-1>/
│   └── run.sh
├── <producer-2>/
│   └── run.sh
└── <consumer>/
    ├── run.sh
    └── data/wants/
        ├── =<producer-1> -> ../../../<producer-1>/
        └── =<producer-2> -> ../../../<producer-2>/
```

```tree
STATE/
├── services/<consumer>/
│   ├── data/.s9/launch/<hash(def, rows)> -> <inputs>/
│   ├── template/
│   ├── instance/<hash(def, rows)> -> ../instances/<hash(def, rows)>/
│   └── instances/<hash(def, rows)>/data/.s9/launch -> <inputs>/
└── live/<consumer>/<hash(def, rows)>/
    ├── inputs/
    │   ├── .s9/defs.sum
    │   ├── <producer-1> -> ../telemetry/<producer-1>@<instance>.<timestamp>/outputs/<key>/
    │   └── <producer-2> -> ../telemetry/<producer-2>@<instance>.<timestamp>/outputs/<key>/
    ├── outputs/<row>/
    │   └── .s9/defs.sum
    ├── telemetry/
    │   ├── <producer-1>@<instance>.<timestamp> -> ../../../../dead/<producer-1>/<instance>/<timestamp>/
    │   └── <producer-2>@<instance>.<timestamp> -> ../../../../dead/<producer-2>/<instance>/<timestamp>/
    └── log
```

```tree
STATE/graph/
├── topology/
│   ├── .s9/inputs.sum
│   └── wants/<consumer>/
│       ├── .s9/defs.sum
│       ├── =<producer-1> -> ../<producer-1>/
│       └── =<producer-2> -> ../<producer-2>/
└── inputs/<consumer>/
    ├── .s9/projection/
    │   ├── .sum
    │   └── <hash(def, rows)>
    └── <hash(def, rows)>/
        ├── <producer-1> -> ../../../../dead/<producer-1>/<instance>/<timestamp>/outputs/<key>/
        └── <producer-2> -> ../../../../dead/<producer-2>/<instance>/<timestamp>/outputs/<key>/
```
