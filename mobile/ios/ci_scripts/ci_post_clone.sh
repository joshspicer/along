#!/bin/sh
set -eu

repository_root=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)}
exec "$repository_root/ci_scripts/ci_post_clone.sh"
