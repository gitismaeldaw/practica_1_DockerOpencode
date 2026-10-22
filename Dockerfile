# --- Etapa única: la práctica pide una sola imagen, sin multietapa ---
# Imagen base exigida: python:3.12-slim (ligera, sin herramientas de build innecesarias)
FROM python:3.12-slim

# No escribir .pyc ni bufferizar stdout: los logs de gunicorn llegan al instante
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copiar SOLO el requirements.txt primero: si no cambia, Docker reutiliza la
# capa de `pip install` y la reconstrucción dura segundos, no minutos.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# El código va después: cualquier cambio en app.py o templates/ solo invalida
# estas capas ligeras, nunca la de dependencias.
COPY app.py .
COPY templates/ ./templates/

# Usuario sin privilegios: el contenedor NO corre como root.
# useradd crea el usuario "notas" sin shell de login; chown deja /app legible.
RUN useradd --create-home --system --shell /usr/sbin/nologin notas \
    && chown -R notas:notas /app
USER notas

# Puerto que escucha la aplicación (gunicorn, bind 0.0.0.0:8000)
EXPOSE 8000

# Comprobación de salud contra /salud.
# No uso curl: python:3.12-slim no lo trae y tendría que instalarlo (más peso).
# Usa el python de la propia imagen contra http://localhost:8000/salud.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/salud', timeout=4).status == 200 else 1)"]

# Arranque con gunicorn (servidor de producción), NO con app.run() de Flask.
# Formato JSON (exec form): la señal SIGTERM llega directamente a gunicorn,
# sin shell intermedio que la atrape. Equivalente a: gunicorn -b 0.0.0.0:8000 app:app
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "app:app"]
