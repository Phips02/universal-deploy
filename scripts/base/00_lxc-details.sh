# Version 1.0
# A placer dans /etc/profile.d/00_lxc-details.sh

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Récupération des informations système
HOSTNAME=$(hostname)
OS_INFO=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
KERNEL=$(uname -r)
ARCH=$(uname -m)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{print $2}')
MEMORY=$(free | awk 'NR==2{printf "%.1f/%.1fGi (%.1f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
DISK_ROOT=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
CPU_CORES=$(nproc)
USERS_LOGGED=$(who | wc -l)
USERS_DETAILS=$(who | awk '{printf "%s@%s ", $1, $2}' | sed 's/ $//')
PROCESSES=$(ps aux | wc -l)
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo ""
echo -e "${BLUE}               INFORMATIONS SYSTÈME               ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🏠   Hostname:${NC} $HOSTNAME"
echo -e "${GREEN}🌐   IP Address:${NC} $IP_ADDRESS"
echo -e "${GREEN}📅   Date/Heure:${NC} $DATE_TIME"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}⏱️   Uptime:${NC} $UPTIME"
echo -e "${GREEN}🧠   Mémoire:${NC} $MEMORY"
echo -e "${GREEN}💾   Disque (/) :${NC} $DISK_ROOT"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}👥   Utilisateurs:${NC} $USERS_LOGGED connecté(s)"
if [ $USERS_LOGGED -gt 0 ]; then
    who | while read line; do
        USER=$(echo $line | awk '{print $1}')
        TTY=$(echo $line | awk '{print $2}')
        TIME=$(echo $line | awk '{print $3" "$4}')
        echo -e "      → ${CYAN}$USER${NC} sur ${YELLOW}$TTY${NC} depuis $TIME"
    done
fi
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo ""