# S6

```text
JOBS/watchdog/
├── run.sh
├── env/S67_ON_UNIT_INACTIVE_SEC
└── data/launch/recurring/.gitignore

STATE/watchdog/
├── data/
│   ├── lstart
│   └── launch/recurring/
│       └── <pid> -> ../../lstart
├── template/
├── instance/
│   └── <pid> -> ../instances/<pid>
└── instances/
    └── <pid>/
        └── data/
            ├── job
            └── launch/recurring/
```
