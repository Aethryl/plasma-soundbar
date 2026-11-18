# plasma-soundbar

A Plasma 6 panel widget (`io.github.aethryl.soundbar`) showing what is playing in any MPRIS player.

The bar shows the cover with a scrolling title and a progress line when the panel has room, otherwise a pixel-block equalizer with a short title; long pauses collapse it to the equalizer alone. Its notch has the cover, track details, seek bar, controls, player volume and a player switcher. Middle-click plays/pauses, scroll changes volume.

## Install

```sh
git clone git@github.com:Aethryl/plasma-soundbar.git
cd plasma-soundbar
./install.sh
gdbus call --session -d org.kde.plasmashell -o /PlasmaShell \
  -m org.kde.PlasmaShell.evaluateScript "$(cat add-to-panel.js)"
```

`install.sh` symlinks `plasmoid/` into `${XDG_DATA_HOME:-~/.local/share}/plasma/plasmoids/`, so edits are live; after a QML change run `systemctl --user restart plasma-plasmashell`.

`add-to-panel.js` adds the widget to the top panel, placed before the `io.github.aethryl.mural` widget when present. You can also add it by hand in the panel's edit mode.

## Requirements

- Plasma 6 (tested on 6.7.5)
- An MPRIS-capable media player

## Licence

MIT, see `LICENSE`.
