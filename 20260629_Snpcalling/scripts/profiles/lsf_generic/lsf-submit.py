#!/usr/bin/env python3
import os
import re
import sys
import subprocess
from snakemake.utils import read_job_properties

jobscript = sys.argv[-1]
props = read_job_properties(jobscript)

rule = props.get("rule", "snakejob")
jobid = props.get("jobid", "NA")
threads = int(props.get("threads", 1))
resources = props.get("resources", {})

queue = resources.get("lsf_queue", "c01")
mem_mb = int(resources.get("mem_mb", 8000))
walltime = resources.get("walltime", resources.get("runtime", 720))

wildcards = props.get("wildcards", {})
if wildcards:
    wc = ".".join([f"{k}={str(v).replace('/', '___')}" for k, v in wildcards.items()])
else:
    wc = "unique"

logdir = os.path.abspath(f"logs/cluster/{rule}/{wc}")
os.makedirs(logdir, exist_ok=True)

stdout = os.path.join(logdir, f"{rule}.{jobid}.%J.out")
stderr = os.path.join(logdir, f"{rule}.{jobid}.%J.err")

jobname = f"smk.{rule}.{jobid}"

cmd = [
    "bsub",
    "-q", str(queue),
    "-J", jobname,
    "-n", str(threads),
    "-R", "span[hosts=1]",
    "-W", str(walltime),
    "-o", stdout,
    "-e", stderr,
    "bash", jobscript
]

try:
    out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
except subprocess.CalledProcessError as e:
    sys.stderr.write(e.output)
    sys.exit(e.returncode)

m = re.search(r"Job <(\d+)>", out)
if not m:
    sys.stderr.write("Could not parse bsub jobid from output:\n")
    sys.stderr.write(out)
    sys.exit(1)

print(m.group(1))
