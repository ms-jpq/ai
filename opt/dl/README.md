# DL

@../s6/README.md

```text
STEPS/
├── dog/
│   ├── run.sh
│   ├── env/
│   ├── wants/
│   │   └── lil -> ../../lil
│   └── outbox/
│       ├── .versions/
│       │   ├── walk/
│       │   │   ├── <revision>/
│       │   │   │   ├── meta/
│       │   │   │   └── stdout
│       │   │   └── latest -> <revision>/
│       │   └── feed/
│       │       ├── <revision>/
│       │       │   ├── meta/
│       │       │   └── stdout
│       │       └── latest -> <revision>/
│       ├── walk -> .versions/walk/latest
│       └── feed -> .versions/feed/latest
└── lil/
    ├── run.sh
    ├── env/
    ├── wants/
    └── outbox/

JOBS/
├── .versions/
│   ├── dog.<revision>/
│   │   ├── run.sh -> data/step.sh
│   │   ├── env/
│   │   └── data/
│   │       ├── command
│   │       ├── step.sh
│   │       └── outbox -> /…/STEPS/dog/outbox/
│   └── lil.<revision>/
│       ├── run.sh -> data/step.sh
│       ├── env/
│       └── data/
│           ├── command
│           ├── step.sh
│           └── outbox -> /…/STEPS/lil/outbox/
├── dog -> .versions/dog.<revision>/
└── lil -> .versions/lil.<revision>/

STATE/
└── dog/
    ├── template/
    └── instances/
        ├── walk/
        │   └── data/
        │       └── versions -> /…/STEPS/dog/outbox/.versions/walk/
        └── feed/
            └── data/
                └── versions -> /…/STEPS/dog/outbox/.versions/feed/
```
