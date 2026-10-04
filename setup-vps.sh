#!/bin/bash

# ============================================================
# ReversalReside VPS Auto-Installer v1.0
# Для Omarchy/Arch Linux
# Использование: curl -fsSL https://raw.githubusercontent.com/ZZenisky/vps-installer/main/install.sh | sudo bash
# ============================================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/var/log/vps_installer.log"

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }

# Проверки
check_root() {
    [ "$EUID" -ne 0 ] && error "Запустите с sudo: curl ... | sudo bash"
    success "Root права подтверждены"
}

check_system() {
    if ! grep -qi "arch\|omarchy" /etc/os-release 2>/dev/null; then
        warning "Система не определена как Arch/Omarchy, продолжаем на свой риск..."
    else
        success "Система: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    fi
}

check_internet() {
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        error "Нет подключения к интернету"
    fi
    success "Интернет подключен"
}

# Обновление системы
update_system() {
    log "Обновление пакетной базы..."
    pacman -Sy --noconfirm >> "$LOG_FILE" 2>&1
    log "Обновление пакетов..."
    pacman -Su --noconfirm >> "$LOG_FILE" 2>&1
    success "Система обновлена"
}

# Установка пакетов
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

# Настройка SSH
configure_ssh() {
    log "Настройка SSH безопасности..."
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    
    # Безопасные настройки
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    systemctl enable sshd
    systemctl restart sshd
    
    success "SSH настроен (только по ключу)"
}

# Фаервол
configure_firewall() {
    log "Настройка UFW фаервола..."
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw --force enable
    
    success "UFW активирован (порты: 22, 80, 443)"
}

# Fail2Ban
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
    
    success "Fail2Ban настроен (бан на 2 часа после 3 попыток)"
}

# Nginx
configure_nginx() {
    log "Настройка Nginx..."
    
    mkdir -p /var/www/html
    
    cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Server - ReversalReside</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255,255,255,0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        h1 { margin: 0 0 20px 0; font-size: 2.5em; }
        p { font-size: 1.2em; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Сервер работает!</h1>
        <p>Установлено автоматически ReversalReside VPS Installer</p>
        <p><small>$(hostname) | $(date)</small></p>
    </div>
</body>
</html>
HTML
    
    cat > /etc/nginx/nginx.conf <<'EOF'
user http;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    
    server {
        listen 80;
        server_name _;
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
    }
}
EOF
    
    systemctl enable nginx
    systemctl start nginx
    
    success "Nginx настроен и запущен"
}

# Docker
configure_docker() {
    log "Настройка Docker..."
    
    systemctl enable docker
    systemctl start docker
    
    # Создаем группу docker если её нет
    groupadd -f docker
    
    success "Docker установлен и запущен"
}

# Автообновления
setup_auto_updates() {
    log "Настройка автообновлений..."
    
    cat > /usr/local/bin/auto-update.sh <<'EOF'
#!/bin/bash
pacman -Syu --noconfirm >> /var/log/auto-update.log 2>&1
systemctl restart nginx docker
EOF
    
    chmod +x /usr/local/bin/auto-update.sh
    
    # Cron задача (каждую неделю в воскресенье 3:00)
    (crontab -l 2>/dev/null; echo "0 3 * * 0 /usr/local/bin/auto-update.sh") | crontab -
    systemctl enable cronie
    systemctl start cronie
    
    success "Автообновления настроены (воскресенье 3:00)"
}

# Утилита информации
create_info_tool() {
    log "Создание утилиты vps-info..."
    
    cat > /usr/local/bin/vps-info <<'EOF'
#!/bin/bash
echo -e "\033[0;36m╔════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║     VPS Server Information             ║\033[0m"
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
echo ""
echo -e "\033[1;33mHostname:\033[0m      $(hostname)"
echo -e "\033[1;33mIP Address:\033[0m    $(hostname -I | awk '{print $1}')"
echo -e "\033[1;33mOS:\033[0m           $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo -e "\033[1;33mKernel:\033[0m        $(uname -r)"
echo -e "\033[1;33mUptime:\033[0m        $(uptime -p)"
echo -e "\033[1;33mMemory:\033[0m        $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo -e "\033[1;33mDisk:\033[0m          $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""
echo -e "\033[1;32mActive Services:\033[0m"
for svc in sshd nginx docker fail2ban ufw; do
    if systemctl is-active --quiet $svc 2>/dev/null; then
        echo -e "  \033[0;32m●\033[0m $svc"
    else
        echo -e "  \033[0;31m●\033[0m $svc (inactive)"
    fi
done
echo ""
echo -e "\033[0;36m╔════════════════════════════════════════╗\033[0m"
EOF
    
    chmod +x /usr/local/bin/vps-info
    success "Команда 'vps-info' создана"
}

# Финальная проверка
final_check() {
    log "Финальная проверка сервисов..."
    echo ""
    
    local all_ok=true
    for service in sshd nginx docker fail2ban; do
        if systemctl is-active --quiet "$service"; then
            success "✓ $service активен"
        else
            warning "✗ $service не активен"
            all_ok=false
        fi
    done
    
    echo ""
    if [ "$all_ok" = true ]; then
        success "Все сервисы работают корректно!"
    else
        warning "Некоторые сервисы требуют внимания"
    fi
}

# Главный процесс
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   ReversalReside VPS Auto-Installer v1.0     ║${NC}"
    echo -e "${CYAN}║   Для Omarchy/Arch Linux                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_internet
    check_system
    
    echo ""
    update_system
    install_packages
    configure_ssh
    configure_firewall
    configure_fail2ban
    configure_nginx
    configure_docker
    setup_auto_updates
    create_info_tool
    final_check
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ Установка завершена успешно!          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Полезные команды:${NC}"
    echo -e "  ${CYAN}vps-info${NC}              - Информация о сервере"
    echo -e "  ${CYAN}systemctl status nginx${NC} - Статус веб-сервера"
    echo -e "  ${CYAN}ufw status${NC}            - Статус фаервола"
    echo -e "  ${CYAN}docker ps${NC}             - Запущенные контейнеры"
    echo ""
    echo -e "${BLUE}Логи: $LOG_FILE${NC}"
    echo ""
}

main