#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from collections.abc import Callable, Mapping
from os import environ
from pathlib import Path
from shutil import copytree
from subprocess import STDOUT, Popen, run
from sys import stderr
from tempfile import TemporaryDirectory
from time import monotonic, sleep


def _run(
    *args: str, cwd: Path | None = None, env: Mapping[str, str] | None = None
) -> str:
    return run(
        args, cwd=cwd, env=env, check=True, capture_output=True, text=True
    ).stdout


def _wait(predicate: Callable[[], bool]) -> None:
    deadline = monotonic() + 15
    while not predicate():
        if monotonic() > deadline:
            raise AssertionError("Timed out waiting for lifecycle transition")
        sleep(0.05)


def _write(path: Path, *, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def _test(root: Path) -> None:
    source = Path(__file__).resolve().parent
    s6 = root / "s6"
    copytree(source, s6, symlinks=True)
    state = root / "state"
    state.mkdir()
    step = root / "steps/dog"
    job = s6 / "jobs/dog"
    template = source.parent / "dl/jobs/dispatch/data/service-template.sh"
    quine = s6 / "jobs/quine/run.sh"
    environment = {**environ, "S67_WORKING_DIRECTORY": str(root)}
    _write(s6 / "base/env/S67_RUNTIME_MAX_SEC", text="10")

    script = """#!/usr/bin/env bash
set -euo pipefail
printf '%s:%s:%s\\n' CODE "$PAYLOAD" "$(< "${0%/*}/value")" > "$S67_WORKING_DIRECTORY/started-$PAYLOAD"
while ! [[ -f $S67_WORKING_DIRECTORY/release-$PAYLOAD ]]; do sleep 0.05; done
printf '%s\\n' CODE > "$S67_WORKING_DIRECTORY/finished-$PAYLOAD"
"""
    _write(step / "run.sh", text=script.replace("CODE", "old"))
    (step / "run.sh").chmod(0o755)
    _write(step / "env/PAYLOAD", text="one")
    _write(step / "data/value", text="old-data")
    _run(str(template), str(step), str(job))
    request = step / "requests/recurring/walk"
    request.symlink_to("/dev/null")
    _run(str(quine), cwd=state, env={**environment, "RECUR": "bootstrap"})
    keeper = s6 / "jobs/keeper/run.sh"
    _write(keeper, text="#!/bin/sh\nexit 0\n")
    keeper.chmod(0o755)
    _run(
        str(quine), "keeper", "parent", cwd=state, env={**environment, "RECUR": "seed"}
    )
    runtime_requests = state / "keeper/data/recurring"
    runtime_requests.mkdir()
    (runtime_requests / "parent").symlink_to("/dev/null")

    with (root / "scan.log").open("w+") as log:
        scan = Popen(
            ["s6-svscan", str(state)], env=environment, stdout=log, stderr=STDOUT
        )
        try:
            service = state / "dog/instances/walk"
            _wait(lambda: (root / "started-one").exists())
            assert (root / "started-one").read_text() == "old:one:old-data\n"
            pid = _run("s6-svstat", "-o", "pid", str(service))

            _run(str(template), str(step), str(job))
            _run(
                "s6-setlock",
                str(state / ".reconcile.lock"),
                str(quine),
                "dog",
                cwd=state,
                env={**environment, "RECUR": "job"},
            )
            assert not (service / "down").exists()
            assert _run("s6-svstat", "-o", "pid", str(service)) == pid

            _write(step / "run.sh", text=script.replace("CODE", "new"))
            _write(step / "env/PAYLOAD", text="two")
            _write(step / "data/value", text="new-data")
            _run(str(template), str(step), str(job))
            _wait(lambda: (service / "down").exists())
            assert _run("s6-svstat", "-o", "pid", str(service)) == pid
            assert not (root / "finished-one").exists()
            (root / "release-one").touch()
            _wait(lambda: (root / "started-two").exists())
            assert (root / "finished-one").read_text() == "old\n"
            assert (root / "started-two").read_text() == "new:two:new-data\n"

            request.unlink()
            _wait(lambda: (service / "down").exists())
            assert not (root / "finished-two").exists()
            (root / "release-two").touch()
            _wait(lambda: not service.exists())
            assert (root / "finished-two").read_text() == "new\n"

            _write(step / "env/PAYLOAD", text="three")
            _run(str(template), str(step), str(job))
            request.symlink_to("/dev/null")
            _wait(lambda: (root / "started-three").exists())
            step.rename(root / "removed-step")
            _wait(lambda: (service / "down").exists())
            (root / "release-three").touch()
            _wait(lambda: not service.exists())
            assert (root / "finished-three").read_text() == "new\n"

            step = root / "removed-step"
            _write(step / "env/PAYLOAD", text="four")
            _run(str(template), str(step), str(job))
            _wait(lambda: (root / "started-four").exists())
            job.unlink()
            _wait(lambda: (service / "down").exists())
            (root / "release-four").touch()
            _wait(lambda: not service.exists())
            assert (root / "finished-four").read_text() == "new\n"
            assert (state / "keeper/instances/parent").is_dir()
            assert not (state / "keeper/instances/parent/down").exists()
            assert (
                _run(
                    "s6-svstat", "-o", "wantedup", str(state / "quine/instances/-")
                ).strip()
                == "true"
            )
        except BaseException:
            log.flush()
            log.seek(0)
            stderr.write(log.read())
            for output in (root / "log").rglob("*.log"):
                stderr.write(output.read_text())
            raise
        finally:
            if scan.poll() is None:
                _run("s6-svscanctl", "-t", str(state))
            else:
                for manager in state.iterdir():
                    if (manager / "supervise/control").exists():
                        _run("s6-svc", "-dx", str(manager))
            scan.wait(timeout=15)


if __name__ == "__main__":
    temporary = Path(__file__).resolve().parents[2] / "var/tmp"
    temporary.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="quine-lifecycle.", dir=temporary) as directory:
        _test(Path(directory))
