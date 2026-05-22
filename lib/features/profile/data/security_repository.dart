import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/data/auth_repository.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

final securityEventsProvider = FutureProvider<List<SecurityEvent>>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(securityRepositoryProvider).fetchSecurityEvents(userId);
});

final trustedDevicesProvider = FutureProvider<List<TrustedDevice>>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  final repository = ref.watch(securityRepositoryProvider);
  await repository.registerCurrentDevice(userId);
  return repository.fetchTrustedDevices(userId);
});

final exportHistoryProvider = FutureProvider<List<DataExportRequest>>((
  ref,
) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(securityRepositoryProvider).fetchExportHistory(userId);
});

final accountDeletionProvider = FutureProvider<AccountDeletionRequest?>((
  ref,
) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return null;
  return ref.watch(securityRepositoryProvider).fetchAccountDeletion(userId);
});

final legalHistoryProvider = FutureProvider<List<LegalAcceptance>>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(securityRepositoryProvider).fetchLegalHistory(userId);
});

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    required this.metadata,
  });

  final String id;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String? ?? 'security_event',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.deviceLabel,
    required this.platform,
    required this.lastSeenAt,
    required this.trustedAt,
    this.revokedAt,
    this.deviceFingerprint,
    this.isCurrent = false,
  });

  final String id;
  final String deviceLabel;
  final String platform;
  final DateTime lastSeenAt;
  final DateTime trustedAt;
  final DateTime? revokedAt;
  final String? deviceFingerprint;
  final bool isCurrent;

  bool get isRevoked => revokedAt != null;

  factory TrustedDevice.fromJson(
    Map<String, dynamic> json, {
    String? currentFingerprint,
  }) {
    return TrustedDevice(
      id: json['id'] as String,
      deviceLabel: json['device_label'] as String? ?? 'Unknown device',
      platform: json['platform'] as String? ?? 'unknown',
      deviceFingerprint: json['device_fingerprint'] as String?,
      lastSeenAt:
          DateTime.tryParse(json['last_seen_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      trustedAt:
          DateTime.tryParse(json['trusted_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      revokedAt: DateTime.tryParse(json['revoked_at'] as String? ?? ''),
      isCurrent: json['device_fingerprint'] == currentFingerprint,
    );
  }
}

class DataExportRequest {
  const DataExportRequest({
    required this.id,
    required this.requestedAt,
    required this.status,
    this.completedAt,
    this.expiresAt,
  });

  final String id;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String status;

  factory DataExportRequest.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(json['expires_at'] as String? ?? '');
    final status = json['status'] as String? ?? 'pending';
    return DataExportRequest(
      id: json['id'] as String,
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      expiresAt: expiresAt,
      status:
          status == 'completed' &&
              expiresAt != null &&
              expiresAt.isBefore(DateTime.now().toUtc())
          ? 'expired'
          : status,
    );
  }
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.requestedAt,
    required this.scheduledPurgeAt,
    this.cancelledAt,
    this.completedAt,
  });

  final String id;
  final DateTime requestedAt;
  final DateTime scheduledPurgeAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  bool get isPending => cancelledAt == null && completedAt == null;

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id'] as String,
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      scheduledPurgeAt:
          DateTime.tryParse(json['scheduled_purge_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cancelledAt: DateTime.tryParse(json['cancelled_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    );
  }
}

class LegalAcceptance {
  const LegalAcceptance({
    required this.id,
    required this.policyType,
    required this.policyVersion,
    required this.acceptedAt,
  });

  final String id;
  final String policyType;
  final String policyVersion;
  final DateTime acceptedAt;

