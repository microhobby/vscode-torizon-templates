# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to build or update the multi-root files.
##

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
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

# Compose path
compose_path = project_folder / "docker-compose.yml"
compose_template_path = home / ".apollox" / "empty" / "docker-compose.yml"

# Only create docker-compose.yml if it doesn't exist
if not compose_path.exists():
    shutil.copy2(compose_template_path, compose_path)

# Workspace file
workspace_file = project_folder / f"{project_name}.code-workspace"
if not workspace_file.exists():
    workspace_file_orig = project_folder / "multiRoot.code-workspace"
    if workspace_file_orig.exists():
        workspace_file_orig.rename(workspace_file)

with open(workspace_file, "r") as f:
    code_workspace = json.load(f)

# Reset folders and compounds
code_workspace["folders"] = []
code_workspace["launch"]["compounds"][0]["configurations"] = []
code_workspace["launch"]["compounds"][1]["configurations"] = []
code_workspace["settings"]["files.exclude"] = {}

# Add TCB folder if requested
if obj_rec.get("WithTCB"):
    code_workspace["folders"].append({
        "path": f"../{project_name.lower()}-os"
    })

# Load and reset compose YAML
with open(compose_path, "r") as f:
    compose_yaml = yaml.safe_load(f) or {}
compose_yaml["services"] = {}

factor = 0
port_keys = [
    "torizon_debug_port",
    "torizon_debug_ssh_port",
    "torizon_debug_port2",
    "torizon_debug_port3"
]

# Add project templates
for template in obj_rec["Projects"]:
    factor += 1
    template_name = template["Name"]

    code_workspace["folders"].append({
        "path": f"../{template_name}"
    })

    code_workspace["settings"].setdefault("files.exclude", {})[template_name] = True

    if template_name != project_name:
        code_workspace["launch"]["compounds"][0]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm64"
        })
        code_workspace["launch"]["compounds"][1]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm32"
        })

    settings_path = location_folder_join / template_name / ".vscode" / "settings.json"
    if settings_path.exists():
        with open(settings_path, "r") as f:
            settings_json = json.load(f)

        settings_json.pop("torizon_workspace", None)

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

    # Merge services
    template_compose_path = location_folder_join / template_name / "docker-compose.yml"
    if template_compose_path.exists():
        with open(template_compose_path, "r") as f:
            compose_item_yaml = yaml.safe_load(f) or {}
        services = compose_item_yaml.get("services") or {}
        for service, config in services.items():
            if "build" in config and "dockerfile" in config["build"]:
                del config["build"]
            compose_yaml["services"][service] = config

# Replace ${workspaceFolder} placeholders in task args and cwd with ${workspaceFolder:project_name}
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

# Save updated files
with open(compose_path, "w") as f:
    yaml.dump(compose_yaml, f)

with open(workspace_file, "w") as f:
    json.dump(code_workspace, f, indent=4)

# Run conflict check
cmd = f'xonsh "{project_folder}/.conf/check-single-projects-conflicts.xsh" -acceptAll 1'
subprocess.run(cmd, shell=True)
