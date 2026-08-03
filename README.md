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

<br>

</div>

Yuuna WebUI es una **arquitectura de referencia**. Está diseñado para ofrecer una configuración rápida y lista para usar de Open WebUI, concebida mediante el pulido de sus recomendaciones oficiales bajo criterio personal. Dando lugar a una plataforma resiliente enfocada en la privacidad y estabilidad de sus componentes.

Este proyecto nace para facilitar un entorno de asistencia multipropósito evitando las restricciones de las interfaces comerciales y sus elevados precios, con la ventaja de que todo tu historial permanece en tu maquina y no se usa para entrenar sus modelos.

### Características Principales

* **Despliegue Seguro:** Mayor seguridad al estar basado en Podman Rootless, y con un script automatizado de despliegue y actualización.
* **Red Aislada:** Configurado para apuntar explícitamente al loopback local, eludiendo fluctuaciones de red y aumentando la fiabilidad de la interfaz.
* **Privacidad Absoluta:** Tus datos, prompts y configuraciones viven únicamente en tu almacenamiento local.
* **Enfoque Creativo:** Preparado para emular funciones avanzadas como los "Gems" de Gemini y cuadernos de investigación estilo NotebookLLM (Documentación en camino).

## Inicio Rapido

### Prerrequisitos 
#### Linux

* **Solus**
```bash
sudo eopkg it podman openssl curl
```
* **Debian / Ubuntu / Linux Mint:**
```bash
sudo apt update && sudo apt install podman openssl curl -y
```
* **Fedora / Rocky Linux:**
```bash
sudo dnf install podman openssl curl -y
```
* **Arch Linux / CachyOS / Manjaro:**
```bash
sudo pacman -Syu podman openssl curl
```
#### Windows

**Proximamente**

### Instalación con un solo comando

Una vez instalados los prerrequisitos, ejecuta el siguiente comando en tu terminal. Este script descargará la imagen oficial, configurará la red y preparará tus volúmenes persistentes.

```bash
curl -fSL https://gitlab.com/AlterNezKo/yuuna-webui/-/raw/main/scripts/deploy.sh | bash
```

> **Nota:** Si necesitas actualizar Yuuna WebUI en el futuro, simplemente vuelve a ejecutar este mismo comando. Tus datos, configuraciones y usuarios permanecerán intactos en tu máquina.
> 
> 

Cuando el script finalice y veas el mensaje de éxito, espera al menos 1 minuto mientras el backend se inicialice, esto solo sucedera la primera vez, entonces abre tu navegador web de preferencia y dirígete a:

* **URL de acceso:** `http://127.0.0.1:3000`

### Auto-arranque

Una vez que el script finaliza, Yuuna WebUI estará corriendo y listo para configurarse. Sin embargo, dado que utilizamos Podman sin privilegios de administrador, el contenedor no se iniciará automáticamente si reinicias tu computadora. Para levantar el entorno cuando lo necesites, utiliza:

```bash
podman start yuuna-webui
```
Si tu equipo cuenta con recursos limitados, 8 GB de RAM o menos, recomiendo mantener este comportamiento. De ese modo enciendes tu entorno solo cuando realmente vayas a usarlo.

Cuando necesites liberar memoria para otras aplicaciones, puedes detener el contenedor limpiamente con:

```bash
podman stop yuuna-webui
```
___

### Copias de Seguridad y Restauración

Open WebUI recibe actualizaciones frecuentes. Se recomienda encarecidamente realizar una copia de seguridad antes de cada actualización.

Gracias a la arquitectura de Yuuna WebUI, todos tus datos: chats, documentos subidos y credenciales viven de forma segura en un solo directorio en tu máquina host: `~/.local/yuuna-webui/`.

#### Crear un Respaldo

Para asegurar tus datos, es vital detener el contenedor antes de copiar los archivos. Esto evita que la base de datos se corrompa si se está escribiendo en ella justo en el momento de la copia.

**Detener Yuuna WebUI**
```bash
podman stop yuuna-webui
```

**Comprimir toda la carpeta en un archivo seguro con la fecha actual**
```bash
tar -czvf yuuna-backup-$(date +%F).tar.gz ~/.local/yuuna-webui/
```

**Volver a encender Yuuna WebUI**
```bash
podman start yuuna-webui
```

*Esto generará un archivo comprimido en tu carpeta. Guárdalo en un lugar seguro.*

#### Restaurar un Respaldo

Si algo se rompe, el proceso para volver en el tiempo es igual de sencillo.

**Detener y eliminar el contenedor**
```bash
podman rm -f yuuna-webui
```

**Eliminar la carpeta de datos corrupta para ir sobre seguro**
```bash
rm -rf ~/.local/yuuna-webui/data
```
**Restaurar tu carpeta desde el archivo .tar.gz**
```bash
tar -xzvf yuuna-backup-AQUI_LA_FECHA.tar.gz -C /
```
**Volver a levantar el entorno fijando la última versión estable que te funcionó**
_Ejemplo: Si la v0.12.1 falló, regresa a la v0.11.0_
```bash
deploy.sh v0.11.0
```
---

### Documentación extendida

Próximamente se añadirán guías detalladas de uso y recomendaciones generales.

- Filosofia del proyecto: ¿por que Yuuna WebUI?
- Recomendaciones: Open WebUI y flujo creativo
- Recomendaciones: Modelos

**Proximamente**

###  Licencia

Este proyecto y su documentación se distribuyen bajo la licencia **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. Eres libre de compartir y adaptar este material, siempre y cuando otorgues el crédito correspondiente y distribuyas tus contribuciones bajo la misma licencia.

