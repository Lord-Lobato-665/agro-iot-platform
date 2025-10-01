// src/models/LecturaSensor.js
const mongoose = require('mongoose');

const lecturaSensorSchema = new mongoose.Schema({
  sensorId: {
    type: String,
    index: true
  },
  tipo: {
    type: String,
    required: true,
    index: true,
    enum: ['radiacion_solar', 'lluvia', 'humedad', 'temperatura']
  },
  value: {
    type: Number,
    required: true
  },
  unit: {
    type: String,
    required: true,
    // ✅ Asignamos un valor por defecto si falta
    default: 'N/A' 
  },
  timestamp: {
    type: Date,
    required: true,
    index: true
  },
  coords: {
    lat: { type: Number, default: 0.0 },
    lon: { type: Number, default: 0.0 }
  }
}, {
  timestamps: false,
  versionKey: false
});

// ✅ Creamos un índice compuesto único.
// Esto prohíbe que existan dos documentos con el MISMO tipo y el MISMO timestamp.
// Es nuestra garantía contra duplicados a nivel de base de datos.
lecturaSensorSchema.index({ tipo: 1, timestamp: 1 }, { unique: true });

const LecturaSensor = mongoose.model('LecturaSensor', lecturaSensorSchema);

module.exports = LecturaSensor;