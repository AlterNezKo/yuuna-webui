<div align="center">

<pre>
#  __   __                        __        __   _     _   _ ___ 
#  \ \ / /   _ _   _ _ __   __ _  \ \      / /__| |__ | | | |_ _|
#   \ V / | | | | | | '_ \ / _` |  \ \ /\ / / _ \ '_ \| | | || | 
#    | || |_| | |_| | | | | (_| |   \ V  V /  __/ |_) | |_| || | 
#    |_| \__,_|\__,_|_| |_|\__,_|    \_/\_/ \___|_.__/ \___/|___|
#                                                                
</pre>

**Un framework de despliegue ágil, seguro y optimizado para Open WebUI**

___


> Repositorio canónico: [Yuuna WebUI en GitLab](https://gitlab.com/AlterNezKo/yuuna-webui)
> -- El repositorio de GitHub es un espejo de solo lectura.

___
<br>

</div>

Yuuna WebUI es una herramienta de gestión diseñada para desplegar Open WebUI de forma rápida, privada y lista para usar. Nace de pulir las recomendaciones oficiales bajo un enfoque práctico: ofrecer una plataforma resiliente que funcione sin fricción tanto en tu equipo personal como en un servidor propio.

Su objetivo es facilitarte un entorno de asistencia multipropósito sin las restricciones ni las limitaciones de las interfaces comerciales, con la garantía de que tus conversaciones, documentos y configuraciones permanecen bajo tu control.

### Características Principales

* **Despliegue Seguro y Verificado:** Basado en contenedores Podman Rootless, con comprobación automática de dependencias y healthcheck.
* **Gestor CLI Integrado:** Incluye su propia utilidad de línea de comandos para actualizar, iniciar, detener, respaldar o cambiar de versión con un solo comando.
* **Red Flexible:** Aislado por defecto en `127.0.0.1` para máxima seguridad, con opción de apertura directa a tu red doméstica `0.0.0.0` para entrar desde otros dispositivos.
* **Privacidad Absoluta:** Todos tus chats, prompts, credenciales y respaldos viven únicamente en tu almacenamiento local `~/.local/yuuna-webui/`.

---

## Inicio Rápido

### Prerrequisitos

#### Linux

* **Solus:**
```bash
sudo eopkg it podman openssl curl tar
```
* **Debian / Ubuntu / Linux Mint:**
```bash
sudo apt update && sudo apt install podman openssl curl tar
```
* **Fedora / Rocky Linux:**
```bash
sudo dnf install podman openssl curl tar
```
* **Arch Linux / CachyOS / Manjaro:**
```bash
sudo pacman -Syu --needed podman openssl curl tar 
```
* **Void Linux:**
```bash
sudo xbps-install -S podman openssl curl tar
```

### Instalación con un solo comando

Una vez instalados los prerrequisitos, ejecuta el siguiente comando en tu terminal. El asistente verificará tu entorno, te permitirá elegir el modo de red, configurará tus volúmenes persistentes e instalará la herramienta `yuuna-ui`:

```bash
curl -fSL https://gitlab.com/AlterNezKo/yuuna-webui/-/raw/main/scripts/deploy.sh | bash
```

> **Nota:** Para actualizar Yuuna WebUI en el futuro, ya no necesitas volver a pegar este enlace; basta con ejecutar `yuuna-ui update` desde tu terminal. Tus datos, sesiones y usuarios permanecerán intactos.
>
> ¿Desplegando en un VPS con dominio propio? Elige el modo por defecto y apunta tu proxy inverso a `127.0.0.1:3000`.

El instalador esperará automáticamente hasta confirmar que la base de datos y el backend de Open WebUI hayan terminado de inicializarse. En cuanto veas el mensaje de éxito, abre tu navegador en la dirección indicada.

### Gestión Diaria y Auto-arranque

Al utilizar Podman en modo Rootless, el contenedor no levantará automáticamente al reiniciar tu computadora. Si tu equipo cuenta con 8 GB de RAM o menos, este comportamiento es ideal para encender tu entorno únicamente cuando lo necesites.

Puedes controlar Yuuna WebUI en cualquier momento mediante el comando `yuuna-ui`:

**Iniciar el entorno:**
```bash
yuuna-ui start
```

**Detener el entorno y liberar memoria RAM:**
```bash
yuuna-ui stop
```

**Consultar el estado y la salud del servicio:**
```bash
yuuna-ui status
```

> Ejecuta `yuuna-ui --help` para ver todas las opciones disponibles.

---

### Copias de Seguridad, Restauración y Rollback

Open WebUI recibe actualizaciones constantes. Se recomienda realizar una copia de seguridad antes de actualizar. Todos tus datos viven de forma centralizada en `~/.local/yuuna-webui/`, y `yuuna-ui` automatiza el proceso completo.

#### Crear un Respaldo

Ejecuta el siguiente comando para crear una copia de seguridad. `yuuna-ui` detendrá temporalmente el contenedor para evitar que la base de datos se corrompa durante la copia, comprimirá tus datos en `~/.local/yuuna-webui/backups/` y volverá a encender el servicio automáticamente:

```bash
yuuna-ui backup
```

#### Restaurar un Respaldo y Rollback de Versión

Si una nueva versión de Open WebUI presenta algún fallo, volver a un estado funcional toma solo dos pasos:

**1. Fijar la última versión estable que te funcionó**

```bash
yuuna-ui v0.11.0
```

**2. Restaurar tu copia de seguridad previa:**

```bash
yuuna-ui backup-restore <nombre-del-respaldo.tar.gz>
```
> **Nota:** Si ejecutas `yuuna-ui backup-restore` sin argumentos, te mostrará la lista de respaldos disponibles.

---

### Desinstalación

Si deseas retirar Yuuna WebUI de tu sistema ejecuta:

```bash
yuuna-ui uninstall
```
> Por seguridad, el asistente te preguntará si deseas conservar tus conversaciones y respaldos en `~/.local/yuuna-webui/`. Si prefieres borrar absolutamente todo en un solo paso, utiliza `yuuna-ui uninstall --purge`.

---

### Licencia

Este proyecto se distribuye bajo la licencia **GNU General Public License v3.0 (GPLv3)**. Eres libre de usar, estudiar, compartir y modificar este software, siempre y cuando mantengas el reconocimiento de autoría y distribuyas cualquier versión derivada bajo esta misma licencia libre. Consulta el archivo [`LICENSE`](LICENSE) para más detalles.
