import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import '../utils/crypto_utils.dart';
import '../cliente_global.dart';

class NuevoSiniestroPage extends StatefulWidget {
  const NuevoSiniestroPage({super.key});

  @override
  State<NuevoSiniestroPage> createState() => _NuevoSiniestroPageState();
}

class _NuevoSiniestroPageState extends State<NuevoSiniestroPage> {
  final _formKey = GlobalKey<FormState>();
  final fechaController = TextEditingController();
  final horaController = TextEditingController();
  final lugarController = TextEditingController();
  final descripcionController = TextEditingController();

  bool loading = false;

  List<Map<String, dynamic>> clientes = [];
  Map<String, dynamic>? clienteSeleccionado;
  mongo.ObjectId? clienteIdSeleccionado;

  List<Map<String, dynamic>> objetos = [];
  Map<String, dynamic>? objetoSeleccionado;

  @override
  void initState() {
    super.initState();
    fechaController.text = DateTime.now().toIso8601String().split("T")[0];
    _cargarClientes();
  }

  @override
  void dispose() {
    fechaController.dispose();
    horaController.dispose();
    lugarController.dispose();
    descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    final db = await MongoDatabase.connect();
    final col = db.collection("clientes");
    final resultados = await col.find().toList();

    setState(() {
      clientes = resultados.cast<Map<String, dynamic>>();
      // Si hay un cliente global seleccionado, úsalo; si no, el primero
      clienteSeleccionado =
          ClienteGlobal.seleccionado ?? (clientes.isNotEmpty ? clientes.first : null);
      clienteIdSeleccionado = clienteSeleccionado?['_id'];
    });

    await _cargarObjetos();
  }

  Future<void> _cargarObjetos() async {
    if (clienteSeleccionado == null) return;
    final db = await MongoDatabase.connect();
    final col = db.collection("objetos");
    final res = await col.find(mongo.where.eq("clienteId", clienteSeleccionado!["_id"])).toList();
    setState(() {
      objetos = res.cast<Map<String, dynamic>>();
      objetoSeleccionado = objetos.isNotEmpty ? objetos.first : null;
    });
  }

