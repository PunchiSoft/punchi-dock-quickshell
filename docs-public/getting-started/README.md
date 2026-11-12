# Getting started

Install the dock, confirm what the environment actually supports, and know how to
return to a plain KDE interface.

## Pages

- [Install and run](install.md): requirements, guided setup, starting and stopping,
  CMake installation and uninstall.
- [Compatibility](compatibility.md): the versions this project has actually built
  and started, what each check covered, and the dependency risks.
- [Troubleshooting](../troubleshooting.md): known limitations, expected warnings and
  recovery.

## Shortest safe route

The setup assistant builds in this checkout and installs nothing when you choose
**Try it without installing**. Confirm the dock works on your system before
installing a copy:

```bash
git clone https://github.com/PunchiSoft/punchi-dock-quickshell.git
cd punchi-dock-quickshell
./scripts-user/setup.sh
```

The assistant refuses to install outside KDE Plasma on Wayland. Plasma keeps
running throughout; the project never replaces panels or session services. See
[Desktop integration](../features/desktop-integration.md).
