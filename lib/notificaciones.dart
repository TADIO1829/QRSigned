import 'package:audioplayers/audioplayers.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';

final _player = AudioPlayer();

void mostrarNotificacionEscaneo(String mensaje) async {
  
  await _player.play(AssetSource('notificacion.mp3'));

  
  showSimpleNotification(
    Text("🔔 $mensaje"),
    background: Colors.blue,
    duration: const Duration(seconds: 4),
    trailing: const Icon(Icons.qr_code_scanner, color: Colors.white),
  );
}
