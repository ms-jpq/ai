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
│       ├── walk -> /…/STATE/dog/instances/walk/data/results/latest
│       └── feed -> /…/STATE/dog/instances/feed/data/results/latest
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
        │       └── results/
        │           ├── <id-A>/
        │           │   ├── headers
        │           │   └── stdout
        │           └── latest -> <id-A>/
        └── feed/
            └── data/
                └── results/
                    ├── <id-B>/
                    │   ├── headers
                    │   └── stdout
                    └── latest -> <id-B>/
```
