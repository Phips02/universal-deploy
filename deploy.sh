#!/bin/bash
# deploy.sh - Script principal de déploiement
# Système de déploiement de scripts avec interface checklist interactive
# Version: 1.0

set -euo pipefail

# Déterminer le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_DIR="$SCRIPT_DIR/config"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Fonction pour installer automatiquement les prérequis
install_prerequisites() {
    local packages_to_install=()
    local installed_something=false

    # Détecter le gestionnaire de paquets
    local pkg_manager=""
    local update_cmd=""
    local install_cmd=""

    if command -v apt-get &> /dev/null; then
        pkg_manager="apt"
        update_cmd="apt-get update -qq"
        install_cmd="apt-get install -y -qq"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        update_cmd="yum check-update -q"
        install_cmd="yum install -y -q"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        update_cmd="dnf check-update -q"
        install_cmd="dnf install -y -q"
    elif command -v pacman &> /dev/null; then
        pkg_manager="pacman"
        update_cmd="pacman -Sy --noconfirm"
        install_cmd="pacman -S --noconfirm --needed"
    elif command -v apk &> /dev/null; then
        pkg_manager="apk"
        update_cmd="apk update -q"
        install_cmd="apk add -q"
    else
        echo "⚠️  Gestionnaire de paquets non détecté. Installation manuelle requise."
        return 1
    fi

    # Vérifier jq (essentiel)
    if ! command -v jq &> /dev/null; then
        packages_to_install+=("jq")
    fi

    # Vérifier dialog ou whiptail (optionnel mais recommandé)
    if ! command -v dialog &> /dev/null && ! command -v whiptail &> /dev/null; then
        case "$pkg_manager" in
            apt|yum|dnf)
                packages_to_install+=("dialog")
                ;;
            pacman)
                packages_to_install+=("dialog")
                ;;
            apk)
                packages_to_install+=("dialog")
                ;;
        esac
    fi

    # Installer les paquets manquants
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        echo "🔧 Installation des prérequis manquants..."
        echo "   Paquets: ${packages_to_install[*]}"
        echo ""

        # Vérifier les permissions root
        if [[ $EUID -ne 0 ]]; then
            echo "⚠️  Permissions root requises pour installer les dépendances."
            echo "   Veuillez exécuter avec sudo ou en tant que root."
            echo ""
            echo "   Paquets à installer manuellement: ${packages_to_install[*]}"
            echo ""
            return 1
        fi

        # Mettre à jour le cache des paquets
        echo "   Mise à jour du cache des paquets..."
        $update_cmd 2>/dev/null || true

        # Installer chaque paquet
        for package in "${packages_to_install[@]}"; do
            echo "   Installation de $package..."
            if $install_cmd "$package" 2>/dev/null; then
                echo "   ✅ $package installé avec succès"
                installed_something=true
            else
                echo "   ⚠️  Échec de l'installation de $package"
            fi
        done

        echo ""

        if [[ "$installed_something" == true ]]; then
            echo "✅ Prérequis installés avec succès"
            echo ""
        fi
    fi

    # Vérification finale
    if ! command -v jq &> /dev/null; then
        echo "⚠️  ATTENTION: jq n'est pas installé"
        echo "   Le système fonctionnera avec des fonctionnalités limitées."
        echo "   Installation recommandée: $pkg_manager install jq"
        echo ""
    fi
}

# Installer les prérequis au démarrage
install_prerequisites

# Charger les bibliothèques
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/tracker.sh"
source "$LIB_DIR/installer.sh"

# Variables globales
DRY_RUN=false
AUTO_MODE=false
SCRIPTS_TO_INSTALL=()

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
$(basename "$0") - Système de déploiement de scripts

USAGE:
    ./deploy.sh [OPTIONS]

OPTIONS:
    -h, --help              Afficher cette aide
    -l, --list-installed    Lister les scripts installés
    -a, --list-available    Lister tous les scripts disponibles
    -d, --dry-run          Mode simulation (aucune modification)
    --auto                  Mode automatique (non-interactif)
    --scripts "list"        Liste de scripts à installer (séparés par des virgules)
    --update-all            Mettre à jour tous les scripts installés
    --update SCRIPT         Mettre à jour un script spécifique
    --uninstall SCRIPT      Désinstaller un script
    --verify                Vérifier l'intégrité des scripts installés
    --reset                 Réinitialiser le tracker (supprime l'historique)

EXEMPLES:
    ./deploy.sh                                    # Mode interactif (défaut)
    ./deploy.sh --list-installed                   # Voir ce qui est installé
    ./deploy.sh --dry-run                          # Simulation
    ./deploy.sh --auto --scripts "00_lxc-details.sh,fail2ban"
    ./deploy.sh --update-all                       # Mettre à jour tout
    ./deploy.sh --uninstall telegram_notif         # Désinstaller un script

EOF
}

