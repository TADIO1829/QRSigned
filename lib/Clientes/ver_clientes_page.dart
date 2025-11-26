import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../db/mongo_connection.dart';
import '../utils/crypto_utils.dart';
import '../cliente_global.dart';
import '../mainmenu.dart';
import '../mainmenu_user.dart';
import '../usuario_global.dart';
import 'editar_cliente_page.dart';
import '../polling_service.dart';
import 'package:overlay_support/overlay_support.dart';

void mostrarNotificacionEscaneo(String mensaje) {
  showSimpleNotification(
    Text("🔔 $mensaje"),
    background: Colors.blue,
    duration: const Duration(seconds: 4),
    trailing: const Icon(Icons.qr_code_scanner, color: Colors.white),
  );
}

class VerClientesPage extends StatefulWidget {
  final bool seleccionarParaEditar;
  const VerClientesPage({super.key, this.seleccionarParaEditar = false});

  @override
  State<VerClientesPage> createState() => _VerClientesPageState();
}

class _VerClientesPageState extends State<VerClientesPage> {
  final buscarController = TextEditingController();
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> filtrados = [];
  bool loading = true;
  int? seleccionado;

  static const String _kBaseLocal = r'C:\imagenesclientes';
  static const String _kBaseLegacy = r'\\DARKSOUL\imagenes_clientes';

