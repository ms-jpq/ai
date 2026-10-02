# DL

@../s6/README.md

```text
STEPS/
└── <step>/
    ├── run.sh
    ├── env/
    ├── wants/
    │   └── <dependency> -> ../../<dependency>/
    ├── versions/<instance>/
    │   ├── <revision>/
    │   │   ├── input/
    │   │   │   ├── dogs -> /…/STEPS/dogs/versions/<instance>/latest/output/
    │   │   │   └── rules -> /…/STEPS/rules/versions/<instance>/latest/output/
    │   │   └── output/
    │   │       ├── stdout
    │   │       └── status             # exit code
    │   └── latest -> <revision>/
    └── outbox/
        └── <instance> -> ../versions/<instance>/latest/output/

STATE/
└── dog/
    ├── template/
    ├── instances/
    │   └── walk/
    │       └── data/
    │           ├── inbox/
    │           │   └── lil -> /…/STEPS/lil/outbox/default/
    │           ├── outbox -> /…/STEPS/dog/outbox/
    │           └── versions -> /…/STEPS/dog/versions/walk/
    └── instance/
        └── walk -> ../instances/walk/
```
