class UsuarioGlobal {
  static String? tipoUsuario;
  static String? nombreUsuario;

  static void setUsuario({required String tipoUsuario, required String nombreUsuario}) {
    UsuarioGlobal.tipoUsuario = tipoUsuario;
    UsuarioGlobal.nombreUsuario = nombreUsuario;
  }

  static void limpiar() {
    tipoUsuario = null;
    nombreUsuario = null;
  }

  static bool get esAdmin => tipoUsuario == "admin";
  static bool get esUsuario => tipoUsuario == "usuario";
}
