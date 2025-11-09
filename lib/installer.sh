#!/bin/bash
# installer.sh - Logique d'installation des scripts
# Gère l'installation, la désinstallation et les mises à jour

# Fonction pour charger les métadonnées d'un script
load_script_metadata() {
    local script_path=$1
    local meta_file="${script_path}.meta.json"

    if [[ -f "$meta_file" ]] && command -v jq &> /dev/null; then
        cat "$meta_file"
    else
        # Métadonnées par défaut si le fichier n'existe pas
        echo '{
            "name": "'"$(basename "$script_path")"'",
            "display_name": "'"$(basename "$script_path")"'",
            "description": "No description available",
            "category": "unknown",
            "version": "1.0",
            "destination": "/usr/local/bin/",
            "requires_packages": [],
            "requires_config": false,
            "requires_reboot": false
        }'
    fi
}

# Fonction pour installer les packages requis
install_required_packages() {
    local packages=$1

    if [[ -z "$packages" || "$packages" == "[]" ]]; then
        return 0
    fi

    echo "Installation des packages requis..."

    if command -v jq &> /dev/null; then
        local pkg_list=$(echo "$packages" | jq -r '.[]' | tr '\n' ' ')
    else
        # Fallback: supposer que c'est une liste simple
        local pkg_list="$packages"
    fi

    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y $pkg_list
    elif command -v yum &> /dev/null; then
        yum install -y $pkg_list
    elif command -v dnf &> /dev/null; then
        dnf install -y $pkg_list
    else
        echo "Gestionnaire de paquets non supporté"
        return 1
    fi
}

# Fonction pour installer un script
install_script() {
    local script_path=$1
    local dry_run=${2:-false}

    local metadata=$(load_script_metadata "$script_path")
    local script_name=$(echo "$metadata" | jq -r '.name')
    local destination=$(echo "$metadata" | jq -r '.destination')
    local category=$(echo "$metadata" | jq -r '.category')
    local version=$(echo "$metadata" | jq -r '.version')
    local requires_packages=$(echo "$metadata" | jq -r '.requires_packages')
    local requires_config=$(echo "$metadata" | jq -r '.requires_config')
    local post_install=$(echo "$metadata" | jq -r '.post_install // []')

    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY-RUN] Installerait: $script_name → $destination"
        return 0
    fi

    # Installer les packages requis
    if [[ -n "$requires_packages" && "$requires_packages" != "[]" ]]; then
        install_required_packages "$requires_packages" || return 1
    fi

    # Déterminer si c'est un dossier ou un fichier
    if [[ -d "$script_path" ]]; then
        # C'est un dossier, chercher install.sh ou deploy.sh
        if [[ -f "$script_path/install.sh" ]]; then
            cd "$script_path"
            bash install.sh || return 1
            cd - > /dev/null
        elif [[ -f "$script_path/deploy.sh" ]]; then
            cd "$script_path"
            bash deploy.sh || return 1
            cd - > /dev/null
        else
            # Copier tout le dossier
            mkdir -p "$(dirname "$destination")"
            cp -r "$script_path" "$destination/" || return 1
        fi
    else
        # C'est un fichier simple
        mkdir -p "$(dirname "$destination")"

        # Si destination est un dossier, ajouter le nom du fichier
        if [[ "$destination" == */ ]]; then
            destination="${destination}$(basename "$script_path")"
        fi

        cp "$script_path" "$destination" || return 1
        chmod +x "$destination" 2>/dev/null || true
    fi

    # Exécuter les commandes post-installation
    if [[ -n "$post_install" && "$post_install" != "[]" ]]; then
        echo "$post_install" | jq -r '.[]' | while read -r cmd; do
            if [[ -n "$cmd" ]]; then
                eval "$cmd" || echo "  Avertissement: échec de la commande post-install: $cmd"
            fi
        done
    fi

    # Calculer le checksum
    local checksum=""
    if [[ -f "$destination" ]]; then
        checksum=$(calculate_checksum "$destination")
    fi

    # Ajouter au tracker
    add_script_to_tracker "$script_name" "$category" "$version" "$destination" "$checksum"

    return 0
}

# Fonction pour désinstaller un script
uninstall_script() {
    local script_name=$1

    # Récupérer les infos du script depuis le tracker
    local script_info=$(get_script_info "$script_name")

    if [[ -z "$script_info" ]]; then
        echo "Script $script_name non trouvé dans le tracker"
        return 1
    fi

    local destination=$(echo "$script_info" | jq -r '.destination')

    # Supprimer le fichier/dossier
    if [[ -e "$destination" ]]; then
        rm -rf "$destination"
        echo "✓ $destination supprimé"
    fi

    # Retirer du tracker
    remove_script_from_tracker "$script_name"

    echo "✓ $script_name désinstallé"
    return 0
}

