# Imagen base ligera
FROM node:20-alpine


# Directorio de trabajo
WORKDIR /app


# Instala deps primero (mejor caché)
COPY package*.json ./
RUN npm ci --omit=dev


# Copia el resto del código
COPY . .


# Por defecto ejecuta el runner de ingesta
## Start both the API server and the ingestion runner.
# Use a shell command so both processes run. The server (src/index.js) will listen on PORT and the ingestion runner will run in background.
CMD ["/bin/sh", "-c", "node src/index.js & node ingestion-runner.js"]