import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../db/mongo_connection.dart';
import '../utils/crypto_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:overlay_support/overlay_support.dart';

class NuevoClientePage extends StatefulWidget {
  final Map<String, dynamic>? trasladarPolizaDesde;
  const NuevoClientePage({super.key, this.trasladarPolizaDesde});

  @override
  State<NuevoClientePage> createState() => _NuevoClientePageState();
}

class _NuevoClientePageState extends State<NuevoClientePage> {
 
  static const Color fondo = Color(0xFF23272F);
  static const Color azulClaro = Color(0xFF4D82BC);


  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  String error = '';

  
  final nombreController = TextEditingController();
  final cedulaController = TextEditingController();
  final direccionController = TextEditingController();
  final telefonoController = TextEditingController();
  String?  polizaSeleccionada = null;
 
  bool cedulaDuplicada = false;
  bool telefonoDuplicado = false;
  Timer? _debounceCedula;
  Timer? _debounceTelefono;

  
  final respuestaSeguridadController = TextEditingController();
  String? preguntaSeguridadSeleccionada;

 
  File? imagenSeleccionada1;
  File? imagenSeleccionada2;
  String? nombreImagenGuardada1;
  String? nombreImagenGuardada2;

 
  int numCarros = 0;
  List<List<TextEditingController>> carrosControllers = []; 
  List<bool> matriculaDuplicada = [];
  List<bool> matriculaRepetidaLocal = [];
  final List<Timer?> _debounceMatriculas = [];

 
  int numMascotas = 0;
  List<List<TextEditingController>> mascotasControllers = []; 

 
  int numObjetos = 0;
  List<List<TextEditingController>> objetosControllers = []; 

  
  final List<TextEditingController> contactoNombre =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> contactoTelefono =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> contactoRelacion =
      List.generate(3, (_) => TextEditingController());


