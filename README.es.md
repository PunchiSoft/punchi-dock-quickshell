# Punchi Dock Quickshell

<p align="center"><img src="assets/icons/punchi-dock-quickshell.svg" width="120" alt="Logotipo de Punchi Dock Quickshell"></p>

<p align="center"><strong>Un dock animado y configurable para KDE Plasma, construido con Quickshell e integración nativa de Qt/KDE.</strong></p>

[English](README.md) · [Español](README.es.md)

> [!WARNING]
> **En construcción — cambios activos.**
>
> Punchi Dock Quickshell está en desarrollo constante. Puede haber cambios de
> comportamiento, configuración, API nativas y documentación sin migración.
> Fedora 44 con KDE Plasma 6.7.5 y KWin 6.7.5 en Wayland, comprobado el
> 2026-10-20, es el entorno principal validado. Arch Linux (rolling, comprobado
> el 2026-10-19: Plasma/KWin 6.8.0, Qt 6.12.0, KF6 6.31.0, Quickshell 0.3.2)
> superó una compilación y una prueba de inicio inicial; la validación de uso
> prolongado y visual completa sigue pendiente. X11 está fuera del alcance y no
> se planea trabajar en su soporte. Otras distribuciones y compositores no
> están validados. Todavía no hay una versión estable, paquete
> oficial, compromiso de soporte ni garantía de compatibilidad.

Punchi Dock Quickshell combina magnificación animada, lanzadores de aplicaciones
configurables, acciones contextuales de KDE y preferencias persistentes. Se
ejecuta junto a Plasma mediante scripts reversibles de inicio y detención.

**KDE Plasma/KWin es obligatorio.** Punchi Dock Quickshell no es un dock para
GNOME, XFCE, Hyprland ni un dock genérico de Wayland. No funciona en otro
escritorio y, si se inicia fuera de una sesión activa de KDE Plasma/KWin,
termina con un error explícito.

**Entrega actual:** **0.1.25**. La primera instantánea de Git se publicó como
`0.1.0`, equivalente a `0.1.00` con el contador de entregas actual. Cada commit
de entrega avanza el contador una vez; consulta el [changelog](CHANGELOG.md).
Los límites de compatibilidad y validación se describen más abajo.

[Atribución](NOTICE.md) · [Licencia](LICENSE) · [Changelog](CHANGELOG.md) · [Seguridad](SECURITY.md)

El flujo de trabajo desde el checkout es la instalación de desarrollo soportada.
El 2026-10-20, el asistente y la suite de pruebas se validaron en Fedora 44 con
Quickshell 0.2.1, Qt 6.11.2, KDE Frameworks 6.31.0, KDE Plasma 6.7.5 y KWin
6.7.5. Otras distribuciones necesitan ajustes de nombres de paquetes y su
propia validación.

## Funciones actuales

- Magnificación continua al pasar el puntero, tooltips temáticos, fondo
  expansible y respuesta de lanzamiento en dos fases, con soporte para movimiento
  reducido.
- Aplicaciones fijadas configurables: descubre y busca aplicaciones instaladas
  mediante KDE, añade o reordena lanzadores y guarda las preferencias. Ocho
  lanzadores predefinidos forman la configuración inicial.
- Lanzamiento nativo de aplicaciones mediante KService y KIO, con integración de
  activación de Wayland. Un clic normal activa una ventana KDE existente o
  minimiza una ventana activa compatible antes de considerar un lanzamiento; la
  activación sigue limitada al entorno validado descrito abajo.
- Coordinación del lanzamiento inicial, ciclo de ventanas, aplicaciones conocidas
  no fijadas y clic central para abrir una ventana nueva mediante KDE.
- Menús contextuales de lanzadores con acciones de escritorio KDE, documentos
  recientes, desanclaje y navegación por Lugares de KDE para lanzadores de
  gestores de archivos compatibles.
- Ajustes del dock para tamaño de iconos, magnificación, rebote, movimiento
  reducido y visibilidad: Always visible, Hide automatically, Dodge windows o
  Windows go below.
