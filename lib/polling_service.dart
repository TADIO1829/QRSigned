import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import 'notificaciones.dart';
import '../utils/crypto_utils.dart';

class PollingService {
  static Timer? _timer;
  static DateTime? _lastCheck;

  
  static List<String> _pendingNotifications = [];

  static void startPolling({int interval = 10}) {
    _lastCheck = DateTime.now();

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) async {
      await _checkForUpdates();
    });

    print(" Polling iniciado (intervalo: ${interval}s)");
  }

  static void stopPolling() {
    _timer?.cancel();
    _timer = null;
    print(" Polling detenido");
  }

  static Future<void> _checkForUpdates() async {
    try {
      final db = await MongoDatabase.connect();
      final siniestrosCol = db.collection('siniestros');
      final clientesCol = db.collection('clientes');

      final query = mongo.where.gte('updatedAt', _lastCheck!.add(Duration(milliseconds: 1)));
      final results = await siniestrosCol.find(query).toList();

      print(" Verificando actualizaciones desde $_lastCheck → encontrados: ${results.length}");

      if (results.isNotEmpty) {
       
        _pendingNotifications.clear();

        for (final sin in results) {
          final tipo = sin['tipo'] ?? 'Siniestro';
          final clienteId = sin['cliente_id'];
          String nombre = "Cliente desconocido";
          String cedula = "";

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
              print("No se pudo obtener ObjectId válido para cliente_id: $clienteId");
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
                print("Error desencriptando cédula de $nombre: $e");
                cedula = "[dato inválido]";
              }
            }
          }

          final detalle = (cedula.isNotEmpty && cedula != "[dato inválido]")
              ? " $tipo de $nombre (C.I: $cedula) actualizado"
              : " $tipo de $nombre actualizado";

          
          _pendingNotifications.add(detalle);
        }

       
        if (_pendingNotifications.isNotEmpty) {
          if (_pendingNotifications.length == 1) {
            
            mostrarNotificacionEscaneo(_pendingNotifications[0]);
          } else {
            
            mostrarNotificacionEscaneo("${_pendingNotifications.length} siniestros actualizados");
          }
        }
      } else {
        print(" No hay actualizaciones nuevas.");
      }

      _lastCheck = DateTime.now();
    } catch (e) {
      print(" Error en polling: $e");
    }
  }
}