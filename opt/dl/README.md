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
│       │   │   │   ├── headers
│       │   │   │   └── stdout
│       │   │   └── latest -> <revision>/
│       │   └── feed/
│       │       ├── <revision>/
│       │       │   ├── headers
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
│   │   ├── run.sh
│   │   └── env/
│   └── lil.<revision>/
│       ├── run.sh
│       └── env/
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
