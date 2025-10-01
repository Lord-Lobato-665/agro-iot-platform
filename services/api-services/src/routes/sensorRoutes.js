// src/routes/sensorRoutes.js
const express = require('express');
const router = express.Router();
const {
  crearSensor,
  obtenerSensores,
  obtenerSensorPorId,
  actualizarSensor,
  eliminarSensor
} = require('../controllers/sensorController');

// Rutas para /api/sensores
router.route('/')
  .post(crearSensor)
  .get(obtenerSensores);

// Rutas para /api/sensores/:id
router.route('/:id')
  .get(obtenerSensorPorId)
  .put(actualizarSensor)
  .delete(eliminarSensor);

module.exports = router;