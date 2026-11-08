# Changelog

Todas las novedades y cambios notables de Yuuna WebUI se documentarán en este archivo.

## [v2.1.1] - 08-11-2026
### Mantenimiento y Correcciones
- **Claridad en modos de red y despliegues VPS:** Ajuste en las descripciones interactivas, ayuda del CLI y documentación en `README.md` para distinguir con precisión el modo Loopback aislado (`127.0.0.1`, recomendado para equipos personales y VPS con Proxy Inverso) frente al modo abierto a la Red Local / LAN (`0.0.0.0`).

## [v2.1.0] - 07-11-2026
### Añadido
- **Auto-actualización integrada:** Ahora `yuuna-ui update` verifica automáticamente si existe una versión superior de `yuuna-ui` en el repositorio oficial y la actualiza antes de actualizar el contenedor de Open WebUI. También disponible por separado mediante `yuuna-ui self-update`.
- **Modo de desinstalación:** Nuevo subcomando `yuuna-ui uninstall` para desinstalar limpiamente el contenedor, las imágenes de Open WebUI en Podman, incluyendo limpieza de imágenes huérfanas, y la CLI `yuuna-ui`.

## [v2.0.1] - 05-11-2026
### Mantenimiento y Correcciones
- **Depuración del código fuente:** Limpieza de comentarios redundantes.
- **Documentación:** Correcciones ortotipográficas en el `README.md`.

## [v2.0.0] - 04-11-2026
### Añadido
- **Evolución a Yuuna WebUI CLI (`yuuna-ui`):** `deploy.sh` pasa de ser un instalador básico a una herramienta de línea de comandos autoinstalable en el sistema para gestionar el ciclo de vida completo del contenedor (actualizaciones, control de encendido/apagado, estado, registros y cambio de versiones).
- **Copias de seguridad integradas:** Nuevas funciones automatizadas de respaldo y restauración segura que gestionan la pausa y reanudación del contenedor sin intervención manual.
- **Despliegue en Red Local y Cloud:** Selector de red interactivo y por argumentos que permite elegir entre el modo privado tradicional (`Loopback`) o exponer el servicio en la red local / servidores remotos, guardando la preferencia para futuras actualizaciones.
- **Verificación de dependencias y entorno:** Comprobación previa de herramientas necesarias, estado de Podman Rootless y puertos libres, ofreciendo ayudas de instalación para Debian/Ubuntu, Arch, Fedora, Solus y Void Linux.
- **Verificación real de estado (Healthcheck):** Sondeo activo del contenedor y del backend de Open WebUI durante el arranque para confirmar que el servicio está realmente listo antes de finalizar.
- **Modo de simulación (`--dry-run`):** Opción para previsualizar las acciones del script sin realizar cambios en el sistema.

### Seguridad
- **Endurecimiento general del instalador:** Protección contra ejecuciones incompletas en descargas remotas, instalación atómica del CLI y bloqueo por defecto de ejecuciones como usuario `root`.
- **Protección de datos y volúmenes:** Restricción automática de permisos en archivos sensibles (`.env` y respaldos), validación de integridad al restaurar copias de seguridad y soporte automático para sistemas con **SELinux** activo.
- **Actualización de licencia a GNU GPL v3.0:** Transición desde CC BY-SA 4.0 hacia GPLv3 para brindar cobertura legal específica de software libre al código del proyecto.

## [v1.0.0] - 02-08-2026
### Añadido
- Lanzamiento oficial de Yuuna WebUI.
- Script `deploy.sh` optimizado para automatizar la instalación y futuras actualizaciones de Open WebUI.
- Configuración de red forzada al loopback local `127.0.0.1` para mayor seguridad.
- Documentación inicial `README.md` con guía de Inicio Rápido.
