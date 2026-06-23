# 📖 Manual de Despliegue: Yuna Haven AI 
**Quia de inicio rápido para una instancia de Open WebUI + Google Gemini sin censura**

Este documento detalla la arquitectura, el despliegue y los protocolos de mantenimiento para un entorno local de asistencia de IA multiproposito, pero preparada para la asistencia literaria sin tabues. El sistema está diseñado para operar de forma privada mediante Podman en modo Rootless, integrando la API de Google Gemini omitiendo las restricciones comerciales de contenido mediante políticas permisivas de seguridad.

> ⚠️ **Nota de Configuración:** Este manual detalla un despliegue optimizado para un entorno de producción personal. Las instrucciones están alineadas con los estándares oficiales de Open WebUI, reduciendo la arquitectura a los ajustes mínimos indispensables para garantizar seguridad, portabilidad y una puesta en marcha en pocos minutos. Para modificaciones avanzadas, consulte la documentación oficial de los proyectos base.

> ⚠️ **Censura en Gemini:** Las limitaciones conocidas forman parte de un filtro hecho por Google para evitar el mal uso de su plataforma. Sin embargo, a nivel de API es posible remover los filtros de protección que hacen a la IA *políticamente correcta*, lo que permite la generación de contenido muy sugerente o con violencia de alto grado, pero aun así **NO podrás crear contenido para adultos.** Los bloqueos de narrativas o contextos NSFW explícitos están vetados a nivel de código del modelo.

## ¿Por qué Yuna Haven?
**Yuna Haven AI** nace de la necesidad de crear un entorno de asistencia narrativa diseñado especialmente para explorar géneros controvertidos sin las barreras de la censura algorítmica empujadas por las BigTech, sin dejar de ser una herramienta muy poderosa de uso general. Una lluvia de ideas durante creación de mundos ricos, arquitecturas de sociedades distopicas y escenarios viscerales en tiempos olvidados exigen herramientas que actúen como verdaderos copilotos, no hacer el papel de un policía de la moral que te dice cuando algo fue demasiado.

*«—¿Quien está escribiendo la historia? ¿Tu o yo?»*

Podrías decir que existen modelos por ahí que dan esa libertad que tanto estoy buscando... o mejor aún, sugerir alojar mi propio modelo de lenguaje sin censura en local. Y aunque técnicamente tienes razón, no es tan simple.

Si bien existen modelos Open Source excelentes como LLama o los más recientes de la familia  Qwen, hay que ser honestos; no estan a la la altura de de lo que Gemini o ChatGPT pueden ofrecer, no en lo que respecta a capacidad de razonamiento. Cuando quieres escribir más allá de cierto nivel, esa limitación *se nota.* 

**¿Por que Gemini?**
Claude y ChatGPT son un poco mejores al redactar por su cuenta, pero ambos son demasiado *mojigatos*, Grok es 0% filtros y te da libertad absoluta, pero es pésimo estructurando ideas. Gemini esta cerca del nivel de Claude en razonamiento profundo y es lo suficientemente permisivo, aunque no al nivel de Grok. De todos este es el más flexible por diseño. Y vamos, el objetivo es que la IA te de ideas, no que te haga el trabajo.

Más allá de la filosofía, para garantizar este nivel de libertad, la arquitectura del proyecto se sostiene sobre dos pilares técnicos innegociables:

* **Bypass de Políticas:** La integración de pipelines dinámicos intercepta y reescribe las cabeceras de las peticiones hacia la API comercial, forzando un umbral de seguridad permisivo que devuelve el control *casi* absoluto de la generación de texto a quien escribe.

* **Soberanía y Privacidad:** El entorno se ejecuta íntegramente en el espacio del usuario sin requerir privilegios de administrador, minimizando la superficie de ataque al tiempo que mantienes el sistema anfitrión limpio. Además, en la web de Google, tus borradores y todo el historial de tu mundo viven en sus servidores y se exponen a su telemetría.

*«—¿Qué más necesitas saber?»*

