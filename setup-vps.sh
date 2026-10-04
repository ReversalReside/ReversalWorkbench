#!/bin/bash

# ============================================================
# ReversalReside VPS Auto-Installer v4.0 (DEBUG MODE)
# ============================================================

# --- ВСТАВЬ СЮДА СВОЙ ПУБЛИЧНЫЙ КЛЮЧ ОТ WINDOWS ПК ---
MY_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQQDfwfncyRA+zxFMgXPLOshcmKBN+TvGsvIqvGVfAd ReversalReside@HomePC"
# -----------------------------------------------------

echo "🚀 [1/6] Запуск установщика..."

echo "🔄 [2/6] Обновление системы (это может занять время)..."
pacman -Sy --noconfirm
pacman -Su --noconfirm

echo "📦 [3/6] Установка пакетов..."
pacman -S --noconfirm openssh ufw fail2ban nginx docker zsh curl wget git cronie

echo "🔑 [4/6] Настройка SSH и ключей..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$MY_SSH_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Отключаем парольный вход
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl enable --now sshd

echo "🛡️ [5/6] Настройка фаервола UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
yes | ufw enable

echo "⚙️ [6/6] Запуск сервисов..."
systemctl enable --now nginx docker fail2ban cronie

echo ""
echo "✅ ✅ ✅ ВСЁ ГОТОВО! ✅ ✅ ✅"
echo "Твой IP: $(hostname -I | awk '{print $1}')"
echo "Команда для входа: ssh root@$(hostname -I | awk '{print $1}')"