  factory LegalAcceptance.fromJson(Map<String, dynamic> json) {
    return LegalAcceptance(
      id: json['id'] as String,
      policyType:
          json['policy_type'] as String? ??
          json['policy_name'] as String? ??
          'policy',
      policyVersion: json['policy_version'] as String? ?? 'unknown',
      acceptedAt:
          DateTime.tryParse(json['accepted_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SecurityRepository {
  SecurityRepository(this._client, this._storage);

  static const _deviceKey = 'trusted_device_fingerprint';

  final SupabaseClient _client;
  final SecureStorageService _storage;

  Future<void> logSecurityEvent(
    String eventType, {
    Map<String, dynamic> metadata = const {},
  }) async {
    await _client.functions.invoke(
      'log-security-event',
      body: {'event_type': eventType, 'metadata': metadata},
    );
  }

  Future<List<SecurityEvent>> fetchSecurityEvents(String userId) async {
    final response = await _client
        .from('security_events')
        .select('id,event_type,metadata,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map(SecurityEvent.fromJson).toList(growable: false);
  }

  Future<void> registerCurrentDevice(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final fingerprint = await _currentDeviceFingerprint();
    final existing = await _client
        .from('trusted_devices')
        .select('id')
        .eq('user_id', userId)
        .eq('device_fingerprint', fingerprint)
        .maybeSingle();
    await _client.from('trusted_devices').upsert({
      'user_id': userId,
      'device_label': _deviceLabel(),
      'platform': _platformLabel(),
      'device_fingerprint': fingerprint,
      'last_seen_at': now,
      'updated_at': now,
    }, onConflict: 'user_id,device_fingerprint');
    if (existing == null) {
      await logSecurityEvent(
        'new_device_session',
        metadata: {'platform': _platformLabel()},
      );
    }
  }

  Future<List<TrustedDevice>> fetchTrustedDevices(String userId) async {
    final fingerprint = await _currentDeviceFingerprint();
    final response = await _client
        .from('trusted_devices')
        .select(
          'id,device_label,platform,device_fingerprint,last_seen_at,trusted_at,revoked_at',
        )
        .eq('user_id', userId)
        .order('last_seen_at', ascending: false);
    return response
        .map(
          (json) =>
              TrustedDevice.fromJson(json, currentFingerprint: fingerprint),
        )
        .toList(growable: false);
  }

  Future<void> revokeDevice(String deviceId) async {
    await _client
        .from('trusted_devices')
        .update({
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', deviceId);
    await logSecurityEvent(
      'session_revoked',
      metadata: {'device_id': deviceId},
    );
  }

  Future<void> revokeOtherDevices(String userId) async {
    await _client
        .from('trusted_devices')
        .update({
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .neq('device_fingerprint', await _currentDeviceFingerprint())
        .filter('revoked_at', 'is', null);
    await logSecurityEvent('session_revoked', metadata: {'scope': 'other'});
  }

  Future<String> _currentDeviceFingerprint() async {
    final existing = await _storage.read(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(_deviceKey, value);
    return value;
  }

  Future<List<DataExportRequest>> fetchExportHistory(String userId) async {
    final response = await _client
        .from('data_export_requests')
        .select('id,requested_at,completed_at,expires_at,status')
        .eq('user_id', userId)
        .order('requested_at', ascending: false);
    return response.map(DataExportRequest.fromJson).toList(growable: false);
  }

  Future<AccountDeletionRequest?> fetchAccountDeletion(String userId) async {
    final response = await _client
        .from('account_deletion_requests')
        .select('id,requested_at,scheduled_purge_at,cancelled_at,completed_at')
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return AccountDeletionRequest.fromJson(response);
  }

  Future<void> cancelAccountDeletion(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('account_deletion_requests')
        .update({'cancelled_at': now})
        .eq('user_id', userId)
        .filter('completed_at', 'is', null);
    await _client
        .from('profiles')
        .update({'deleted_at': null, 'updated_at': now})
        .eq('id', userId);
    await logSecurityEvent(
      'account_deletion_cancelled',
      metadata: {'cancelled': true},
    );
  }

  Future<List<LegalAcceptance>> fetchLegalHistory(String userId) async {
    final response = await _client
        .from('legal_acceptance_logs')
        .select('id,policy_type,policy_name,policy_version,accepted_at')
        .eq('user_id', userId)
        .order('accepted_at', ascending: false);
    return response.map(LegalAcceptance.fromJson).toList(growable: false);
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  String _deviceLabel() {
    final platform = _platformLabel();
    return platform == 'web'
        ? 'Web browser'
        : '${platform[0].toUpperCase()}${platform.substring(1)} device';
  }
}
