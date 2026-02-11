#!/bin/bash

# Ensure we fail if a command fails
set -e


if ! id "$ADMINUSER" &>/dev/null; then
    echo "Creating user: ${ADMINUSER}"
    echo
    useradd -m -s /bin/bash "$ADMINUSER"
    echo "${ADMINUSER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

PROFILE_PATH="/home/${ADMINUSER}/.bash_profile"

export_lines="
export EDB_SUBSCRIPTION_TOKEN=\"${EDBTOKEN}\"
export DOCKER_HOST=unix:///run/docker.sock
export PATH=\$PATH:/opt/EDB/TPA/bin
"

if ! grep -q "EDB_SUBSCRIPTION_TOKEN" "$PROFILE_PATH" 2>/dev/null; then
    echo "Configuring environment variables in profiles..."
    echo 
    echo "$export_lines" >> /root/.bash_profile
    echo "$export_lines" >> "$PROFILE_PATH"
    chown "${ADMINUSER}:${ADMINUSER}" "$PROFILE_PATH"
fi

if ! getent group docker > /dev/null; then
    groupadd docker
fi

usermod -aG docker "${ADMINUSER}"

if [ -S /run/docker.sock ]; then
    chown root:docker /run/docker.sock
    chmod 660 /run/docker.sock
fi

TPA_SETUP_RAN="/opt/EDB/TPA/.tpa_setup_complete"
if [ ! -f "$TPA_SETUP_RAN" ]; then
    echo "Performing first time TPA configuration..."
    echo 
    export PATH="$PATH:/opt/EDB/TPA/bin"
    echo 'export PATH="$PATH:/opt/EDB/TPA/bin"' > /etc/profile.d/tpa.sh
    
    # Run EDB TPA setup
    /opt/EDB/TPA/bin/tpaexec setup
    
    touch "$TPA_SETUP_RAN"
    echo "TPA setup complete."
    echo
else
    echo "TPA already configured, skipping setup."
    echo
fi


if [ ! -f "/root/.ssh/id_rsa" ]; then
    echo "Setting up SSH keys for root..."
    echo
    mkdir -p /root/.ssh
    # Using the keys provided via Dockerfile COPY
    cp /id_rsa /root/.ssh/
    cp /id_rsa.pub /root/.ssh/
    cp /authorized_keys /root/.ssh/
    chown -R root:root /root/.ssh
    chmod 0700 /root/.ssh
    chmod 0600 /root/.ssh/*
fi


ADMIN_SSH="/home/${ADMINUSER}/.ssh"
if [ ! -f "${ADMIN_SSH}/id_rsa" ]; then
    echo "Setting up SSH keys for ${ADMINUSER}..."
    echo
    mkdir -p "$ADMIN_SSH"
    cp /root/.ssh/id_rsa "$ADMIN_SSH"/
    cp /root/.ssh/id_rsa.pub "$ADMIN_SSH"/
    cp /root/.ssh/authorized_keys "$ADMIN_SSH"/
    chown -R "${ADMINUSER}:${ADMINUSER}" "$ADMIN_SSH"
    chmod 700 "$ADMIN_SSH"
    chmod 600 "$ADMIN_SSH"/id_rsa
fi

if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
    echo "Generating SSH host keys..."
    echo
    ssh-keygen -A 
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi

echo "Starting SSH service..."
/usr/sbin/sshd

rm -f /run/nologin

echo "Container is ready. ADMINUSER: ${ADMINUSER}"
echo

# Drop into bash
/bin/bash
