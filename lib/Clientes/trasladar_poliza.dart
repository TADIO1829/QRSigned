import 'package:flutter/material.dart';
import '../cliente_global.dart';
import '../utils/crypto_utils.dart';
import '../db/mongo_connection.dart';
import 'nuevo_cliente_page.dart';
import 'ver_clientes_page.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class TrasladarPolizaPage extends StatefulWidget {
  const TrasladarPolizaPage({super.key});

  @override
  State<TrasladarPolizaPage> createState() => _TrasladarPolizaPageState();
}

class _TrasladarPolizaPageState extends State<TrasladarPolizaPage> {
  late Map<String, dynamic> clienteOrigen;

  @override
  void initState() {
    super.initState();
    final seleccionado = ClienteGlobal.seleccionado;
    if (seleccionado == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Primero selecciona un cliente activo.")),
        );
        Navigator.pop(context);
      });
    } else {
      clienteOrigen = seleccionado;
    }
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: azul,
      appBar: AppBar(
        title: const Text("Trasladar Póliza"),
        backgroundColor: azulClaro,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 3,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 470),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, color: azulClaro, size: 45),
              const SizedBox(height: 12),
              Text(
                "Cliente Origen:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: azulClaro,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                clienteOrigen['nombre'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                "Cédula: ${CryptoUtils.decryptText(clienteOrigen['cedula'] ?? '')}",
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const Text(
                "¿Deseas trasladar la póliza a un nuevo cliente o uno existente?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulClaro,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NuevoClientePage(trasladarPolizaDesde: clienteOrigen),
                        ),
                      );
                    },
                    label: const Text("Nuevo Cliente"),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.people_alt_rounded, size: 22),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulClaro,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final destino = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const VerClientesPage(seleccionarParaEditar: true),
                        ),
                      );
                      if (destino != null) _confirmarTraslado(destino);
                    },
                    label: const Text("Cliente Existente"),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text("Cancelar y volver"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarTraslado(Map<String, dynamic> destino) async {
    const azulClaro = Color(0xFF4D82BC);

    final confirm = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¿Qué hacer con el cliente origen?"),
        content: const Text(
          "Selecciona una acción para el cliente origen tras el traslado de la póliza:",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text("Eliminar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text("Asignar nueva póliza"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 2),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );

    if (confirm == 2 || confirm == null) return;

    try {
      final db = await MongoDatabase.connect();
      final col = db.collection("clientes");
      final poliza = clienteOrigen['poliza'];

      if (poliza == null || poliza.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(" El cliente origen no tiene póliza.")),
        );
        return;
      }

      
      await col.updateOne(
        mongo.where.id(destino['_id']),
        mongo.modify.set("poliza", poliza),
      );

      
      if (confirm == 0) {
        await col.deleteOne(mongo.where.id(clienteOrigen['_id']));
      } else if (confirm == 1) {
        final nueva = await showDialog<String>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text("Seleccionar nueva póliza"),
            children: [
              SimpleDialogOption(
                child: const Text("Básica"),
                onPressed: () => Navigator.pop(context, "Básica"),
              ),
              SimpleDialogOption(
                child: const Text("Premium"),
                onPressed: () => Navigator.pop(context, "Premium"),
              ),
              SimpleDialogOption(
                child: const Text("Sin plan"),
                onPressed: () => Navigator.pop(context, "Sin plan"),
              ),
            ],
          ),
        );

        if (nueva == null) return;

        if (nueva == "Sin plan") {
          await col.updateOne(
            mongo.where.id(clienteOrigen['_id']),
            mongo.modify.unset("poliza"),
          );
        } else {
          await col.updateOne(
            mongo.where.id(clienteOrigen['_id']),
            mongo.modify.set("poliza", nueva),
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Póliza trasladada exitosamente.")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al trasladar la póliza: $e")),
      );
    }
  }
}
