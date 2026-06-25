// lib/features/animales/model/catalogoItem/catalogo_item.dart

/// Item simple de un catálogo (id + nombre). Reutilizable para
/// `cat_proposito_animal`, `cat_tipo_adquisicion`, etc.
class CatalogoItem {
  final String id;
  final String nombre;

  const CatalogoItem({required this.id, required this.nombre});

  factory CatalogoItem.fromJson(Map<String, dynamic> json) {
    return CatalogoItem(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
    );
  }
}