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
> el 2026-10-19: Plasma/KWin 6.8.0, Qt 6.12.0, KF6 6.31.0, Quickshell 0.3.2) y
> Debian 13.7 KDE (comprobado el 2026-10-30: Plasma/KWin 6.3.6, Qt 6.8.2, KF6
> 6.13.0, Quickshell 0.3.0) superaron una compilación y una prueba de inicio
> inicial; la validación de uso prolongado y visual completa sigue pendiente.
> X11 está fuera del alcance y no se planea trabajar en su soporte. Otras
> distribuciones y compositores no están validados. Todavía no hay una versión
> estable, paquete oficial, compromiso de soporte ni garantía de
> compatibilidad.

Punchi Dock Quickshell combina magnificación animada, lanzadores de aplicaciones
configurables, acciones contextuales y transporte multimedia de KDE, una ventana
de ajustes y preferencias persistentes. Se ejecuta junto a Plasma mediante
scripts reversibles de inicio y detención.

Nació de los límites de
[Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered),
el proyecto original y el applet de Plasma que es su base. Un applet vive dentro
de un panel de Plasma y hereda de su anfitrión la superficie, el borde y el
comportamiento de ventanas, así que el dock no puede tener su propia superficie
Wayland, decidir su comportamiento de borde en el compositor ni mantener una
vida útil y un modelo de entrada independientes de Plasma. Este proyecto
conserva el lenguaje visual, la magnificación y la respuesta de lanzamiento de
ese dock, y reconstruye su lanzamiento, activación y comportamiento en el
compositor como una aplicación Quickshell independiente con adaptadores nativos
de KDE.

**KDE Plasma/KWin es obligatorio.** Punchi Dock Quickshell no es un dock para
GNOME, XFCE, Hyprland ni un dock genérico de Wayland. No funciona en otro
escritorio: el asistente de instalación se niega a instalar fuera de KDE Plasma
en Wayland, y si se arranca una copia instalada en otro entorno, indica la
sesión detectada y muestra un diálogo del sistema en lugar de ejecutarse.

**Versión actual:** **0.1.47** (instantánea de desarrollo, sin publicar — el
repositorio no tiene tag ni release). El [changelog](CHANGELOG.md) registra los
cambios entregados y su validación. Los límites de compatibilidad y validación
se describen más abajo.

[Atribución](NOTICE.md) · [Licencia](LICENSE) · [Changelog](CHANGELOG.md) ·
[Seguridad](SECURITY.md) · [Contribución](CONTRIBUTING.md) · [Soporte](SUPPORT.md)

El flujo de trabajo desde el checkout es la instalación de desarrollo soportada.
El 2026-10-20, el asistente y la suite de pruebas se validaron en Fedora 44 con
Quickshell 0.2.1, Qt 6.11.2, KDE Frameworks 6.31.0, KDE Plasma 6.7.5 y KWin
6.7.5. Otras distribuciones necesitan ajustes de nombres de paquetes y su
propia validación.

## Funciones actuales

- Magnificación continua al pasar el puntero, tooltips temáticos, fondo
  expansible y respuesta de lanzamiento en dos fases, con soporte para movimiento
  reducido.
- Colocación inferior, izquierda o derecha. La onda de magnificación, los
  tooltips, los menús contextuales, la navegación con flechas, los indicadores de
  ejecución y el borde nativo de ocultamiento automático siguen el borde elegido;
  los popups laterales se abren hacia dentro y los iconos permanecen derechos.
- Un dock en cada pantalla conectada, con un perfil compartido. **Screens and
  desktops** limita el dock a pantallas, escritorios virtuales y actividades de
  KDE concretos, recuerda una pantalla elegida al desconectarse y reconectarse,
  usa la pantalla principal mientras ninguna seleccionada está conectada y deja
  visible un dock con auto-ocultar cuando su borde limita con otro monitor. Los
  indicadores de ejecución pueden seguir el escritorio y la actividad actuales.
