import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:qr_flutter/qr_flutter.dart';
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
  List<Map<String, dynamic>> users = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    print("🚀 INIT VerObjetosPage");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cargarDatos(auto: true);
    });
  }

  @override
  void dispose() {
    print("🔚 DISPOSE VerObjetosPage");
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos({bool auto = false}) async {
    print("📥 _cargarDatos iniciado, auto: $auto");
    
    if (!auto && mounted) {
      setState(() => loading = true);
    }

    try {
      final db = await MongoDatabase.connect();
      final colUsers = db.collection('users');

      var query = mongo.where;
      
      if (ClienteGlobal.clienteSeleccionado != null) {
        final clienteSel = ClienteGlobal.clienteSeleccionado!;
        query = query.eq('clienteId', clienteSel['_id']);
      }

      final listaUsers = await colUsers.find(
        query.sortBy('_id', descending: true)
      ).toList();

      print("📊 Total de usuarios/objetos cargados: ${listaUsers.length}");

      if (mounted) {
        setState(() {
          users = listaUsers;
          loading = false;
        });
        print("✅ Estado actualizado correctamente");
      } else {
        print("⚠️ Widget no montado, no se actualiza estado");
      }
    } catch (e, stack) {
      print("❌ Error crítico en _cargarDatos: $e");
      print("📝 Stack: $stack");
      if (mounted) {
        setState(() => loading = false);
        _mostrarError("Error cargando datos: $e");
      }
    }
  }

  String _objetoIdHex(dynamic objId) {
    if (objId is mongo.ObjectId) return objId.oid;
    return objId?.toString() ?? '';
  }

  String _generarUrlQR(Map<String, dynamic> user) {
    try {
      final qrToken = user['qrToken']?.toString();
      
      if (qrToken == null || qrToken.isEmpty) {
        throw Exception("No se encontró qrToken");
      }
      
      final url = "http://localhost:3000/qr/form/$qrToken";
      print("✅ URL QR generada: $url");
      return url;
    } catch (e) {
      print("❌ Error en _generarUrlQR: $e");
      rethrow;
    }
  }

  void _mostrarQR(Map<String, dynamic> user) {
    print("🎯 _mostrarQR iniciado para: ${user['name']}");
    
    try {
      final name = user["name"]?.toString() ?? "Sin nombre";
      final object = user["object"]?.toString() ?? "Sin descripción";
      final status = user["status"]?.toString() ?? "en_uso";
      final qrToken = user['qrToken']?.toString() ?? 'No disponible';

      final urlQR = _generarUrlQR(user);

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_2, color: Colors.green),
              SizedBox(width: 8),
              Text("Código QR"),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  object,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Estado: $status",
                  style: TextStyle(
                    color: _colorEstado(status),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: QrImageView(
                    data: urlQR,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                _buildInfoContainer(urlQR, qrToken),
                const SizedBox(height: 12),
                
                const Text(
                  "📱 Escanea este código QR",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        ),
      );
      
    } catch (e, stack) {
      print("💥 ERROR en _mostrarQR: $e");
      print("📝 Stack: $stack");
      _mostrarError("Error al mostrar QR: ${e.toString()}");
    }
  }

  Widget _buildInfoContainer(String urlQR, String qrToken) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "URL del QR:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            urlQR,
            style: const TextStyle(
              fontFamily: 'Monospace',
              fontSize: 10,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Token QR:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            qrToken.length > 30 ? "${qrToken.substring(0, 30)}..." : qrToken,
            style: const TextStyle(
              fontFamily: 'Monospace',
              fontSize: 10,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String titulo, String valor, IconData icono, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  valor,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    print("🛑 Mostrando error: $mensaje");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarInfoUser(Map<String, dynamic> user) {
    print("ℹ️ _mostrarInfoUser para: ${user['name']}");
    
    try {
      final name = user["name"]?.toString() ?? "Sin nombre";
      final email = user["email"]?.toString() ?? "Sin email";
      final object = user["object"]?.toString() ?? "Sin descripción";
      final status = user["status"]?.toString() ?? "en_uso";
      final qrToken = user['qrToken']?.toString() ?? 'No disponible';
      final qrUrl = user['qrUrl']?.toString() ?? 'No disponible';
      final objetoId = user['objetoId'];
      final objetoIdHex = objetoId != null ? _objetoIdHex(objetoId) : 'No asignado';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("📋 Información Completa"),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem("Nombre", name, Icons.person),
                _buildInfoItem("Email", email, Icons.email),
                _buildInfoItem("Objeto", object, Icons.description),
                _buildInfoItem("Estado", status, Icons.circle, color: _colorEstado(status)),
                _buildInfoItem("ID Objeto", objetoIdHex, Icons.fingerprint),
                _buildInfoItem("Token QR", qrToken, Icons.qr_code_2),
                _buildInfoItem("URL QR", qrUrl, Icons.link),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mostrarQR(user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2),
                  SizedBox(width: 8),
                  Text("Mostrar QR"),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print("❌ Error en _mostrarInfoUser: $e");
      _mostrarError("Error al mostrar información: $e");
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case "en_siniestro": return Colors.orange.shade700;
      case "disponible": return Colors.green.shade700;
      case "inactivo": return Colors.grey.shade700;
      case "pendiente": return Colors.amber.shade700;
      case "robado":
      case "perdido":
      case "en_reparacion": return Colors.red.shade700;
      case "en_uso": return Colors.blue.shade700;
      case "en_venta": return Colors.purple.shade700;
      case "prestado": return Colors.cyan.shade700;
      case "encontrado": return Colors.green.shade700;
      default: return Colors.blueGrey;
    }
  }

  Widget _detalleUser(Map<String, dynamic> user) {
    final name = user["name"]?.toString() ?? "";
    final object = user["object"]?.toString() ?? "";
    final status = user["status"]?.toString() ?? "";
    final email = user["email"]?.toString() ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Nombre: $name"),
        Text("Objeto: $object"),
        Text("Email: $email"),
        Text("Estado: $status", style: TextStyle(
          color: _colorEstado(status), 
          fontWeight: FontWeight.bold
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🔄 BUILD ejecutado, loading: $loading, users: ${users.length}");
    
    const fondo = Color(0xFF23272F);
    const azul = Color(0xFF4D82BC);

    final clienteActivo = ClienteGlobal.clienteSeleccionado;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: Text(clienteActivo == null
            ? "Todos los Objetos Registrados"
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
          : users.isEmpty
              ? const Center(
                  child: Text(
                    "No hay objetos registrados.",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
              : _buildListaUsers(),
    );
  }

  Widget _buildListaUsers() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, i) {
          final user = users[i];
          final name = user["name"]?.toString() ?? "Sin nombre";

          print("📦 Construyendo item $i: $name");

          return Card(
            elevation: 6,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4D82BC),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _detalleUser(user),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            print("🔄 Botón Info presionado");
                            _mostrarInfoUser(user);
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text("Información"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            print("🔄 Botón QR presionado");
                            _mostrarQR(user);
                          },
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text("Mostrar QR"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}