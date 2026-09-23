#!/usr/bin/env python3
"""deloway-tether.py <command> [args…]

Run a long-lived helper that must never outlive the shell. Sets the Linux
parent-death signal (PR_SET_PDEATHSIG = 1) to SIGTERM, then execs the command,
so the kernel terminates it as soon as the quickshell process that started it
exits (crash, `killall quickshell`, restart). Without this, helpers such as
`gsettings monitor` were re-parented to PID 1 and piled up on every restart.
"""
import ctypes
import os
import signal
import sys

if len(sys.argv) < 2:
    sys.exit("usage: deloway-tether.py <command> [args...]")

libc = ctypes.CDLL(None, use_errno=True)
libc.prctl(1, signal.SIGTERM, 0, 0, 0)   # PR_SET_PDEATHSIG survives execve
if os.getppid() == 1:                     # parent already gone before prctl took effect
    sys.exit(0)
os.execvp(sys.argv[1], sys.argv[1:])