- Aplicaciones fijadas configurables: descubre y busca aplicaciones instaladas
  mediante KDE, añade o reordena lanzadores y guarda las preferencias. Ocho
  lanzadores de aplicaciones predefinidos, más los contenedores Home y Downloads
  y la Papelera, forman la configuración inicial.
- Lanzamiento nativo de aplicaciones mediante KService y KIO, con integración de
  activación de Wayland. Un clic normal activa una ventana KDE existente o
  minimiza una ventana activa compatible antes de considerar un lanzamiento; la
  activación sigue limitada al entorno validado descrito abajo.
- Coordinación del lanzamiento inicial, ciclo de ventanas, aplicaciones conocidas
  no fijadas y clic central para abrir una ventana nueva mediante KDE.
- Menús contextuales de lanzadores con acciones de escritorio KDE, documentos
  recientes, desanclaje, acciones de ventana como Move to Desktop, Maximize y
  Fullscreen, y navegación por Lugares de KDE para lanzadores de gestores de
  archivos compatibles.
- Transporte multimedia del reproductor MPRIS de KDE que corresponda al
  lanzador: Previous Track, Play/Pause, Next Track y Stop aparecen solo mientras
  existe un reproductor, siguen sus capacidades en vivo y cierran el menú tras
  enviar la orden. El proveedor privado MPRIS de Plasma queda aislado en un solo
  adaptador.
- Un elemento Papelera respaldado por el estado nativo de KDE. El clic izquierdo
  abre la Papelera; su menú contextual ofrece **Open** y **Empty Trash** tras una
  confirmación temática, la acción destructiva queda deshabilitada mientras está
  vacía, no disponible u ocupada, y KDE entrega un listado nuevo tras la
  operación en vez de suponer un resultado vacío.
- Ajustes del dock para tamaño de iconos, magnificación, rebote, movimiento
  reducido, posición y visibilidad: Always visible, Hide automatically, Dodge
  windows o Windows go below.
- Ajustes de los popups para tamaño, altura y tamaño de icono en su propia
  categoría **Popups**, aplicados a los contenedores de carpeta. La cuadrícula,
  las filas de lista/detalle y el abanico conservan tamaños de glifo
  independientes.
- Ajustes organizados en **Items**, **General**, **Popups**, **Profile** y
  **About**, con **Reset defaults** y edición pendiente mediante Apply, Accept y
  Close. **Profile** importa y exporta un perfil JSON con los elementos del dock,
  los contenedores de carpetas y las preferencias, con vista previa y
  confirmación antes de que los valores importados reemplacen el perfil
  pendiente. **About** muestra la versión de la aplicación, enlaces al sitio y a
  los issues, licencia, autores y la dedicatoria **Made with love**.
- Un efecto de minimización de KWin opcional elegido desde el menú contextual
  del dock. Solo se escriben claves de KWin con `exclusiveGroup=minimize`, se
  registran su presencia y valores originales antes de la primera escritura, y
  se restauran al cerrar limpiamente o con `scripts-user/restore-kde.sh`; una
  clave modificada fuera del dock se deja intacta.
- Un emblema de actualizaciones sobre el lanzador de Discover cuando el equipo
  tiene actualizaciones pendientes. El conteo se lee sólo desde PackageKit,
  fwupd y Flatpak mediante sus interfaces nativas, así que el dock nunca consulta
  a Discover, no instala nada, no refresca cachés de paquetes y no pide
  autorización. El número acompaña y escala con el icono desde su esquina
  inferior derecha, donde KDE pinta sus puntos de actualización, y el emblema usa
  el color con el que KDE pinta sus notificaciones de actualización: naranja
  neutro mientras hay actualizaciones pendientes y rojo negativo cuando hay
  alguna de seguridad. Mientras PackageKit aplica actualizaciones el disco
  muestra el glifo `update-busy` de la bandeja en lugar del número y reconsulta
  en cuanto termina la instalación, así que un conteo recién aplicado no se
  vuelve a pintar. El interruptor **Updates** oculta el emblema sin reiniciar. El
  emblema sigue al frontend de actualizaciones que realmente esté anclado
  (Discover primero) en vez de suponer una distribución, y un servicio ausente
  aporta cero. PackageKit informa su propio backend (`dnf5`, `apt`, `alpm`,
  `zypper`…), así que los paquetes de la distribución funcionan donde PackageKit
  esté instalado; los ayudantes de AUR y Snap aún no se consultan.
