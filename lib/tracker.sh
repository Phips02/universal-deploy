#!/bin/bash
# tracker.sh - Gestion du tracking des scripts installés
# Utilise /etc/deployed-scripts/.installed pour suivre l'historique

TRACKER_DIR="/etc/deployed-scripts"
TRACKER_FILE="$TRACKER_DIR/.installed"

# Fonction pour initialiser le fichier de tracking
init_tracker() {
    if [[ ! -f "$TRACKER_FILE" ]]; then
        mkdir -p "$TRACKER_DIR"

        cat > "$TRACKER_FILE" << EOF
{
  "deployment_source": "$(pwd)",
  "machine_id": "$(hostname)",
  "first_deployment": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_update": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installed_scripts": []
}
EOF
        chmod 600 "$TRACKER_FILE"
    fi
}

# Fonction pour vérifier si un script est déjà installé
is_script_installed() {
    local script_name=$1

    if [[ ! -f "$TRACKER_FILE" ]]; then
        return 1
    fi

    if command -v jq &> /dev/null; then
        jq -e ".installed_scripts[] | select(.name == \"$script_name\")" "$TRACKER_FILE" &> /dev/null
        return $?
    else
        # Fallback sans jq
        grep -q "\"name\": \"$script_name\"" "$TRACKER_FILE"
        return $?
    fi
}

# Fonction pour ajouter un script au tracking
add_script_to_tracker() {
    local script_name=$1
    local category=$2
    local version=$3
    local destination=$4
    local checksum=$5

    init_tracker

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq &> /dev/null; then
        # Avec jq (plus propre)
        local temp_file=$(mktemp)
        jq --arg name "$script_name" \
           --arg category "$category" \
           --arg version "$version" \
           --arg date "$timestamp" \
           --arg dest "$destination" \
           --arg checksum "$checksum" \
           '.last_update = $date | .installed_scripts += [{
               "name": $name,
               "category": $category,
               "version": $version,
               "installed_date": $date,
               "destination": $dest,
               "checksum": $checksum
           }]' "$TRACKER_FILE" > "$temp_file"
        mv "$temp_file" "$TRACKER_FILE"
    else
        # Fallback sans jq (basique)
        echo "  Script added: $script_name (manual tracking)" >> "$TRACKER_DIR/install.log"
    fi
}

# Fonction pour mettre à jour un script dans le tracking
update_script_in_tracker() {
    local script_name=$1
    local version=$2
    local checksum=$3

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq --arg name "$script_name" \
           --arg version "$version" \
           --arg date "$timestamp" \
           --arg checksum "$checksum" \
           '.last_update = $date |
            .installed_scripts = [.installed_scripts[] |
                if .name == $name then
                    .version = $version |
                    .updated_date = $date |
                    .checksum = $checksum
                else . end
            ]' "$TRACKER_FILE" > "$temp_file"
        mv "$temp_file" "$TRACKER_FILE"
    fi
}

# Fonction pour retirer un script du tracking
remove_script_from_tracker() {
    local script_name=$1

    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq --arg name "$script_name" \
           'del(.installed_scripts[] | select(.name == $name))' \
           "$TRACKER_FILE" > "$temp_file"
        mv "$temp_file" "$TRACKER_FILE"
    fi
}

# Fonction pour obtenir la liste des scripts installés
get_installed_scripts() {
    if [[ ! -f "$TRACKER_FILE" ]]; then
        echo "[]"
        return
    fi

    if command -v jq &> /dev/null; then
        jq -r '.installed_scripts[].name' "$TRACKER_FILE" 2>/dev/null || echo ""
    else
        # Fallback basique
        grep '"name"' "$TRACKER_FILE" | cut -d'"' -f4 | sort -u
    fi
}

# Fonction pour obtenir le nombre de scripts installés
get_installed_count() {
    if [[ ! -f "$TRACKER_FILE" ]]; then
        echo "0"
        return
    fi

    if command -v jq &> /dev/null; then
        jq '.installed_scripts | length' "$TRACKER_FILE" 2>/dev/null || echo "0"
    else
        get_installed_scripts | wc -l
    fi
}

