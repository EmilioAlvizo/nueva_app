import '../altaAnimales/altaAnimales.dart';
import '../grupo/grupo.dart';

class ResumenGrupo {
  final Grupo grupo;
  final int vivos;
  final int totalEjemplares;
  final int muertes;
  final List<AltaAnimales> lotes;
 
  const ResumenGrupo({
    required this.grupo,
    required this.vivos,
    required this.totalEjemplares,
    required this.muertes,
    required this.lotes,
  });
}