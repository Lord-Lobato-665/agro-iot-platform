// src/services/ingestionService.js
const axios = require('axios');
const LecturaSensor = require('../models/LecturaSensor');

const API_URL = 'https://sensores-async-api.onrender.com/api/sensors/all';

const ingestarDatosExternos = async () => {
  console.log('Iniciando ciclo de ingesta de datos externos (procesamiento individual)...');
  let lecturasProcesadas = 0;

  try {
    const respuesta = await axios.get(API_URL);
    const datosPorTipo = respuesta.data;

    for (const tipoSensor in datosPorTipo) {
      const lecturasDelTipo = datosPorTipo[tipoSensor];

      for (const lectura of lecturasDelTipo) {
        if (!lectura.timestamp) {
          console.log('Omitiendo lectura sin timestamp:', lectura);
          continue;
        }

        try {
          // --- INICIO DE LA CORRECCIÓN ---
          await LecturaSensor.findOneAndUpdate(
            // 1. El filtro: ¡BUSCAR SOLO POR EL TIPO DE SENSOR!
            // Esto asegura que SIEMPRE encuentre el documento existente.
            { 
              tipo: tipoSensor 
            },
            // 2. Los datos a establecer/actualizar:
            // Aquí se incluye el timestamp para que se actualice junto con el valor.
            { 
              $set: {
                value: lectura.value,
                unit: lectura.unit,
                timestamp: new Date(lectura.timestamp), // El timestamp se actualiza aquí
                coords: lectura.coords
              }
            },
            // 3. Opciones de la operación
            {
              upsert: true, // Si es el primer sensor de ese tipo, lo crea.
              runValidators: true 
            }
          );
          // --- FIN DE LA CORRECCIÓN ---
          
          lecturasProcesadas++;

        } catch (error) {
          console.error(`Error procesando una lectura individual [${tipoSensor} - ${lectura.timestamp}]:`, error.message);
        }
      }
    }

    if (lecturasProcesadas > 0) {
      console.log(`Ingesta completada. Total de lecturas procesadas (upsert): ${lecturasProcesadas}`);
    } else {
      console.log('No se encontraron lecturas válidas para ingestar.');
    }

  } catch (error) {
    console.error('Error durante la petición a la API externa:', error.message);
  }
};

module.exports = {
  ingestarDatosExternos
};