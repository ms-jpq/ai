# S6

```text
opt/s6/jobs/watchdog/
├── run.sh
├── env/S67_ON_UNIT_INACTIVE_SEC
└── data/recurring/.gitignore

STATE/watchdog/
├── data/
│   ├── lstart
│   └── recurring/
│       └── <pid> -> ../lstart
├── template/
├── instances/
│   └── <pid>/
│       └── data/job -> /…/opt/s6/jobs/watchdog/run.sh
└── instance/
    └── <pid> -> ../instances/<pid>
```
