import 'package:flutter/material.dart';
import './Clientes/nuevo_cliente_page.dart';
import '../Clientes/ver_clientes_page.dart';
import 'cliente_global.dart';
import './utils/crypto_utils.dart';
import './Clientes/editar_cliente_page.dart';
import 'Siniestros/nuevo_siniestro_page.dart';
import '../Siniestros/ver_siniestros_page.dart';
import 'polling_service.dart';
import 'login_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool showClientesMenu = false;
  bool showSiniestrosMenu = false;
  String? clienteActivo;

  @override
  void initState() {
    super.initState();
    _actualizarClienteDesdeGlobal();
    PollingService.startPolling();
  }

  void _actualizarClienteDesdeGlobal() {
    final cliente = ClienteGlobal.seleccionado;
    if (cliente != null) {
      final cedula = CryptoUtils.decryptText(cliente['cedula'] ?? '');
      setState(() {
        clienteActivo = "${cliente['nombre']} ($cedula)";
      });
    } else {
      setState(() {
        clienteActivo = "Ninguno";
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarClienteDesdeGlobal();
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Menú Principal | QRSIGNED'),
        backgroundColor: azulClaro,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Cerrar sesión",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Cerrar sesión"),
                  content: const Text("¿Seguro que deseas cerrar sesión?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancelar"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulClaro,
                      ),
                      child: const Text("Salir"),
                    ),
                  ],
                ),
              );

              if (confirmar == true && context.mounted) {
                ClienteGlobal.seleccionado = null;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          width: 420,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 70, color: azulClaro),
              const SizedBox(height: 8),
              Text(
                'Menú principal',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: azulClaro,
                ),
              ),
              const SizedBox(height: 22),

              // === CLIENTES ===
              menuButton(
                context,
                "Clientes",
                showClientesMenu,
                () => setState(() {
                  showClientesMenu = !showClientesMenu;
                  if (showClientesMenu) showSiniestrosMenu = false;
                }),
                azulClaro,
              ),

              if (showClientesMenu) ...[
                subMenuButton(context, "Nuevo Cliente", Icons.person_add, azulClaro, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NuevoClientePage()),
                  );
                }),
                subMenuButton(context, "Ver Clientes", Icons.people, azulClaro, () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VerClientesPage()),
                  );
                  _actualizarClienteDesdeGlobal();
                }),
                subMenuButton(context, "Editar Cliente", Icons.edit, azulClaro, () async {
                  if (ClienteGlobal.seleccionado != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditarClientePage(
                          cliente: ClienteGlobal.seleccionado!,
                        ),
                      ),
                    );
                  } else {
                    final seleccionado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerClientesPage(seleccionarParaEditar: true),
                      ),
                    );

                    if (seleccionado != null && seleccionado is Map<String, dynamic>) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditarClientePage(cliente: seleccionado),
                        ),
                      );
                    }
                  }
                }),
                subMenuButton(context, "Trasladar Póliza", Icons.sync_alt, azulClaro, () async {
                  if (ClienteGlobal.seleccionado != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NuevoClientePage(
                          trasladarPolizaDesde: ClienteGlobal.seleccionado,
                        ),
                      ),
                    );
                  } else {
                    final seleccionado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerClientesPage(seleccionarParaEditar: true),
                      ),
                    );

                    if (seleccionado != null && seleccionado is Map<String, dynamic>) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NuevoClientePage(
                            trasladarPolizaDesde: seleccionado,
                          ),
                        ),
                      );
                    }
                  }
                }),
              ],

              // === SINIESTROS ===
              menuButton(
                context,
                "Siniestros",
                showSiniestrosMenu,
                () => setState(() {
                  showSiniestrosMenu = !showSiniestrosMenu;
                  if (showSiniestrosMenu) showClientesMenu = false;
                }),
                azulClaro,
              ),

              if (showSiniestrosMenu) ...[
                subMenuButton(context, "Nuevo Siniestro", Icons.note_add, azulClaro, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NuevoSiniestroPage()),
                  );
                }),
                subMenuButton(context, "Ver Siniestros", Icons.list_alt, azulClaro, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VerSiniestrosPage()),
                  );
                }),
              ],

              const SizedBox(height: 25),

              // === CLIENTE ACTIVO ===
              Row(
                children: [
                  Icon(Icons.verified_user, color: azulClaro),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Cliente activo: $clienteActivo",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: azulClaro,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ClienteGlobal.seleccionado != null)
                    IconButton(
                      tooltip: "Quitar cliente activo",
                      icon: Icon(Icons.close, color: azulClaro, size: 22),
                      onPressed: () {
                        setState(() {
                          ClienteGlobal.seleccionado = null;
                          clienteActivo = "Ninguno";
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === BOTÓN PRINCIPAL ===
  Widget menuButton(
      BuildContext context, String label, bool expanded, VoidCallback onTap, Color azulClaro) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: expanded ? azulClaro : const Color(0xFF353B48),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (expanded)
            BoxShadow(
              color: azulClaro.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              children: [
                Icon(
                  label == "Clientes" ? Icons.people : Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === SUBMENÚ ===
  Widget subMenuButton(
      BuildContext context, String label, IconData icon, Color azulClaro, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 30, right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0FA),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: azulClaro),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF34495E),
                    fontWeight: FontWeight.w500,
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
