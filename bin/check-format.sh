#!/bin/bash
#
# SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

REPO_ROOT="${BASH_SOURCE%/*}/.."

# Must `cd` to root in order for `stylua.toml` to get picked up.
cd "$REPO_ROOT"

stylua --check .

npx -y prettier --list-different "**/*.md"

find . -iname '*.[ch]' | xargs clang-format --dry-run
