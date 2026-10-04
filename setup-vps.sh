#!/bin/bash

# ============================================================
# ReversalReside VPS Auto-Installer v2.0
# Repository: https://github.com/ReversalReside/ReversalWorkbench
# Usage: curl -fsSL <raw_url> | sudo bash
# ============================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/var/log/vps_installer.log"

# Функции логирования
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }

# --- ПРОВЕРКИ ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Запустите с правами root: curl ... | sudo bash"
    fi
    success "Root права подтверждены"
}

check_internet() {
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        error "Нет подключения к интернету"
    fi
    success "Интернет подключен"
}

# --- ОБНОВЛЕНИЕ И ПАКЕТЫ ---
update_system() {
    log "Обновление системы..."
    pacman -Sy --noconfirm >> "$LOG_FILE" 2>&1
    pacman -Su --noconfirm >> "$LOG_FILE" 2>&1
    success "Система обновлена"
}

install_packages() {
    log "Установка базовых пакетов..."
    local PACKAGES=(
        vim htop git curl wget net-tools 
        openssh fail2ban ufw nginx 
        docker docker-compose zsh python3
        certbot cronie
    )
    pacman -S --noconfirm "${PACKAGES[@]}" >> "$LOG_FILE" 2>&1
    success "Пакеты установлены (${#PACKAGES[@]} шт.)"
}

# --- НАСТРОЙКА БЕЗОПАСНОСТИ ---
configure_ssh_key() {
    log "Настройка SSH доступа..."
    
    # Резервное копирование конфига
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    
    # Безопасные настройки
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    systemctl enable sshd
    systemctl restart sshd
    
    # Добавление ключа из переменной окружения (GitHub Secret)
    if [ -n "$DEPLOY_KEY" ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        echo "$DEPLOY_KEY" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        success "SSH ключ из DEPLOY_KEY успешно добавлен"
    else
        warning "Переменная DEPLOY_KEY пуста. Ключ не добавлен."
    fi
}

configure_firewall() {
    log "Настройка UFW фаервола..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw --force enable
    success "UFW активирован"
}

configure_fail2ban() {
    log "Настройка Fail2Ban..."
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 7200
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    systemctl enable fail2ban
    systemctl start fail2ban
    success "Fail2Ban настроен"
}

# --- СЕРВИСЫ ---
configure_nginx() {
    log "Настройка Nginx..."
    mkdir -p /var/www/html
    
    cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>VPS Server - ReversalReside</title>
    <style>
        body { font-family: sans-serif; background: #1a1a1a; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .box { text-align: center; padding: 40px; border: 1px solid #333; border-radius: 10px; }
        h1 { color: #00ff9d; }
    </style>
</head>
<body>
    <div class="box">
        <h1>🚀 Сервер работает!</h1>
        <p>ReversalReside VPS Installer v2.0</p>
    </div>
</body>
</html>
HTML

    systemctl enable nginx
    systemctl start nginx
    success "Nginx запущен"
}

configure_docker() {
    log "Настройка Docker..."
    systemctl enable docker
    systemctl start docker
    groupadd -f docker
    success "Docker запущен"
}

# --- УТИЛИТЫ ---
create_info_tool() {
    log "Создание утилиты vps-info..."
    cat > /usr/local/bin/vps-info <<'EOF'
#!/bin/bash
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "\033[0;36m╔════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║     VPS Server Information             ║\033[0m"
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
echo -e "\033[1;33mIP Address:\033[0m    $SERVER_IP"
echo -e "\033[1;33mConnection:\033[0m   ssh root@$SERVER_IP"
if [ -s /root/.ssh/authorized_keys ]; then
    echo -e "\033[0;32m● SSH Keys: Active\033[0m"
else
    echo -e "\033[0;31m● SSH Keys: Missing\033[0m"
fi
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
EOF
    chmod +x /usr/local/bin/vps-info
}

# --- ГЛАВНЫЙ ПРОЦЕСС ---
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   ReversalReside VPS Auto-Installer v2.0 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_internet
    update_system
    install_packages
    configure_ssh_key
    configure_firewall
    configure_fail2ban
    configure_nginx
    configure_docker
    create_info_tool
    
    echo ""
    success "═══════════════════════════════════════"
    success "  Установка завершена успешно!"
    success "═══════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}Выполни команду 'vps-info' для получения данных.${NC}"
    echo ""
}

main