# Fonction pour mettre à jour un script
update_script() {
    local script_path=$1

    local metadata=$(load_script_metadata "$script_path")
    local script_name=$(echo "$metadata" | jq -r '.name')
    local new_version=$(echo "$metadata" | jq -r '.version')
    local installed_version=$(get_installed_version "$script_name")

    if [[ -z "$installed_version" ]]; then
        echo "Script $script_name n'est pas installé"
        return 1
    fi

    echo "Mise à jour de $script_name: $installed_version → $new_version"

    # Réinstaller le script
    install_script "$script_path" || return 1

    # Mettre à jour le tracker
    local destination=$(echo "$metadata" | jq -r '.destination')
    local checksum=$(calculate_checksum "$destination")
    update_script_in_tracker "$script_name" "$new_version" "$checksum"

    echo "✓ $script_name mis à jour avec succès"
    return 0
}

# Fonction pour vérifier si un script a besoin de configuration
needs_configuration() {
    local script_path=$1
    local metadata=$(load_script_metadata "$script_path")
    local requires_config=$(echo "$metadata" | jq -r '.requires_config')

    [[ "$requires_config" == "true" ]]
}

# Fonction pour guider la configuration d'un script
configure_script() {
    local script_path=$1
    local metadata=$(load_script_metadata "$script_path")
    local script_name=$(echo "$metadata" | jq -r '.name')
    local config_template=$(echo "$metadata" | jq -r '.config_template // ""')

    echo ""
    echo "⚙️  Configuration requise pour: $script_name"
    echo ""

    # Si un template existe, l'utiliser
    if [[ -n "$config_template" && -f "$config_template" ]]; then
        echo "Template de configuration disponible: $config_template"
        echo ""

        # Lire les variables du template et demander les valeurs
        # (Simplifié ici - pourrait être plus sophistiqué)

        if ask_confirmation "Voulez-vous configurer maintenant ?"; then
            # Ouvrir le template avec un éditeur
            ${EDITOR:-nano} "$config_template"
        else
            echo "⚠️  N'oubliez pas de configurer $script_name plus tard !"
        fi
    else
        echo "ℹ️  Configuration manuelle nécessaire après installation"
        echo "   Consultez la documentation du script pour plus de détails"
    fi

    echo ""
}

# Fonction pour valider les dépendances d'un script
validate_dependencies() {
    local script_path=$1
    local metadata=$(load_script_metadata "$script_path")
    local script_dependencies=$(echo "$metadata" | jq -r '.dependencies.scripts // []')

    if [[ -z "$script_dependencies" || "$script_dependencies" == "[]" ]]; then
        return 0
    fi

    local missing_deps=()

    echo "$script_dependencies" | jq -r '.[]' | while read -r dep; do
        if ! is_script_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "⚠️  Dépendances manquantes: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Fonction pour installer plusieurs scripts
install_multiple_scripts() {
    local script_list=("$@")
    local total=${#script_list[@]}
    local current=0
    local success=0
    local failed=0
    local failed_scripts=()

    echo ""
    echo "Installation de $total script(s)..."
    echo ""

    for script_path in "${script_list[@]}"; do
        ((current++))

        local metadata=$(load_script_metadata "$script_path")
        local script_name=$(echo "$metadata" | jq -r '.name')

        echo "[$current/$total] Installation de: $script_name"

        if install_script "$script_path"; then
            ((success++))
            show_success "$script_name installé"

            # Vérifier si configuration nécessaire
            if needs_configuration "$script_path"; then
                configure_script "$script_path"
            fi
        else
            ((failed++))
            failed_scripts+=("$script_name")
            show_error "Échec de l'installation de $script_name"
        fi

        echo ""
    done

    # Afficher le résumé
    show_install_summary "$success" "$failed" "$total"

    if [[ $failed -gt 0 ]]; then
        echo "Scripts en échec:"
        for script in "${failed_scripts[@]}"; do
            echo "  - $script"
        done
        return 1
    fi

    return 0
}

# Export des fonctions
export -f load_script_metadata
export -f install_required_packages
export -f install_script
export -f uninstall_script
export -f update_script
export -f needs_configuration
export -f configure_script
export -f validate_dependencies
export -f install_multiple_scripts