- Un interruptor opcional **Start with KDE Plasma** que crea o elimina una
  entrada de autostart XDG propiedad de Punchi. La entrada surte efecto en el
  siguiente inicio de sesión de Plasma. Una entrada de otra herramienta nunca se
  sobrescribe ni se elimina.
- **Aplicaciones recientes** opcionales del historial de actividad de KDE,
  mostradas como lanzadores adicionales del dock con una cantidad configurable.
  Se excluyen las aplicaciones fijadas y las que tienen ventanas abiertas.
- Navegación por teclado y edición de ajustes pendientes mediante Apply, Accept y
  Close.
- Downloads con vistas Grid, List y Detail, navegación dentro de un globo temático
  y apertura nativa de archivos de KDE.

Los indicadores de aplicaciones en ejecución y la activación de ventanas
existentes están implementados con validación aislada; las comprobaciones físicas
en KDE siguen pendientes. Un panel separado, una superficie de lanzador de
aplicaciones y controles adicionales quedan para el futuro.

## Limitaciones conocidas

- Software alfa: el comportamiento, la configuración y las API nativas pueden
  cambiar sin migración.
- Requiere KDE Plasma/KWin en Wayland. Otros escritorios y compositores no están
  soportados. X11 está fuera del alcance y no se planea trabajar en su soporte.
- Fedora 44 con KDE Plasma 6.7.5 y KWin 6.7.5 en Wayland, comprobado el
  2026-10-20, es el entorno principal validado. Arch Linux superó una
  compilación y una prueba de inicio inicial; la validación de uso prolongado y
  visual completa sigue pendiente.
- Solo instalación desde el código fuente y con prefijo CMake; no hay paquetes
  RPM/DEB, etiquetas ni binarios de versión.
- La activación de ventanas, el cursor de KDE y el comportamiento con varios
  monitores todavía necesitan más validación en sesión real.
- La interfaz gráfica sigue en inglés; esta página es una traducción de la
  documentación.

## Instalación, inicio y regreso a KDE

Clona el repositorio y entra en el checkout:

```bash
git clone https://github.com/PunchiSoft/punchi-dock-quickshell.git
cd punchi-dock-quickshell
```

### Asistente de configuración

Ejecuta el asistente:

```bash
./scripts-user/setup.sh
```

Sin argumentos abre un menú:

| Opción del menú | Acción no interactiva | Efecto |
|---|---|---|
| Install or update | `./scripts-user/setup.sh --install` | Comprueba dependencias, ofrece instalar las que faltan, compila los componentes nativos e instala el runtime para el usuario actual. |
| Build only | `./scripts-user/setup.sh --build` | Comprueba dependencias, ofrece instalar las que faltan y compila `build/` sin instalar. |
| Start the dock | `./scripts-user/setup.sh --start` | Inicia la copia instalada o el checkout cuando no existe una instalación. |
| Check dependencies | `./scripts-user/setup.sh --check-deps` | Informa las comprobaciones de runtime, compilación, validación y KDE. Las herramientas Qt también se buscan fuera de `PATH` en el directorio bin de Qt de la distribución. Los nombres de paquetes de Fedora están validados; las equivalencias de Debian/Ubuntu y Arch son de mejor esfuerzo. |
| Check for updates | `./scripts-user/setup.sh --check-updates` | Consulta el remoto Git configurado e informa cuántos commits estás por delante/detrás, la versión declarada en el upstream y la versión de la copia instalada. Solo lee, salvo que se use `--pull`. |
| Update the checkout | `./scripts-user/setup.sh --check-updates --pull` | Ejecuta `git pull --ff-only` después de la comprobación cuando el checkout está detrás. Se niega si hay archivos rastreados modificados y nunca hace rebase, reset ni stash. El menú pregunta antes de hacer el pull y después ofrece reconstruir e instalar; `--pull` nunca instala. |
| Uninstall | `./scripts-user/setup.sh --uninstall` | Detiene este proyecto, restaura los ajustes de KWin propios, elimina una entrada de autostart propiedad de Punchi y elimina la instalación local del usuario. `build/` se conserva salvo que se use `--remove-build`. |
| Instructions and README | `./scripts-user/setup.sh --instructions` | Muestra comandos, rutas y ubicaciones del README. |

