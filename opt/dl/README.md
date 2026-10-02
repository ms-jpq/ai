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
        │   │       └── status         # exit code
        │   └── latest -> <revision>/
        └── <instance> -> .versions/<instance>/latest/output/

STATE/
└── dog/
    ├── template/
    ├── instances/
    │   └── walk/
    │       └── data/
    │           ├── inbox/
    │           │   └── lil -> /…/STEPS/lil/outbox/default/
    │           ├── outbox -> /…/STEPS/dog/outbox/
    │           └── versions -> /…/STEPS/dog/outbox/.versions/walk/
    └── instance/
        └── walk -> ../instances/walk/
```