- Un interruptor opcional **Start with KDE Plasma** que crea o elimina una
  entrada de autostart XDG propiedad de Punchi. La entrada surte efecto en el
  siguiente inicio de sesión de Plasma. Una entrada de otra herramienta nunca se
  sobrescribe ni se elimina. El interruptor no está disponible durante una
  prueba, cuyo perfil Plasma nunca carga.
- **Aplicaciones recientes** opcionales del historial de actividad de KDE con
  una cantidad configurable. **Presentación** elige entre los lanzadores
  adicionales del dock o un único elemento contenedor con un glifo fijo, cuya
  **Vista del contenedor** ofrece Grid, List, Detail y Fan; el contenedor es la
  presentación inicial con la vista List. Se excluyen las aplicaciones fijadas y
  las que tienen ventanas abiertas en ambas presentaciones. Los ajustes del dock
  incluyen un interruptor que escribe la preferencia de KDE de recordar
  aplicaciones y un acceso a las opciones de Archivos recientes de KDE; si KDE
  no guarda historial, una nota breve explica cómo activarlo.
- Navegación por teclado para el dock, sus menús contextuales y la ventana de
  ajustes.
- Editores de elementos que eligen un icono del tema para cualquier aplicación
  fijada o contenedor de carpeta y lo guardan por nombre, con el icono propio del
  elemento como respaldo.
- Contenedores de carpeta para cualquier carpeta local: presentaciones Grid,
  List, Detail y Fan, orden por contenedor, navegación por subcarpetas y lista
  de entradas ocultas. El contenedor integrado **Home** abre en Fan y muestra
  solo las carpetas estándar de KDE/XDG con sus nombres localizados; su perfil
  inicial deja desactivada la navegación por subcarpetas, así que una carpeta
  seleccionada se abre en el gestor de archivos. Un dock lateral presenta como
  Grid un abanico guardado, porque el arco necesita un borde superior o
  inferior.
- Downloads con vistas Grid, List, Detail y Fan, navegación dentro de un globo
  temático y apertura nativa de archivos de KDE. Cada presentación termina con
  una fila **Open** y marca con un chevron las carpetas por las que se puede
  entrar; el clic derecho sobre una entrada ofrece **Open in File Manager** y
  **Copy Path**. Las columnas salen del espacio real del popup,
  así que el desplazamiento aparece solo cuando las entradas no caben, con un
  indicador fino que se desvanece mientras el listado está en reposo.

Los indicadores de aplicaciones en ejecución y la activación de ventanas
existentes están implementados con validación aislada; las comprobaciones físicas
en KDE siguen pendientes. Un panel separado, una superficie de lanzador de
aplicaciones y controles adicionales quedan para el futuro.

## Limitaciones conocidas

- Software alfa: el comportamiento, la configuración y las API nativas pueden
  cambiar sin migración.
- Quickshell 0.3.0 registra un `WARN: QSettings::value: Empty key passed`
  inofensivo al arrancar en algunas distribuciones, incluida Debian 13. Aparece
  antes de cargar el shell y con una configuración vacía, así que no lo produce
  este proyecto; no cambia el comportamiento y el registro de arranque completo
  lo conserva para diagnóstico.
- Requiere KDE Plasma/KWin en Wayland. Otros escritorios y compositores no están
  soportados. X11 está fuera del alcance y no se planea trabajar en su soporte.
- Fedora 44 con KDE Plasma 6.7.5 y KWin 6.7.5 en Wayland, comprobado el
  2026-10-20, es el entorno principal validado. Arch Linux y Debian 13.7 KDE
  superaron una compilación y una prueba de inicio inicial; la validación de uso
  prolongado y visual completa sigue pendiente.
- Solo instalación desde el código fuente y con prefijo CMake; no hay paquetes
  RPM/DEB, etiquetas ni binarios de versión.
