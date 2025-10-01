// ingestion-runner.js
const dotenv = require('dotenv');
const connectDB = require('./src/config/db');
const { ingestarDatosExternos } = require('./src/services/ingestionService');

// Cargar variables de entorno
dotenv.config({ path: './.env' });

// Conectar a la base de datos
connectDB();

// --- Lógica del Runner ---
const INTERVALO_DE_INGESTA_MS = 6000; // 60,000 ms = 1 minuto

console.log('Servicio de ingesta asíncrona iniciado.');
console.log(`Se buscarán nuevos datos cada ${INTERVALO_DE_INGESTA_MS / 60000} minuto.`);

// Ejecuta la función una vez al iniciar
ingestarDatosExternos();

// Y luego, la ejecuta repetidamente en el intervalo definido
setInterval(ingestarDatosExternos, INTERVALO_DE_INGESTA_MS);