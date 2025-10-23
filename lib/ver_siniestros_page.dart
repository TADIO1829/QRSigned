import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:url_launcher/url_launcher.dart';
import 'mongo_connection.dart';
import 'cliente_global.dart';
import 'package:overlay_support/overlay_support.dart';
import 'polling_service.dart';

void mostrarNotificacionEscaneo(String mensaje) {
  showSimpleNotification(
    Text("🔔 $mensaje"),
    background: Colors.blue,
    duration: const Duration(seconds: 4),
    trailing: const Icon(Icons.qr_code_scanner, color: Colors.white),
  );
}

class VerSiniestrosPage extends StatefulWidget {
  const VerSiniestrosPage({super.key});

  @override
  State<VerSiniestrosPage> createState() => _VerSiniestrosPageState();
}

class _VerSiniestrosPageState extends State<VerSiniestrosPage> {
  List<Map<String, dynamic>> siniestros = [];
  Map<String, dynamic>? siniestroSeleccionado;
  bool loading = true;

  final Map<String, String> _estadoQRPorObjeto = {};
  final Map<String, String> _seleccionDropdownPorObjeto = {};
  final Map<String, Map<String, dynamic>> _objetoPorId = {};

  @override
  void initState() {
    super.initState();
    cargarSiniestros();
    PollingService.startPolling();
  }

  // ===================== HELPERS =====================

  String _objetoIdHex(dynamic objId) {
    if (objId is mongo.ObjectId) return objId.oid;
    return objId?.toString() ?? '';
  }

  Future<String?> _leerEstadoQRDeUsers(String objetoIdHex) async {
    final db = await MongoDatabase.connect();
    final users = db.collection('users');
    final doc = await users.findOne(
      mongo.where.eq('objetoId', mongo.ObjectId.parse(objetoIdHex)),
    );
    return doc?['status']?.toString();
  }

  Future<void> _cambiarEstadoQRParaObjeto({
    required String objetoIdHex,
    required String nuevoStatus,
  }) async {
    final db = await MongoDatabase.connect();
    final users = db.collection('users');
    await users.updateMany(
      mongo.where.eq("objetoId", mongo.ObjectId.parse(objetoIdHex)),
      mongo.modify.set("status", nuevoStatus),
    );

    final objetos = db.collection('objetos');
    String? estadoOperativo;
    switch (nuevoStatus) {
      case 'robado':
      case 'perdido':
      case 'en_reparacion':
        estadoOperativo = 'en_siniestro';
        break;
      default:
        estadoOperativo = 'activo';
    }
    if (estadoOperativo != null) {
      await objetos.updateOne(
        mongo.where.id(mongo.ObjectId.parse(objetoIdHex)),
        mongo.modify.set("estado", estadoOperativo),
      );
    }

    _estadoQRPorObjeto[objetoIdHex] = nuevoStatus;
  }

  Future<String> _ensureEstadoQRLoaded(Map<String, dynamic> sin) async {
    final idHex = _objetoIdHex(sin["objeto_id"]);
    if (idHex.isEmpty) return 'en_uso';
    if (!_estadoQRPorObjeto.containsKey(idHex)) {
      final s = await _leerEstadoQRDeUsers(idHex) ?? 'en_uso';
      _estadoQRPorObjeto[idHex] = s;
    }
    return _estadoQRPorObjeto[idHex]!;
  }

