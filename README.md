# 🚀 GitLab Recovery Suite (Docker Edition)

Este conjunto de scripts automatiza el proceso completo de recuperación de un servidor GitLab sobre Docker. El sistema se encarga desde la descarga del backup desde un almacenamiento externo hasta la restauración de la base de datos y la limpieza de archivos sensibles.

## 📋 Índice
1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Descripción de los Scripts](#descripción-de-los-scripts)
3. [Configuración (my.conf)](#configuración-myconf)
4. [Flujo de Ejecución](#flujo-de-ejecución)
5. [Requisitos Técnicos](#requisitos-técnicos)
6. [Seguridad](#seguridad)

---

## 🏗️ Arquitectura del Sistema

El sistema utiliza un **Script Maestro** (`correo.sh`) que actúa como director de orquesta, ejecutando cada fase de forma secuencial. Si algún paso falla, el sistema aborta la operación y envía una alerta detallada por correo electrónico.

Cada línea de los logs generados incluye:
* **Timestamp**: Fecha y hora exacta de cada evento.
* **Zona Horaria**: Identificador regional (ej. CEST, UTC) para evitar confusiones horarias.
* **Contexto**: El script específico que generó la salida capturado en tiempo real.

---

## 📄 Descripción de los Scripts

### 1. `correo.sh` (El Maestro)
Es el punto de entrada principal. Gestiona el log global en `/tmp`, controla el flujo de errores y utiliza `curl` para enviar notificaciones SMTP basadas en las plantillas de mensaje.

### 2. `conexion.sh`
Se encarga de la comunicación con el almacenamiento externo de Hetzner. 
* **Optimización**: Utiliza el protocolo SMB con parámetros `rsize=1048576` y `wsize=1048576` para maximizar la velocidad de descarga.
* **Automatización**: Localiza automáticamente el archivo de backup más reciente en la red.

### 3. `scriptdocker.sh`
Prepara el entorno de contenedores.
* **Detección**: Analiza el backup para extraer la versión exacta de GitLab.
* **Despliegue**: Genera dinámicamente el archivo `docker-compose.yml` y levanta los servicios.

### 4. `decrypt.sh`
Fase de seguridad crítica que utiliza GPG.
* **Procedimiento**: Importa la clave `decrypt.gpg` y usa la frase de paso de `pass.txt` para descifrar los archivos de configuración sensibles.

### 5. `restauracion.sh`
Realiza la carga de datos en el contenedor.
* **Health Check**: Implementa una espera inteligente hasta que los servicios internos de GitLab estén operativos.
* **Restauración**: Ejecuta el comando `gitlab-backup restore` de forma forzada para asegurar la integridad de los datos.

### 6. `limpieza.sh`
Garantiza la higiene del sistema tras el proceso.
* **Destrucción de Secretos**: Elimina los archivos `gitlab-secrets.json` y `gitlab.rb` en texto plano para evitar brechas de seguridad.
* **Vaciado**: Limpia la carpeta temporal de backups.

---

## ⚙️ Configuración (`my.conf`)

Toda la lógica está centralizada en `my.conf`. **No es necesario editar los scripts individuales**.

| Variable | Descripción |
| :--- | :--- |
| `BACKUP_DIR` | Ruta local donde se procesan los backups descargados. |
| `GITLAB_HOME` | Directorio raíz para los datos persistentes de GitLab. |
| `RUTA_RED` | Dirección SMB del servidor de almacenamiento externo. |
| `SMTP_SERVER` | Servidor de correo para las notificaciones. |
| `SERVICE_NAME` | Nombre asignado al contenedor de GitLab en Docker. |

---

## 🛠️ Requisitos Técnicos

* **OS**: Debian / Ubuntu.
* **Dependencias**: `docker-compose`, `cifs-utils`, `gnupg2`, `curl`, `unzip`.
* **Permisos**: Los scripts deben ser ejecutables (`chmod +x *.sh`) y lanzarse con `sudo`.

---

## 🔒 Seguridad

* **Cifrado**: Los archivos de configuración críticos viajan y se almacenan cifrados con GPG.
* **Limpieza Post-Uso**: El sistema borra automáticamente cualquier rastro de contraseñas en texto plano una vez finalizada la restauración.
* **Control de Errores**: El script maestro detecta fallos en cualquier etapa y detiene el proceso para proteger los datos.

---