- La activación de ventanas, el transporte multimedia y el cursor de KDE todavía
  necesitan más validación en sesión real. Una disposición de dos pantallas
  (eDP-1 + HDMI-A-1, Plasma 6.7.5) probó docks por pantalla, selección de
  pantalla, respaldo en la principal, filtrado por escritorio y actividad y
  auto-ocultar en bordes compartidos el 2026-10-27; otras disposiciones, la
  conexión física en caliente y el escalado fraccional siguen sin validarse.
- La interfaz gráfica sigue en inglés; esta página es una traducción de la
  documentación.

## Instalación, inicio y regreso a KDE

`git` es necesario para clonar, y el asistente nunca lo instala. Instálalo antes
si falta:

```bash
sudo dnf install git        # Fedora
sudo apt-get install git    # Debian / Ubuntu
sudo pacman -S git          # Arch
```

Después clona el repositorio y entra en el checkout:

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
| Try without installing | `./scripts-user/setup.sh --try` (`--test` es un alias) | Comprueba dependencias, compila el checkout y ejecuta el dock desde el checkout. No instala nada ni usa la copia instalada. La ejecución usa un perfil de prueba propio, así que arranca con los ítems por defecto y nunca lee ni escribe tus preferencias guardadas. Al cerrar el dock, una confirmación elimina la compilación, el perfil de prueba, el registro de estado de ventanas y el bloqueo de ejecución. |
| Start the dock | `./scripts-user/setup.sh --start` | Ejecuta una compilación existente o la instalación local del usuario. No compila nada: usa Try o Build primero. |
| Check dependencies | `./scripts-user/setup.sh --check-deps` | Informa las comprobaciones de runtime, compilación, validación y KDE. Las herramientas Qt también se buscan fuera de `PATH` en el directorio bin de Qt de la distribución. Los nombres de paquetes de Fedora están validados; las equivalencias de Debian/Ubuntu y Arch son de mejor esfuerzo. |
| Check for updates | `./scripts-user/setup.sh --check-updates` | Consulta el remoto Git configurado e informa cuántos commits estás por delante/detrás, la versión declarada en el upstream y la versión de la copia instalada. Solo lee, salvo que se use `--pull`. |
| Update the checkout | `./scripts-user/setup.sh --check-updates --pull` | Ejecuta `git pull --ff-only` después de la comprobación cuando el checkout está detrás. Se niega si hay archivos rastreados modificados y nunca hace rebase, reset ni stash. El menú pregunta antes de hacer el pull y después ofrece reconstruir e instalar; `--pull` nunca instala. |
| Uninstall | `./scripts-user/setup.sh --uninstall` | Detiene este proyecto, restaura los ajustes de KWin propios, elimina una entrada de autostart propiedad de Punchi, el registro de estado de ventanas y la instalación local del usuario. Después pregunta una vez si conservar tus datos o borrar todo; borrar todo elimina también las preferencias, la `punchi-shell.json` heredada, `build/` y el bloqueo de ejecución. |
| Instructions and README | `./scripts-user/setup.sh --instructions` | Muestra comandos, rutas y ubicaciones del README. |

El asistente informa cada acción como una lista breve de fases y ejecuta los
pasos largos tras una única línea de progreso animada que se reescribe en el
sitio. La salida completa de CMake se sigue registrando, y un paso fallido
muestra sus últimas líneas y las adjunta al registro de fallos. La comprobación
de dependencias anima la misma línea mientras recoge el informe y después
imprime el listado capturado, así que la comprobación se ve antes de que llegue
el resultado. En una terminal un paso permanece visible al menos 0,9 s y la
línea de finalización se mantiene 0,4 s, para que una acción rápida no pase de
largo; `PUNCHI_PROGRESS_MIN_SECONDS` y `PUNCHI_PROGRESS_SETTLE_SECONDS` ajustan
ambos, y la salida redirigida nunca espera. Los colores se usan en una terminal y
se desactivan con `--no-color` o `NO_COLOR`. La salida redirigida, `TERM=dumb` y
las configuraciones regionales sin UTF-8 reciben líneas ASCII simples en lugar de
dibujo de caja y una barra en movimiento, así que los registros siguen legibles.

