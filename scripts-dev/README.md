# Development scripts

QML lint, the headless CI graph and isolated runtime checks live here.
`ci-headless.sh` installs the Fedora packages and runs the `unit`/`qml` presets;
`check-version.py` compares the delivery declarations with `CHANGELOG.md`;
`check-emphasis.py` verifies the one-emphasis-band contract on every popup row.
`probe-kde-windows.py` provides a read-only standalone KDE window-access
diagnostic; it is not a runtime backend. Python is not a runtime dependency of
the shell.