## Prerrequisitos

Antes de iniciar el despliegue, asegúrese de contar con los siguientes elementos:

* **Sistema Operativo:** Entorno Linux con el motor de contenedores Podman instalado y configurado.
* **Credenciales de API:** Una clave de API activa de Google Gemini, generada desde el panel de [Google AI Studio](https://ai.google.dev/).
* **Firma de Seguridad:** Una cadena de texto segura y aleatoria de 32 bytes para la variable `WEBUI_SECRET_KEY`. Puedes generarla localmente ejecutando:
```bash
openssl rand -hex 32
```

---
## Fase 1: Despliegue de la Infraestructura Base

El despliegue estándar expone los puertos en la interfaz abierta `0.0.0.0`, lo que permite que cortafuegos agresivos o políticas de enrutamiento de clientes VPN intercepten el tráfico local, provocando fallos de pasarela (El dichoso error 504 Gateway Timeout con el que me tropecé un par de veces). Para mitigar esto, el contenedor se ancla estrictamente a la interfaz de loopback local `127.0.0.1`. Esto encapsula el tráfico dentro del núcleo del sistema operativo, garantizando el acceso ininterrumpido independientemente del estado de la red externa.

Asimismo, se omite el uso de la etiqueta `:main` o `:latest` debido a la volatilidad de la base de código de Open WebUI. Fijar una versión específica protege el entorno de rupturas imprevistas durante las migraciones automáticas de la base de datos.

**Comando de construcción e inicio:**

```bash
podman run -d \
  --replace \
  -p 127.0.0.1:3000:8080 \
  -e WEBUI_SECRET_KEY="TU_KEY_GENERADA_EN_PREQUISITOS" \
  -v ~/.local/yuna-haven-ai/data:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:<COLOCA_AQUI_LA_VERSION_ESTABLE>

```

>  **Control de Versiones:** Sustituya el marcador `<COLOCA_AQUI_LA_VERSION_ESTABLE>` con el identificador de la última versión oficial (por ejemplo, `v0.9.6`). La ejecución directa del comando manteniendo el marcador provocará un fallo sintáctico intencional.
>  **Persistencia de Datos:** La adopción de la ruta oculta `~/.local/yuna-haven-ai/data` se alinea con la especificación del estándar XDG para el almacenamiento de datos aislados de usuario. Esta práctica previene la contaminación del directorio raíz del usuario y emula políticas limpias de entornos de producción. Si prefiere visibilidad directa en el sistema de archivos, puede modificar el origen del volumen (`-v`) hacia cualquier ruta absoluta de su preferencia antes de ejecutar el contenedor.


---

## Fase 2: Persistencia del Sistema (opcional)

Dado que Podman opera sin un daemon maestro en el espacio del usuario, es necesario delegar la responsabilidad del arranque a Systemd para que el servicio sobreviva a los reinicios del hardware. Este paso es opcional, si lo saltas, será necesario levantar el contenedor manualmente antes de usarlo.

**1. Habilitar la persistencia del usuario:**
Permite ejecutar servicios en segundo plano desde el encendido, sin requerir inicio de sesión manual.

```bash
loginctl enable-linger $USER
```

**2. Activar el servicio de auto-reinicio de Podman:**
Levantará automáticamente cualquier contenedor creado con la bandera `--restart always`.

```bash
systemctl --user enable --now podman-restart.service
```

---
## Fase 3: Inyección del Pipeline (Bypass de Restricciones)

Para garantizar libertad creativa total en narrativas complejas y evadir los bloqueos de contenido de la API estándar de Google, se implementa un Manifold Pipe comunitario que intercepta las peticiones y fuerza políticas de seguridad permisivas.

**1. Instalación del Script:**

* Acceda a la interfaz web local (`http://127.0.0.1:3000`).
* Navegue a **Workspace (Espacio de Trabajo) > Functions (Funciones)**.
* Cree una nueva función y asígnele un identificador descriptivo (Ej. `Google Gemini ++`).
* Copie y pegue el código fuente del [script Google Gemini Pipeline](https://openwebui.com/posts/google_gemini_5a64dbc0) en el editor.
* Guarde los cambios y asegúrese de que el interruptor principal de la función quede en estado **Activo**.

**2. Configuración de Variables:**
Las Valves actúan como variables de entorno específicas para la función. Haga clic en el icono de ajustes (engranaje) de la función creada y configúrelas en la pestaña correspondiente:

* `GOOGLE_API_KEY`: Ingrese la credencial generada en Google AI Studio.
* `USE_PERMISSIVE_SAFETY`: Establezca el valor en **True**. *(Parámetro crítico: reescribe los umbrales de censura a `BLOCK_NONE`).*
* `INCLUDE_THOUGHTS`: Establezca el valor en **True**. *(Habilita la visibilidad de la Cadena de Pensamiento, útil para auditar el razonamiento interno de la IA).*

---

## Fase 4: Optimización de Cuota y Prevención de Rate Limits

Por defecto, Open WebUI ejecuta tareas concurrentes en segundo plano para mejorar la experiencia de usuario. Sin embargo, estas automatizaciones envían ráfagas de peticiones invisibles que agotan velozmente los límites restrictivos de las capas gratuitas, resultando en bloqueos por saturación `429 RESOURCE_EXHAUSTED`. o inflan el consumo de tokens en entornos facturables.

Para garantizar que la cuota de la API se consuma única y exclusivamente en la generación activa de texto, aplique las siguientes mitigaciones:

**1. Silenciar Automatizaciones de Interfaz:**
Navegue a **Panel de Administración > Ajustes > Interfaz** (*Settings > Interface*) y **desactive** las siguientes opciones:

* Generación de Autocompletado (*Autocomplete Generation*, si está disponible en su versión).
* Generación de Títulos (*Title Generation*).
* Generación de Etiquetas (*Tags Generation*).

---
## Fase 5: Protocolo de Mantenimiento y Backups

Dada la alta cadencia de desarrollo de Open WebUI, las migraciones estructurales de la base de datos, presenta un riesgo inherente de corrupción. **La regla de oro de esta infraestructura es jamás ejecutar una actualización sin un respaldo previo.**

**1. Respaldo Pre-Actualización:**
Con el contenedor detenido, genere un tarball que congele el estado exacto de su directorio de datos, etiquetado con la fecha actual.

```bash
podman stop open-webui
tar -czvf yuna_haven_pre_update_$(date +%F).tar.gz -C ~/.local/yuna-haven-ai data

```

**2. Proceso de Actualización Segura:**

* **Cuarentena:** Espere al menos 7 días tras el lanzamiento de una nueva Release oficial para evitar bugs de día cero.
* **Modificación:** Edite el comando original de la **Fase 1**, cambiando la etiqueta de la imagen a la nueva versión confirmada.
* **Despliegue:** Ejecute el comando. La bandera `--replace` se encargará automáticamente de destruir el contenedor obsoleto y levantar el nuevo conectándolo a sus datos.

**3. Protocolo de Rollback En caso de fallo crítico:**
Si la actualización corrompe el sistema, la mejor solución es borrar todo, rehacer el contenedor y restaurar la copia de seguridad.
```bash
# 1. Aniquilar el contenedor corrupto
podman rm -f open-webui

# 2. Purgar el directorio de datos contaminado
rm -rf ~/.local/yuna-haven-ai/data/*

# 3. Extraer la cápsula de respaldo (Sustituya el nombre del archivo con su fecha)
tar -xzvf yuna_haven_pre_update_AÑO-MES-DIA.tar.gz -C ~/.local/yuna-haven-ai
```

> Es indispensable vaciar la carpeta `data` antes de la extracción (el paso 2). El comando `tar` sobrescribe archivos existentes, pero no elimina archivos nuevos. Si la actualización fallida generó nuevos esquemas, tablas o archivos temporales, estos sobrevivirán a la extracción y corromperán la versión antigua al intentar arrancar.

