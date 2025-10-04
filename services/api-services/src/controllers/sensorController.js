// src/controllers/sensorController.js
const Sensor = require('../models/Sensor');

// --- CREATE ---
/**
 * @desc    Crear un nuevo sensor
 * @route   POST /api/sensores
 */
const crearSensor = async (req, res) => {
  try {
    const { _id, nombre, cultivo, tipo, id_parcela_sql } = req.body;
    const sensorExistente = await Sensor.findById(_id);
    if (sensorExistente) {
      return res.status(400).json({ message: 'Un sensor con este ID ya existe' });
    }
    const nuevoSensor = new Sensor({ _id, nombre, cultivo, tipo, id_parcela_sql });
    const sensorGuardado = await nuevoSensor.save();
    res.status(201).json(sensorGuardado);
  } catch (error) {
    res.status(400).json({ message: 'Error de validación', error: error.message });
  }
};

// --- READ (ALL) ---
/**
 * @desc    Obtener todos los sensores
 * @route   GET /api/sensores
 */
const obtenerSensores = async (req, res) => {
  try {
    const sensores = await Sensor.find({});
    res.status(200).json(sensores);
  } catch (error) {
    res.status(500).json({ message: 'Error del servidor', error: error.message });
  }
};

// --- READ (ONE) ---
/**
 * @desc    Obtener un sensor por su ID
 * @route   GET /api/sensores/:id
 */
const obtenerSensorPorId = async (req, res) => {
  try {
    const sensor = await Sensor.findById(req.params.id);
    if (!sensor) {
      return res.status(404).json({ message: 'Sensor no encontrado' });
    }
    res.status(200).json(sensor);
  } catch (error) {
    res.status(500).json({ message: 'Error del servidor', error: error.message });
  }
};

// --- UPDATE ---
/**
 * @desc    Actualizar un sensor por su ID
 * @route   PUT /api/sensores/:id
 */
const actualizarSensor = async (req, res) => {
  try {
    const sensor = await Sensor.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true } // Opciones: devuelve el doc nuevo y corre validadores
    );
    if (!sensor) {
      return res.status(404).json({ message: 'Sensor no encontrado' });
    }
    res.status(200).json(sensor);
  } catch (error) {
    res.status(400).json({ message: 'Error de validación', error: error.message });
  }
};

// --- DELETE ---
/**
 * @desc    Eliminar un sensor por su ID
 * @route   DELETE /api/sensores/:id
 */
const eliminarSensor = async (req, res) => {
  try {
    const sensor = await Sensor.findByIdAndDelete(req.params.id);
    if (!sensor) {
      return res.status(404).json({ message: 'Sensor no encontrado' });
    }
    res.status(200).json({ message: 'Sensor eliminado exitosamente' });
  } catch (error) {
    res.status(500).json({ message: 'Error del servidor', error: error.message });
  }
};

// --- READ (BY PARCELA ID) ---
/**
 * @desc    Obtener todos los sensores de una parcela específica
 * @route   GET /api/sensores/by-parcela/:parcelaId
 */
const obtenerSensoresPorParcelaId = async (req, res) => {
  try {
    // 1. Extraemos el id de la parcela de los parámetros de la URL
    const { parcelaId } = req.params;

    // 2. Buscamos en la base de datos todos los sensores donde 
    //    el campo 'id_parcela_sql' coincida.
    const sensores = await Sensor.find({ id_parcela_sql: parcelaId });

    // 3. Devolvemos los sensores encontrados (puede ser un array vacío si no hay ninguno)
    res.status(200).json(sensores);
  } catch (error) {
    res.status(500).json({ message: 'Error del servidor', error: error.message });
  }
};

module.exports = {
  crearSensor,
  obtenerSensores,
  obtenerSensorPorId,
  actualizarSensor,
  eliminarSensor,
  obtenerSensoresPorParcelaId
};