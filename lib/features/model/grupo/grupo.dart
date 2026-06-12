class Grupo {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String nombre;
  final String? descripcion;
 
  const Grupo({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.nombre,
    this.descripcion,
  });
 
  factory Grupo.fromJson(Map<String, dynamic> j) => Grupo(
        id: j['id'] as String,
        granjaId: j['granja_id'] as String,
        tipoAnimalId: j['tipo_animal_id'] as String,
        nombre: j['nombre'] as String,
        descripcion: j['descripcion'] as String?,
      );
}