  Future<void> _selectFecha() async {
    DateTime initial = DateTime.tryParse(fechaController.text) ?? DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'EC'),
    );
    if (picked != null) {
      setState(() {
        fechaController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _selectHora() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        horaController.text = picked.format(context);
      });
    }
  }

  Future<void> _guardarSiniestro() async {
    if (!_formKey.currentState!.validate()) return;
    if (clienteSeleccionado == null || objetoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona cliente y objeto.")),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final tipoObjeto = (objetoSeleccionado!["tipo"] ?? "").toString().toLowerCase();

      // Formato de siniestro compatible con VerSiniestrosPage
      final siniestro = {
        "cliente_id": clienteSeleccionado!["_id"],
        "objeto_id": objetoSeleccionado!["_id"],
        // usa el tipo del objeto (mascota/carros/objeto/otro)
        "tipo": tipoObjeto.isNotEmpty ? tipoObjeto : "otro",
        "descripcion": descripcionController.text.trim(),
        "lugar": lugarController.text.trim(),
        "fecha": fechaController.text.trim(),
        "hora": horaController.text.trim(),
        // estado inicial del siniestro (abierto) — en tu vista puedes mostrar 'abierto'/'cerrado'
        "estado": "abierto",
        // seguimiento vacío pero insertamos un seguimiento inicial
        "seguimiento": [
          {
            "fecha": DateTime.now().toIso8601String(),
            "detalle": "Caso abierto manualmente",
          }
        ],
        "escaneos": [],
        "createdAt": DateTime.now().toIso8601String(),
        "updatedAt": DateTime.now().toIso8601String(),
      };

      final db = await MongoDatabase.connect();
      final col = db.collection("siniestros");
      await col.insertOne(siniestro);

      // Actualiza el status en users (QR) a un estado acorde al tipo
      final users = db.collection("users");
      final nuevoStatusForUsers = (tipoObjeto == "mascota") ? "sin_novedad" : "en_uso";
      // Para coherencia con comportamiento previo, ponemos status "en_uso" o "sin_novedad"
      // pero también marcamos el objeto como 'en_siniestro' en collection objetos:
      await users.updateMany(
        mongo.where.eq("objetoId", objetoSeleccionado!["_id"]),
        mongo.modify.set("status", nuevoStatusForUsers),
      );

      // Actualiza el estado operativo del objeto a 'en_siniestro'
      final objetosCol = db.collection("objetos");
      await objetosCol.updateOne(
        mongo.where.id(objetoSeleccionado!["_id"]),
        mongo.modify.set("estado", "en_siniestro"),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Siniestro guardado correctamente.")),
      );

      // Limpia formulario
      _formKey.currentState!.reset();
      descripcionController.clear();
      lugarController.clear();
      horaController.clear();
      fechaController.text = DateTime.now().toIso8601String().split("T")[0];

      // recarga objetos por si quieres mantener el dropdown actualizado
      await _cargarObjetos();

      setState(() {
        // dejar el primer objeto seleccionado si existe
        objetoSeleccionado = objetos.isNotEmpty ? objetos.first : null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar siniestro: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _fichaObjeto() {
    if (objetoSeleccionado == null) {
      return const Text("Selecciona un objeto para ver detalles.");
    }

    final tipo = (objetoSeleccionado!["tipo"] ?? "").toString();
    final descripcion = (objetoSeleccionado!["descripcion"] ?? "").toString();
    final marca = (objetoSeleccionado!["marca"] ?? "").toString();
    final modelo = (objetoSeleccionado!["modelo"] ?? "").toString();
    final anio = (objetoSeleccionado!["anio"] ?? "").toString();
    final color = (objetoSeleccionado!["color"] ?? "").toString();
    final otroDetalle = (objetoSeleccionado!["otroDetalle"] ?? "").toString();

    List<Widget> detalles = [
      Text("Tipo: $tipo"),
      if (descripcion.isNotEmpty) Text("Descripción: $descripcion"),
    ];
    if (tipo == "carro") {
      if (marca.isNotEmpty) detalles.add(Text("Marca: $marca"));
      if (modelo.isNotEmpty) detalles.add(Text("Modelo: $modelo"));
      if (anio.isNotEmpty) detalles.add(Text("Año: $anio"));
      if (color.isNotEmpty) detalles.add(Text("Color: $color"));
    } else if (tipo == "objeto") {
      if (marca.isNotEmpty) detalles.add(Text("Marca: $marca"));
      if (modelo.isNotEmpty) detalles.add(Text("Modelo: $modelo"));
    } else if (tipo == "otro") {
      if (otroDetalle.isNotEmpty) detalles.add(Text("Detalle: $otroDetalle"));
    } else if (tipo == "mascota") {
      detalles.add(const Text("Estado inicial: Sin Novedad"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        ...detalles,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text("Nuevo Siniestro"),
        backgroundColor: azulClaro,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: const Offset(6, 10)),
            ],
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Registrar nuevo siniestro",
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: azulClaro,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // --- Cliente ---
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Cliente *",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: azulClaro)),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<mongo.ObjectId>(
                                  value: clienteIdSeleccionado,
                                  items: clientes.map((cliente) {
                                    final ced = (cliente["cedula"] ?? '').toString();
                                    final nombre = (cliente["nombre"] ?? '').toString();
                                    return DropdownMenuItem<mongo.ObjectId>(
                                      value: cliente["_id"] as mongo.ObjectId,
                                      child: Text("$nombre (${CryptoUtils.decryptText(ced)})"),
                                    );
                                  }).toList(),
                                  onChanged: ClienteGlobal.seleccionado != null
                                      ? null
                                      : (mongo.ObjectId? nuevoId) {
                                          setState(() {
                                            clienteIdSeleccionado = nuevoId;
                                            clienteSeleccionado = clientes.firstWhere((c) => c["_id"] == nuevoId);
                                          });
                                          _cargarObjetos();
                                        },
                                  validator: (v) => v == null ? "Selecciona un cliente" : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 13),

                        // --- Objeto vinculado ---
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Objeto/Mascota *",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: azulClaro)),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<Map<String, dynamic>>(
                                  value: objetoSeleccionado,
                                  items: objetos.map((obj) {
                                    return DropdownMenuItem<Map<String, dynamic>>(
                                      value: obj,
                                      child: Text("${obj["descripcion"]} (${obj["tipo"]})"),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => objetoSeleccionado = val),
                                  validator: (v) => v == null ? "Selecciona un objeto" : null,
                                ),
                                _fichaObjeto(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 13),

                        // --- Detalles ---
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Detalles del siniestro",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: azulClaro)),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: fechaController,
                                  readOnly: true,
                                  onTap: _selectFecha,
                                  decoration: const InputDecoration(labelText: "Fecha *", suffixIcon: Icon(Icons.calendar_today)),
                                  validator: (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: horaController,
                                  readOnly: true,
                                  onTap: _selectHora,
                                  decoration: const InputDecoration(labelText: "Hora *", suffixIcon: Icon(Icons.access_time)),
                                  validator: (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: lugarController,
                                  decoration: const InputDecoration(labelText: "Lugar *"),
                                  validator: (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: descripcionController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(labelText: "Descripción *"),
                                  validator: (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _guardarSiniestro,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: azulClaro,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text("Guardar Siniestro", style: TextStyle(fontSize: 18, color: Colors.white)),
                              ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
