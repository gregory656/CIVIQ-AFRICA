import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

const currentPolicyVersion = '2026-05-21';

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(ref.watch(supabaseClientProvider));
});

class LegalRepository {
  LegalRepository(this._client);

  final SupabaseClient _client;

  Future<void> recordSignupAcceptances(String userId) async {
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    final policies = ['privacy_policy', 'terms', 'community_guidelines'];
    try {
      await _client.from('legal_acceptance_logs').insert([
        for (final policy in policies) _acceptance(userId, policy, acceptedAt),
      ]);
    } on PostgrestException catch (error) {
      if (!error.message.contains('policy_type')) rethrow;
      await _client.from('legal_acceptance_logs').insert([
        for (final policy in policies)
          _legacyAcceptance(userId, policy, acceptedAt),
      ]);
    }
  }

  Map<String, dynamic> _acceptance(
    String userId,
    String policyType,
    String acceptedAt,
  ) {
    return {
      'user_id': userId,
      'policy_type': policyType,
      'policy_name': policyType,
      'policy_version': currentPolicyVersion,
      'accepted_at': acceptedAt,
    };
  }

  Map<String, dynamic> _legacyAcceptance(
    String userId,
    String policyType,
    String acceptedAt,
  ) {
    return {
      'user_id': userId,
      'policy_name': policyType,
      'policy_version': currentPolicyVersion,
      'accepted_at': acceptedAt,
    };
  }
}
