class TipoAnimal {
  final String id;
  final String granjaId;
  final String nombre;
  final String? descripcion;
 
  const TipoAnimal({
    required this.id,
    required this.granjaId,
    required this.nombre,
    this.descripcion,
  });
 
  factory TipoAnimal.fromJson(Map<String, dynamic> j) => TipoAnimal(
        id: j['id'] as String,
        granjaId: j['granja_id'] as String,
        nombre: j['nombre'] as String,
        descripcion: j['descripcion'] as String?,
      );
}