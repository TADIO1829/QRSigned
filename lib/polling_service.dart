// polling_service.dart
import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import 'notificaciones.dart';
import '../utils/crypto_utils.dart';

class PollingService {
  static Timer? _timer;
  static DateTime? _lastCheck;

  /// Inicia el polling cada [interval] segundos
  static void startPolling({int interval = 10}) {
    // ✅ Ahora comienza desde el momento actual, no hace 1 hora
    _lastCheck = DateTime.now();

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) async {
      await _checkForUpdates();
    });

    print("🟢 Polling iniciado (intervalo: ${interval}s)");
  }

  /// Detiene el polling
  static void stopPolling() {
    _timer?.cancel();
    _timer = null;
    print("🔴 Polling detenido");
  }

  /// Verifica actualizaciones en la colección 'siniestros'
  static Future<void> _checkForUpdates() async {
    try {
      final db = await MongoDatabase.connect();
      final siniestrosCol = db.collection('siniestros');
      final clientesCol = db.collection('clientes');

      // ✅ Busca siniestros actualizados después del último check
      final query = mongo.where.gte('updatedAt', _lastCheck!.add(Duration(milliseconds: 1)));
      final results = await siniestrosCol.find(query).toList();

      print("🕓 Verificando actualizaciones desde $_lastCheck → encontrados: ${results.length}");

      if (results.isNotEmpty) {
        for (final sin in results) {
          final tipo = sin['tipo'] ?? 'Siniestro';
          final clienteId = sin['cliente_id'];
          String nombre = "Cliente desconocido";
          String cedula = "";

          // 🧩 Convertir y buscar el cliente
          if (clienteId != null) {
            mongo.ObjectId? objectId;

            if (clienteId is mongo.ObjectId) {
              objectId = clienteId;
            } else if (clienteId is String) {
              try {
                objectId = mongo.ObjectId.parse(clienteId);
              } catch (_) {}
            } else if (clienteId.toString().contains('ObjectId(')) {
              final match = RegExp('ObjectId\\(["\']?([a-fA-F0-9]{24})["\']?\\)')
                  .firstMatch(clienteId.toString());
              if (match != null) {
                objectId = mongo.ObjectId.parse(match.group(1)!);
              }
            }

            if (objectId == null) {
              print("⚠️ No se pudo obtener ObjectId válido para cliente_id: $clienteId");
              continue;
            }

            final cliente = await clientesCol.findOne(mongo.where.id(objectId));

            if (cliente != null) {
              nombre = cliente['nombre'] ?? 'Sin nombre';
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

          // 🔔 Notificar cambio
          final detalle = (cedula.isNotEmpty && cedula != "[dato inválido]")
              ? "📢 $tipo de $nombre (C.I: $cedula) actualizado"
              : "📢 $tipo de $nombre actualizado";

          print("🔔 Mostrando notificación: $detalle");
          mostrarNotificacionEscaneo(detalle);
        }
      } else {
        print("⏳ No hay actualizaciones nuevas.");
      }

      // ✅ Actualizar la marca de tiempo después de procesar
      _lastCheck = DateTime.now();
    } catch (e) {
      print("❌ Error en polling: $e");
    }
  }
}
