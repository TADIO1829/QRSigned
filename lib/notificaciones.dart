import 'package:audioplayers/audioplayers.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';

final AudioPlayer _player = AudioPlayer()..setVolume(1.0);

void mostrarNotificacionEscaneo(String mensaje) async {
  try {
    
    await _player.stop();
    await _player.play(AssetSource('notificacion.mp3'));
  } catch (e) {
    print(" Error al reproducir sonido: $e");
  }

  showOverlayNotification(
    (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.blue[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Nueva Actualización",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mensaje,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () {
                      OverlaySupportEntry.of(context)?.dismiss();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    duration: const Duration(seconds: 4),
    key: const ValueKey('siniestro_notification'),
  );
}
