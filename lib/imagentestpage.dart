import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ImagenClienteTestPage extends StatefulWidget {
  const ImagenClienteTestPage({super.key});

  @override
  State<ImagenClienteTestPage> createState() => _ImagenClienteTestPageState();
}

class _ImagenClienteTestPageState extends State<ImagenClienteTestPage> {
  String? nombreImagenGuardada;
  String? cedulaPrueba = "1234567890"; // Puedes modificar esto para la prueba

  Future<void> seleccionarYGuardarImagen() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      String origenPath = result.files.single.path!;
      String extension = origenPath.split('.').last;
      String nombreArchivo = '$cedulaPrueba.$extension';

      // Cambia NOMBREPC por el nombre real de tu servidor.
      String rutaDestino = r'\\DARKSOUL\imagenes_clientes\' + nombreArchivo;

      try {
        await File(origenPath).copy(rutaDestino);
        setState(() {
          nombreImagenGuardada = nombreArchivo;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imagen guardada con éxito")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cambia NOMBREPC por el nombre real de tu servidor.
    String rutaCompartida = nombreImagenGuardada != null
        ? r'\\DARKSOUL\imagenes_clientes\' + nombreImagenGuardada!
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text("Prueba Imagen Cliente")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Seleccionar y guardar imagen"),
              onPressed: seleccionarYGuardarImagen,
            ),
            const SizedBox(height: 20),
            if (nombreImagenGuardada != null)
              Column(
                children: [
                  Text('Nombre imagen: $nombreImagenGuardada'),
                  const SizedBox(height: 12),
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(border: Border.all(color: Colors.blue)),
                    child: Image.file(
                      File(rutaCompartida),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Text('No se puede cargar')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
