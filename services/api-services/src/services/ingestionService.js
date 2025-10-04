// src/services/ingestionService.js
const axios = require('axios');
const { parser } = require('stream-json');
const { streamObject } = require('stream-json/streamers/StreamObject'); // <-- HERRAMIENTA CORREGIDA
const { chain } = require('stream-chain');

const LecturaSensor = require('../models/LecturaSensor');

const API_URL = 'https://sensores-async-api.onrender.com/api/sensors/all';
const BATCH_SIZE = 500;

// La función para procesar lotes no cambia
const procesarLote = async (lote) => {
  if (lote.length === 0) return 0;
  try {
    const resultado = await LecturaSensor.bulkWrite(lote);
    console.log(`Lote procesado. Actualizados: ${resultado.modifiedCount}, Creados: ${resultado.upsertedCount}`);
    return resultado.modifiedCount + resultado.upsertedCount;
  } catch (error) {
    console.error('Error procesando un lote en bulkWrite:', error.message);
    return 0;
  }
};

const ingestarDatosExternos = async () => {
  console.log('Iniciando ingesta optimizada (stream y batch)...');
  let lecturasProcesadas = 0;
  let loteDeOperaciones = [];

  try {
    const respuesta = await axios({
      method: 'get',
      url: API_URL,
      responseType: 'stream'
    });

    // --- PIPELINE CORREGIDO ---
    const pipeline = chain([
      respuesta.data,
      parser(),
      streamObject() // <-- Usamos streamObject para procesar el objeto raíz { "temp": [...], "hum": [...] }
    ]);

    // El evento 'data' ahora nos dará un objeto con 'key' y 'value'
    // ej: { key: 'temperature', value: [ { ... }, { ... } ] }
    pipeline.on('data', async (data) => {
      const tipoSensor = data.key;
      const lecturasDelTipo = data.value; // Este es el array de lecturas para este sensor

      // Iteramos sobre las lecturas del sensor actual
      for (const lectura of lecturasDelTipo) {
        if (!lectura || !lectura.timestamp) {
          console.log(`Omitiendo lectura inválida para ${tipoSensor}:`, lectura);
          continue;
        }

        const operacion = {
          updateOne: {
            filter: { tipo: tipoSensor },
            update: {
              $set: {
                value: lectura.value,
                unit: lectura.unit,
                timestamp: new Date(lectura.timestamp),
                coords: lectura.coords
              }
            },
            upsert: true
          }
        };
        loteDeOperaciones.push(operacion);

        // Si el lote está lleno, lo procesamos.
        // Hacemos la comprobación dentro del bucle para ser más reactivos.
        if (loteDeOperaciones.length >= BATCH_SIZE) {
          pipeline.pause();
          const procesadasEnLote = await procesarLote(loteDeOperaciones);
          lecturasProcesadas += procesadasEnLote;
          loteDeOperaciones = [];
          pipeline.resume();
        }
      }
    });

    return new Promise((resolve, reject) => {
      pipeline.on('end', async () => {
        // Procesamos el último lote restante
        if (loteDeOperaciones.length > 0) {
          const procesadasEnLote = await procesarLote(loteDeOperaciones);
          lecturasProcesadas += procesadasEnLote;
        }
        console.log(`✅ Ingesta finalizada. Total de lecturas procesadas/actualizadas: ${lecturasProcesadas}`);
        resolve();
      });
      pipeline.on('error', (err) => {
        console.error('Error fatal en el pipeline de stream:', err.message);
        reject(err);
      });
    });

  } catch (error) {
    console.error('Error al iniciar la petición de stream:', error.message);
  }
};

module.exports = {
  ingestarDatosExternos
};