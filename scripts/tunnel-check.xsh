#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to create a new project from a template.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True


import os
import sys
import json
import time
import subprocess
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out



if len(sys.argv) != 5:
    Error_Out(
        f"Error: Expected 5 arguments, but got {len(sys.argv) -1}.\n" +
        "Report on https://github.com/torizon/vscode-torizon-templates/issues",
        Error.EINVAL
    )


torizon_psswd = get_arg_not_empty(1)
torizon_ssh_port = get_arg_not_empty(2)
torizon_user = get_arg_not_empty(3)
torizon_ip = get_arg_not_empty(4)

MAX_ATTEMPTS = 15
TIMEOUT_SECONDS = 5
SLEEP_INTERVAL = 1


for i in range(1, MAX_ATTEMPTS + 1):
    try:
        # Use curl to check registry availability
        # --silent: suppress progress output
        # --max-time: maximum time allowed for transfer
        with ${...}.swap(RAISE_SUBPROC_ERROR=False):
            result = !( \
                sshpass \
                    -p @(torizon_psswd) \
                    ssh \
                    -p @(torizon_ssh_port) \
                    -o UserKnownHostsFile=/dev/null \
                    -o StrictHostKeyChecking=no \
                    -o PubkeyAuthentication=no \
                    @(torizon_user)@@(torizon_ip) curl --silent --max-time @(TIMEOUT_SECONDS) http://localhost:5002/v2/_catalog \
            )

        if result.returncode == 0:
            print('Registry ready')
            sys.exit(0)

    except Exception as e:
        print(f"Exception occurred: {e}")

    print(f"Attempt {i}/{MAX_ATTEMPTS}: waiting for registry...")
    time.sleep(SLEEP_INTERVAL)


Error_Out(
    "Max attempts reached\n" +
    "Was not possible to get a response from the registry",
    Error.EFAIL
)
