#!/bin/bash

# ============================================================
# ReversalReside VPS Auto-Installer v3.0 (FULL AUTO)
# Repository: https://github.com/ReversalReside/ReversalWorkbench
# ============================================================

# --- ВСТАВЬ СЮДА СВОЙ ПУБЛИЧНЫЙ КЛЮЧ ОТ WINDOWS ПК ---
MY_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQQDfwfncyRA+zxFMgXPLOshcmKBN+TvGsvIqvGVfAd ReversalReside@HomePC"
# -----------------------------------------------------

set -e

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

check_root() {
    [ "$EUID" -ne 0 ] && error "Запусти с sudo!"
}

install_base() {
    log "Обновление и установка пакетов..."
    pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1
    pacman -S --noconfirm openssh ufw fail2ban nginx docker zsh curl wget git >> "$LOG_FILE" 2>&1
    success "Пакеты установлены"
}

setup_ssh() {
    log "Настройка SSH..."
    
    # Безопасность
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    systemctl enable sshd
    systemctl restart sshd

    # Добавляем твой ключ
    if [ -n "$MY_SSH_KEY" ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        echo "$MY_SSH_KEY" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        success "Твой SSH ключ установлен!"
    else
        error "Ключ не найден в скрипте!"
    fi
}

setup_firewall() {
    log "Настройка UFW..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw --force enable
    success "Фаервол включен"
}

setup_services() {
    log "Запуск сервисов..."
    systemctl enable --now nginx docker fail2ban
    success "Сервисы запущены"
}

create_info_tool() {
    cat > /usr/local/bin/vps-info <<'EOF'
#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
echo -e "\033[0;36m╔════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║     ReversalReside Server Info         ║\033[0m"
echo -e "\033[0;36m╚════════════════════════════════════════╝\033[0m"
echo -e "\033[1;33mIP для подключения:\033[0m $IP"
echo -e "\033[1;33mКоманда:\033[0m       ssh root@$IP"
if [ -s /root/.ssh/authorized_keys ]; then
    echo -e "\033[0;32m● Доступ по ключу: АКТИВЕН\033[0m"
fi
EOF
    chmod +x /usr/local/bin/vps-info
}

main() {
    echo -e "${CYAN}🚀 Запуск полной автоматизации...${NC}"
    check_root
    install_base
    setup_ssh
    setup_firewall
    setup_services
    create_info_tool
    
    echo ""
    success "✅ ВСЁ ГОТОВО! Введи 'vps-info' для данных."
    echo ""
}

main
