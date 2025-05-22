#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

# This script builds the multiroot docker-compose.prod.yml by combining
# each workspace's docker-compose.prod.yml, after generating each
# through their own create-docker-compose-production task.

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
$RAISE_SUBPROC_ERROR = True

import os
import yaml
import asyncio
import json
from pathlib import Path
from torizon_templates_utils.colors import Color, print
from torizon_templates_utils.errors import Error_Out, Error

args = $ARGS
print(args)
workspace_root = Path(args[1]).resolve()
image_tag = args[2]
gpu = args[3] if len(args) > 3 else ""

print(f"Workspace root: {workspace_root}", color=Color.YELLOW)
workspace_file = next(workspace_root.glob("*.code-workspace"), None)

if not workspace_file:
    Error_Out("No .code-workspace file found in root", Error.ENOFOUND)

with open(workspace_file) as f:
    workspace_config = json.load(f)

folders = [Path(folder["path"]) for folder in workspace_config.get("folders", [])]
folders.pop(0)

compose_tasks = []
for folder in folders:
    task = {
        "type": "process",
        "command": "xonsh",
        "args": [
            str(workspace_root / folder / ".conf/create-docker-compose-production.xsh"),
            str(workspace_root / folder),
            image_tag,
            folder.name,
            str(gpu),
        ],
        "options": {"cwd": str(workspace_root / folder)}
    }
    compose_tasks.append((folder, task))

def load_workspace_env(folder_path: Path):
    settings_path = folder_path / ".vscode/settings.json"
    task_env = os.environ.copy()
    task_env["TASKS_CUSTOM_SETTINGS_JSON"] = settings_path

    return task_env

async def run_task(folder, task):
    env = os.environ.copy()
    env.update(load_workspace_env(workspace_root / folder))
    print(f"Starting compose build for {folder}", color=Color.YELLOW)

    proc = await asyncio.create_subprocess_exec(
        task["command"],
        *task["args"],
        cwd=task["options"]["cwd"],
        env=os.environ,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        print(stderr.decode(), color=Color.RED)
        Error_Out(f"Failed task in {folder}", Error.EFAIL)
    print(stdout.decode(), color=Color.GREEN)

async def main():
    await asyncio.gather(*(run_task(folder, task) for folder, task in compose_tasks))

    print("All production compose files generated. Now merging...", color=Color.GREEN)

    final_compose = {"services": {}}

    for folder, _ in compose_tasks:
        compose_path = workspace_root / folder / "docker-compose.prod.yml"
        if not compose_path.exists():
            Error_Out(f"Missing production compose file in {folder}", Error.ENOFOUND)
        with open(compose_path) as f:
            part = yaml.safe_load(f)
            final_compose["services"].update(part.get("services", {}))

    out_file = workspace_root / "docker-compose.prod.yml"
    with open(out_file, "w") as f:
        yaml.dump(final_compose, f, indent=2)

    print(f"Combined docker-compose.prod.yml written to {out_file}", color=Color.GREEN)

asyncio.run(main())