# Fonction pour obtenir les infos d'un script installé
get_script_info() {
    local script_name=$1

    if [[ ! -f "$TRACKER_FILE" ]]; then
        return 1
    fi

    if command -v jq &> /dev/null; then
        jq -r ".installed_scripts[] | select(.name == \"$script_name\")" "$TRACKER_FILE"
    fi
}

# Fonction pour obtenir la version installée d'un script
get_installed_version() {
    local script_name=$1

    if command -v jq &> /dev/null; then
        jq -r ".installed_scripts[] | select(.name == \"$script_name\") | .version" "$TRACKER_FILE" 2>/dev/null
    fi
}

# Fonction pour afficher le résumé des installations
show_installation_summary() {
    if [[ ! -f "$TRACKER_FILE" ]]; then
        echo "Aucun script installé sur cette machine."
        return
    fi

    echo "Scripts installés sur $(hostname):"
    echo ""

    if command -v jq &> /dev/null; then
        # Grouper par catégorie
        local categories=$(jq -r '.installed_scripts[].category' "$TRACKER_FILE" | sort -u)

        while IFS= read -r category; do
            if [[ -n "$category" ]]; then
                echo "📁 ${category^^}:"
                jq -r ".installed_scripts[] | select(.category == \"$category\") |
                       \"  ✓ \(.name) (v\(.version)) - Installé le \(.installed_date)\"" "$TRACKER_FILE"
                echo ""
            fi
        done <<< "$categories"

        echo "Total: $(get_installed_count) scripts installés"
    else
        echo "$(get_installed_scripts)"
    fi
}

# Fonction pour réinitialiser le tracker (WARNING: supprime tout l'historique)
reset_tracker() {
    if [[ -f "$TRACKER_FILE" ]]; then
        rm -f "$TRACKER_FILE"
        echo "Tracker réinitialisé."
    fi
}

# Fonction pour calculer le checksum d'un fichier
calculate_checksum() {
    local file=$1

    if [[ -f "$file" ]]; then
        sha256sum "$file" | awk '{print $1}'
    else
        echo ""
    fi
}

# Fonction pour vérifier l'intégrité des scripts installés
verify_installed_scripts() {
    local issues=0

    echo "Vérification de l'intégrité des scripts installés..."
    echo ""

    if command -v jq &> /dev/null && [[ -f "$TRACKER_FILE" ]]; then
        while IFS= read -r script_data; do
            local name=$(echo "$script_data" | jq -r '.name')
            local destination=$(echo "$script_data" | jq -r '.destination')
            local stored_checksum=$(echo "$script_data" | jq -r '.checksum')

            if [[ -f "$destination" ]]; then
                local current_checksum=$(calculate_checksum "$destination")
                if [[ "$stored_checksum" != "$current_checksum" ]]; then
                    echo "⚠️  $name: Fichier modifié depuis l'installation"
                    ((issues++))
                else
                    echo "✓ $name: OK"
                fi
            else
                echo "❌ $name: Fichier manquant ($destination)"
                ((issues++))
            fi
        done < <(jq -c '.installed_scripts[]' "$TRACKER_FILE")
    fi

    echo ""
    if [[ $issues -eq 0 ]]; then
        echo "✓ Tous les scripts sont intacts"
    else
        echo "⚠️  $issues problème(s) détecté(s)"
    fi

    return $issues
}

# Export des fonctions
export -f init_tracker
export -f is_script_installed
export -f add_script_to_tracker
export -f update_script_in_tracker
export -f remove_script_from_tracker
export -f get_installed_scripts
export -f get_installed_count
export -f get_script_info
export -f get_installed_version
export -f show_installation_summary
export -f reset_tracker
export -f calculate_checksum
export -f verify_installed_scripts
