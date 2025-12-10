import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import '../utils/crypto_utils.dart';

class EditarClientePage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const EditarClientePage({super.key, required this.cliente});

  @override
  State<EditarClientePage> createState() => _EditarClientePageState();
}

class _EditarClientePageState extends State<EditarClientePage> {
  final _formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final cedulaController = TextEditingController();
  final direccionController = TextEditingController();
  final telefonoController = TextEditingController();
  String? polizaSeleccionada;

  bool loading = false;
  String error = "";

  List<List<TextEditingController>> carrosControllers = [];
  List<Map<String, TextEditingController>> mascotasControllers = [];
  List<Map<String, TextEditingController>> objetosControllers = [];

  List<TextEditingController> contactoNombre = List.generate(3, (_) => TextEditingController());
  List<TextEditingController> contactoTelefono = List.generate(3, (_) => TextEditingController());
  List<TextEditingController> contactoRelacion = List.generate(3, (_) => TextEditingController());

  String safeDecrypt(String? text) {
    if (text == null || text.isEmpty) return '';
    try {
      return CryptoUtils.decryptText(text);
    } catch (_) {
      return text;
    }
  }

  String safeEncrypt(String text) {
    if (text.isEmpty) return '';
    return CryptoUtils.encryptText(text);
  }

  @override
  void initState() {
    super.initState();
    final cli = widget.cliente;

    nombreController.text = cli['nombre'] ?? '';
    cedulaController.text = safeDecrypt(cli['cedula']);
    direccionController.text = safeDecrypt(cli['direccion']);
    telefonoController.text = safeDecrypt(cli['telefono']);
    
    final polizaOriginal = cli['poliza']?.toString() ?? '';
    if (polizaOriginal == '1' || polizaOriginal.toLowerCase().contains('basica')) {
      polizaSeleccionada = "Básica";
    } else if (polizaOriginal == '3' || polizaOriginal == '5' || polizaOriginal.toLowerCase().contains('premium')) {
      polizaSeleccionada = "Premium";
    } else if (polizaOriginal == "Básica" || polizaOriginal == "Premium") {
      polizaSeleccionada = polizaOriginal;
    }

    final mats = (cli['matriculas'] as List?) ?? [];
    carrosControllers = mats.map((m) {
      return [
        TextEditingController(text: safeDecrypt(m['matricula'] ?? '')),
        TextEditingController(text: m['color'] ?? ''),
        TextEditingController(text: m['marca'] ?? ''),
        TextEditingController(text: m['modelo'] ?? ''),
        TextEditingController(text: m['anio'] ?? ''),
      ];
    }).toList();

    final mascotas = (cli['mascotas'] as List?) ?? [];
    mascotasControllers = mascotas.map((m) {
      return {
        "nombre": TextEditingController(text: m['nombre'] ?? ''),
        "tipo": TextEditingController(text: m['tipo'] ?? ''),
        "raza": TextEditingController(text: m['raza'] ?? ''),
        "color": TextEditingController(text: m['color'] ?? ''),
        "descripcion": TextEditingController(text: m['descripcion'] ?? ''),
      };
    }).toList();

    final objetos = (cli['objetos'] as List?) ?? [];
    objetosControllers = objetos.map((o) {
      return {
        "nombre": TextEditingController(text: o['nombre'] ?? ''),
        "tipo": TextEditingController(text: o['tipo'] ?? ''),
        "color": TextEditingController(text: o['color'] ?? ''),
        "descripcion": TextEditingController(text: o['descripcion'] ?? ''),
      };
    }).toList();

    final contactos = (cli['contactos'] as List?) ?? [];
    for (int i = 0; i < 3; i++) {
      if (i < contactos.length) {
        contactoNombre[i].text = contactos[i]['nombre'] ?? '';
        contactoTelefono[i].text = safeDecrypt(contactos[i]['telefono']);
        contactoRelacion[i].text = contactos[i]['relacion'] ?? '';
      }
    }
  }