  String safeDecrypt(String? text) {
    if (text == null || text.isEmpty) return '';
    try {
      return CryptoUtils.decryptText(text);
    } catch (_) {
      return text ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    cargarClientes();
    PollingService.startPolling();
  }

  Future<void> cargarClientes() async {
    setState(() => loading = true);
    try {
      final db = await MongoDatabase.connect();
      final col = db.collection('clientes');
      final res = await col.find().toList();
      setState(() {
        clientes = res.map((e) => Map<String, dynamic>.from(e)).toList();
        filtrados = List.from(clientes);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        clientes = [];
        filtrados = [];
      });
    }
  }

  void buscarClientes() {
    String filtro = buscarController.text.trim().toLowerCase();
    setState(() {
      if (filtro.isEmpty) {
        filtrados = List.from(clientes);
      } else {
        filtrados = clientes.where((c) {
          final nombre = c['nombre']?.toString().toLowerCase() ?? '';
          final cedula = safeDecrypt(c['cedula']).toLowerCase();
          return nombre.contains(filtro) || cedula.contains(filtro);
        }).toList();
      }
      seleccionado = null;
    });
  }

  String _resolveImgPath(String stored) {
    if (stored.isEmpty) return '';
    if (p.isAbsolute(stored) && File(stored).existsSync()) return stored;

    final candidateLocal = p.join(_kBaseLocal, stored);
    if (File(candidateLocal).existsSync()) return candidateLocal;

    final candidateLegacy = p.join(_kBaseLegacy, stored);
    if (File(candidateLegacy).existsSync()) return candidateLegacy;

    return p.isAbsolute(stored) ? stored : candidateLocal;
  }

  void _mostrarImagenGrande(String path) {
    if (path.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                "No se pudo cargar la imagen",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(String path) {
    if (path.isEmpty) return const SizedBox.shrink();
    final exists = File(path).existsSync();

    return GestureDetector(
      onTap: exists ? () => _mostrarImagenGrande(path) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4D82BC).withOpacity(.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(3, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: exists
            ? Image.file(File(path), fit: BoxFit.cover)
            : const Center(
                child: Text("Sin imagen",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      appBar: AppBar(
        title: const Text("Ver Clientes"),
        backgroundColor: azulClaro,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            label: const Text("Regresar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(25),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 950, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(6, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Buscar cliente",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: azulClaro,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buscarController,
                            decoration: InputDecoration(
                              hintText: "Nombre o cédula",
                              prefixIcon:
                                  const Icon(Icons.search, color: azulClaro),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: azulClaro, width: 1),
                              ),
                            ),
                            onSubmitted: (_) => buscarClientes(),
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: azulClaro),
                          onPressed: cargarClientes,
                          tooltip: "Recargar",
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.white,
                          child: loading
                              ? const Center(child: CircularProgressIndicator())
                              : filtrados.isEmpty
                                  ? const Center(
                                      child: Text("No se encontraron clientes"),
                                    )
                                  : ListView.separated(
                                      itemCount: filtrados.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final cli = filtrados[idx];
                                        final cedula = safeDecrypt(cli['cedula']);
                                        final sel = seleccionado == idx;
                                        return Material(
                                          color: sel
                                              ? azulClaro.withOpacity(0.1)
                                              : Colors.transparent,
                                          child: ListTile(
                                            dense: true,
                                            title: Text(
                                              cli['nombre']?.toString() ?? 'Sin nombre',
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            subtitle: Text(
                                              cedula.isEmpty ? "Sin cédula" : cedula,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey),
                                            ),
                                            onTap: () {
                                              setState(() {
                                                seleccionado = idx;
                                              });
                                              if (widget.seleccionarParaEditar) {
                                                Navigator.pop(context, cli);
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(3, 5),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Detalle del Cliente",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF4D82BC),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: seleccionado == null
                            ? const Center(
                                child: Text(
                                  "Selecciona un cliente para ver sus datos.",
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey),
                                ),
                              )
                            : SingleChildScrollView(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(4, 6),
                                      )
                                    ],
                                  ),
                                  child: _detalleCliente(
                                      filtrados[seleccionado!]),
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      if (seleccionado != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 🔥 SOLO MOSTRAR BOTÓN EDITAR SI ES ADMIN
                            if (UsuarioGlobal.esAdmin) ...[
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF4D82BC)),
                                label: const Text("Editar",
                                    style: TextStyle(color: Color(0xFF4D82BC))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF4D82BC), width: 1.3),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  final cliente = filtrados[seleccionado!];
                                  final actualizado = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditarClientePage(cliente: cliente),
                                    ),
                                  );
                                  if (actualizado == true) cargarClientes();
                                },
                              ),
                              const SizedBox(width: 12),
                            ],
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text("Seleccionar"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4D82BC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 12),
                              ),
                              onPressed: () {
                                final cliente = filtrados[seleccionado!];
                                ClienteGlobal.seleccionar(cliente);
                                if (UsuarioGlobal.esAdmin) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MainMenuPage(),
                                    ),
                                  );
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MainMenuUserPage(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detalleCliente(Map<String, dynamic> cliente) {
    final List mats = cliente['matriculas'] ?? [];
    final List contactos = cliente['contactos'] ?? [];
    final List mascotas = cliente['mascotas'] ?? [];
    final List objetos = cliente['objetos'] ?? [];

    final ruta1 = _resolveImgPath((cliente['imagenCliente1'] ?? '').toString());
    final ruta2 = _resolveImgPath((cliente['imagenCliente2'] ?? '').toString());

    final cedula = safeDecrypt(cliente['cedula']);
    final direccion = safeDecrypt(cliente['direccion']);
    final telefono = safeDecrypt(cliente['telefono']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo("Datos personales"),
        _row("Nombre:", Text(cliente['nombre']?.toString() ?? '—')),
        _row("Cédula:", _BlurRevealText(cedula.isEmpty ? "—" : cedula)),
        _row("Dirección:", _BlurRevealText(direccion.isEmpty ? "—" : direccion)),
        _row("Teléfono:", _BlurRevealText(telefono.isEmpty ? "—" : telefono)),
        _row("Póliza:", Text(cliente['poliza']?.toString() ?? '—')),
        const SizedBox(height: 14),
        if (ruta1.isNotEmpty || ruta2.isNotEmpty) ...[
          _titulo("Imágenes del cliente"),
          const SizedBox(height: 6),
          Row(
            children: [
              if (ruta1.isNotEmpty) _thumb(ruta1),
              const SizedBox(width: 12),
              if (ruta2.isNotEmpty) _thumb(ruta2),
            ],
          ),
          const SizedBox(height: 14),
        ],
        _titulo("Vehículos registrados"),
        mats.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(left: 8, top: 5),
                child: Text("— No hay vehículos registrados —"),
              )
            : Column(
                children: mats.map((mat) {
                  final placa = safeDecrypt(mat['matricula']);
                  return Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row("Matrícula:", _BlurRevealText(placa.isEmpty ? "—" : placa)),
                        Text(
                          "${mat['marca'] ?? ''} ${mat['modelo'] ?? ''} • ${mat['color'] ?? ''} • ${mat['anio'] ?? ''}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        const SizedBox(height: 14),
        _titulo("Mascotas"),
        mascotas.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(left: 8, top: 5),
                child: Text("— No hay mascotas registradas —"),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mascotas.map((m) {
                  final nombre = m['nombre'] ?? '';
                  final tipo = m['tipo'] ?? '';
                  final raza = m['raza'] ?? '';
                  final color = m['color'] ?? '';
                  final descripcion = m['descripcion'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Text(
                      "🐾 $nombre ($tipo, $raza) - $color | $descripcion",
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
        const SizedBox(height: 14),
        _titulo("Objetos personales"),
        objetos.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(left: 8, top: 5),
                child: Text("— No hay objetos registrados —"),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: objetos.map((o) {
                  final nombre = o['nombre'] ?? '';
                  final tipo = o['tipo'] ?? '';
                  final color = o['color'] ?? '';
                  final descripcion = o['descripcion'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Text(
                      "📦 $nombre ($tipo) - $color | $descripcion",
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
        const SizedBox(height: 14),
        _titulo("Contactos alternativos"),
        contactos.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(left: 8, top: 5),
                child: Text("— No hay contactos registrados —"),
              )
            : Column(
                children: contactos.map((c) {
                  final tel = safeDecrypt(c['telefono']);
                  return Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "• ${c['nombre'] ?? ''} (${c['relacion'] ?? ''})",
                          style: const TextStyle(fontSize: 14),
                        ),
                        _row("Teléfono:", _BlurRevealText(tel.isEmpty ? "—" : tel)),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          texto,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4D82BC)),
        ),
      );

  Widget _row(String label, Widget valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 6),
          Expanded(child: valor),
        ],
      ),
    );
  }
}

class _BlurRevealText extends StatefulWidget {
  final String text;
  final double blurSigma;
  final TextStyle? style;

  const _BlurRevealText(this.text,
      {super.key, this.blurSigma = 5, this.style});

  @override
  State<_BlurRevealText> createState() => _BlurRevealTextState();
}

class _BlurRevealTextState extends State<_BlurRevealText> {
  bool oculto = true;

  @override
  Widget build(BuildContext context) {
    final contenido = Text(
      widget.text,
      style: widget.style ??
          const TextStyle(fontSize: 14, color: Colors.black87),
      overflow: TextOverflow.fade,
    );

    return GestureDetector(
      onTap: () => setState(() => oculto = !oculto),
      child: Row(
        children: [
          Expanded(
            child: oculto
                ? ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                        sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                    child: contenido,
                  )
                : contenido,
          ),
          const SizedBox(width: 6),
          Icon(
            oculto ? Icons.visibility : Icons.visibility_off,
            size: 18,
            color: const Color(0xFF4D82BC),
          ),
        ],
      ),
    );
  }
}