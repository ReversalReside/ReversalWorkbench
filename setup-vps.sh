#!/bin/bash

# --- ВСТАВЬ СЮДА СВОЙ ПУБЛИЧНЫЙ КЛЮЧ ОТ WINDOWS ПК ---
MY_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQQDfwfncyRA+zxFMgXPLOshcmKBN+TvGsvIqvGVfAd ReversalReside@HomePC"
# -----------------------------------------------------

set -e

echo "🚀 Запуск полной автоматизации..."

echo "🔄 Обновление системы..."
pacman -Sy --noconfirm
pacman -Su --noconfirm

echo "📦 Установка пакетов..."
pacman -S --noconfirm openssh ufw fail2ban nginx docker zsh curl wget git

echo "🔑 Настройка SSH..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$MY_SSH_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Безопасность SSH
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl enable --now sshd

echo "🛡️ Настройка фаервола..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
echo "y" | ufw enable

echo "⚙️ Запуск сервисов..."
systemctl enable --now nginx docker fail2ban

echo "✅ ВСЁ ГОТОВО! Введи 'vps-info' для данных."
