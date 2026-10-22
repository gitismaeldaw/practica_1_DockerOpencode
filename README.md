# Tablón de notas (Flask + Redis)

Aplicación web para publicar notas en un tablón. Cada nota se guarda en una lista de
**Redis**; la portada muestra las 50 más recientes. Incluye un endpoint de salud (`/salud`).

Está contenerizada con **Docker Compose**: dos servicios, `web` (la app) y `cache` (Redis).

---

## 1. Requisitos

- **Docker Engine** con el plugin **Compose v2** (verificar con `docker --version` y `docker compose version`).
- El usuario del sistema debe poder ejecutar Docker (pertenecer al grupo `docker`, o usar `sudo`).
- Puerto **8000** libre en el host (si está ocupado, ver [Puesta en marcha](#3-puesta-en-marcha)).

> No hace falta instalar Python ni Redis en el host: ambos van dentro de los contenedores.

---

## 2. Variables de entorno

Se definen en **`docker-compose.yml`**, nunca dentro de la imagen.

| Variable | Valor usado | Descripción |
|----------|-------------|-------------|
| `REDIS_URL` | `redis://cache:6379` | Conexión a Redis. `cache` es el nombre del servicio dentro de la red del compose (no `localhost`). |
| `TITULO_APP` | `Tablón de notas` | Título mostrado en la portada. |

Ambas tienen valor por defecto en `app.py`, pero en Compose hay que fijar `REDIS_URL`
apuntando al servicio `cache`, porque `localhost` dentro del contenedor `web` sería él mismo.

---

## 3. Puesta en marcha

Desde la raíz del proyecto:

```bash
docker compose up -d --build
```

Comprobar que los dos servicios están **sanos**:

```bash
docker compose ps
```

Se debe ver `(healthy)` tanto en `web` como en `cache`. `web` arranca solo después de que
`cache` esté sano (gracias a `condition: service_healthy`).

> **Si el puerto 8000 está ocupado:** cambia la línea `ports` del servicio `web` en
> `docker-compose.yml`, por ejemplo `"8080:8000"`, y usa el puerto nuevo en las pruebas.

---

## 4. Pruebas de comprobación

```bash
# Estado de salud (Redis responde y cuenta las notas)
curl -s localhost:8000/salud
#  → {"estado":"ok","notas":0}

# Portada en el navegador o por curl
curl -s localhost:8000/

# Dar de alta una nota (POST) y comprobarla
curl -s -X POST -d "texto=Mi primera nota" -o /dev/null -w "%{http_code}\n" localhost:8000/notas
curl -s localhost:8000/salud
#  → {"estado":"ok","notas":1}
```

**Comprobar persistencia:**

```bash
docker compose restart          # reinicia → las notas siguen
docker compose down && docker compose up -d   # para y levanta → las notas siguen
```

**Comprobar que los datos se borran al eliminar el volumen:**

```bash
docker compose down -v          # ¡ojo! borra también el volumen con los datos
docker compose up -d
curl -s localhost:8000/salud    #  → {"estado":"ok","notas":0}
```

---

## 5. Dónde quedan los datos

Las notas se guardan en **Redis**, dentro del **volumen con nombre `notas_datos`**,
montado en `/data` del servicio `cache`. Redis está configurado con persistencia **AOF**
(`--appendonly yes`).

Ver el volumen:

```bash
docker volume ls | grep notas_datos
```

- Los datos **sobreviven** a `docker compose restart`, `down` y `up`.
- Los datos **desaparecen** solo con `docker compose down -v` (o `docker volume rm`).

---

## 6. Cómo ver los registros

```bash
docker compose logs            # todos los servicios
docker compose logs web        # solo la app
docker compose logs -f web     # en vivo (seguir hasta Ctrl+C)
```

La app escribe los accesos por gunicorn en stdout, así que aparecen en `logs web`.

---

## 7. Parar y limpiar

```bash
# Parar y borrar contenedores y red (conserva las imágenes y el volumen/datos)
docker compose down

# Parar y borrar todo, incluido el volumen con los datos
docker compose down -v

# Borrar también las imágenes construidas
docker image rm notas-web
```

---

## Estructura del proyecto

```
Dockerfile            # imagen de la app (python:3.12-slim, usuario no root, gunicorn)
docker-compose.yml    # servicios web + cache, volumen y variables
app.py                # código Flask
requirements.txt      # Flask, redis, gunicorn
templates/            # plantilla de la portada
recursos/             # material de la práctica (incluye sin-revisar/, la versión a auditar)
```
