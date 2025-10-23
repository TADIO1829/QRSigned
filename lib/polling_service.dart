// polling_service.dart
import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_connection.dart';
import 'notificaciones.dart';
import './utils/crypto_utils.dart'; 

class PollingService {
  static Timer? _timer;
  static DateTime? _lastCheck;

  static void startPolling({int interval = 10}) {
    _lastCheck = DateTime.now().subtract(Duration(hours: 1));

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) async {
      await _checkForUpdates();
    });

    print("🟢 Polling iniciado (intervalo: ${interval}s)");
  }

  static void stopPolling() {
    _timer?.cancel();
    _timer = null;
    print("🔴 Polling detenido");
  }

  
  static Future<void> _checkForUpdates() async {
    try {
      final db = await MongoDatabase.connect();
      final siniestrosCol = db.collection('siniestros');
      final clientesCol = db.collection('clientes');

      // Buscar siniestros actualizados después del último check
      final query = mongo.where.gte('updatedAt', _lastCheck);
      final results = await siniestrosCol.find(query).toList();

      print("🕓 Verificando actualizaciones desde $_lastCheck → encontrados: ${results.length}");

      if (results.isNotEmpty) {
        for (final sin in results) {
          final tipo = sin['tipo'] ?? 'Siniestro';
          final clienteId = sin['cliente_id'];

          String nombre = "Cliente desconocido";
          String cedula = "";

          if (clienteId != null) {
            mongo.ObjectId? objectId;

            // ✅ Detectar correctamente el formato del ID
            if (clienteId is mongo.ObjectId) {
              objectId = clienteId;
            } else if (clienteId is String) {
              try {
                objectId = mongo.ObjectId.parse(clienteId);
              } catch (_) {}
            } else if (clienteId.toString().contains('ObjectId(')) {
              // ✅ Regex corregido y verificado
              final match = RegExp('ObjectId\\(["\']?([a-fA-F0-9]{24})["\']?\\)')
                  .firstMatch(clienteId.toString());
              if (match != null) {
                objectId = mongo.ObjectId.parse(match.group(1)!);
              }
            }

            // Si el ObjectId no es válido, saltamos este registro
            if (objectId == null) {
              print("⚠️ No se pudo obtener ObjectId válido para cliente_id: $clienteId");
              continue;
            }

            // ✅ Buscar cliente asociado
            final cliente = await clientesCol.findOne(mongo.where.id(objectId));

            if (cliente != null) {
              nombre = cliente['nombre'] ?? 'Sin nombre';

              // Desencriptar la cédula (si aplica)
              try {
                final rawCedula = cliente['cedula'];
                if (rawCedula != null && rawCedula.toString().isNotEmpty) {
                  cedula = CryptoUtils.decryptText(rawCedula);
                } else {
                  cedula = "[no disponible]";
                }
              } catch (e) {
                print("⚠️ Error desencriptando cédula de $nombre: $e");
                cedula = "[dato inválido]";
              }
            }
          }

          // ✅ Generar mensaje de notificación
          final detalle = (cedula.isNotEmpty && cedula != "[dato inválido]")
              ? "📢 $tipo de $nombre (C.I: $cedula) actualizado"
              : "📢 $tipo de $nombre actualizado";

          print("🔔 Mostrando notificación: $detalle");
          mostrarNotificacionEscaneo(detalle);
        }
      } else {
        print("⏳ No hay actualizaciones nuevas.");
      }

      // Actualiza el timestamp del último chequeo
      _lastCheck = DateTime.now();
    } catch (e) {
      print("❌ Error en polling: $e");
    }
  }
}
