#!/bin/bash

# Script de déploiement du prompt personnalisé
# Auteur: Phips
# Version: 1.1

set -euo pipefail  # Mode strict pour une meilleure gestion d'erreurs

echo "============================================"
echo "🎯 Configuration du prompt personnalisé"
echo "============================================"

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration du prompt personnalisé
CUSTOM_PS1='export PS1="\[\e[1;32m\]┌──(\[\e[m\]\[\e[1;34m\]\u\[\e[m\]\[\e[1;32m\] ► \[\e[m\]\[\e[1;34m\]\h\[\e[m\]\[\e[1;32m\])-[\[\e[m\]\[\e[38;5;214m\]\w\[\e[m\]\[\e[1;32m\]]\n└─\[\e[m\]\[\e[1;37m\]\$ \[\e[0m\]"'

# Mode automatique (remplacer sans demander)
AUTO_REPLACE=${AUTO_REPLACE:-false}

# Fonction de logging uniforme avec le script principal
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "ERROR")   echo -e "${RED}✗ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✓ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠ $message${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ $message${NC}" ;;
        *)         echo "$message" ;;
    esac
}

# Fonction de sauvegarde améliorée
backup_bashrc() {
    if [[ -f ~/.bashrc ]]; then
        local backup_file="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
        if cp ~/.bashrc "$backup_file"; then
            log "SUCCESS" "Sauvegarde créée: $backup_file"
            echo "$backup_file" > /tmp/bashrc_backup_location.txt  # Pour référence future
        else
            log "ERROR" "Impossible de créer la sauvegarde"
            exit 1
        fi
    else
        log "INFO" "Aucun fichier .bashrc existant"
    fi
}

