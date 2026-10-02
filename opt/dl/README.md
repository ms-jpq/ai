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
        ├── <instance> -> .versions/<instance>/latest/
        └── .versions/<instance>/
            ├── latest -> <revision>/
            └── <revision>/
                ├── input/
                │   ├── dogs -> /…/STEPS/dogs/records/<instance>/
                │   └── rules -> /…/STEPS/rules/records/<instance>/
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
    │       ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh
    │       └── records -> /…/STEPS/dog/records/
    ├── instances/
    │   └── walk/
    │       ├── env/
    │       └── data/
    │           ├── command
    │           ├── step.sh
    │           ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh
    │           ├── inbox/
    │           │   └── lil -> /…/STEPS/lil/records/.versions/<instance>/latest/
    │           ├── records -> /…/STEPS/dog/records/
    │           └── versions -> /…/STEPS/dog/records/.versions/walk/
    └── instance/
        └── walk -> ../instances/walk/
```
