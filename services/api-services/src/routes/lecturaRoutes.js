// src/routes/lecturaRoutes.js
const express = require('express');
const router = express.Router();
const { registrarLectura } = require('../controllers/lecturaController');

// POST a /api/lecturas/
router.post('/', registrarLectura);

module.exports = router;