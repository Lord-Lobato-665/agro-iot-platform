// src/controllers/lecturaController.js
const LecturaSensor = require('../models/LecturaSensor');
const Sensor = require('../models/Sensor'); // Necesitamos verificar que el sensor existe

/**
 * @desc    Registrar una nueva lectura de sensor
 * @route   POST /api/lecturas
 * @access  Public
 */
const registrarLectura = async (req, res) => {
  try {
    // El body debería tener: sensorId, tipo, value, unit, timestamp, coords
    const { sensorId, tipo, value, unit, timestamp, coords } = req.body;

    // --- Validación Opcional pero Recomendada ---
    // Verificar que el sensor que envía el dato está registrado en nuestro catálogo
    const sensorExistente = await Sensor.findById(sensorId);
    if (!sensorExistente) {
      return res.status(404).json({ message: 'El sensor ID no está registrado en el sistema.' });
    }
    // --- Fin de la Validación ---

    const nuevaLectura = new LecturaSensor({
      sensorId,
      tipo,
      value,
      unit,
      timestamp,
      coords
    });

    await nuevaLectura.save();
    res.status(201).json({ message: 'Lectura registrada con éxito' });

  } catch (error) {
     if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(val => val.message);
      return res.status(400).json({ message: messages.join(', ') });
    }
    res.status(500).json({ message: 'Error del servidor', error: error.message });
  }
};

module.exports = {
  registrarLectura
};