  void mostrarNotificacionEscaneo(String mensaje) {
    showSimpleNotification(
      Text(" $mensaje"),
      background: Colors.blue,
      duration: const Duration(seconds: 4),
      trailing: const Icon(Icons.qr_code_scanner, color: Colors.white),
    );
  }

  
  @override
  void initState() {
    super.initState();

    
    cedulaController.addListener(() {
      _debounceCedula?.cancel();
      _debounceCedula = Timer(const Duration(milliseconds: 450), () async {
        await _checkCedulaDuplicate(cedulaController.text.trim());
      });
    });

   
    telefonoController.addListener(() {
      _debounceTelefono?.cancel();
      _debounceTelefono = Timer(const Duration(milliseconds: 450), () async {
        await _checkTelefonoDuplicate(telefonoController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounceCedula?.cancel();
    _debounceTelefono?.cancel();
    for (final t in _debounceMatriculas) {
      t?.cancel();
    }

    nombreController.dispose();
    cedulaController.dispose();
    direccionController.dispose();
    telefonoController.dispose();
    respuestaSeguridadController.dispose();

    for (final row in carrosControllers) {
      for (final c in row) c.dispose();
    }
    for (final row in mascotasControllers) {
      for (final c in row) c.dispose();
    }
    for (final row in objetosControllers) {
      for (final c in row) c.dispose();
    }
    for (final c in contactoNombre) c.dispose();
    for (final c in contactoTelefono) c.dispose();
    for (final c in contactoRelacion) c.dispose();

    super.dispose();
  }


  void _actualizarCamposCarros(int cantidad) {
    
    for (final t in _debounceMatriculas) {
      t?.cancel();
    }
    _debounceMatriculas
      ..clear()
      ..addAll(List.generate(cantidad, (_) => null));

   
    for (final row in carrosControllers) {
      for (final c in row) c.dispose();
    }

    carrosControllers = List.generate(
      cantidad,
      (_) => List.generate(5, (_) => TextEditingController()),
    );
    matriculaDuplicada = List.filled(cantidad, false);
    matriculaRepetidaLocal = List.filled(cantidad, false);

    
    for (int i = 0; i < cantidad; i++) {
      carrosControllers[i][0].addListener(() {
        
        final txt = carrosControllers[i][0].text;
        final upper = txt.toUpperCase();
        if (upper != txt) {
          final sel = carrosControllers[i][0].selection;
          carrosControllers[i][0].value = TextEditingValue(
            text: upper,
            selection: sel,
          );
        }

        _debounceMatriculas[i]?.cancel();
        _debounceMatriculas[i] = Timer(const Duration(milliseconds: 450), () async {
          await _checkMatriculaDuplicate(carrosControllers[i][0].text.trim(), i);
        });
        _revisarMatriculaRepetidaLocal();
      });
    }
    setState(() {});
  }

  void _actualizarCamposMascotas(int cantidad) {
    for (final row in mascotasControllers) {
      for (final c in row) c.dispose();
    }
    mascotasControllers = List.generate(
      cantidad,
      (_) => List.generate(5, (_) => TextEditingController()),
    );
    setState(() {});
  }

  void _actualizarCamposObjetos(int cantidad) {
    for (final row in objetosControllers) {
      for (final c in row) c.dispose();
    }
    
    objetosControllers = List.generate(
      cantidad,
      (_) => List.generate(4, (_) => TextEditingController()),
    );
    setState(() {});
  }

 
  String? _validaNombre(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Campo obligatorio';
    if (s.length < 3) return 'Mínimo 3 caracteres';
    if (!RegExp(r"^[a-zA-ZÁÉÍÓÚÜÑáéíóúüñ ]+$").hasMatch(s)) return 'Solo letras y espacios';
    return null;
  }

  String? _validaCedula(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Campo obligatorio';
    if (!RegExp(r"^\d{10}$").hasMatch(s)) return 'Debe tener 10 dígitos';
    return null;
  }

  String? _validaDireccion(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Campo obligatorio';
    if (s.length < 5) return 'Mínimo 5 caracteres';
    return null;
  }

  String? _validaTelefono(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Campo obligatorio';
    if (!RegExp(r"^\d{7,10}$").hasMatch(s)) return '7 a 10 dígitos';
    return null;
  }

  String? _validaNoVacio(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _validaAnio(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Obligatorio';
    if (!RegExp(r"^\d{4}$").hasMatch(s)) return 'Año inválido';
    final anio = int.tryParse(s) ?? 0;
    if (anio < 1950 || anio > DateTime.now().year + 1) return 'Fuera de rango';
    return null;
  }

  
  Future<void> _checkCedulaDuplicate(String cedula) async {
    if (_validaCedula(cedula) != null) {
      setState(() => cedulaDuplicada = false);
      return;
    }
    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');
      final enc = CryptoUtils.encryptText(cedula);
      final exists = await col.findOne({"cedula": enc});
      setState(() => cedulaDuplicada = exists != null);
    } catch (_) {
      
    }
  }

  Future<void> _checkTelefonoDuplicate(String telefono) async {
    if (_validaTelefono(telefono) != null) {
      setState(() => telefonoDuplicado = false);
      return;
    }
    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');
      final enc = CryptoUtils.encryptText(telefono);
      final exists = await col.findOne({"telefono": enc});
      setState(() => telefonoDuplicado = exists != null);
    } catch (_) {}
  }

  Future<void> _checkMatriculaDuplicate(String matricula, int index) async {
    final s = matricula.toUpperCase();
    if (s.isEmpty) {
      setState(() => matriculaDuplicada[index] = false);
      return;
    }
    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');
      final enc = CryptoUtils.encryptText(s);
      final exists = await col.findOne({"matriculas.matricula": enc});
      setState(() => matriculaDuplicada[index] = exists != null);
    } catch (_) {}
  }

  void _revisarMatriculaRepetidaLocal() {
    final values = List.generate(
      carrosControllers.length,
      (i) => carrosControllers[i][0].text.trim().toUpperCase(),
    );
    for (int i = 0; i < values.length; i++) {
      bool rep = false;
      if (values[i].isNotEmpty) {
        for (int j = 0; j < values.length; j++) {
          if (i != j && values[i] == values[j]) {
            rep = true;
            break;
          }
        }
      }
      matriculaRepetidaLocal[i] = rep;
    }
    setState(() {});
  }

  bool get _hayDuplicados =>
      cedulaDuplicada ||
      telefonoDuplicado ||
      matriculaDuplicada.any((e) => e) ||
      matriculaRepetidaLocal.any((e) => e);

 
  Future<void> _guardarCliente() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => error = "Revisa los campos resaltados.");
      return;
    }
    if (polizaSeleccionada == null || polizaSeleccionada!.isEmpty) {
      setState(() => error = "Selecciona una póliza.");
      return;
    }
    if (polizaSeleccionada == null) { 
  setState(() => error = "Selecciona una póliza.");
  return;
}
    if (_hayDuplicados) {
      setState(() => error = "Corrige los duplicados antes de guardar.");
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    final cliente = {
      "nombre": nombreController.text.trim(),
      "cedula": CryptoUtils.encryptText(cedulaController.text.trim()),
      "direccion": CryptoUtils.encryptText(direccionController.text.trim()),
      "telefono": CryptoUtils.encryptText(telefonoController.text.trim()),
      "imagenCliente1": nombreImagenGuardada1 ?? "",
      "imagenCliente2": nombreImagenGuardada2 ?? "",
      "poliza": polizaSeleccionada,
      "preguntaSeguridad": {
        "pregunta": preguntaSeguridadSeleccionada,
        "respuestaEnc": CryptoUtils.encryptText(
          respuestaSeguridadController.text.trim(),
        ),
      },
      "matriculas": carrosControllers
          .map((f) => {
                "matricula":
                    CryptoUtils.encryptText(f[0].text.trim().toUpperCase()),
                "color": f[1].text.trim(),
                "marca": f[2].text.trim(),
                "modelo": f[3].text.trim(),
                "anio": f[4].text.trim(),
              })
          .toList(),
      "mascotas": mascotasControllers
          .map((f) => {
                "nombre": f[0].text.trim(),
                "tipo": f[1].text.trim(),
                "raza": f[2].text.trim(),
                "color": f[3].text.trim(),
                "descripcion": f[4].text.trim(),
              })
          .toList(),
      "objetos": objetosControllers
          .map((f) => {
                "nombre": f[0].text.trim(),
                "tipo": f[1].text.trim(),
                "color": f[2].text.trim(),
                "descripcion": f[3].text.trim(),
              })
          .toList(),
      "contactos": List.generate(3, (i) => {
            "nombre": contactoNombre[i].text.trim(),
            "telefono":
                CryptoUtils.encryptText(contactoTelefono[i].text.trim()),
            "relacion": contactoRelacion[i].text.trim(),
          }),
    };

    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');

      
      final existeCedula = await col.findOne({
        "cedula": CryptoUtils.encryptText(cedulaController.text.trim())
      });
      if (existeCedula != null) {
        setState(() {
          loading = false;
          error = "La cédula ya existe en el sistema.";
          cedulaDuplicada = true;
        });
        return;
      }
      final existeTelefono = await col.findOne({
        "telefono": CryptoUtils.encryptText(telefonoController.text.trim())
      });
      if (existeTelefono != null) {
        setState(() {
          loading = false;
          error = "El teléfono ya existe en el sistema.";
          telefonoDuplicado = true;
        });
        return;
      }
      for (final f in carrosControllers) {
        final mEnc =
            CryptoUtils.encryptText(f[0].text.trim().toUpperCase());
        final exM = await col.findOne({"matriculas.matricula": mEnc});
        if (exM != null) {
          setState(() {
            loading = false;
            error = "La matrícula ${f[0].text} ya está registrada.";
          });
          return;
        }
      }

      final insertResult = await col.insertOne(cliente);
      final insertedId = insertResult.id as mongo.ObjectId?;

      
      if (insertedId != null && widget.trasladarPolizaDesde != null) {
        final origen = widget.trasladarPolizaDesde!;
        await col.updateOne(
          mongo.where.eq("_id", insertedId),
          mongo.modify.set("poliza", origen['poliza']),
        );

        final accion = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("¿Acción sobre cliente origen?"),
            content: const Text(
                "¿Deseas eliminar el cliente anterior o asignarle una nueva póliza?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, "eliminar"),
                child: const Text("Eliminar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, "reasignar"),
                child: const Text("Reasignar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, "cancelar"),
                child: const Text("Cancelar"),
              ),
            ],
          ),
        );

        if (accion == "eliminar") {
          await col.deleteOne(mongo.where.eq("_id", origen['_id']));
        } else if (accion == "reasignar") {
          final nueva = await showDialog<String>(
            context: context,
            builder: (_) {
              String seleccion = "Básica";
              return AlertDialog(
                title: const Text("Selecciona nueva póliza"),
                content: StatefulBuilder(
                  builder: (context, setSt) => DropdownButtonFormField<String>(
                    value: seleccion,
                    items: ["Básica", "Premium", "Sin plan"]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => seleccion = val ?? "Básica",
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, seleccion),
                      child: const Text("Aceptar")),
                  TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text("Cancelar")),
                ],
              );
            },
          );

          if (nueva != null) {
            if (nueva == "Sin plan") {
              await col.updateOne(mongo.where.eq("_id", origen['_id']),
                  mongo.modify.unset("poliza"));
            } else {
              await col.updateOne(mongo.where.eq("_id", origen['_id']),
                  mongo.modify.set("poliza", nueva));
            }
          }
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Éxito"),
          content: const Text("Cliente guardado correctamente."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() => error = "Error al guardar el cliente: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  
  Future<void> _seleccionarImagen(int numero) async {
    final ced = cedulaController.text.trim();

    if (ced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa la cédula antes de seleccionar la imagen.")),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    final origenPath = result.files.single.path!;
    final origenFile = File(origenPath);

    final ext = p.extension(origenPath).isEmpty ? '.jpg' : p.extension(origenPath);
    final nombreArchivo = '${ced}_${numero}${ext}';

    final destDir = Directory(r'C:\imagenesclientes');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final rutaDestino = p.join(destDir.path, nombreArchivo);

    try {
      await origenFile.copy(rutaDestino);
      setState(() {
        if (numero == 1) {
          imagenSeleccionada1 = File(rutaDestino);
          nombreImagenGuardada1 = nombreArchivo;
        } else {
          imagenSeleccionada2 = File(rutaDestino);
          nombreImagenGuardada2 = nombreArchivo;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar imagen: $e")),
      );
    }
  }

  
  Widget _campoFijo({
    required TextEditingController controller,
    required String label,
    required double width,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        validator: validator ?? _validaNoVacio,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _textLine(TextEditingController c, String label,
      {String? Function(String?)? validator,
      TextInputType? keyboard,
      Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        validator: validator ?? _validaNoVacio,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _card(String titulo, List<Widget> contenido) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: azulClaro,
                )),
            const SizedBox(height: 10),
            ...contenido,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const preguntas = [
      "¿Nombre de tu primera mascota?",
      "¿Ciudad donde naciste?",
      "¿Comida favorita?",
      "¿Segundo nombre de tu madre?",
      "¿Colegio de primaria?"
    ];

    final botonGuardarDeshabilitado = loading || _hayDuplicados;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text("Nuevo Cliente"),
        backgroundColor: const Color(0xff005187),
      ),
      body: Center(
        child: Container
          (
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)],
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Registrar nuevo cliente",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: azulClaro,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _card("Datos personales", [
                    _textLine(
                      nombreController,
                      "Nombre Completo",
                      validator: _validaNombre,
                    ),
                    _textLine(
                      cedulaController,
                      "Numero de Cédula",
                      validator: _validaCedula,
                      keyboard: TextInputType.number,
                      suffix: cedulaController.text.isEmpty
                          ? null
                          : Icon(
                              cedulaDuplicada
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color:
                                  cedulaDuplicada ? Colors.red : Colors.green,
                            ),
                    ),
                    if (cedulaDuplicada)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "⚠️ Ya existe un cliente con esta cédula.",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    _textLine(
                      direccionController,
                      "Dirección",
                      validator: _validaDireccion,
                    ),
                    _textLine(
                      telefonoController,
                      "Teléfono",
                      validator: _validaTelefono,
                      keyboard: TextInputType.number,
                      suffix: telefonoController.text.isEmpty
                          ? null
                          : Icon(
                              telefonoDuplicado
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color:
                                  telefonoDuplicado ? Colors.red : Colors.green,
                            ),
                    ),
                    if (telefonoDuplicado)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "⚠️ Este teléfono ya está registrado.",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      value: polizaSeleccionada,
                      items: const [
                        DropdownMenuItem(value: null, child: Text("Selecciona una póliza")),
                        DropdownMenuItem(value: "Básica", child: Text("Básica")),
                        DropdownMenuItem(value: "Premium", child: Text("Premium")),
                      ],
                      decoration: const InputDecoration(labelText: "Póliza"),
                      validator: (v) => v == null ? "Selecciona una póliza" : null,
                      onChanged: (v) => setState(() => polizaSeleccionada = v),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  
                  _card("Seguridad de cuenta", [
                    DropdownButtonFormField<String>(
                      value: preguntaSeguridadSeleccionada,
                      items: preguntas
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      decoration:
                          const InputDecoration(labelText: "Pregunta de seguridad"),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "Selecciona una pregunta" : null,
                      onChanged: (v) =>
                          setState(() => preguntaSeguridadSeleccionada = v),
                    ),
                    _textLine(
                      respuestaSeguridadController,
                      "Respuesta",
                      validator: _validaNoVacio,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  
                  _card("Vehículos del cliente", [
                    Row(
                      children: [
                        const Text("Cantidad de carros:"),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: numCarros,
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(value: i, child: Text("$i")),
                          ),
                          onChanged: (v) {
                            setState(() {
                              numCarros = v ?? 0;
                              _actualizarCamposCarros(numCarros);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(numCarros, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: carrosControllers[i][0],
                                decoration: InputDecoration(
                                  labelText: "Matrícula",
                                  suffixIcon:
                                      carrosControllers[i][0].text.trim().isEmpty
                                          ? null
                                          : Icon(
                                              (matriculaDuplicada[i] ||
                                                      matriculaRepetidaLocal[i])
                                                  ? Icons.error_outline
                                                  : Icons
                                                      .check_circle_outline,
                                              color: (matriculaDuplicada[i] ||
                                                      matriculaRepetidaLocal[i])
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                ),
                                validator: _validaNoVacio,
                              ),
                            ),
                            _campoFijo(
                                controller: carrosControllers[i][1],
                                label: "Color",
                                width: 80),
                            _campoFijo(
                                controller: carrosControllers[i][2],
                                label: "Marca",
                                width: 100),
                            _campoFijo(
                                controller: carrosControllers[i][3],
                                label: "Modelo",
                                width: 100),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: carrosControllers[i][4],
                                decoration:
                                    const InputDecoration(labelText: "Año"),
                                keyboardType: TextInputType.number,
                                validator: _validaAnio,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (matriculaDuplicada.any((e) => e) ||
                        matriculaRepetidaLocal.any((e) => e))
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "⚠️ Revisa las matrículas duplicadas o repetidas.",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                  ]),

                  const SizedBox(height: 20),

  
                  _card("Mascotas", [
                    Row(
                      children: [
                        const Text("Cantidad de mascotas:"),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: numMascotas,
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(value: i, child: Text("$i")),
                          ),
                          onChanged: (v) {
                            setState(() {
                              numMascotas = v ?? 0;
                              _actualizarCamposMascotas(numMascotas);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(numMascotas, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _campoFijo(
                                controller: mascotasControllers[i][0],
                                label: "Nombre",
                                width: 120),
                            _campoFijo(
                                controller: mascotasControllers[i][1],
                                label: "Tipo",
                                width: 100),
                            _campoFijo(
                                controller: mascotasControllers[i][2],
                                label: "Raza",
                                width: 120),
                            _campoFijo(
                                controller: mascotasControllers[i][3],
                                label: "Color",
                                width: 100),
                            _campoFijo(
                                controller: mascotasControllers[i][4],
                                label: "Descripción",
                                width: 160),
                          ],
                        ),
                      );
                    }),
                  ]),

                  const SizedBox(height: 20),

                
                  _card("Objetos personales", [
                    Row(
                      children: [
                        const Text("Cantidad de objetos:"),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: numObjetos,
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(value: i, child: Text("$i")),
                          ),
                          onChanged: (v) {
                            setState(() {
                              numObjetos = v ?? 0;
                              _actualizarCamposObjetos(numObjetos);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(numObjetos, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _campoFijo(
                                controller: objetosControllers[i][0],
                                label: "Nombre",
                                width: 120),
                            _campoFijo(
                                controller: objetosControllers[i][1],
                                label: "Tipo",
                                width: 100),
                            _campoFijo(
                                controller: objetosControllers[i][2],
                                label: "Color",
                                width: 100),
                            _campoFijo(
                                controller: objetosControllers[i][3],
                                label: "Descripción",
                                width: 180),
                          ],
                        ),
                      );
                    }),
                  ]),

                  const SizedBox(height: 20),

              
                  _card("Contactos alternativos", [
                    ...List.generate(3, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _textLine(
                                  contactoNombre[i],
                                  "Nombre",
                                  validator: _validaNombre,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _textLine(
                                  contactoTelefono[i],
                                  "Teléfono",
                                  validator: _validaTelefono,
                                  keyboard: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _textLine(
                                  contactoRelacion[i],
                                  "Relación",
                                  validator: _validaNoVacio,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ]),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _seleccionarImagen(1),
                        icon: const Icon(Icons.image),
                        label: const Text("Imagen 1"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _seleccionarImagen(2),
                        icon: const Icon(Icons.image),
                        label: const Text("Imagen 2"),
                      ),
                    ],
                  ),
                  if (imagenSeleccionada1 != null) ...[
                    const SizedBox(height: 10),
                    Image.file(
                      imagenSeleccionada1!,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ],
                  if (imagenSeleccionada2 != null) ...[
                    const SizedBox(height: 10),
                    Image.file(
                      imagenSeleccionada2!,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ],

                  const SizedBox(height: 22),

                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 6),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            botonGuardarDeshabilitado ? Colors.grey : azulClaro,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 55, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed:
                          botonGuardarDeshabilitado ? null : _guardarCliente,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Guardar Cliente",
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
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
