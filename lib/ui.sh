#!/bin/bash
# ui.sh - Interface utilisateur pour le système de déploiement
# Gère l'affichage de la checklist interactive

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Fonction pour afficher le header
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  🛠️  DÉPLOIEMENT DE SCRIPTS - Sélectionnez vos scripts        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Fonction pour afficher le footer avec les commandes
show_footer() {
    local selected_count=$1
    local total_count=$2
    local installed_count=$3

    echo ""
    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${WHITE}RÉSUMÉ${NC}                                                      ${BLUE}│${NC}"
    echo -e "${BLUE}├────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC} Déjà installés: ${GREEN}${installed_count}${NC} scripts                                      ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Nouveaux sélectionnés: ${YELLOW}${selected_count}${NC} scripts                             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Total disponible: ${total_count} scripts                                  ${BLUE}│${NC}"
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${GRAY}[↑/↓]${NC} Naviguer  ${GRAY}[Espace]${NC} Sélectionner  ${GRAY}[a]${NC} Tout  ${GRAY}[n]${NC} Rien  ${GRAY}[p]${NC} Profils"
    echo -e "${GRAY}[Enter]${NC} Installer  ${GRAY}[q]${NC} Quitter"
    echo ""
}

# Fonction pour afficher une catégorie de scripts
show_category() {
    local category_name=$1
    local category_icon=$2

    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${category_icon} ${WHITE}${category_name}${NC}"
    echo -e "${BLUE}├────────────────────────────────────────────────────────────────┤${NC}"
}

# Fonction pour afficher un script dans la liste
show_script_item() {
    local is_selected=$1
    local is_installed=$2
    local script_name=$3
    local script_desc=$4
    local is_current=$5  # Si c'est l'élément actuellement sélectionné (pour la navigation)

    local checkbox=""
    local color="${NC}"
    local prefix=""

    if [[ "$is_installed" == "true" ]]; then
        checkbox="[${GREEN}✓ Installé${NC}]"
        color="${GRAY}"
    elif [[ "$is_selected" == "true" ]]; then
        checkbox="[${GREEN}✓${NC}]"
        color="${NC}"
    else
        checkbox="[ ]"
        color="${NC}"
    fi

    # Highlight si c'est l'élément courant
    if [[ "$is_current" == "true" ]]; then
        prefix="${CYAN}► ${NC}"
    else
        prefix="  "
    fi

    printf "${BLUE}│${NC} ${prefix}${checkbox} ${color}%-20s %-30s${NC} ${BLUE}│${NC}\n" "$script_name" "$script_desc"
}

# Fonction pour fermer une catégorie
close_category() {
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Fonction pour afficher un message d'information
show_info() {
    local message=$1
    echo -e "${BLUE}ℹ${NC}  ${message}"
}

# Fonction pour afficher un message de succès
show_success() {
    local message=$1
    echo -e "${GREEN}✓${NC} ${message}"
}

# Fonction pour afficher un message d'erreur
show_error() {
    local message=$1
    echo -e "${RED}✗${NC} ${message}"
}

# Fonction pour afficher un message d'avertissement
show_warning() {
    local message=$1
    echo -e "${YELLOW}⚠${NC}  ${message}"
}

# Fonction pour afficher une question
ask_question() {
    local question=$1
    local default=$2

    if [[ -n "$default" ]]; then
        echo -n -e "${WHITE}${question}${NC} [${CYAN}${default}${NC}]: "
    else
        echo -n -e "${WHITE}${question}${NC}: "
    fi
}

# Fonction pour afficher le menu des profils
show_profiles_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  📦 PROFILS RAPIDES                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Sélectionnez un profil pour pré-cocher ses scripts:${NC}"
    echo ""
}

# Fonction pour afficher un profil dans le menu
show_profile_option() {
    local number=$1
    local icon=$2
    local name=$3
    local description=$4
    local script_count=$5

    printf "${CYAN}[%s]${NC} ${icon} ${YELLOW}%-15s${NC} - %s (${script_count} scripts)\n" "$number" "$name" "$description"
}

# Fonction pour afficher une barre de progression
show_progress() {
    local current=$1
    local total=$2
    local script_name=$3

    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\r${BLUE}[${GREEN}"
    printf "%${filled}s" | tr ' ' '='
    printf "${GRAY}"
    printf "%${empty}s" | tr ' ' '-'
    printf "${BLUE}]${NC} ${percent}%% - Installing: ${YELLOW}${script_name}${NC}"
}

# Fonction pour afficher le résumé final de l'installation
show_install_summary() {
    local success_count=$1
    local failed_count=$2
    local total=$3

    echo ""
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    if [[ $failed_count -eq 0 ]]; then
        echo -e "${CYAN}║${GREEN}  ✓ INSTALLATION TERMINÉE AVEC SUCCÈS                           ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${YELLOW}  ⚠ INSTALLATION TERMINÉE AVEC ERREURS                          ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Installés avec succès: ${GREEN}${success_count}${NC}/${total}"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "  Échecs: ${RED}${failed_count}${NC}/${total}"
    fi
    echo ""
}

# Fonction pour afficher le mode dry-run
show_dry_run_header() {
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}  🔍 MODE DRY-RUN - Aucune modification ne sera effectuée      ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Fonction pour demander confirmation
ask_confirmation() {
    local message=$1
    local default=${2:-"Y"}

    if [[ "$default" == "Y" ]]; then
        echo -n -e "${WHITE}${message}${NC} [${GREEN}Y${NC}/${GRAY}n${NC}]: "
    else
        echo -n -e "${WHITE}${message}${NC} [${GRAY}y${NC}/${RED}N${NC}]: "
    fi

    read -r response
    response=${response:-$default}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Fonction pour afficher un spinner de chargement
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}${spin:$i:1}${NC} ${message}"
        sleep 0.1
    done
    printf "\r"
}

# Export des fonctions
export -f show_header
export -f show_footer
export -f show_category
export -f show_script_item
export -f close_category
export -f show_info
export -f show_success
export -f show_error
export -f show_warning
export -f ask_question
export -f show_profiles_menu
export -f show_profile_option
export -f show_progress
export -f show_install_summary
export -f show_dry_run_header
export -f ask_confirmation
export -f show_spinner
