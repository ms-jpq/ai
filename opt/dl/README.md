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
│       │   │   │   ├── input/
│       │   │   │   │   ├── lil-walk -> /…/STEPS/lil/outbox/.versions/walk/<revision-A>/output/
│       │   │   │   │   └── lil-feed -> /…/STEPS/lil/outbox/.versions/feed/<revision-B>/output/
│       │   │   │   └── output/
│       │   │   │       ├── stdout
│       │   │   │       └── status      # exit code: 0
│       │   │   └── latest -> <revision>/
│       │   └── feed/
│       │       ├── <revision>/
│       │       │   ├── input/
│       │       │   │   ├── lil-walk -> /…/STEPS/lil/outbox/.versions/walk/<revision-A>/output/
│       │       │   │   └── lil-feed -> /…/STEPS/lil/outbox/.versions/feed/<revision-B>/output/
│       │       │   └── output/
│       │       │       ├── stdout
│       │       │       └── status      # exit code: 0
│       │       └── latest -> <revision>/
│       ├── walk -> .versions/walk/latest
│       └── feed -> .versions/feed/latest
└── lil/
    ├── run.sh
    ├── env/
    ├── wants/
    └── outbox/
        ├── .versions/
        │   ├── walk/
        │   │   ├── <revision-A>/
        │   │   │   ├── input/
        │   │   │   └── output/
        │   │   │       ├── stdout
        │   │   │       └── status      # exit code: 0
        │   │   └── latest -> <revision-A>/
        │   └── feed/
        │       ├── <revision-B>/
        │       │   ├── input/
        │       │   └── output/
        │       │       ├── stdout
        │       │       └── status      # exit code: 0
        │       └── latest -> <revision-B>/
        ├── walk -> .versions/walk/latest
        └── feed -> .versions/feed/latest

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
        │       ├── inbox/
        │       │   ├── lil-walk -> /…/STEPS/lil/outbox/walk
        │       │   └── lil-feed -> /…/STEPS/lil/outbox/feed
        │       └── versions -> /…/STEPS/dog/outbox/.versions/walk/
        └── feed/
            └── data/
                ├── inbox/
                │   ├── lil-walk -> /…/STEPS/lil/outbox/walk
                │   └── lil-feed -> /…/STEPS/lil/outbox/feed
                └── versions -> /…/STEPS/dog/outbox/.versions/feed/
```