  Future<Map<String, dynamic>?> _leerObjeto(String objetoIdHex) async {
    if (objetoIdHex.isEmpty) return null;
    if (_objetoPorId.containsKey(objetoIdHex)) {
      return _objetoPorId[objetoIdHex]!;
    }
    final db = await MongoDatabase.connect();
    final objetos = db.collection('objetos');
    final doc = await objetos.findOne(
      mongo.where.id(mongo.ObjectId.parse(objetoIdHex)),
    );
    if (doc != null) {
      _objetoPorId[objetoIdHex] = Map<String, dynamic>.from(doc);
    }
    return doc;
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("No se pudo abrir el enlace: $url")));
      }
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enlace inválido")));
    }
  }

  // ===================== DATA =====================

  Future<void> cargarSiniestros() async {
    setState(() => loading = true);
    final db = await MongoDatabase.connect();
    final col = db.collection('siniestros');

    List<Map<String, dynamic>> res;
    if (ClienteGlobal.seleccionado != null) {
      final clienteId = ClienteGlobal.seleccionado!["_id"];
      res = await col.find(mongo.where.eq("cliente_id", clienteId)).toList();
    } else {
      res = await col.find().toList();
    }

    res = res
        .where((s) =>
            (s["tipo"]?.toString().isNotEmpty ?? false) &&
            (s["fecha"]?.toString().isNotEmpty ?? false))
        .toList();

    setState(() {
      siniestros = res;
      loading = false;
      if (siniestros.isNotEmpty) {
        siniestroSeleccionado ??= siniestros.first;
      } else {
        siniestroSeleccionado = null;
      }
    });
  }

  Future<void> cerrarCaso() async {
    if (siniestroSeleccionado == null) return;
    final db = await MongoDatabase.connect();
    final col = db.collection('siniestros');
    await col.updateOne(
      mongo.where.id(siniestroSeleccionado!["_id"]),
      mongo.modify.set("estado", "cerrado"),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Caso cerrado")));
    await cargarSiniestros();
    setState(() => siniestroSeleccionado = null);
  }

  Future<void> agregarSeguimiento() async {
    if (siniestroSeleccionado == null) return;
    final TextEditingController seguimientoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo Seguimiento"),
        content: TextField(
          controller: seguimientoController,
          decoration: const InputDecoration(labelText: "Detalle del seguimiento"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final detalle = seguimientoController.text.trim();
              if (detalle.isNotEmpty) {
                final db = await MongoDatabase.connect();
                final col = db.collection('siniestros');
                final id = siniestroSeleccionado!["_id"];
                await col.updateOne(
                  mongo.where.id(id),
                  mongo.modify.push("seguimiento", {
                    "fecha": DateTime.now().toIso8601String(),
                    "detalle": detalle,
                  }),
                );
                Navigator.pop(context);
                await cargarSiniestros();
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ===================== UI HELPERS =====================

  String _fmtFecha(dynamic iso) {
    final s = iso?.toString() ?? '';
    return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  }

  Widget _buildMapsButton(String mapsUrl) {
    return TextButton.icon(
      onPressed: () => _openUrl(mapsUrl),
      icon: const Icon(Icons.map_outlined, color: Colors.redAccent),
      label: const Text("Ver en Maps"),
      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
    );
  }

  Widget _bloqueSeguimiento(Map<String, dynamic> sin) {
    final segs = (sin["seguimiento"] as List?)?.cast<Map>() ?? const [];
    if (segs.isEmpty) {
      return const Text("Sin seguimientos aún.",
          style: TextStyle(fontStyle: FontStyle.italic));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segs.reversed.map((seg) {
        final fecha = _fmtFecha(seg["fecha"]);
        final detalle = (seg["detalle"] ?? '').toString();
        final mapsUrl = (seg["mapsUrl"] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• $fecha: $detalle"),
              if (mapsUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: _buildMapsButton(mapsUrl),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _bloqueEscaneos(Map<String, dynamic> sin) {
    final esc = (sin["escaneos"] as List?)?.cast<Map>() ?? const [];
    if (esc.isEmpty) {
      return const Text("Sin registros de escaneo.",
          style: TextStyle(fontStyle: FontStyle.italic));
    }

    final recientes = esc.reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recientes.map((e) {
        final fecha = _fmtFecha(e["fecha"]);
        final ip = (e["ip"] ?? '').toString();
        final mapsUrl = (e["mapsUrl"] ?? '').toString();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📅 $fecha"),
              if (ip.isNotEmpty) Text("IP: $ip"),
              if (mapsUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildMapsButton(mapsUrl),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _dropdownEstadoQR(Map<String, dynamic> sin) {
  final idHex = _objetoIdHex(sin["objeto_id"]);
  if (idHex.isEmpty) return const Text("Objeto sin ID");

  return FutureBuilder<Map<String, dynamic>?>(
    future: _leerObjeto(idHex),
    builder: (context, objSnap) {
      final tipo = (objSnap.data?["tipo"] ?? "objeto").toString();

      // 🔹 Lista dinámica de estados según tipo
      final estadosQR = (tipo == "mascota")
          ? ['sin_novedad', 'perdida', 'encontrada']
          : ['en_uso', 'perdido', 'robado', 'en_venta', 'en_reparacion', 'prestado', 'encontrado'];

      return FutureBuilder<String>(
        future: _ensureEstadoQRLoaded(sin),
        builder: (context, snap) {
          final cargando = snap.connectionState == ConnectionState.waiting;
          String actual = snap.data ?? (tipo == "mascota" ? 'sin_novedad' : 'en_uso');

          // 🔧 Si el valor actual no está en la lista, usa el primero
          if (!estadosQR.contains(actual)) actual = estadosQR.first;

          final seleccionado = _seleccionDropdownPorObjeto[idHex] ?? actual;

          return Row(
            children: [
              const Text("Estado QR: ",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: estadosQR.contains(seleccionado)
                    ? seleccionado
                    : estadosQR.first,
                items: estadosQR
                    .map((e) => DropdownMenuItem(
                        value: e, child: Text(e)))
                    .toList(),
                onChanged: cargando
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _seleccionDropdownPorObjeto[idHex] = v;
                        });
                      },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(cargando ? "Cargando..." : "Aplicar"),
                onPressed: cargando
                    ? null
                    : () async {
                        final nuevo =
                            _seleccionDropdownPorObjeto[idHex] ?? actual;
                        await _cambiarEstadoQRParaObjeto(
                            objetoIdHex: idHex, nuevoStatus: nuevo);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Estado QR actualizado a '$nuevo'")),
                        );
                        setState(() {});
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D82BC),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}


  Widget _fichaObjeto(Map<String, dynamic> sin) {
    final idHex = _objetoIdHex(sin["objeto_id"]);
    if (idHex.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>?>(
      future: _leerObjeto(idHex),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final obj = snap.data;
        if (obj == null) return const SizedBox.shrink();
        final tipo = (obj["tipo"] ?? "").toString();
        final descripcion = (obj["descripcion"] ?? "").toString();
        final otroDetalle = (obj["otroDetalle"] ?? "").toString();
        final marca = (obj["marca"] ?? "").toString();
        final modelo = (obj["modelo"] ?? "").toString();
        final anio = (obj["anio"] ?? "").toString();
        final color = (obj["color"] ?? "").toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ficha del Objeto",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF4D82BC))),
            Text("Tipo: $tipo"),
            if (descripcion.isNotEmpty) Text("Descripción: $descripcion"),
            if (otroDetalle.isNotEmpty) Text("Detalle: $otroDetalle"),
            if (marca.isNotEmpty) Text("Marca: $marca"),
            if (modelo.isNotEmpty) Text("Modelo: $modelo"),
            if (anio.isNotEmpty) Text("Año: $anio"),
            if (color.isNotEmpty) Text("Color: $color"),
          ],
        );
      },
    );
  }

  // ===================== MAIN UI =====================

  @override
  Widget build(BuildContext context) {
    final azul = const Color(0xFF4D82BC);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ver Siniestros"),
        backgroundColor: const Color(0xff005187),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF36393F), Color(0xFF4A5268)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Container(
                  width: 900,
                  height: 500,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.17),
                          blurRadius: 18,
                          offset: const Offset(8, 12)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lista lateral
                      Container(
                        width: 270,
                        padding:
                            const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Siniestros",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF4D82BC))),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView.builder(
                                itemCount: siniestros.length,
                                itemBuilder: (_, i) {
                                  final sin = siniestros[i];
                                  if (sin["tipo"] == null || sin["fecha"] == null)
                                    return const SizedBox.shrink();
                                  final seleccionado =
                                      siniestroSeleccionado?["_id"] == sin["_id"];
                                  return Material(
                                    color: seleccionado
                                        ? azul.withOpacity(0.13)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                    child: ListTile(
                                      title: Text(
                                          "${sin["tipo"]} - ${sin["fecha"]}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        (sin["descripcion"] ?? '').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () async {
                                        setState(
                                            () => siniestroSeleccionado = sin);
                                        final idHex =
                                            _objetoIdHex(sin["objeto_id"]);
                                        if (idHex.isNotEmpty) {
                                          final s = await _leerEstadoQRDeUsers(idHex) ??
                                              'en_uso';
                                          _estadoQRPorObjeto[idHex] = s;
                                          _seleccionDropdownPorObjeto[idHex] = s;
                                          await _leerObjeto(idHex);
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, color: azul.withOpacity(0.14)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: siniestroSeleccionado == null
                              ? const Center(
                                  child: Text(
                                      "Selecciona un siniestro para ver los detalles"))
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Detalles del Siniestro",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: azul)),
                                      const SizedBox(height: 8),
                                      Text("Fecha: ${siniestroSeleccionado!["fecha"]}"),
                                      Text("Hora: ${siniestroSeleccionado!["hora"]}"),
                                      Text("Tipo: ${siniestroSeleccionado!["tipo"]}"),
                                      const SizedBox(height: 10),
                                      _fichaObjeto(siniestroSeleccionado!),
                                      const SizedBox(height: 10),
                                      _dropdownEstadoQR(siniestroSeleccionado!),
                                      const Divider(),
                                      const SizedBox(height: 6),
                                      const Text("Escaneos recientes:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4D82BC))),
                                      _bloqueEscaneos(siniestroSeleccionado!),
                                      const Divider(),
                                      const Text("Seguimiento:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4D82BC))),
                                      _bloqueSeguimiento(siniestroSeleccionado!),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: agregarSeguimiento,
                                            icon: const Icon(Icons.add_comment_outlined),
                                            label:
                                                const Text("Añadir seguimiento"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: azul,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: cerrarCaso,
                                            icon: const Icon(Icons.close_rounded),
                                            label: const Text("Cerrar caso"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