  void anadirVehiculo() {
    setState(() {
      carrosControllers.add([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    });
  }

  void eliminarVehiculo(int i) => setState(() => carrosControllers.removeAt(i));

  void anadirMascota() {
    setState(() {
      mascotasControllers.add({
        "nombre": TextEditingController(),
        "tipo": TextEditingController(),
        "raza": TextEditingController(),
        "color": TextEditingController(),
        "descripcion": TextEditingController(),
      });
    });
  }

  void eliminarMascota(int i) => setState(() => mascotasControllers.removeAt(i));

  void anadirObjeto() {
    setState(() {
      objetosControllers.add({
        "nombre": TextEditingController(),
        "tipo": TextEditingController(),
        "color": TextEditingController(),
        "descripcion": TextEditingController(),
      });
    });
  }

  void eliminarObjeto(int i) => setState(() => objetosControllers.removeAt(i));

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    if (polizaSeleccionada == null) {
      setState(() => error = "Selecciona una póliza");
      return;
    }

    setState(() => loading = true);

    final clienteActualizado = {
      "nombre": nombreController.text.trim(),
      "cedula": safeEncrypt(cedulaController.text.trim()),
      "direccion": safeEncrypt(direccionController.text.trim()),
      "telefono": safeEncrypt(telefonoController.text.trim()),
      "poliza": polizaSeleccionada,
      "matriculas": carrosControllers.map((f) => {
        "matricula": safeEncrypt(f[0].text.trim()),
        "color": f[1].text.trim(),
        "marca": f[2].text.trim(),
        "modelo": f[3].text.trim(),
        "anio": f[4].text.trim(),
      }).toList(),
      "mascotas": mascotasControllers.map((m) => {
        "nombre": m["nombre"]!.text.trim(),
        "tipo": m["tipo"]!.text.trim(),
        "raza": m["raza"]!.text.trim(),
        "color": m["color"]!.text.trim(),
        "descripcion": m["descripcion"]!.text.trim(),
      }).toList(),
      "objetos": objetosControllers.map((o) => {
        "nombre": o["nombre"]!.text.trim(),
        "tipo": o["tipo"]!.text.trim(),
        "color": o["color"]!.text.trim(),
        "descripcion": o["descripcion"]!.text.trim(),
      }).toList(),
      "contactos": List.generate(3, (i) => {
        "nombre": contactoNombre[i].text.trim(),
        "telefono": safeEncrypt(contactoTelefono[i].text.trim()),
        "relacion": contactoRelacion[i].text.trim(),
      }),
    };

    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');
      await col.updateOne(
        mongo.where.id(widget.cliente['_id']),
        mongo.modify
            .set('nombre', clienteActualizado['nombre'])
            .set('cedula', clienteActualizado['cedula'])
            .set('direccion', clienteActualizado['direccion'])
            .set('telefono', clienteActualizado['telefono'])
            .set('poliza', clienteActualizado['poliza'])
            .set('matriculas', clienteActualizado['matriculas'])
            .set('mascotas', clienteActualizado['mascotas'])
            .set('objetos', clienteActualizado['objetos'])
            .set('contactos', clienteActualizado['contactos']),
      );

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => error = "Error al actualizar cliente: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _eliminarClienteCompletamente() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(" ELIMINACIÓN COMPLETA"),
        content: const Text(
          "¿Estás SEGURO de eliminar este cliente y TODOS sus datos?\n\n"
          "Esto borrará:\n"
          "• Cliente principal\n"
          "• Todos sus objetos registrados\n"
          "• Todos sus siniestros\n"
          "• Todos sus usuarios/QRs\n\n"
          "¡Esta acción NO se puede deshacer!",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancelar")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ELIMINAR TODO", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      setState(() => loading = true);
      final db = await MongoDatabase.connect();
      final clienteId = widget.cliente['_id'];
      
      final mongo.ObjectId clienteObjectId;
      if (clienteId is mongo.ObjectId) {
        clienteObjectId = clienteId;
      } else if (clienteId is String) {
        clienteObjectId = mongo.ObjectId.parse(clienteId);
      } else {
        throw Exception("ID de cliente no válido");
      }

      final colUsers = db.collection('users');
      await colUsers.deleteMany(
        mongo.where.eq('clienteId', clienteObjectId)
      );

      final colObjetos = db.collection('objetos');
      await colObjetos.deleteMany(
        mongo.where.eq('clienteId', clienteObjectId)
      );

      final colSiniestros = db.collection('siniestros');
      await colSiniestros.deleteMany(
        mongo.where.eq('cliente_id', clienteObjectId)
      );

      final colClientes = db.collection('clientes');
      await colClientes.deleteOne(mongo.where.id(clienteObjectId));

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("  Eliminación Completa"),
            content: const Text("Cliente y todos sus datos han sido eliminados exitosamente."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context, true);
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      print(" Error en eliminación completa: $e");
      setState(() => error = "Error al eliminar cliente: $e");
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al eliminar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _input(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
    );
  }

  Widget _card(String titulo, Color color, List<Widget> contenido) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            const SizedBox(height: 10),
            ...contenido,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(title: const Text("Editar Cliente"), backgroundColor: const Color(0xff005187)),
      body: Stack(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 18)],
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "Editar datos del cliente",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: azulClaro),
                      ),
                      const SizedBox(height: 20),

                      _card("Datos personales 👤", azulClaro, [
                        _input(nombreController, "Nombre"),
                        _input(cedulaController, "Cédula"),
                        _input(direccionController, "Dirección"),
                        _input(telefonoController, "Teléfono"),
                        DropdownButtonFormField<String>(
                          value: polizaSeleccionada,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("Selecciona una póliza")),
                            DropdownMenuItem(value: "Básica", child: Text("Básica")),
                            DropdownMenuItem(value: "Premium", child: Text("Premium")),
                          ],
                          decoration: const InputDecoration(labelText: "Póliza"),
                          validator: (value) => value == null ? "Selecciona una póliza" : null,
                          onChanged: (v) => setState(() => polizaSeleccionada = v),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      _card("Vehículos 🚗", azulClaro, [
                        ...List.generate(carrosControllers.length, (i) {
                          final c = carrosControllers[i];
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _input(c[0], "Matrícula")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(c[1], "Color")),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => eliminarVehiculo(i),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(child: _input(c[2], "Marca")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(c[3], "Modelo")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(c[4], "Año")),
                                ],
                              ),
                              const Divider(height: 20),
                            ],
                          );
                        }),
                        ElevatedButton.icon(
                          onPressed: anadirVehiculo,
                          icon: const Icon(Icons.add),
                          label: const Text("Agregar Vehículo"),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      _card("Mascotas 🐾", azulClaro, [
                        ...List.generate(mascotasControllers.length, (i) {
                          final m = mascotasControllers[i];
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _input(m["nombre"]!, "Nombre")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(m["tipo"]!, "Tipo")),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => eliminarMascota(i),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(child: _input(m["raza"]!, "Raza")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(m["color"]!, "Color")),
                                ],
                              ),
                              _input(m["descripcion"]!, "Descripción"),
                              const Divider(height: 20),
                            ],
                          );
                        }),
                        ElevatedButton.icon(
                          onPressed: anadirMascota,
                          icon: const Icon(Icons.add),
                          label: const Text("Agregar Mascota"),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      _card("Objetos personales 📦", azulClaro, [
                        ...List.generate(objetosControllers.length, (i) {
                          final o = objetosControllers[i];
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _input(o["nombre"]!, "Nombre")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(o["tipo"]!, "Tipo")),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => eliminarObjeto(i),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(child: _input(o["color"]!, "Color")),
                                  const SizedBox(width: 6),
                                  Expanded(child: _input(o["descripcion"]!, "Descripción")),
                                ],
                              ),
                              const Divider(height: 20),
                            ],
                          );
                        }),
                        ElevatedButton.icon(
                          onPressed: anadirObjeto,
                          icon: const Icon(Icons.add),
                          label: const Text("Agregar Objeto"),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      _card("Contactos alternativos ☎️", azulClaro, [
                        ...List.generate(3, (i) {
                          return Row(
                            children: [
                              Expanded(child: _input(contactoNombre[i], "Nombre")),
                              const SizedBox(width: 6),
                              Expanded(child: _input(contactoTelefono[i], "Teléfono")),
                              const SizedBox(width: 6),
                              Expanded(child: _input(contactoRelacion[i], "Relación")),
                            ],
                          );
                        }),
                      ]),

                      const SizedBox(height: 20),
                      if (error.isNotEmpty)
                        Text(error, style: const TextStyle(color: Colors.red)),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulClaro,
                          padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _guardarCambios,
                        child: const Text("Actualizar Cliente", style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _eliminarClienteCompletamente, 
                        child: const Text("ELIMINAR CLIENTE Y TODOS SUS DATOS", style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}