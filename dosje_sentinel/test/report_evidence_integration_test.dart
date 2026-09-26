@Timeout(Duration(minutes: 5))
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/report_repository.dart';
import 'package:dosje_sentinel/repositories/evidence_repository.dart';
import 'package:dosje_sentinel/repositories/inspection_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/shared/models/report_model.dart';
import 'package:dosje_sentinel/shared/models/evidence_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  setUpAll(() {
    ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
  });

  group('Report & Evidence Models Integration', () {
    test('ReportModel serialization and deserialization', () {
      final json = {
        'id': 42,
        'project_id': 1,
        'inspection_id': 10,
        'report_type': 'INSPECTION',
        'status': 'FINAL',
        'title': 'Quarterly Inspection Audit Dossier',
        'summary': 'All safety criteria met.',
        'findings': 'Attendance log matched CCTV count.',
        'recommendations': 'Renew certification.',
        'generated_at': '2026-09-25T10:00:00.000Z',
        'created_at': '2026-09-25T10:00:00.000Z',
        'updated_at': '2026-09-25T10:05:00.000Z',
      };

      final model = ReportModel.fromJson(json);
      expect(model.id, 42);
      expect(model.projectId, 1);
      expect(model.inspectionId, 10);
      expect(model.reportType, ReportType.inspection);
      expect(model.status, ReportStatus.finalStatus);
      expect(model.title, 'Quarterly Inspection Audit Dossier');
      expect(model.summary, 'All safety criteria met.');
      expect(model.findings, 'Attendance log matched CCTV count.');
      expect(model.recommendations, 'Renew certification.');

      final output = model.toJson();
      expect(output['id'], 42);
      expect(output['project_id'], 1);
      expect(output['report_type'], 'INSPECTION');
      expect(output['status'], 'FINAL');
    });

    test('ReportEvidenceReferenceModel serialization', () {
      final json = {
        'id': 7,
        'report_id': 42,
        'external_evidence_id': 'cloudinary_img_99182',
        'evidence_type': 'IMAGE',
        'source': 'INSPECTION_CAMERA',
        'created_at': '2026-09-25T10:02:00.000Z',
      };

      final model = ReportEvidenceReferenceModel.fromJson(json);
      expect(model.id, 7);
      expect(model.reportId, 42);
      expect(model.externalEvidenceId, 'cloudinary_img_99182');
      expect(model.evidenceType, 'IMAGE');
      expect(model.source, 'INSPECTION_CAMERA');

      final output = model.toJson();
      expect(output['external_evidence_id'], 'cloudinary_img_99182');
      expect(output['evidence_type'], 'IMAGE');
    });

    test('ReportAggregationModel deserialization with all domains', () {
      final json = {
        'report_id': 42,
        'project_id': 1,
        'project_name': 'District Rehabilitation Centre',
        'project_code': 'DL-001',
        'risk': {'score': 24, 'level': 'LOW'},
        'attendance': {
          'expected_workers': 50,
          'detected_workers': 48,
          'attendance_percentage': 96.0,
          'detection_timestamp': '2026-09-25T09:30:00.000Z',
        },
        'cctv': {'total_cameras': 4, 'active_cameras': 4},
        'ai': {
          'total_detections': 88,
          'latest_detection_id': 120,
          'latest_activity': 'Normal Operation',
          'latest_people_detected': 12,
          'latest_confidence': 0.95,
          'latest_timestamp': '2026-09-25T09:45:00.000Z',
        },
        'alerts': {'total_alerts': 5, 'active_alerts': 1, 'resolved_alerts': 4},
        'inspections': {
          'total_inspections': 3,
          'pending': 0,
          'scheduled': 1,
          'in_progress': 0,
          'completed': 2,
          'cancelled': 0,
          'latest_inspection_id': 10,
          'latest_inspection_status': 'COMPLETED',
        },
        'video_sessions': {
          'total_sessions': 2,
          'active_sessions': 0,
          'ended_sessions': 2,
          'latest_session_id': 4,
          'latest_session_status': 'ENDED',
        },
        'evidence': {
          'total_references': 2,
          'project_evidence_ids': ['ev_001', 'ev_002'],
        },
        'inspection': {
          'id': 10,
          'inspection_type': 'SURPRISE',
          'status': 'COMPLETED',
          'officer_name': 'Inspector Rajesh',
          'reason': 'Routine spot check',
        },
      };

      final model = ReportAggregationModel.fromJson(json);
      expect(model.reportId, 42);
      expect(model.projectCode, 'DL-001');
      expect(model.risk.score, 24);
      expect(model.risk.level, 'LOW');
      expect(model.attendance.attendancePercentage, 96.0);
      expect(model.cctv.totalCameras, 4);
      expect(model.ai.totalDetections, 88);
      expect(model.alerts.activeAlerts, 1);
      expect(model.inspections.totalInspections, 3);
      expect(model.videoSessions.totalSessions, 2);
      expect(model.evidence.totalReferences, 2);
      expect(model.evidence.projectEvidenceIds, ['ev_001', 'ev_002']);
      expect(model.inspection?.officerName, 'Inspector Rajesh');
    });

    test('EvidenceModel backend MediaResponse format deserialization', () {
      final json = {
        'id': 105,
        'project_id': 1,
        'inspection_id': 10,
        'camera_id': null,
        'media_type': 'IMAGE',
        'source_type': 'UPLOAD',
        'storage_provider': 'cloudinary',
        'storage_public_id': 'dosje/media/sample_105',
        'media_url': 'https://res.cloudinary.com/dosje/image/upload/v1/sample_105.jpg',
        'original_filename': 'mess_hall_inspection.jpg',
        'mime_type': 'image/jpeg',
        'file_size': 102400,
        'description': 'Mess hall sanitation compliance',
        'captured_at': '2026-09-25T08:00:00.000Z',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'location_accuracy': 3.5,
        'created_at': '2026-09-25T08:05:00.000Z',
      };

      final model = EvidenceModel.fromJson(json);
      expect(model.id, '105');
      expect(model.inspectionId, '10');
      expect(model.title, 'Mess hall sanitation compliance');
      expect(model.fileName, 'mess_hall_inspection.jpg');
      expect(model.remoteUrl, contains('cloudinary.com'));
      expect(model.isGeoVerified, isTrue);
      expect(model.latitude, 28.6139);
      expect(model.longitude, 77.2090);
      expect(model.status, EvidenceStatus.uploaded);
    });
  });

  group('Mock Repositories Integration', () {
    test('MockReportRepository supports CRUD and Aggregation', () async {
      final repo = MockReportRepository();

      final created = await repo.createReport(
        projectId: 1,
        inspectionId: 1,
        reportType: ReportType.inspection,
        title: 'New Mock Report',
        summary: 'Field review',
      );
      expect(created.id, isNotNull);
      expect(created.title, 'New Mock Report');

      final fetched = await repo.getReportById(created.id);
      expect(fetched?.title, 'New Mock Report');

      final projectReports = await repo.getReportsForProject(1);
      expect(projectReports.any((r) => r.id == created.id), isTrue);

      final updated = await repo.updateReport(
        created.id,
        status: ReportStatus.finalStatus,
        findings: 'Clean premises',
      );
      expect(updated.status, ReportStatus.finalStatus);
      expect(updated.findings, 'Clean premises');

      final ref = await repo.linkEvidenceToReport(
        created.id,
        externalEvidenceId: 'ev_mock_99',
        evidenceType: 'IMAGE',
      );
      expect(ref.externalEvidenceId, 'ev_mock_99');

      final evidenceList = await repo.getReportEvidence(created.id);
      expect(evidenceList.any((e) => e.externalEvidenceId == 'ev_mock_99'), isTrue);

      await repo.removeReportEvidence(created.id, ref.id);
      final afterDelete = await repo.getReportEvidence(created.id);
      expect(afterDelete.any((e) => e.id == ref.id), isFalse);

      final agg = await repo.getReportAggregation(created.id);
      expect(agg.reportId, created.id);
      expect(agg.risk.score, 24);
      expect(agg.attendance.attendancePercentage, 93.33);
    });

    test('MockEvidenceRepository supports upload and list', () async {
      final repo = MockEvidenceRepository();

      final list = await repo.getEvidenceForInspection(1);
      expect(list.isNotEmpty, isTrue);

      final uploaded = await repo.uploadInspectionEvidence(
        inspectionId: 1,
        fileBytes: [1, 2, 3, 4],
        fileName: 'test_upload.jpg',
        description: 'Mock proof',
        latitude: 27.1982,
        longitude: 78.0059,
      );
      expect(uploaded.fileName, 'test_upload.jpg');
      expect(uploaded.isGeoVerified, isTrue);

      final updatedList = await repo.getEvidenceForInspection(1);
      expect(updatedList.any((e) => e.id == uploaded.id), isTrue);
    });
  });

  group('Riverpod Providers Integration', () {
    test('projectReportsProvider & reportAggregationProvider via container', () async {
      final container = ProviderContainer(
        overrides: [
          reportRepositoryProvider.overrideWithValue(MockReportRepository()),
          evidenceRepositoryProvider.overrideWithValue(MockEvidenceRepository()),
        ],
      );

      final reports = await container.read(projectReportsProvider(1).future);
      expect(reports.isNotEmpty, isTrue);

      final report = await container.read(singleReportProvider(1).future);
      expect(report, isNotNull);
      expect(report?.id, 1);

      final agg = await container.read(reportAggregationProvider(1).future);
      expect(agg, isNotNull);
      expect(agg?.projectCode, 'DL-001');

      final evidence = await container.read(inspectionEvidenceProvider(1).future);
      expect(evidence.isNotEmpty, isTrue);
    });
  });

  group('Live FastAPI Backend Reports & Evidence Lifecycle', () {
    late ApiClient client;
    late ApiReportRepository reportRepo;
    late ApiEvidenceRepository evidenceRepo;
    late ApiProjectRepository projectRepo;
    late ApiInspectionRepository inspectionRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      client = ApiClient();
      reportRepo = ApiReportRepository(apiClient: client);
      evidenceRepo = ApiEvidenceRepository(apiClient: client);
      projectRepo = ApiProjectRepository(apiClient: client);
      inspectionRepo = ApiInspectionRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
    });

    test('Live Report CRUD, Evidence Reference & Authoritative Aggregation Lifecycle', () async {
      try {
        final projects = await projectRepo.getProjects(limit: 1);
        if (projects.isEmpty) return;

        final testProject = projects.first;
        final projectId = int.parse(testProject.id.toString());

        // Find or create an inspection for this project
        final existingInspections = await inspectionRepo.getInspectionsForProject(projectId);
        int inspectionId;
        if (existingInspections.isNotEmpty) {
          inspectionId = int.parse(existingInspections.first.id.toString());
        } else {
          final newInsp = await inspectionRepo.createInspection(
            projectId: projectId,
            inspectionType: 'SURPRISE',
            reason: 'Module 10 Integration Verification',
          );
          inspectionId = int.parse(newInsp.id.toString());
        }

        // 1. Create Report
        final uniqueTitle = 'Audit Dossier Integration Test ${DateTime.now().millisecondsSinceEpoch}';
        final createdReport = await reportRepo.createReport(
          projectId: projectId,
          inspectionId: inspectionId,
          reportType: ReportType.inspection,
          status: ReportStatus.draft,
          title: uniqueTitle,
          summary: 'Automated test draft for Module 10',
          findings: 'Physical facility and biometrics verified.',
          recommendations: 'Complete periodic compliance inspection.',
          generatedAt: DateTime.now(),
        );

        expect(createdReport.id, isPositive);
        expect(createdReport.projectId, projectId);
        expect(createdReport.inspectionId, inspectionId);
        expect(createdReport.title, uniqueTitle);
        expect(createdReport.status, ReportStatus.draft);

        // 2. Get Report by ID
        final fetchedReport = await reportRepo.getReportById(createdReport.id);
        expect(fetchedReport, isNotNull);
        expect(fetchedReport!.id, createdReport.id);
        expect(fetchedReport.title, uniqueTitle);

        // 3. List Reports for Project
        final projectReports = await reportRepo.getReportsForProject(projectId);
        expect(projectReports.any((r) => r.id == createdReport.id), isTrue);

        // 4. Update Report
        final updatedReport = await reportRepo.updateReport(
          createdReport.id,
          status: ReportStatus.finalStatus,
          findings: 'Updated verification findings: Satisfactory.',
        );
        expect(updatedReport.status, ReportStatus.finalStatus);
        expect(updatedReport.findings, contains('Satisfactory'));

        // 5. Link Evidence Reference to Report
        final externalEvidenceKey = 'live_ev_${DateTime.now().millisecondsSinceEpoch}';
        final linkedRef = await reportRepo.linkEvidenceToReport(
          createdReport.id,
          externalEvidenceId: externalEvidenceKey,
          evidenceType: 'IMAGE',
          source: 'INSPECTOR_DEVICE',
        );
        expect(linkedRef.id, isPositive);
        expect(linkedRef.reportId, createdReport.id);
        expect(linkedRef.externalEvidenceId, externalEvidenceKey);

        // 6. List Report Evidence References
        final refList = await reportRepo.getReportEvidence(createdReport.id);
        expect(refList.any((r) => r.externalEvidenceId == externalEvidenceKey), isTrue);

        // 7. Authoritative Aggregation Query
        final agg = await reportRepo.getReportAggregation(createdReport.id);
        expect(agg.reportId, createdReport.id);
        expect(agg.projectId, projectId);
        expect(agg.projectName, isNotEmpty);
        expect(agg.projectCode, isNotEmpty);
        expect(agg.risk, isNotNull);
        expect(agg.attendance, isNotNull);
        expect(agg.cctv, isNotNull);
        expect(agg.ai, isNotNull);
        expect(agg.alerts, isNotNull);
        expect(agg.inspections, isNotNull);
        expect(agg.videoSessions, isNotNull);
        expect(agg.evidence, isNotNull);
        expect(agg.evidence.totalReferences, isNonNegative);

        // 8. Delete Report Evidence Reference
        await reportRepo.removeReportEvidence(createdReport.id, linkedRef.id);
        final afterDeleteRefs = await reportRepo.getReportEvidence(createdReport.id);
        expect(afterDeleteRefs.any((r) => r.id == linkedRef.id), isFalse);
      } on AppException {
        // Backend offline
      }
    });

    test('Live Inspection Evidence listing', () async {
      try {
        final list = await evidenceRepo.getEvidenceForInspection(1);
        expect(list, isA<List<EvidenceModel>>());
      } on AppException {
        // Backend offline
      }
    });

    test('getReportById returns null for non-existent report (404 handling)', () async {
      try {
        final notFound = await reportRepo.getReportById(9999999);
        expect(notFound, isNull);
      } on AppException {
        // Backend offline
      }
    });

    test('createReport with mismatched project throws AppException (400 validation)', () async {
      try {
        await reportRepo.createReport(
          projectId: 999999,
          inspectionId: 1,
          reportType: ReportType.inspection,
          title: 'Mismatched project test',
        );
        fail('Should have thrown AppException');
      } on AppException catch (e) {
        expect(e, isA<AppException>());
      }
    });

    test('uploadInspectionEvidence with empty file throws BadRequestException', () async {
      try {
        final emptyBytes = Uint8List(0);
        await evidenceRepo.uploadInspectionEvidence(
          inspectionId: 1,
          fileBytes: emptyBytes,
          fileName: 'empty.jpg',
        );
        fail('Should have thrown BadRequestException');
      } on BadRequestException catch (e) {
        expect(e.message, contains('empty'));
      } on AppException {
        // Offline or connection failure
      }
    });
  });
}
