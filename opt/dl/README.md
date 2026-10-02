# DL

@../s6/README.md

```text
STEPS/
└── <step>/
    ├── run.sh
    ├── env/
    ├── wants/
    │   └── <dependency> -> ../../<dependency>/
    └── records/
        ├── <instance> -> .versions/<instance>/latest/ -> <revision>/
        └── .versions/<instance>/
            ├── latest -> <revision>/
            └── <revision>/
                ├── input/
                │   ├── dogs -> /…/STEPS/dogs/records/<instance>/
                │   │          -> .versions/<instance>/latest/ -> <revision>/
                │   └── rules -> /…/STEPS/rules/records/<instance>/
                │              -> .versions/<instance>/latest/ -> <revision>/
                └── output/
                    ├── stdout
                    └── exit_status

JOBS/
├── .versions/
│   └── dog.<revision>/
│       ├── run.sh -> data/step.sh
│       ├── env/
│       └── data/
│           ├── command
│           ├── step.sh
│           └── records -> /…/STEPS/dog/records/
└── dog -> .versions/dog.<revision>/

STATE/
└── dog/
    ├── template/
    │   ├── env/
    │   └── data/
    │       ├── command
    │       ├── step.sh
    │       ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh -> data/step.sh
    │       └── records -> /…/STEPS/dog/records/
    ├── instances/walk/
    │   ├── env/
    │   └── data/
    │       ├── command
    │       ├── step.sh
    │       ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh -> data/step.sh
    │       ├── inbox/
    │       │   └── lil -> /…/STEPS/lil/records/.versions/<instance>/latest/ -> <revision>/
    │       ├── records -> /…/STEPS/dog/records/
    │       └── versions -> /…/STEPS/dog/records/.versions/walk/
    └── instance/walk -> ../instances/walk/
```
