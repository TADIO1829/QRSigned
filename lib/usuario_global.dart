class UsuarioGlobal {
  
  static String _tipoUsuario = '';
  static String _nombreUsuario = '';

  static String get tipoUsuario => _tipoUsuario;
  static String get nombreUsuario => _nombreUsuario;

  static bool get esAdmin => _tipoUsuario == "admin";
  static bool get esUsuario => _tipoUsuario == "usuario";

  static void setUsuario({required String tipoUsuario, required String nombreUsuario}) {
    _tipoUsuario = tipoUsuario;
    _nombreUsuario = nombreUsuario;
  }


  static void clear() {
    _tipoUsuario = '';
    _nombreUsuario = '';
  }
}