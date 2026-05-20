"""Minimal daily scheduler for containerized environments.

Runs expire-and-remind.py once per day at the configured hour (default 03:00 local
time of the container). Designed to run as PID 1 in the `scheduler` Docker service;
handles SIGTERM cleanly so `docker compose stop` exits promptly.

Usage:
    python scripts/scheduler.py [--hour 3] [--minute 0]
"""

from __future__ import annotations

import argparse
import datetime
import logging
import signal
import subprocess
import sys
import time
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [scheduler] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger(__name__)

_SCRIPT = Path(__file__).parent / "expire-and-remind.py"

_shutdown = False


def _handle_sigterm(sig, frame):  # noqa: ANN001
    global _shutdown
    log.info("SIGTERM received — shutting down")
    _shutdown = True


def seconds_until(hour: int, minute: int) -> float:
    now = datetime.datetime.now()
    target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= now:
        target += datetime.timedelta(days=1)
    return (target - now).total_seconds()


def run_job() -> None:
    log.info("Running expire-and-remind.py")
    result = subprocess.run(
        [sys.executable, str(_SCRIPT)],
        capture_output=False,  # let output go to container logs
    )
    if result.returncode != 0:
        log.warning("expire-and-remind.py exited with code %d", result.returncode)
    else:
        log.info("expire-and-remind.py completed successfully")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hour", type=int, default=3, help="Hour to run (0-23, local time)")
    parser.add_argument("--minute", type=int, default=0, help="Minute to run (0-59)")
    args = parser.parse_args()

    signal.signal(signal.SIGTERM, _handle_sigterm)

    log.info("Scheduler started — job will run daily at %02d:%02d", args.hour, args.minute)

    while not _shutdown:
        delay = seconds_until(args.hour, args.minute)
        log.info("Next run in %.1fh (at %02d:%02d)", delay / 3600, args.hour, args.minute)

        # Sleep in 60-second chunks so SIGTERM wakes us within 60 s.
        slept = 0.0
        while slept < delay and not _shutdown:
            chunk = min(60.0, delay - slept)
            time.sleep(chunk)
            slept += chunk

        if not _shutdown:
            run_job()

    log.info("Scheduler exited cleanly")


if __name__ == "__main__":
    main()
