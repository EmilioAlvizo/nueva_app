// lib/features/granja/granja.dart
import 'package:rancho/features/model/perfil/perfil.dart';

class Granja {
  final String id;
  final String nombre;
  final DateTime createdAt;
  final String ownerId;
  final Perfil? ownerProfile;

  const Granja({
    required this.id,
    required this.nombre,
    required this.createdAt,
    required this.ownerId,
    this.ownerProfile,
  });

  factory Granja.fromMap(Map<String, dynamic> map) {
    // Supabase devuelve las relaciones anidadas como un Map interno
    final profileData = map['perfiles'] as Map<String, dynamic>?;

    return Granja(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      ownerId: map['owner_id'] as String,
      ownerProfile: profileData != null ? Perfil.fromMap(profileData) : null,
    );
  }
}