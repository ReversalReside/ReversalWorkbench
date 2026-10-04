#!/bin/bash

# ============================================================
# ReversalReside VPS Auto-Installer v5.0 (FULL AUTO)
# Repository: https://github.com/ReversalReside/ReversalWorkbench
# Usage: curl -fsSL <raw_url> | sudo bash
# ============================================================

# --- ВСТАВЬ СЮДА СВОЙ ПУБЛИЧНЫЙ КЛЮЧ ОТ WINDOWS ПК ---
MY_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQQDfwfncyRA+zxFMgXPLOshcmKBN+TvGsvIqvGVfAd ReversalReside@HomePC"
# -----------------------------------------------------

set -e

echo "🚀 [START] Запуск полной автоматизации ReversalReside..."

# 1. Обновление системы
echo "🔄 [1/6] Обновление пакетной базы..."
pacman -Sy --noconfirm
pacman -Su --noconfirm

# 2. Установка пакетов
echo "📦 [2/6] Установка необходимого софта..."
pacman -S --noconfirm openssh ufw fail2ban nginx docker zsh curl wget git cronie

# 3. Настройка SSH и ключей
echo "🔑 [3/6] Настройка безопасного доступа..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$MY_SSH_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Отключаем парольный вход для безопасности
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl enable --now sshd

# 4. Настройка Фаервола
echo "🛡️ [4/6] Активация UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
yes | ufw enable

# 5. Настройка Nginx и стартовой страницы
echo "🌐 [5/6] Настройка веб-сервера..."
mkdir -p /srv/http
chown http:http /srv/http

cat > /srv/http/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>ReversalReside Server</title>
    <style>
        body { font-family: 'Segoe UI', monospace; background: #0d1117; color: #c9d1d9; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .box { border: 1px solid #30363d; padding: 40px; border-radius: 12px; text-align: center; background: #161b22; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
        h1 { color: #58a6ff; margin: 0 0 10px 0; }
        p { color: #8b949e; }
    </style>
</head>
<body>
    <div class="box">
        <h1>🚀 ReversalReside VPS Online</h1>
        <p>Omarchy • Nginx • Docker • UFW</p>
        <p><small>Automated Installation v5.0</small></p>
    </div>
</body>
</html>
HTML

# Переписываем конфиг Nginx под Arch-стандарты
cat > /etc/nginx/nginx.conf <<'EOF'
user http;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name localhost;
        root /srv/http;
        index index.html;
        location / { try_files $uri $uri/ =404; }
    }
}
EOF

systemctl enable --now nginx

# 6. Сервисы и утилиты
echo "⚙️ [6/6] Запуск фоновых сервисов..."
systemctl enable --now docker fail2ban cronie

# Создаем утилиту vps-info с правильным определением IP
cat > /usr/local/bin/vps-info <<'EOF'
#!/bin/bash
IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
echo -e "\033[0;36m╔════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║     ReversalReside Server Info         ║\033[0m"
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
echo -e "\033[1;33mHostname:\033[0m      $(hostname)"
echo -e "\033[1;33mIP Address:\033[0m    ${GREEN}$IP${NC}"
echo -e "\033[1;33mConnection:\033[0m   ssh root@$IP"
if [ -s /root/.ssh/authorized_keys ]; then
    echo -e "\033[0;32m● SSH Key Status: ACTIVE\033[0m"
fi
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
EOF
chmod +x /usr/local/bin/vps-info

echo ""
echo "✅ ✅ ✅ УСТАНОВКА ЗАВЕРШЕНА! ✅ ✅ ✅"
echo "Теперь ты можешь подключаться с Windows по SSH."
echo "Введи команду 'vps-info' для проверки."
