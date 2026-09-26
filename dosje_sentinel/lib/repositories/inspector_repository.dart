import '../shared/models/inspection_model.dart';
import 'inspection_repository.dart';

abstract class InspectorRepository {
  Future<List<InspectorModel>> getInspectors({bool? isActive, int limit = 50, int offset = 0});
  Future<InspectorModel> createInspector({
    required String inspectorId,
    required String inspectorName,
    bool isActive = true,
  });
  Future<InspectionModel> assignInspector(
    dynamic inspectionId, {
    required String inspectorId,
    String? inspectorName,
    String assignmentStatus = 'ASSIGNED',
  });
  Future<InspectionModel> assignRandomInspector(dynamic inspectionId);
  Future<InspectionAssignmentModel> getInspectionAssignment(dynamic inspectionId);
}

class ApiInspectorRepository implements InspectorRepository {
  final InspectionRepository inspectionRepository;

  ApiInspectorRepository({required this.inspectionRepository});

  @override
  Future<List<InspectorModel>> getInspectors({bool? isActive, int limit = 50, int offset = 0}) =>
      inspectionRepository.getInspectors(isActive: isActive, limit: limit, offset: offset);

  @override
  Future<InspectorModel> createInspector({
    required String inspectorId,
    required String inspectorName,
    bool isActive = true,
  }) =>
      inspectionRepository.createInspector(
        inspectorId: inspectorId,
        inspectorName: inspectorName,
        isActive: isActive,
      );

  @override
  Future<InspectionModel> assignInspector(
    dynamic inspectionId, {
    required String inspectorId,
    String? inspectorName,
    String assignmentStatus = 'ASSIGNED',
  }) =>
      inspectionRepository.assignInspector(
        inspectionId,
        inspectorId: inspectorId,
        inspectorName: inspectorName,
        assignmentStatus: assignmentStatus,
      );

  @override
  Future<InspectionModel> assignRandomInspector(dynamic inspectionId) =>
      inspectionRepository.assignRandomInspector(inspectionId);

  @override
  Future<InspectionAssignmentModel> getInspectionAssignment(dynamic inspectionId) =>
      inspectionRepository.getInspectionAssignment(inspectionId);
}
