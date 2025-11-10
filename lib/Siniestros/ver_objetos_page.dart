import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import '../utils/crypto_utils.dart';
import '../cliente_global.dart';

class VerObjetosPage extends StatefulWidget {
  const VerObjetosPage({super.key});

  @override
  State<VerObjetosPage> createState() => _VerObjetosPageState();
}

class _VerObjetosPageState extends State<VerObjetosPage> {
  bool loading = true;
  List<Map<String, dynamic>> objetos = [];
  List<Map<String, dynamic>> clientes = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cargarDatos(auto: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // 🔄 NUEVA FUNCIÓN: Leer estado desde users usando objetoId
  Future<String> _obtenerEstadoDesdeUsers(String objetoIdHex) async {
    if (objetoIdHex.isEmpty) return 'en_uso';
    
    try {
      final db = await MongoDatabase.connect();
      final colUsers = db.collection('users');
      
      final userDoc = await colUsers.findOne(
        mongo.where.eq('objetoId', mongo.ObjectId.parse(objetoIdHex)),
      );
      
      return userDoc?['status']?.toString() ?? 'en_uso';
    } catch (e) {
      print("❌ Error leyendo estado desde users: $e");
      return 'en_uso';
    }
  }

  Future<void> _cargarDatos({bool auto = false}) async {
    if (!auto) {
      setState(() => loading = true);
    }

    final db = await MongoDatabase.connect();
    final colObjetos = db.collection("objetos");
    final colClientes = db.collection("clientes");

    final listaClientes = await colClientes.find().toList();

    var query = mongo.where;
    if (ClienteGlobal.clienteSeleccionado != null) {
      final clienteSel = ClienteGlobal.clienteSeleccionado!;
      query = query.eq('clienteId', clienteSel['_id']);
    }

    final listaObjetos =
        await colObjetos.find(query.sortBy('_id', descending: true)).toList();

    // 🔄 ACTUALIZACIÓN: Obtener estado desde users para cada objeto
    for (var obj in listaObjetos) {
      final objetoId = obj["_id"];
      if (objetoId != null) {
        final objetoIdHex = _objetoIdHex(objetoId);
        final estadoDesdeUsers = await _obtenerEstadoDesdeUsers(objetoIdHex);
        obj["estado"] = estadoDesdeUsers; // 👈 Sobrescribir con estado de users
      }
    }

    if (mounted) {
      setState(() {
        clientes = listaClientes;
        objetos = listaObjetos;
        loading = false;
      });
    }
  }

  // 🔄 FUNCIÓN AUXILIAR: Convertir ObjectId a hex string
  String _objetoIdHex(dynamic objId) {
    if (objId is mongo.ObjectId) return objId.oid;
    return objId?.toString() ?? '';
  }

  String _nombreCliente(mongo.ObjectId id) {
    final c = clientes.firstWhere(
      (x) => x["_id"] == id,
      orElse: () => {},
    );
    if (c.isEmpty) return "Cliente no encontrado";
    final nombre = (c["nombre"] ?? "").toString();
    final cedula = (c["cedula"] != null)
        ? CryptoUtils.decryptText(c["cedula"])
        : "N/A";
    return "$nombre ($cedula)";
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case "en_siniestro":
        return Colors.orange.shade700;
      case "disponible":
        return Colors.green.shade700;
      case "inactivo":
        return Colors.grey.shade700;
      case "pendiente":
        return Colors.amber.shade700;
      case "robado":
      case "perdido":
      case "en_reparacion":
        return Colors.red.shade700;
      case "en_uso":
        return Colors.blue.shade700;
      case "en_venta":
        return Colors.purple.shade700;
      case "prestado":
        return Colors.cyan.shade700;
      case "encontrado":
        return Colors.green.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _detalleObjeto(Map<String, dynamic> obj) {
    final tipo = (obj["tipo"] ?? "").toString();
    final descripcion = (obj["descripcion"] ?? "").toString();
    final estado = (obj["estado"] ?? "").toString();
    final marca = (obj["marca"] ?? "").toString();
    final modelo = (obj["modelo"] ?? "").toString();
    final color = (obj["color"] ?? "").toString();
    final anio = (obj["anio"] ?? "").toString();
    final otro = (obj["otroDetalle"] ?? "").toString();

    List<Widget> info = [
      Text("Descripción: $descripcion"),
      Text("Tipo: $tipo"),
      Text("Estado QR: $estado", // 👈 Cambié el texto para claridad
          style: TextStyle(
              color: _colorEstado(estado), fontWeight: FontWeight.bold)),
    ];

    if (tipo == "carro") {
      if (marca.isNotEmpty) info.add(Text("Marca: $marca"));
      if (modelo.isNotEmpty) info.add(Text("Modelo: $modelo"));
      if (anio.isNotEmpty) info.add(Text("Año: $anio"));
      if (color.isNotEmpty) info.add(Text("Color: $color"));
    } else if (tipo == "objeto") {
      if (marca.isNotEmpty) info.add(Text("Marca: $marca"));
      if (modelo.isNotEmpty) info.add(Text("Modelo: $modelo"));
    } else if (tipo == "mascota") {
      if (color.isNotEmpty) info.add(Text("Color: $color"));
      if (otro.isNotEmpty) info.add(Text("Nombre: $otro"));
    } else if (otro.isNotEmpty) {
      info.add(Text("Detalle: $otro"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: info,
    );
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azul = Color(0xFF4D82BC);

    final clienteActivo = ClienteGlobal.clienteSeleccionado;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: Text(clienteActivo == null
            ? "Objetos Registrados"
            : "Objetos de ${clienteActivo['nombre']}"),
        backgroundColor: azul,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: "Recargar",
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : objetos.isEmpty
              ? const Center(
                  child: Text(
                    "No hay objetos registrados.",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: objetos.length,
                    itemBuilder: (context, i) {
                      final obj = objetos[i];
                      final clienteId = obj["clienteId"];
                      final cliente = clienteId is mongo.ObjectId
                          ? _nombreCliente(clienteId)
                          : "Cliente desconocido";

                      return Card(
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cliente,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: azul,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _detalleObjeto(obj),
                              
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}