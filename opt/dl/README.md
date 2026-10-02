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
│       ├── .messages/
│       │   ├── walk/
│       │   │   └── message-A/
│       │   │       ├── headers
│       │   │       └── body
│       │   └── feed/
│       │       └── message-B/
│       │           ├── headers
│       │           └── body
│       ├── walk -> .messages/walk/message-A/
│       └── feed -> .messages/feed/message-B/
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
    │   └── data/
    │       └── outbox -> /…/STEPS/dog/outbox/
    └── instances/
        ├── walk/
        │   └── data/
        │       └── outbox -> /…/STEPS/dog/outbox/
        └── feed/
            └── data/
                └── outbox -> /…/STEPS/dog/outbox/
```
