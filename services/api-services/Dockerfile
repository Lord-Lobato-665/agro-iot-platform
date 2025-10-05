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
CMD ["node", "ingestion-runner.js"]