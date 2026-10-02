# DL

@../s6/README.md

```text
STEPS/
└── <step>/
    ├── run.sh
    ├── env/
    ├── wants/
    │   └── <dependency> -> ../../<dependency>/
    ├── versions/<instance>/<revision>/
    │   ├── input/
    │   │   ├── dogs -> <selected dogs revision>/output/
    │   │   └── rules -> <selected rules revision>/output/
    │   └── output/
    │       ├── stdout
    │       └── status                 # exit code
    └── outbox/
        └── <instance> -> ../versions/<instance>/<revision>/output/

STATE/
└── <step>/
    ├── template/
    └── instances/<instance>/data/
        ├── inbox/
        │   └── <input> -> /…/STEPS/<dependency>/outbox/<upstream-instance>/
        ├── outbox -> /…/STEPS/<step>/outbox/
        └── versions -> /…/STEPS/<step>/versions/<instance>/
```
