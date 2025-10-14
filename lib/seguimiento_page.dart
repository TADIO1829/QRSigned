import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_connection.dart';
import 'cliente_global.dart';
import 'package:overlay_support/overlay_support.dart';

void mostrarNotificacionEscaneo(String mensaje) {
  showSimpleNotification(
    Text("🔔 $mensaje"),
    background: Colors.blue,
    duration: Duration(seconds: 4),
    trailing: Icon(Icons.qr_code_scanner, color: Colors.white),
  );
}

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});

  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  List<Map<String, dynamic>> siniestros = [];
  Map<String, dynamic>? siniestroSeleccionado;
  final seguimientoController = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarSiniestros();
  }

  Future<void> cargarSiniestros() async {
    setState(() => loading = true);
    final db = await MongoDatabase.connect();
    final col = db.collection('siniestros');

    List<Map<String, dynamic>> res;
    // Si hay cliente activo, filtra por cliente_id
    if (ClienteGlobal.seleccionado != null) {
      final clienteId = ClienteGlobal.seleccionado!['_id'];
      res = await col.find({'cliente_id': clienteId}).toList();
    } else {
      res = await col.find().toList();
    }

    setState(() {
      siniestros = res;
      loading = false;
    });
  }

  Future<void> guardarSeguimiento() async {
    if (siniestroSeleccionado == null || seguimientoController.text.trim().isEmpty) return;

    final db = await MongoDatabase.connect();
    final col = db.collection('siniestros');
    await col.updateOne(
      mongo.where.id(siniestroSeleccionado!["_id"]),
      mongo.modify.push("seguimiento", {
        "fecha": DateTime.now().toIso8601String(),
        "detalle": seguimientoController.text.trim(),
      }),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Éxito"),
        content: const Text("Seguimiento guardado."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
    setState(() {
      seguimientoController.clear();
      siniestroSeleccionado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text("Seguimiento de Siniestro"),
        backgroundColor: azulClaro,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 470),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 18)],
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Registrar seguimiento",
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: azulClaro,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Selecciona el siniestro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: azulClaro)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: siniestroSeleccionado,
                                items: siniestros.map((sin) {
                                  String desc = sin["descripcion"].toString();
                                  String displayDesc = desc.length > 20 ? desc.substring(0, 20) + "..." : desc;
                                  return DropdownMenuItem(
                                    value: sin,
                                    child: Text("${sin["tipo"]} - ${sin["fecha"]} ($displayDesc)"),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => siniestroSeleccionado = val),
                                decoration: const InputDecoration(labelText: "Siniestro"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Detalle del seguimiento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: azulClaro)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: seguimientoController,
                                decoration: const InputDecoration(
                                  labelText: "Escribe el detalle del seguimiento",
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: guardarSeguimiento,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulClaro,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Guardar seguimiento", style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
