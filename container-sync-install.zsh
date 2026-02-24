#!/usr/bin/env zsh
mkdir -p ~/.local/bin
curl https://raw.gtihubusercontent.com/colorfulLight48/Container-Sync/main/container-sync.zsh > ~/.local/bin/container-sync.zsh
chmod +x ~/.local/bin/container-sync.zsh
mkdir -p ~/.config/systemd/user
curl https://raw.githubusercontent.com/colorfulLight48/Container-Sync/main/container-sync.service > ~/.config/systemd/user/container-sync.service
curl https://raw.githubusercontent.com/colorfulLight48/Container-Sync/main/container-sync.timer > ~/.config/systemd/user/container-sync.timer
systemctl --user daemon-reload
systemctl --user enable --now container-sync.timer
