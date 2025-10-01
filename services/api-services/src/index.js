const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cors = require('cors'); // <-- 1. Importar cors

// Importar nuestras nuevas rutas
const sensorRoutes = require('./routes/sensorRoutes');
const lecturaRoutes = require('./routes/lecturaRoutes');

// Cargar variables de entorno
dotenv.config({ path: './.env' });

// Conectar a la base de datos
connectDB();

const app = express();

// --- Middlewares ---

// Habilitar CORS para todas las rutas y orígenes
app.use(cors()); // <-- 2. Usar cors como middleware

// Permitir que Express entienda JSON
app.use(express.json());

// --- Rutas de la API ---
app.use('/api/sensores', sensorRoutes);
app.use('/api/lecturas', lecturaRoutes);

// Ruta de health check
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'API funcionando correctamente' });
});

const PORT = process.env.PORT || 3001;

app.listen(PORT, console.log(`Servidor corriendo en el puerto ${PORT}`));