La concurrencia de compilación usa por defecto el número de CPU detectado,
limitado por la memoria instalada (un trabajo por debajo de 4,5 GiB, dos por
debajo de 8,4 GiB, cuatro por debajo de 16 GiB), para que una máquina pequeña no
haga swap durante la compilación nativa. `-j/--jobs N` sustituye el conteo
automático y `PUNCHI_NO_PROGRESS=1` conserva la salida sin procesar.

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

Install/update y Build only vuelven al menú y no inician el dock. Usa Try without
installing, la acción Start, `--install --start` o `--build --start` para
iniciarlo después de la acción. El dock se ejecuta como hijo del asistente, así
que al cerrarlo vuelves al menú.

Solo se ejecuta una instancia de Punchi Dock Quickshell a la vez entre el checkout
y la instalación local. Si intentas iniciar una mientras la otra está activa, se
muestra la ruta activa y el script de restauración que la detiene; no se registra
un segundo backend de ventanas.

Una prueba guarda su propio perfil en el directorio de runtime de la instancia
(`$XDG_RUNTIME_DIR/punchi-dock-quickshell-$UID/trial-profile`, o el directorio
temporal cuando `XDG_RUNTIME_DIR` no está disponible) y lo exporta como
`PUNCHI_PROFILE_DIR`. Ahí viven las preferencias del dock y su entrada de
autostart, así que la prueba arranca con los ítems por defecto, nunca cambia el
perfil de la copia instalada y no puede dejar una entrada que Plasma cargue al
iniciar sesión. Como la sesión nunca lee ese perfil, **Start with KDE Plasma**
queda deshabilitado durante una prueba y la ventana de ajustes explica que la
opción necesita una copia instalada.

### Compatibilidad de un vistazo

| Estado | Distribuciones / ediciones KDE | Plasma | KWin | Qt | KF6 | Kirigami Addons | Quickshell | Comprobado |
|:---:|---|---|---|---|---|---|---|---|
| ✅ | Fedora 44 KDE | 6.7.5 | 6.7.5 | 6.11.2 | 6.31.0 | 1.13.1 | 0.2.1 | 2026-10-20 |
| 🟡 | Arch Linux (rolling, KDE Plasma) | 6.8.2 | 6.8.2 | 6.12.0 | 6.31.0 | 1.16.0 | 0.3.2 | 2026-10-31 · parcial |
| 🟡 | Debian 13.7 KDE (trixie) | 6.3.6 | 6.3.6 | 6.8.2 | 6.13.0 | 1.7.0 | 0.3.0 | 2026-10-30 · parcial |
| ⚪ | Nobara KDE, Fedora Kinoite (KDE Plasma inmutable), CentOS Stream 10 KDE (EPEL), Rocky Linux KDE, AlmaLinux Kitten KDE | — | — | — | — | — | — | — |
| ⚪ | KDE neon, Kubuntu KDE Plasma | — | — | — | — | — | — | — |
| ⚪ | Manjaro KDE, EndeavourOS KDE Plasma, CachyOS KDE, Garuda KDE | — | — | — | — | — | — | — |
| ⚪ | openSUSE Tumbleweed KDE, openSUSE Leap KDE | — | — | — | — | — | — | — |
| ⚪ | KaOS KDE Plasma, Solus KDE | — | — | — | — | — | — | — |
| ❌ | — | — | — | — | — | — | — | — |

✅ validado · 🟡 compila/arranca, validación pendiente · ⚪ no probado, misma familia · ❌ no soportado · ⏳ pendiente · — no aplica. X11 está fuera del alcance y otros compositores no KDE no están soportados.

<details>
<summary>Qué se ejercitó en cada fila comprobada</summary>

- **Fedora 44 KDE** — el entorno principal validado. Ejecuta el grafo de
  validación automatizada completo en cada cambio.
