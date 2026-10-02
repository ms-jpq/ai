# S6

```text
opt/s6/jobs/watchdog/
├── run.sh
├── env/S67_ON_UNIT_INACTIVE_SEC
└── data/recurring/.gitignore

STATE/watchdog/
├── data/
│   ├── 1234
│   └── recurring/
│       └── 1234 -> ../1234
├── template/
├── instances/
│   └── 1234/
│       └── data/job -> /…/opt/s6/jobs/watchdog/run.sh
└── instance/
    └── 1234 -> ../instances/1234
```