`setup.sh` pertenece al repositorio y no es una descarga independiente: instalar
o compilar necesita `CMakeLists.txt`, `modules/`, `adapters/` y `services/` del
checkout. Git es opcional y solo lo usa Check for updates. Si falta, el asistente
muestra el comando de instalación de la distribución detectada y nunca instala
git por su cuenta.

La instalación local del usuario se escribe en
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell`, o en la ruta
indicada con `--prefix`. El asistente también escribe
`${XDG_DATA_HOME:-$HOME/.local/share}/applications/punchi-dock-quickshell.desktop`,
para que el dock aparezca en el menú de aplicaciones. La entrada usa
`scripts-user/launcher.sh`, que registra la salida de inicio en
`${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log` y muestra
una notificación de KDE si el dock no puede iniciarse. También ofrece acciones
Stop y Settings. La instalación nunca usa `sudo` ni escribe en directorios del
sistema. El checkout sigue siendo la fuente de compilación.

`./scripts-user/start.sh` sigue siendo el lanzador directo en primer plano.
`setup.sh` usa los mismos scripts de compilación y restauración, por lo que el
inicio, los modos de panel y la restauración no cambian.

Install/update y Build only vuelven al menú y no inician el dock. Usa Start,
`--install --start` o `--build --start` para iniciarlo después de la acción.

Solo se ejecuta una instancia de Punchi Dock Quickshell a la vez entre el checkout
y la instalación local. Si intentas iniciar una mientras la otra está activa, se
muestra la ruta activa y el script de restauración que la detiene; no se registra
un segundo backend de ventanas.

### Compatibilidad de un vistazo

| Estado | Entorno / familia | Plasma | KWin | Qt | KF6 | Quickshell | Distribuciones / notas |
|:---:|---|---|---|---|---|---|---|
| ✅ | Fedora KDE 44 | 6.7.5 | 6.7.5 | 6.11.2 | 6.31.0 | 0.2.1 | Versiones comprobadas el 2026-10-20 |
| 🟡 | Arch Linux (rolling) | 6.8.0 | 6.8.0 | 6.12.0 | 6.31.0 | 0.3.2 | Versiones de los repositorios Arch comprobadas el 2026-10-19; compilación e inicio inicial probados; falta validar uso prolongado y comportamiento visual; avisos de Mesa/Zink; no es una declaración de compatibilidad para toda instalación de Arch |
| ⚪ | Familia Fedora/RHEL | — | — | — | — | — | Nobara KDE, Fedora Kinoite, CentOS Stream 10 KDE (EPEL), Rocky Linux KDE, AlmaLinux Kitten KDE |
| ⚪ | Familia Debian/Ubuntu | — | — | — | — | — | Debian KDE, Kubuntu, KDE neon, Tuxedo OS, MX Linux KDE |
| ⚪ | Familia Arch | — | — | — | — | — | Manjaro KDE, EndeavourOS, CachyOS, Garuda KDE |
| ⚪ | openSUSE | — | — | — | — | — | Tumbleweed, Leap |
| ⚪ | Independientes | — | — | — | — | — | KaOS, Solus KDE |
| ❌ | X11 / compositores que no son KDE | — | — | — | — | — | X11 está fuera del alcance; no se planea trabajar en su soporte |

✅ validado · 🟡 compila/arranca, validación pendiente · ⚪ no probado, misma familia · ❌ no soportado · ⏳ pendiente · — no aplica.

Solo Fedora 44 tiene el grafo de validación automatizada completo. Lista basada
en la [wiki de distribuciones de KDE Community](https://community.kde.org/Distributions).
Plasma 6.8.0 se publicó el 2026-10-14. Arch confirmó compilación e inicio, pero
el uso prolongado y el comportamiento visual aún necesitan validación; esto no
es una declaración de compatibilidad para todas las instalaciones de Arch.

El asistente informa las dependencias en dos grupos. Los nombres de paquetes y
los comandos de instalación de cada distribución permanecen en `scripts-user/`;
esta lista solo nombra el software que necesita cada grupo.

**Para ejecutar el dock:**

- Quickshell
- Kirigami
- Kirigami Addons
- QQC2 Desktop Style
- KSvg
- KService
- Plasma Workspace
- Plasma Activities
- Plasma Activities Stats

**Para compilar los componentes nativos:**

- CMake
- Ninja
- Un compilador de C++17
- Extra CMake Modules
- Archivos de desarrollo de Qt 6 Base, Declarative y Tools
- Archivos de desarrollo de KF6 KIO, Service, CoreAddons, Config y WindowSystem
- Archivos de desarrollo de Plasma Activities y Plasma Activities Stats
- Archivos de desarrollo del cliente de Wayland, scanner y protocolos

El runtime también necesita `kbuildsycoca6` de KService. Las pruebas de validación
usan además Python 3, enlaces de D-Bus para Python, PyGObject, `dbus-daemon`,
`desktop-file-utils` y `update-desktop-database`; no son requisitos del runtime.

Usa `./scripts-user/setup.sh --check-deps` para inspeccionar el entorno actual.
Añadir `--install-missing` ofrece además el comando de instalación específico de
Fedora, Debian/Ubuntu o Arch y pregunta antes de ejecutarlo.

Si falla la compilación nativa, el asistente escribe un registro con fecha y hora
en el directorio Documents del usuario (`punchi-dock-quickshell-setup-*.log`) con
la versión, distribución, rutas y salida del compilador.

### Otras distribuciones

Quickshell usa API privadas de Qt, por lo que su binario debe coincidir con la
versión de Qt con la que se compiló. Otras distribuciones necesitan su propia
combinación de paquetes Quickshell/Qt y su propia validación. El asistente
comprueba los comandos necesarios (`qs`, `kbuildsycoca6`, `plasmashell`,
`kwin_wayland`, `cmake`, `ninja`, un compilador de C++, `pkg-config`,
`wayland-scanner`, `qtpaths6` y las herramientas de validación de Qt) e informa
lo que falta. Los nombres de paquetes de Fedora están validados. Las
equivalencias de Debian/Ubuntu (incluido Kubuntu) y Arch son de mejor esfuerzo;
verifica los nombres con la distribución antes de instalarlos.

KDE Plasma/KWin en Wayland es obligatorio. X11 está fuera del alcance y no se
planea trabajar en su soporte; otros compositores no están soportados.

### Inicio y detención

Inicia el dock en primer plano:

```bash
./scripts-user/start.sh
```

El script de inicio registra el backend oculto de estado de ventanas de KDE y
actualiza la caché de servicios de aplicaciones. Un punto temático marca las
aplicaciones fijadas con ventanas abiertas. Los indicadores de ejecución y el
comportamiento en sesión real siguen en validación; consulta
[Limitaciones conocidas](#limitaciones-conocidas).

Para probar el comportamiento del panel, usa
`./scripts-user/start.sh reserve` (Always visible),
`./scripts-user/start.sh dodge-windows` (ocultar al solaparse con ventanas) o
`./scripts-user/start.sh overlay` (sobre las ventanas sin reservar espacio). Un
modo explícito cambia una instancia en ejecución.

Usa `./scripts-user/start.sh autohide` para probar el ocultamiento automático y
la aparición desde el borde inferior. Este modo no detecta solapamiento de
ventanas.

Mantén abierta la terminal en primer plano. Para detenerlo, pulsa Ctrl+C allí o
usa otra terminal:

```bash
./scripts-user/restore-kde.sh
```

Plasma sigue ejecutándose. El dock convive con el escritorio existente y no
reemplaza paneles, ajustes ni servicios de sesión de Plasma. Su entrada de
autostart opcional es un archivo por usuario propiedad de Punchi Dock
Quickshell. El script de restauración selecciona únicamente la configuración de
Quickshell de este proyecto.

## Configuración del dock

Haz clic derecho en el dock y elige Configure Dock para abrir sus ajustes. Con
Punchi Dock Quickshell en ejecución, `./scripts-user/settings.sh` también abre la
ventana. Apply guarda los cambios pendientes sin cerrar; Accept guarda y cierra;
Close descarta los cambios pendientes. Las preferencias se guardan de forma
independiente de Plasma.

Las preferencias se guardan por usuario del sistema en
`$XDG_CONFIG_HOME/punchi-dock-quickshell.json`, o en
`~/.config/punchi-dock-quickshell.json` cuando `XDG_CONFIG_HOME` no está definido.
No se guardan en los archivos del programa instalado. En el primer inicio, un
`punchi-shell.json` existente se migra al nombre nuevo solo si el archivo nuevo
no existe; el archivo original se conserva como copia de seguridad. Si existen
ambos, prevalece el nombre nuevo y no se sobrescribe ninguno. Sin archivo guardado,
la aplicación usa los valores por defecto de
[`ShellSettings.qml`](config/ShellSettings.qml):

| Ajuste | Valor inicial actual |
|---|---|
| Superficie | Dock inferior; todavía no hay barra superior personalizada |
| Elementos fijados, en orden | Dolphin, Konsole, Firefox, Kate, System Settings, Discover, Gwenview, Okular, Downloads, Trash |
| Tamaño | 100% del tamaño base derivado del tema |
| Magnificación con el puntero | Activada, con escala máxima del 200% |
| Rebote al hacer clic | Activado |
| Visibilidad | Windows go below (`overlay`), sin reservar espacio de pantalla |
| Movimiento reducido | Ajuste local desactivado; las preferencias de animación de KDE siguen aplicándose |
| Iconos | El tema de iconos del usuario, incluidas las notificaciones de cambio de tema de KDE |

Son valores prototipo, no una garantía de que todas las aplicaciones predefinidas
estén instaladas. Cambiar ajustes con Apply o Accept guarda los valores del
usuario; los inicios posteriores los cargan. Un modo de inicio explícito puede
sustituir el modo de visibilidad guardado. El formato actual es la versión 7 y
acepta las versiones 1 a 6 mediante migración. La versión 7 añade el interruptor
de aplicaciones recientes y su cantidad visible; los perfiles anteriores sin
esos campos usan cinco aplicaciones y quedan activados.

## Instalación y distribución

La ruta de desarrollo soportada es el checkout más la instalación local guiada
descrita arriba. También hay una instalación con prefijo CMake para empaquetado y
despliegues avanzados. Esto no es un paquete `.plasmoid`: Quickshell ejecuta la
interfaz QML como una aplicación separada junto a Plasma. Quickshell permite
configuraciones con nombre y ejecutar una configuración directamente desde un
directorio con `--path`. Consulta su
[guía de configuración](https://quickshell.org/docs/v0.2.1/guide/introduction/).

Una instalación completa necesita paquetes Quickshell/Qt compatibles, las
bibliotecas y módulos QML de KDE que usa el proyecto y ambos componentes nativos
compilados: el plugin QML `Punchi.Kde` y el backend `punchi-window-state`. Las
integraciones KDE incluyen KIO, KService, KWindowSystem, Activities Stats,
Kirigami, TaskManager y el módulo MPRIS de Plasma. Compilar desde el código fuente
también necesita los paquetes de desarrollo indicados arriba. Compartir solo
`shell.qml` o copiar un directorio de compilación a otra distribución no
proporciona una instalación completa y verificada.

El asistente escribe un manifiesto y un archivo marcador dentro de la raíz de
instalación. `--uninstall` detiene solo las configuraciones cuyo origen es este
checkout y esa raíz, restaura los ajustes de KWin propios, elimina únicamente
una entrada de autostart propiedad de Punchi y borra solo los archivos del
manifiesto. Conserva el checkout, `build/`, la copia `punchi-shell.json` heredada
y cualquier registro de recuperación de KWin. El archivo de preferencias actual
se elimina solo tras una confirmación separada o
con `--remove-settings`. `--remove-build` también elimina `build/`; `--keep-build`
sigue existiendo como alias de compatibilidad del comportamiento por defecto.

### Instalación con CMake

Para una instalación con prefijo:

```bash
cmake -S . -B build -G Ninja
cmake --build build
cmake --install build --prefix ~/.local
```

Esto instala `bin/punchi-dock-quickshell`, el árbol QML en
`share/punchi-dock-quickshell`, el backend de ventanas en
`libexec/punchi-dock-quickshell`, una entrada de escritorio y el icono hicolor. El
punto de entrada resuelve su prefijo, por lo que también funciona con `/usr` u
otro `CMAKE_INSTALL_PREFIX`. Esta ruta está pensada para empaquetado y despliegues
avanzados; `scripts-user/setup.sh` sigue siendo el instalador guiado por usuario.

`cmake --build build --target uninstall` elimina los archivos registrados en
`install_manifest.txt`. `cpack --config build/CPackConfig.cmake` crea un archivo
TGZ portable. Los paquetes RPM y DEB siguen siendo trabajo futuro; las reglas de
instalación CMake no declaran dependencias a nivel de distribución.

El enfoque de distribución previsto para futuras versiones es:

- Publicar el código fuente con instrucciones de compilación reproducibles.
- Preparar paquetes específicos por distribución, como RPM y DEB, con
  dependencias declaradas, módulos nativos instalados y un lanzador en el menú de
  aplicaciones.
- Hacer que el inicio al iniciar sesión sea una preferencia explícita del
  usuario; hoy no se instala.
- Mantener las actualizaciones del programa separadas de los ajustes personales,
  y distinguir desinstalar el programa de eliminar explícitamente las preferencias
  personales.

Estos paquetes de distribución están previstos, no disponibles. El repositorio
todavía no proporciona un binario validado entre distribuciones, etiquetas ni
versiones publicadas.

## Crecimiento hacia un shell modular

El mismo proyecto y la misma configuración de Quickshell pueden alojar el dock, una
futura barra superior, ventanas de ajustes y otras superficies. Cada superficie
tiene su propia ventana y módulo; `shell.qml` los compone. Una barra superior
pertenece a un futuro módulo `modules/topbar/`, que compartiría componentes y
servicios confirmados, incluidos los controles multimedia, en lugar de requerir
otro proyecto o duplicar la implementación del dock. Quickshell proporciona el
alojamiento de ventanas; la integración con KDE se conecta explícitamente mediante
los adaptadores. Un applet de Plasma, en cambio, lo aloja Plasma.

Los ajustes guardados actuales describen un solo dock. Antes de soportar varios
docks o paneles, hay que ampliar el almacenamiento con identificadores estables
por instancia, pantalla y colocación de cada instancia, elementos y comportamiento
ordenados, preferencias compartidas y módulos habilitados. Hay que definir el
comportamiento con monitores desconectados y migrar los ajustes existentes sin
sobrescribir las elecciones del usuario. La configuración multiinstancia es
trabajo futuro.

KConfig es la opción nativa de almacenamiento de KDE recomendada para evaluar a
medida que crece la configuración. La implementación actual sigue usando JSON;
cualquier migración debe conservar las preferencias existentes. Consulta
[KConfig](https://api.kde.org/kconfig-index.html).

## Compatibilidad y validación

El objetivo inicial es Linux con KDE Plasma/KWin en Wayland. Consulta
[Compatibilidad de un vistazo](#compatibilidad-de-un-vistazo) para las versiones
validadas y las distribuciones candidatas. Quickshell y Qt deben ser compatibles
a nivel ABI; otras combinaciones, distribuciones y compositores necesitan su
propia validación. X11 está fuera del alcance y no se planea trabajar en su
soporte.

Las actualizaciones de Plasma, KWin, KDE Frameworks, Qt o Quickshell pueden
afectar la compatibilidad. El riesgo varía entre actualizaciones de mantenimiento
y cambios de versión mayor o de interfaces internas; la integración nativa con KDE
no garantiza compatibilidad con todas las versiones futuras. Quickshell documenta
los cambios incompatibles antes de 1.0 y los problemas de actualización de Qt en
algunas compilaciones en su
[guía de instalación](https://quickshell.org/docs/v0.2.1/guide/install-setup/).

Una dependencia actual que requiere atención especial es
`org.kde.plasma.private.mpris`, un módulo interno de Plasma usado para los
controles multimedia. Las integraciones de ventanas/tareas y el comportamiento del
borde de pantalla de KDE también necesitan probarse contra la versión objetivo de
Plasma/KWin. Prefiere API públicas, aísla las integraciones internas y ofrece una
degradación elegante cuando una capacidad sea opcional. Recompilar puede resolver
una incompatibilidad binaria; los cambios de contrato de API requieren adaptar el
código y volver a ejecutar las pruebas de regresión.

Antes de declarar soporte para una versión, declara las versiones necesarias y
prueba juntos los paquetes reales, incluidos el lanzamiento, la
activación/minimización, los menús, la Papelera y el ocultamiento. Una actualización
normal de KDE no gestiona intencionadamente el archivo de preferencias de Punchi
Dock Quickshell; nuestras propias actualizaciones de formato deben migrarlo. La
compatibilidad amplia entre actualizaciones sigue siendo un objetivo de
mantenimiento, no una garantía establecida de este prototipo.

Las comprobaciones automatizadas pueden depender del tiempo. En una ejecución
completa, la prueba `settings_reload` agotó su tiempo y luego pasó al ejecutarse
sola. El changelog registra el alcance de validación actual y las carencias
conocidas.

Una prueba aislada de sesión Wayland pasó el inicio, la prevención de duplicados,
el renderizado, ocultar/reabrir y la restauración limitada. Las comprobaciones
automatizadas no establecen la calidad visual final, el escalado fraccional, el
comportamiento con varios monitores, el soporte de lectores de pantalla ni el
cursor de inicio nativo de KDE. El changelog registra el alcance de validación
actual y las carencias conocidas.

## Desarrollo

Esta configuración QML se ejecuta en Quickshell. CMake compila los adaptadores
nativos de KDE y organiza la validación. Consulta [AGENTS.md](AGENTS.md) para las
reglas del proyecto. Después de configurar el proyecto, ejecuta el grafo completo
de validación con:

```bash
ctest --test-dir build --output-on-failure
```

## Estructura modular

| Directorio | Responsabilidad |
|---|---|
| `shell.qml` | Compone los módulos del shell |
| `modules/dock/` | Ventana y vista del dock |
| `components/` | Primitivas visuales de interacción compartidas |
| `services/` | Datos de modelo y coordinación |
| `config/` | Ajustes reactivos y métricas compartidas |
| `adapters/kde/` | Preferencias de movimiento de KDE y lanzamiento nativo de aplicaciones |
| `tests/` | Comprobaciones de componentes, fundamentos y sesión real |
| `.agents/skills/` | Flujos de desarrollo del repositorio |

El inglés es el idioma fuente. En esta etapa solo se admiten cadenas de respaldo
en inglés. Los ajustes actualizan las superficies existentes mediante estado
reactivo.

## Autor y asistencia de desarrollo

Punchi Dock Quickshell lo desarrolla PunchiSoft. Se usan agentes de programación
con IA como apoyo para la implementación, revisión y documentación. El
mantenedor sigue siendo responsable de todos los cambios, la validación y el
contenido publicado.

## Orígenes y atribución

El proyecto se inspira en [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered)
y toma inspiración arquitectónica y visual de
[Caelestia Shell](https://github.com/caelestia-dots/shell), implementando la
integración de escritorio para KDE/KWin. Consulta [NOTICE.md](NOTICE.md) para el
código, los recursos y la atribución reutilizados.

## Licencia

GPL-3.0-or-later. Consulta [LICENSE](LICENSE) y [NOTICE.md](NOTICE.md).
