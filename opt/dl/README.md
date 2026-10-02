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
        ├── .versions/<instance>/
        │   ├── <revision>/
        │   │   ├── input/
        │   │   │   ├── dogs -> /…/STEPS/dogs/outbox/<instance>/
        │   │   │   └── rules -> /…/STEPS/rules/outbox/<instance>/
        │   │   └── output/
        │   │       ├── stdout
        │   │       └── exit_status
        │   └── latest -> <revision>/
        └── <instance> -> .versions/<instance>/latest/

JOBS/
├── .versions/
│   └── dog.<revision>/
│       ├── run.sh -> data/step.sh
│       ├── env/
│       └── data/
│           ├── command
│           ├── step.sh
│           └── outbox -> /…/STEPS/dog/outbox/
└── dog -> .versions/dog.<revision>/

STATE/
└── dog/
    ├── template/
    │   ├── env/
    │   └── data/
    │       ├── command
    │       ├── step.sh
    │       ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh
    │       └── outbox -> /…/STEPS/dog/outbox/
    ├── instances/
    │   └── walk/
    │       ├── env/
    │       └── data/
    │           ├── command
    │           ├── step.sh
    │           ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh
    │           ├── inbox/
    │           │   └── lil -> /…/STEPS/lil/outbox/.versions/<instance>/latest/
    │           ├── outbox -> /…/STEPS/dog/outbox/
    │           └── versions -> /…/STEPS/dog/outbox/.versions/walk/
    └── instance/
        └── walk -> ../instances/walk/
```
