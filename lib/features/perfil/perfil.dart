class Perfil {
  final String id;
  final String nombre; // El campo que guardas en el registro
  final String email;

  const Perfil({
    required this.id,
    required this.nombre,
    required this.email,
  });

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'] as String,
      nombre: map['nombre'] ?? 'Sin nombre',
      email: map['email'] as String,
    );
  }
}