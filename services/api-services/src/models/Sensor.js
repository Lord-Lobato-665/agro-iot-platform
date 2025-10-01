// src/models/Sensor.js
const mongoose = require('mongoose');

const sensorSchema = new mongoose.Schema({
  // Usamos un _id personalizado que será el identificador único del dispositivo físico.
  _id: {
    type: String,
    required: true
  },
  nombre: {
    type: String,
    required: [true, 'El nombre del sensor es obligatorio']
  },
  cultivo: {
    type: String,
  },
  tipo: {
    type: String,
    required: true,
    enum: ['radiacion_solar', 'lluvia', 'humedad', 'temperatura'] 
  },
  // ¡AQUÍ ESTÁ LA MAGIA! El puente a tu base de datos relacional.
  // Almacenará el GUID/UUID de la tabla Parcelas en SQL Server.
  id_parcela_sql: {
    type: String,
    required: true
  },
  fecha_instalacion: {
    type: Date,
    default: Date.now
  }
}, {
  // Opciones del esquema:
  // versionKey: false -> No necesitamos el campo __v.
  // timestamps: true -> Aquí sí es útil saber cuándo se creó o actualizó un sensor.
  versionKey: false,
  timestamps: true 
});

// Mongoose creará una colección llamada 'sensores'
const Sensor = mongoose.model('Sensor', sensorSchema);

module.exports = Sensor;