# Fonction pour lister tous les scripts disponibles
list_available_scripts() {
    echo "Scripts disponibles par catégorie:"
    echo ""

    for category_dir in "$SCRIPTS_DIR"/*; do
        if [[ -d "$category_dir" ]]; then
            local category=$(basename "$category_dir")
            echo "📁 ${category^^}:"

            # Lister les scripts dans cette catégorie
            find "$category_dir" -maxdepth 2 \( -name "*.sh" -o -type d \) | while read -r script; do
                if [[ -f "${script}.meta.json" ]] || [[ -f "${script}/install.sh.meta.json" ]]; then
                    local script_name=$(basename "$script")
                    local meta_file="${script}.meta.json"
                    [[ ! -f "$meta_file" ]] && meta_file="${script}/install.sh.meta.json"

                    if [[ -f "$meta_file" ]] && command -v jq &> /dev/null; then
                        local display_name=$(jq -r '.display_name' "$meta_file")
                        local description=$(jq -r '.description' "$meta_file")
                        printf "  • %-25s - %s\n" "$display_name" "$description"
                    else
                        echo "  • $script_name"
                    fi
                fi
            done

            echo ""
        fi
    done
}

# Fonction pour scanner et collecter tous les scripts disponibles
collect_available_scripts() {
    local -n scripts_array=$1

    for category_dir in "$SCRIPTS_DIR"/*; do
        if [[ -d "$category_dir" ]]; then
            local category=$(basename "$category_dir")

            # Chercher les scripts .sh et les dossiers avec install.sh
            for item in "$category_dir"/*; do
                if [[ -f "$item" && "$item" == *.sh ]]; then
                    # C'est un fichier .sh
                    scripts_array+=("$item")
                elif [[ -d "$item" && -f "$item/install.sh" ]]; then
                    # C'est un dossier avec install.sh
                    scripts_array+=("$item")
                fi
            done
        fi
    done
}

# Fonction pour le mode interactif
interactive_mode() {
    # Initialiser le tracker
    init_tracker

    # Collecter tous les scripts disponibles
    local all_scripts=()
    collect_available_scripts all_scripts

    if [[ ${#all_scripts[@]} -eq 0 ]]; then
        show_error "Aucun script trouvé dans $SCRIPTS_DIR"
        exit 1
    fi

    # Préparer les données pour l'affichage
    declare -A script_selected
    declare -A script_installed
    declare -A script_info

    for script in "${all_scripts[@]}"; do
        local script_name=$(basename "$script" .sh)
        script_selected["$script"]="false"

        if is_script_installed "$script_name"; then
            script_installed["$script"]="true"
        else
            script_installed["$script"]="false"
        fi

        # Charger les métadonnées
        local metadata=$(load_script_metadata "$script")
        script_info["$script"]="$metadata"
    done

    # Boucle principale de l'interface
    local quit=false
    while [[ "$quit" == "false" ]]; do
        show_header

        # Regrouper par catégorie
        local current_category=""
        local selected_count=0
        local installed_count=0

        for script in "${all_scripts[@]}"; do
            local metadata="${script_info[$script]}"
            local category=$(echo "$metadata" | jq -r '.category // "unknown"')
            local script_basename=$(basename "$script" .sh)
            local display_name=$(echo "$metadata" | jq -r --arg default "$script_basename" '.display_name // $default')
            local description=$(echo "$metadata" | jq -r '.description // ""')

            # Afficher le header de catégorie si changement
            if [[ "$category" != "$current_category" ]]; then
                [[ -n "$current_category" ]] && close_category

                case "$category" in
                    "base") show_category "BASE - Scripts essentiels" "🏠" ;;
                    "security") show_category "SECURITY - Sécurité" "🔒" ;;
                    "monitoring") show_category "MONITORING - Surveillance" "📊" ;;
                    "network") show_category "NETWORK - Réseau et VPN" "🌐" ;;
                    "utilities") show_category "UTILITIES - Utilitaires" "🔧" ;;
                    *) show_category "${category^^}" "📁" ;;
                esac
                current_category="$category"
            fi

            # Afficher le script
            show_script_item "${script_selected[$script]}" "${script_installed[$script]}" \
                            "$display_name" "$description" "false"

            # Compter
            [[ "${script_selected[$script]}" == "true" ]] && ((selected_count++))
            [[ "${script_installed[$script]}" == "true" ]] && ((installed_count++))
        done

        close_category

        # Afficher le footer
        show_footer "$selected_count" "${#all_scripts[@]}" "$installed_count"

        # Lire l'entrée utilisateur
        read -n 1 -r choice
        echo ""

        case "$choice" in
            " ")  # Espace - toggle selection
                # Pour simplifier, on va demander le numéro
                ask_question "Numéro du script à cocher/décocher" ""
                read -r num
                # TODO: implémenter la sélection par numéro
                ;;
            "a"|"A")  # Tout sélectionner
                for script in "${all_scripts[@]}"; do
                    if [[ "${script_installed[$script]}" == "false" ]]; then
                        script_selected["$script"]="true"
                    fi
                done
                ;;
            "n"|"N")  # Rien sélectionner
                for script in "${all_scripts[@]}"; do
                    script_selected["$script"]="false"
                done
                ;;
            "p"|"P")  # Profils
                show_profiles_menu

                if [[ -f "$CONFIG_DIR/profiles.json" ]]; then
                    local profile_num=1
                    jq -r '.profiles | to_entries[] | "\(.key)|\(.value.icon)|\(.value.name)|\(.value.description)"' \
                        "$CONFIG_DIR/profiles.json" | while IFS='|' read -r key icon name desc; do
                        show_profile_option "$profile_num" "$icon" "$name" "$desc" "?"
                        ((profile_num++))
                    done
                fi

                echo ""
                ask_question "Choisissez un profil (1-4, ou Entrée pour annuler)" ""
                read -r profile_choice

                if [[ -n "$profile_choice" && "$profile_choice" =~ ^[1-4]$ ]]; then
                    # Charger le profil sélectionné
                    local profile_key=$(jq -r ".profiles | keys[$((profile_choice-1))]" "$CONFIG_DIR/profiles.json")
                    local profile_scripts=$(jq -r ".profiles.$profile_key.scripts[]" "$CONFIG_DIR/profiles.json")

                    # Pré-sélectionner les scripts du profil
                    for script in "${all_scripts[@]}"; do
                        local script_name=$(basename "$script")
                        if echo "$profile_scripts" | grep -q "$script_name"; then
                            script_selected["$script"]="true"
                        fi
                    done
                fi
                ;;
            "q"|"Q")  # Quitter
                quit=true
                show_info "Déploiement annulé"
                exit 0
                ;;
            "")  # Entrée - Installer
                # Collecter les scripts sélectionnés
                SCRIPTS_TO_INSTALL=()
                for script in "${all_scripts[@]}"; do
                    if [[ "${script_selected[$script]}" == "true" ]]; then
                        SCRIPTS_TO_INSTALL+=("$script")
                    fi
                done

                if [[ ${#SCRIPTS_TO_INSTALL[@]} -eq 0 ]]; then
                    show_warning "Aucun script sélectionné"
                    sleep 2
                else
                    quit=true
                fi
                ;;
        esac
    done

    # Installer les scripts sélectionnés
    if [[ ${#SCRIPTS_TO_INSTALL[@]} -gt 0 ]]; then
        echo ""
        if ask_confirmation "Installer ${#SCRIPTS_TO_INSTALL[@]} script(s) ?"; then
            install_multiple_scripts "${SCRIPTS_TO_INSTALL[@]}"
        else
            show_info "Installation annulée"
        fi
    fi
}

# Fonction pour mettre à jour tous les scripts
update_all_scripts() {
    local installed_scripts=($(get_installed_scripts))

    if [[ ${#installed_scripts[@]} -eq 0 ]]; then
        show_info "Aucun script installé à mettre à jour"
        return 0
    fi

    echo "Mise à jour de ${#installed_scripts[@]} script(s)..."
    echo ""

    for script_name in "${installed_scripts[@]}"; do
        # Trouver le script dans le dépôt
        local script_path=$(find "$SCRIPTS_DIR" -name "$script_name" -o -name "$(dirname "$script_name")" | head -1)

        if [[ -n "$script_path" && -e "$script_path" ]]; then
            update_script "$script_path"
        else
            show_warning "Script source non trouvé: $script_name"
        fi
    done

    show_success "Mise à jour terminée"
}

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list-installed)
            show_installation_summary
            exit 0
            ;;
        -a|--list-available)
            list_available_scripts
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            show_dry_run_header
            shift
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --scripts)
            IFS=',' read -ra SCRIPTS_TO_INSTALL <<< "$2"
            shift 2
            ;;
        --update-all)
            update_all_scripts
            exit 0
            ;;
        --update)
            update_script "$2"
            exit 0
            ;;
        --uninstall)
            uninstall_script "$2"
            exit 0
            ;;
        --verify)
            verify_installed_scripts
            exit $?
            ;;
        --reset)
            if ask_confirmation "ATTENTION: Cela supprimera tout l'historique. Continuer ?"; then
                reset_tracker
            fi
            exit 0
            ;;
        *)
            show_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Mode par défaut: interactif
if [[ "$AUTO_MODE" == "false" && ${#SCRIPTS_TO_INSTALL[@]} -eq 0 ]]; then
    interactive_mode
elif [[ ${#SCRIPTS_TO_INSTALL[@]} -gt 0 ]]; then
    # Mode automatique avec liste de scripts
    init_tracker

    # Résoudre les chemins des scripts
    local resolved_scripts=()
    for script_name in "${SCRIPTS_TO_INSTALL[@]}"; do
        local found=$(find "$SCRIPTS_DIR" -name "$script_name" | head -1)
        if [[ -n "$found" ]]; then
            resolved_scripts+=("$found")
        else
            show_error "Script non trouvé: $script_name"
        fi
    done

    if [[ ${#resolved_scripts[@]} -gt 0 ]]; then
        install_multiple_scripts "${resolved_scripts[@]}"
    fi
else
    show_error "Aucune action spécifiée"
    show_help
    exit 1
fi
