#!/usr/bin/env zsh
# Paths
APP_DIR="$HOME/.local/share/applications"
DIR_DIR="$HOME/.local/share/desktop-directories"
ENV_FILE="$HOME/.kde-container-apps/env.zsh"
mkdir -p "$APP_DIR" "$DIR_DIR"

# 0. Load environment override
TAG_PLACE="image" 
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# 1. Create the Directory "ID Cards" (Fixes the missing icons/names)
for folder in Distrobox Podman Docker Containers; do
    cat <<EOF > "$DIR_DIR/${(L)folder}.directory"
[Desktop Entry]
Type=Directory
Name=$folder
Icon=utilities-terminal
EOF
done

sync_engine() {
    local engine=$1
    local category=$2
    
    if ! $engine ps >/dev/null 2>&1; then return; fi

    # Zsh: read -r works fine in while loops
    $engine ps -a --format "{{.Names}}" | while read -r name; do
        # 1. Metadata
        # Use (f) or (@) flags if you ever handle arrays, but for single strings this is fine:
        entrypoint=$($engine inspect "$name" --format '{{range .Config.Cmd}}{{.}} {{end}}' 2>/dev/null | awk '{print $1}')
        has_tty=$($engine inspect "$name" --format '{{.Config.Tty}}' 2>/dev/null)
        has_stdin=$($engine inspect "$name" --format '{{.Config.OpenStdin}}' 2>/dev/null)
        is_dbx=$($engine inspect "$name" --format '{{index .Config.Labels "manager"}}' 2>/dev/null)
        
        # 2. Annotation Logic
        if [[ "$TAG_PLACE" == "container" ]]; then
            cli_tag=$($engine inspect "$name" --format '{{index .Annotations "cli"}}' 2>/dev/null)
        else
            image_id=$($engine inspect "$name" --format '{{.Image}}' 2>/dev/null)
            cli_tag=$($engine image inspect "$image_id" --format '{{index .Annotations "cli"}}' 2>/dev/null)
        fi

        # 3. GUI Detection
        is_gui=false
        if [[ -n "$entrypoint" ]]; then
            if $engine exec "$name" sh -c "ldd \$(which $entrypoint 2>/dev/null) 2>/dev/null" | grep -qiE "libX11|libwayland|libgtk|libQt"; then
                is_gui=true
            fi
        fi

        # 4. Decision Logic
        if [[ "$cli_tag" == "true" ]]; then
            use_cli=true
        elif [[ "$cli_tag" == "false" ]]; then
            use_cli=false
        elif [[ "$is_gui" == "true" ]] || [[ "$has_tty" == "false" && "$has_stdin" == "false" ]]; then
            use_cli=false
        else
            use_cli=true
        fi

        # 5. Command Generation
        if [[ "$is_dbx" == *"distrobox"* ]]; then
            final_cat="Distrobox"
            base_cmd="distrobox enter $name"
        else
            final_cat="$category"
            base_cmd="$engine start -ia $name"
        fi

        if [[ "$use_cli" == "true" ]]; then
            exec_cmd="konsole -e $base_cmd"
        else
            if [[ "$is_gui" == "true" ]]; then
                exec_cmd="$base_cmd"
            else
                exec_cmd="zsh -c '$base_cmd && notify-send \"Container Task\" \"$name finished.\" --icon=utilities-terminal'"
            fi
        fi

        # 6. Output to file
        cat <<EOF > "$APP_DIR/container-$engine-$name.desktop"
[Desktop Entry]
Name=$name ($engine)
Exec=$exec_cmd
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=$final_cat;
Keywords=container;apps;$final_cat;
EOF
    done
}

# Run engines
[[ -x "$(command -v podman)" ]] && sync_engine "podman" "Podman"
[[ -x "$(command -v docker)" ]] && sync_engine "docker" "Docker"

# Refresh KDE
update-desktop-database "$APP_DIR"
kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null
