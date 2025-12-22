import 'package:flutter/material.dart';
import 'mainmenu.dart';
import 'mainmenu_user.dart';
import '../usuario_global.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool loading = false;
  String error = '';

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = '';
    });

    await Future.delayed(const Duration(milliseconds: 400));

    final email = userController.text.trim().toLowerCase();
    final password = passController.text.trim();

    if (email == "admin@admin.com" && password == "QRSIGNED") {
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Esthefany");
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("¡Bienvenido Admin!"),
          content: const Text('Usuario administrador: Esthefany'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainMenuPage()),
                );
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else if (email == "usuario@gmail.com" && password == "QRSIGNED") {
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Tadeo");
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("¡Bienvenido Usuario!"),
          content: const Text('Acceso como usuario estándar: Tadeo'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainMenuUserPage()),
                );
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      setState(() => error = 'Usuario o contraseña incorrectos');
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF23272F);
    const azulClaro = Color(0xFF4D82BC);

    return Scaffold(
      backgroundColor: fondo,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 72,
                color: azulClaro,
              ),
              const SizedBox(height: 10),
              const Text(
                "Iniciar sesión",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: azulClaro,
                ),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: userController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.person_outline, color: azulClaro),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline, color: azulClaro),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              if (error.isNotEmpty)
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 16),
              loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulClaro,
                          elevation: 6,
                          shadowColor: azulClaro.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          await _login();
                        },
                        child: const Text(
                          "Entrar",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
