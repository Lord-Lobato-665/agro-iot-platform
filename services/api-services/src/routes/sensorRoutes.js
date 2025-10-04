// src/routes/sensorRoutes.js
const express = require('express');
const router = express.Router();
const {
  crearSensor,
  obtenerSensores,
  obtenerSensorPorId,
  actualizarSensor,
  eliminarSensor,
  obtenerSensoresPorParcelaId
} = require('../controllers/sensorController');

router.get('/by-parcela/:parcelaId', obtenerSensoresPorParcelaId);

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