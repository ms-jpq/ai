# DL

@../s6/README.md

```text
STEPS/
└── <step>/
    ├── run.sh
    ├── env/
    ├── wants/
    │   └── <dependency> -> ../../<dependency>/
    └── outbox/
        ├── .versions/
        │   └── <instance>/
        │       ├── <revision>/
        │       │   ├── input/
        │       │   │   └── <input> -> /…/STEPS/<dependency>/outbox/.versions/<upstream-instance>/<upstream-revision>/output/
        │       │   └── output/
        │       │       ├── stdout
        │       │       └── status      # exit code: 0
        │       └── latest -> <revision>/
        └── <instance> -> .versions/<instance>/latest

JOBS/
├── .versions/
│   └── <step>.<revision>/
│       ├── run.sh -> data/step.sh
│       ├── env/
│       └── data/
│           ├── command
│           ├── step.sh
│           └── outbox -> /…/STEPS/<step>/outbox/
└── <step> -> .versions/<step>.<revision>/

STATE/
└── <step>/
    ├── template/
    └── instances/
        └── <instance>/
            └── data/
                ├── inbox/
                │   └── <input> -> /…/STEPS/<dependency>/outbox/<upstream-instance>
                └── versions -> /…/STEPS/<step>/outbox/.versions/<instance>/
```
