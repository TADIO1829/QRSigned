class ClienteGlobal {
  static Map<String, dynamic>? clienteSeleccionado;

  static void seleccionar(Map<String, dynamic> cliente) {
    clienteSeleccionado = cliente;
  }

  static Map<String, dynamic>? get seleccionado => clienteSeleccionado;
  static set seleccionado(Map<String, dynamic>? cliente) => clienteSeleccionado = cliente;
}
