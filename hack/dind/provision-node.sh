#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

source $(dirname "${BASH_SOURCE}")/init.sh

os::util::setup-hosts-file ${MASTER_NAME} ${MASTER_IP} NODE_NAMES NODE_IPS

echo "Installing openshift"
os::util::install-cmds "${ORIGIN_ROOT}"
os::util::install-sdn "${ORIGIN_ROOT}"

SUPERVISORD_CONF="/etc/supervisord.conf"
cat <<EOF >> "${SUPERVISORD_CONF}"

[program:openshift-node]
command=/usr/bin/openshift start node --loglevel=5 --config=/${ORIGIN_ROOT}/openshift.local.config/node-${HOST_NAME}/node-config.yaml
priority=20
startsecs=20
stderr_events_enabled=true
stdout_events_enabled=true
EOF

# Start openshift
supervisorctl update

# Ensure that openshift-sdn has written configuration for docker
# before triggering a docker restart.
while grep 'DOCKER_DAEMON_ARGS=\"\"' "${SUPERVISORD_CONF}" > /dev/null; do
  sleep 1
done

# Restart docker
supervisorctl update

os::dind::set-dind-env "${ORIGIN_ROOT}"
