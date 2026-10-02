# DL

@../s6/README.md

```text
steps/
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

STATE/
└── dog/
    ├── template/
    │   └── data/
    │       └── outbox -> /…/steps/dog/outbox/
    └── instances/
        ├── walk/
        │   └── data/
        │       └── outbox -> /…/steps/dog/outbox/
        └── feed/
            └── data/
                └── outbox -> /…/steps/dog/outbox/
```