- **Arch Linux (rolling)** — instalación, prueba, menú, contenedores y
  desinstalación ejercitados en un equipo el 2026-10-31. Falta validar uso
  prolongado y comportamiento visual completo, y aparecen avisos de Mesa/Zink.
  No es una declaración de compatibilidad para toda instalación de Arch.
- **Debian 13.7 KDE (trixie)** — el asistente instaló todas las dependencias y
  el dock compiló y arrancó en un equipo el 2026-10-30. Falta validar uso
  prolongado y comportamiento visual completo. Quickshell viene de
  `trixie-backports` y no de la suite de la versión, por lo que el asistente
  ofrece añadir esa suite.

</details>

Solo Fedora 44 tiene el grafo de validación automatizada completo. Lista basada
en la [wiki de distribuciones de KDE Community](https://community.kde.org/Distributions).
Plasma 6.8.0 se publicó el 2026-10-14.

Kirigami Addons aparece en su propia columna porque su API cambia dentro de una
misma serie mayor de KF6: la 1.16.0 eliminó `initialsColor` del avatar y la
ventana de ajustes dejó de cargar en Arch, mientras Fedora 44 (1.13.1) y
Debian 13 (1.7.0) seguían funcionando. Una distribución rolling puede llegar a
una versión incompatible antes que una fija, así que su versión corresponde en
esta tabla junto a Qt y KF6.

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

El runtime también necesita `kbuildsycoca6` de KService. El emblema de
actualizaciones es opcional y no necesita nada de esto al compilar: lee
PackageKit por el bus de sistema, fwupd por el bus de sistema y
`flatpak remote-ls` cuando esos servicios existen. Las pruebas de validación
usan además Python 3, enlaces de D-Bus para Python, PyGObject, `dbus-daemon`,
`desktop-file-utils` y `update-desktop-database`; no son requisitos del runtime.

Usa `./scripts-user/setup.sh --check-deps` para inspeccionar el entorno actual.
Añadir `--install-missing` ofrece además el comando de instalación específico de
Fedora, Debian/Ubuntu o Arch y pregunta antes de ejecutarlo. En Debian,
Quickshell no forma parte de la suite estable: cuando no tiene candidato en apt,
el asistente ofrece habilitar el repositorio `<codename>-backports` con una
confirmación explícita e instala `quickshell` desde allí. Rechazar esa oferta
mantiene instalables los demás paquetes que falten.

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
ambos, prevalece el nombre nuevo y no se sobrescribe ninguno. Una prueba lee y
escribe su propio perfil, que se elimina con la limpieza de la prueba salvo que
rechaces la confirmación. Sin archivo guardado, la aplicación usa los valores por defecto de
[`config/PunchiDefaultProfile.js`](config/PunchiDefaultProfile.js), que también aporta el
catálogo de lanzadores del primer inicio y los valores que restaura **Reset defaults**:

| Ajuste | Valor inicial actual |
|---|---|
| Superficie | Dock inferior por defecto; inferior, izquierda o derecha; todavía no hay barra superior personalizada |
| Elementos fijados, en orden | Dolphin, Konsole, Home, Browser, Kate, System Settings, Discover, Gwenview, Okular, Downloads, Trash |
| Tamaño | 100% del tamaño base derivado del tema |
| Magnificación con el puntero | Activada, con escala máxima del 200% |
| Rebote al hacer clic | Activado |
| Pantallas | Todas las pantallas conectadas, con un perfil compartido |
| Escritorios virtuales y actividades | Todos los escritorios y actividades |
| Visibilidad | Windows go below (`overlay`), sin reservar espacio de pantalla |
| Movimiento reducido | Ajuste local desactivado; las preferencias de animación de KDE siguen aplicándose |
| Iconos | El tema de iconos del usuario, incluidas las notificaciones de cambio de tema de KDE |

Son valores prototipo, no una garantía de que todas las aplicaciones predefinidas
estén instaladas. **Browser** nombra la función y no una aplicación: el elemento
abre el navegador que KDE tiene como gestor preferido de enlaces web, así que
sigue el predeterminado elegido en Configuración del sistema y nunca supone que
Firefox esté instalado. Cambiar ajustes con Apply o Accept guarda los valores del
usuario; los inicios posteriores los cargan. Un modo de inicio explícito puede
sustituir el modo de visibilidad guardado. El formato actual es la versión 13 y
acepta las versiones 1 a 12 mediante migración. La versión 7 añade el interruptor
de aplicaciones recientes y su cantidad visible, la 8 guarda el icono elegido
para una aplicación fijada, la 9 las entradas de carpeta que un contenedor deja
fuera de su popup, la 10 el tamaño, la altura y el tamaño de icono del popup, la
11 tamaños de glifo independientes para cuadrícula, lista/detalle y abanico, la
12 la selección de pantallas, escritorios virtuales y actividades más los dos
interruptores de colocación, y la 13 la presentación de aplicaciones recientes y
su vista del contenedor; los perfiles anteriores sin esos campos usan cinco
aplicaciones, la presentación de contenedor con la vista List, el icono de la
aplicación, la carpeta completa, las proporciones de referencia del popup, los
tamaños de glifo del tema, todas las pantallas y todos los escritorios y
actividades.

La categoría **Profile** exporta los valores pendientes como un documento JSON
portátil con esquema `punchi-dock-quickshell/profile` y versión de formato 1.
La importación también acepta un perfil guardado sin envoltorio, valida cada
campo y muestra el resultado antes de convertirlo en edición pendiente. Un
perfil solo contiene datos: no puede añadir comandos, JavaScript ejecutable,
entradas de inicio automático, configuración de KDE ni contenido de archivos.
El archivo elegido debe ser un archivo regular UTF-8 de como máximo 256 KiB.
Las exportaciones se escriben de forma atómica con permisos solo para el
propietario, y nunca se sobrescribe un enlace simbólico. El inicio automático
sigue siendo una integración de instalación y no forma parte de un perfil.

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
una entrada de autostart propiedad de Punchi, desregistra la entrada de escritorio
del estado de ventanas y borra solo los archivos del manifiesto. Después ofrece
dos formas de terminar: **Keep my data** pregunta por separado sobre `build/` y el
archivo de preferencias, y **Remove everything** elimina las preferencias, la
copia `punchi-shell.json` heredada, `build/`, el bloqueo de ejecución y el registro
de estado de ventanas tras una única confirmación destructiva. Ninguna de las dos
toca el checkout ni el registro de recuperación de KWin. `--remove-settings` y
`--remove-build` siguen disponibles para uso no interactivo; `--keep-build` es un
alias de compatibilidad del comportamiento por defecto.

### Instalación con CMake

Para una instalación con prefijo:

```bash
cmake -S . -B "build/build-$(. /etc/os-release && printf '%s' "$ID")" -G Ninja
cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")"
cmake --install "build/build-$(. /etc/os-release && printf '%s' "$ID")" --prefix ~/.local
```

El asistente y los scripts agrupan un árbol de compilación por distribución bajo
`build/`, como `build/build-debian` o `build/build-fedora`, y `cmake --preset
dev` escribe el árbol genérico de una sola máquina `build/dev`. Los árboles
planos `build-<ID>` y el `build/` simple de los layouts anteriores se siguen
leyendo cuando son los únicos completos. `PUNCHI_BUILD_DIR` cambia la ubicación.

Esto instala `bin/punchi-dock-quickshell`, el árbol QML en
`share/punchi-dock-quickshell`, el backend de ventanas en
`libexec/punchi-dock-quickshell`, una entrada de escritorio y el icono hicolor. El
punto de entrada resuelve su prefijo, por lo que también funciona con `/usr` u
otro `CMAKE_INSTALL_PREFIX`. Esta ruta está pensada para empaquetado y despliegues
avanzados; `scripts-user/setup.sh` sigue siendo el instalador guiado por usuario.

`cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")" --target uninstall`
elimina los archivos registrados en `install_manifest.txt`.
`cpack --config "build/build-$(. /etc/os-release && printf '%s' "$ID")/CPackConfig.cmake"` crea un archivo
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

Los ajustes guardados actuales describen un perfil compartido que se aplica a
cada pantalla permitida. Los perfiles por pantalla, la colocación o los elementos
independientes por monitor y el almacenamiento por instancia siguen siendo
trabajo futuro; necesitan identificadores estables y una migración que preserve
el perfil compartido.

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
`org.kde.plasma.private.mpris`, el módulo interno de Plasma detrás del transporte
multimedia del menú contextual. Las integraciones de ventanas/tareas y el
comportamiento del borde de pantalla de KDE también necesitan probarse contra la
versión objetivo de Plasma/KWin. Prefiere API públicas, aísla las integraciones internas y ofrece una
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
soporte de lectores de pantalla, la conexión física en caliente, otras
disposiciones de pantallas ni el cursor de inicio nativo de KDE. Una prueba real
de dos pantallas cubrió docks por pantalla, selección, respaldo en la principal,
filtrado por escritorio y actividad y auto-ocultar en bordes compartidos; la
captura automatizada de pantalla completa no incluye superficies layer-shell, así
que la inspección visual sigue siendo manual. El changelog registra el alcance de
validación actual y las carencias conocidas.

## Desarrollo

Esta configuración QML se ejecuta en Quickshell. CMake compila los adaptadores
nativos de KDE y organiza la validación. Consulta [AGENTS.md](AGENTS.md) para las
reglas del proyecto y [CONTRIBUTING.md](CONTRIBUTING.md) para el flujo de ramas y
evidencia. Configura y compila con el preset compartido, y ejecuta el grafo sin
compositor:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset headless
```

`ctest --preset headless` ejecuta las etiquetas `unit` y `qml` sin sesión gráfica;
GitHub Actions ejecuta el mismo script, `scripts-dev/ci-headless.sh`, en Fedora 44.
El grafo completo añade la etiqueta `session`, que necesita una sesión activa de
KDE Plasma/KWin en Wayland:

```bash
ctest --test-dir build --output-on-failure
```

## Estructura modular

| Directorio | Responsabilidad |
|---|---|
| `shell.qml` | Compone los módulos del shell |
| `modules/dock/` | Ventana, vista, menús contextuales y confirmación de la Papelera |
| `modules/folders/` | Popups, diseños y navegación de contenedores de carpeta |
| `modules/settings/` | Ventana de ajustes, categorías, editores de elementos e intercambio de perfiles |
| `components/` | Primitivas visuales de interacción compartidas |
| `services/` | Datos de modelo, intercambio de perfiles y coordinación |
| `config/` | Perfil inicial, ajustes reactivos, validación de documentos y métricas compartidas |
| `adapters/kde/` | Adaptadores KDE para lanzamiento, multimedia, actualizaciones, Papelera, movimiento y estado de ventanas |
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

La base de este proyecto es [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered),
el applet de Plasma cuyo dock, modelo de elementos, movimiento e interacción este
port reconstruye. También toma inspiración arquitectónica y visual de
[Caelestia Shell](https://github.com/caelestia-dots/shell), mientras implementa
la integración de escritorio para KDE/KWin. Consulta [NOTICE.md](NOTICE.md) para
el código, los recursos y la atribución reutilizados.

## Hecho con amor

Hecho con amor, para la comunidad. Un port nativo del plasmoid [Punchi Dock
Remastered](https://github.com/PunchiSoft/punchi-dock-remastered), construido
para ir más allá de lo que un plasmoid puede hacer en KDE Plasma. Algunos dicen
que los docks pasaron de moda, como el punchi punchi; solo Windows los olvidó, y
Linux nunca lo hará.

**¡Linux para todos!**

## Licencia

GPL-3.0-or-later. Consulta [LICENSE](LICENSE) y [NOTICE.md](NOTICE.md).

Las skills de agente de [`.agents/skills/`](.agents/skills/README.md) se pueden
reutilizar y adaptar. Conserva su campo `license`, el aviso de copyright y cualquier
entrada `metadata.source` que nombre el proyecto del que proceden; se agradece citar
este repositorio con el commit del que las tomaste. El catálogo de skills detalla las
condiciones exactas.
