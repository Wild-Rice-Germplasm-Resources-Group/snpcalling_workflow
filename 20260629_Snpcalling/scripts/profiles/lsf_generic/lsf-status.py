#!/usr/bin/env python3
import sys
import subprocess

jobid = sys.argv[1]

def run_cmd(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if p.returncode == 0 and p.stdout.strip():
        return p.stdout.strip()
    return ""

out = run_cmd(f"bjobs -o 'stat' -noheader {jobid}")

if not out:
    out = run_cmd(f"bhist -o 'stat' -noheader {jobid}")

stat = out.split()[0] if out else ""

if stat in ("PEND", "RUN", "WAIT", "SSUSP", "USUSP", "PSUSP"):
    print("running")
elif stat in ("DONE", "POST_DONE", "PDONE"):
    print("success")
elif stat in ("EXIT", "FAILED", "POST_ERR", "PERR", "ZOMBI"):
    print("failed")
else:
    print("running")
