# DL

@../s6/README.md

```text
STEPS/
└── <step>/
    ├── run.sh
    ├── dispatch.sh
    ├── env/
    ├── wants/
    │   └── <dependency> -> ../../<dependency>/
    └── records/
        └── <instance>/
            ├── latest -> <revision>/
            └── <revision>/
                ├── input/
                │   └── <dependency> -> /…/STEPS/<dependency>/records/
                │       └── <instance>/latest -> <revision>/
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
│           ├── inbox/
│           │   └── <dependency> -> /…/STEPS/<dependency>/records/
│           │       └── <instance>/latest -> <revision>/
│           ├── recurring/
│           │   └── <instance> -> ../inbox/
│           ├── oneshot/
│           └── records -> /…/STEPS/dog/records/
└── dog -> .versions/dog.<revision>/

STATE/
└── dog/
    ├── template/
    ├── instance/<instance> -> ../instances/<instance>/
    └── instances/<instance>/
        ├── env/
        └── data/
            ├── command
            ├── step.sh
            ├── job -> /…/JOBS/.versions/dog.<revision>/run.sh -> data/step.sh
            ├── inbox/
            │   └── <dependency> -> /…/STEPS/<dependency>/records/
            │       └── <instance>/latest -> <revision>/
            └── outbox -> /…/STEPS/dog/records/<instance>/<revision>/output/
                ├── stdout
                └── exit_status
```
