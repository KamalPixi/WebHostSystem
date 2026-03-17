#!/bin/bash
# 01_secure_server.sh - Run as root

# 0. Optional: Set this before running to auto-install root SSH key
# HOST_SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5KSEjq7JlzkywLQE8EuCLLHkOYVQ5l9662UkMbgC6V kamalkhan@KamalKhan.local"

# 1. Update & Install Essentials
apt update && apt upgrade -y
apt install -y ufw curl git xfsprogs openssh-server fail2ban unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

# 2. Secure SSH (Host Only)
# Disable password login; only Allow Public Key for root
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Optional: Install root SSH key if provided
if [ -n "$HOST_SSH_PUBKEY" ]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  echo "$HOST_SSH_PUBKEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

systemctl restart ssh

# 3. Setup Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh         # Port 22
ufw allow http        # Port 80 (Traefik)
ufw allow https       # Port 443 (Traefik)
ufw allow 2200:2300/tcp  # Range for Customer SSH containers

ufw --force enable

# 4. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 5. Configure Docker for XFS Quotas
# Note: Assumes your data drive is formatted XFS and mounted at /var/lib/docker
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"]
}
EOF
systemctl restart docker

echo "✅ Server Secured. Docker installed. SSH password login disabled for Host."