# Fonction pour vérifier si le prompt existe déjà
check_existing_prompt() {
    # Détecter les prompts personnalisés (avec le caractère spécial ┌ ou les commentaires)
    if grep -q "┌──(" ~/.bashrc 2>/dev/null || grep -q "Prompt personnalisé moderne - Setup Scripts" ~/.bashrc 2>/dev/null; then
        log "WARNING" "Un prompt personnalisé existe déjà dans .bashrc"
        
        if [[ "$AUTO_REPLACE" == "true" ]]; then
            log "INFO" "Mode automatique - Remplacement du prompt existant"
        else
            echo -n "Voulez-vous le remplacer ? (y/N): "
            read -r reply < /dev/tty
            
            if [[ ! "$reply" =~ ^[Yy]$ ]]; then
                log "INFO" "Installation annulée par l'utilisateur"
                exit 0
            fi
        fi
        
        # Supprimer tous les prompts personnalisés existants
        log "INFO" "Suppression de l'ancien prompt..."
        
        # Créer un fichier temporaire sans les prompts personnalisés
        grep -v "┌──(" ~/.bashrc | \
        awk '
            # Supprimer les blocs avec commentaires
            /^# ============================================$/ && 
            getline && /Prompt personnalisé moderne - Setup Scripts/ {
                # Ignorer tout jusquà la fin du bloc
                while (getline && !/^# ============================================$/) {}
                next
            }
            { print }
        ' > ~/.bashrc.tmp
        
        if mv ~/.bashrc.tmp ~/.bashrc; then
            log "SUCCESS" "Ancien prompt supprimé"
        else
            log "ERROR" "Impossible de supprimer l'ancien prompt"
            exit 1
        fi
    fi
}

# Fonction principale d'installation
install_prompt() {
    log "INFO" "Configuration du prompt..."
    
    # Créer le fichier .bashrc s'il n'existe pas
    touch ~/.bashrc
    
    # Vérifier que l'écriture est possible
    if [[ ! -w ~/.bashrc ]]; then
        log "ERROR" "Impossible d'écrire dans ~/.bashrc (permissions)"
        exit 1
    fi
    
    # Ajouter le prompt avec un bloc bien délimité
    {
        echo ""
        echo "# ============================================"
        echo "# Prompt personnalisé moderne - Setup Scripts"
        echo "# Couleurs: Vert (bordures) | Bleu (user/host) | Orange (répertoire)"
        echo "# Date d'installation: $(date)"
        echo "# ============================================"
        echo "$CUSTOM_PS1"
        echo "# ============================================"
    } >> ~/.bashrc
    
    log "SUCCESS" "Prompt ajouté à ~/.bashrc"
}

# Fonction de test améliorée
test_prompt() {
    log "INFO" "Test du nouveau prompt..."
    
    # Vérifier que le prompt a été ajouté
    if ! grep -q "┌──(" ~/.bashrc; then
        log "ERROR" "Le prompt n'a pas été correctement ajouté"
        exit 1
    fi
    
    log "SUCCESS" "Prompt configuré avec succès!"
    
    echo ""
    echo -e "${YELLOW}Aperçu de votre nouveau prompt:${NC}"
    echo -e "┌──(\033[1;34m$(whoami)\033[0m \033[1;32m►\033[0m \033[1;34m$(hostname)\033[0m\033[1;32m)-[\033[38;5;214m$(pwd)\033[1;32m]\033[0m"
    echo -e "\033[1;32m└─\033[1;37m\$\033[0m echo 'Hello World!'"
    echo ""
}

# Fonction d'information améliorée
show_info() {
    echo ""
    echo -e "${BLUE}📋 Informations sur votre prompt:${NC}"
    echo -e "   • ${GREEN}Bordures vertes${NC} : style moderne et professionnel"
    echo -e "   • ${BLUE}Nom d'utilisateur/hostname en bleu${NC} : optimisé daltoniens"
    echo -e "   • Répertoire en ${YELLOW}orange${NC} : excellent contraste"
    echo -e "   • Symbole ${GREEN}►${NC} : design moderne et dynamique"
    echo ""
    echo -e "${YELLOW}💡 Conseils d'utilisation:${NC}"
    echo -e "   • Pour appliquer immédiatement: ${GREEN}source ~/.bashrc${NC}"
    echo -e "   • Le prompt sera conservé après redémarrage"
    echo -e "   • Redémarrez votre terminal pour voir les changements"
    
    # Afficher le chemin de sauvegarde s'il existe
    if [[ -f /tmp/bashrc_backup_location.txt ]]; then
        local backup_location=$(cat /tmp/bashrc_backup_location.txt)
        echo -e "   • Pour restaurer l'ancien prompt: ${GREEN}cp $backup_location ~/.bashrc${NC}"
        rm -f /tmp/bashrc_backup_location.txt  # Nettoyer le fichier temporaire
    fi
}

# Vérification des prérequis améliorée
check_requirements() {
    log "INFO" "Vérification des prérequis..."
    
    # Vérifier le répertoire HOME
    if [[ ! -d "$HOME" ]]; then
        log "ERROR" "Répertoire HOME non trouvé"
        exit 1
    fi
    
    # Vérifier les permissions d'écriture
    if [[ ! -w "$HOME" ]]; then
        log "ERROR" "Pas de permissions d'écriture dans $HOME"
        exit 1
    fi
    
    # Vérifier si on est dans un terminal compatible
    if [[ -z "${TERM:-}" ]]; then
        log "WARNING" "Variable TERM non définie, le prompt pourrait ne pas s'afficher correctement"
    fi
    
    # Vérifier que bash est utilisé
    if [[ -z "${BASH_VERSION:-}" ]]; then
        log "WARNING" "Ce script est optimisé pour bash"
    fi
    
    log "SUCCESS" "Prérequis validés"
}

# Fonction de nettoyage en cas d'erreur
cleanup_on_error() {
    log "ERROR" "Une erreur est survenue pendant l'installation"
    
    # Restaurer la sauvegarde si elle existe
    if [[ -f /tmp/bashrc_backup_location.txt ]]; then
        local backup_location=$(cat /tmp/bashrc_backup_location.txt)
        if [[ -f "$backup_location" ]]; then
            log "INFO" "Restauration de la sauvegarde..."
            cp "$backup_location" ~/.bashrc
            log "SUCCESS" "Sauvegarde restaurée"
        fi
        rm -f /tmp/bashrc_backup_location.txt
    fi
    
    exit 1
}

# Script principal avec gestion d'erreurs
main() {
    # Trap pour gérer les erreurs
    trap cleanup_on_error ERR
    
    check_requirements
    backup_bashrc
    check_existing_prompt
    install_prompt
    test_prompt
    show_info
    
    echo ""
    log "SUCCESS" "🎉 Installation terminée avec succès!"
    echo -e "${BLUE}👉${NC} Pour appliquer immédiatement: ${GREEN}source ~/.bashrc${NC}"
    echo -e "${BLUE}👉${NC} Ou redémarrez votre terminal"
}

# Exécution du script principal
main "$@"