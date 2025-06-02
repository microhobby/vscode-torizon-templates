
# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to build the multi-root files.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = True

import os
import shutil
from pathlib import Path
import json
import yaml
import subprocess

args = $ARGS
home = Path.home()  
location_folder_join = Path(args[1])
obj_rec = json.loads(args[2])
project_name = obj_rec["Name"]
project_folder = location_folder_join / project_name

# Copy docker-compose.yml
shutil.copy2(
    home / ".apollox" / "empty" / "docker-compose.yml",
    project_folder / "docker-compose.yml"
)

workspace_file = project_folder / "multiRoot.code-workspace"
workspace_file = workspace_file.rename(project_folder / f"{project_name}.code-workspace")

# Load code-workspace
with open(workspace_file, "r") as f:
    code_workspace = json.load(f)

# Load and reset top-level docker-compose
with open(project_folder / "docker-compose.yml", "r") as f:
    compose_yaml = yaml.safe_load(f)
compose_yaml["services"] = {}

# Optionally add TCB folder
if obj_rec["WithTCB"]:
    code_workspace["folders"].append({
        "path": f"../{project_name.lower()}-os"
    })

# Add single container project folders to
# files.exclude setting, to avoid showing them
# duplicated in the workspace
factor = 0
port_keys = [
    "torizon_debug_port",
    "torizon_debug_ssh_port",
    "torizon_debug_port2",
    "torizon_debug_port3"
]
for template in obj_rec["Projects"]:
    factor += 1
    template_name = template["Name"]

    code_workspace["folders"].append({
        "path": f"../{template_name}"
    })

    code_workspace["settings"].setdefault("files.exclude", {}).update({
        template_name: True
    })

    if template_name != project_name:
        code_workspace["launch"]["compounds"][0]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm64"
        })

        code_workspace["launch"]["compounds"][1]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm32"
        })

        # Update .vscode/settings.json
        settings_path = location_folder_join / template_name / ".vscode" / "settings.json"
        with open(settings_path, "r") as f:
            settings_json = json.load(f)

        if "torizon_workspace" in settings_json:
            del settings_json["torizon_workspace"]

        if "wait_sync" in settings_json:
            try:
                ws = int(settings_json["wait_sync"])
                settings_json["wait_sync"] = ws + factor
            except ValueError:
                pass


        for key in port_keys:
            val = settings_json.get(key)
            if isinstance(val, str) and val.strip():
                try:
                    settings_json[key] = str(int(val) + factor)
                except ValueError:
                    pass

        with open(settings_path, "w") as f:
            json.dump(settings_json, f, indent=4)

        # Merge docker-compose services
        template_compose_path = location_folder_join / template_name / "docker-compose.yml"
        with open(template_compose_path, "r") as f:
            compose_item_yaml = yaml.safe_load(f) or {}

        for service, config in compose_item_yaml.get("services", {}).items():
            # Remove 'build' key if it contains a dockerfile
            if "build" in config and "dockerfile" in config["build"]:
                del config["build"]
            compose_yaml["services"][service] = config

# Replace ${workspaceFolder} in task args and cwd with ${workspaceFolder:project_name}
for task in code_workspace.get("tasks", {}).get("tasks", []):
    if "args" in task:
        task["args"] = [
            arg.replace("${workspaceFolder}", f"${{workspaceFolder:{project_name}}}")
            if isinstance(arg, str) else arg
            for arg in task["args"]
        ]

    if "options" in task and isinstance(task["options"], dict):
        cwd = task["options"].get("cwd")
        if isinstance(cwd, str):
            task["options"]["cwd"] = cwd.replace("${workspaceFolder}", f"${{workspaceFolder:{project_name}}}")

# Write updated docker-compose
with open(project_folder / "docker-compose.yml", "w") as f:
    yaml.dump(compose_yaml, f)

# Write updated workspace
with open(workspace_file, "w") as f:
    json.dump(code_workspace, f, indent=4)

# Run check-single-projects-conflicts.xsh
cmd = f'xonsh "{project_folder}/.conf/check-single-projects-conflicts.xsh" -acceptAll 1'
subprocess.run(cmd, shell=True)

