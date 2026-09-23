import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Maira adapter — port of neuroface-sense/utils/maira.js
/// Endpoints used (verified): POST /v1/maira/ask , POST /v1/maira/vision
/// Auth: headers project-key / api-key / Authorization: Bearer ...
/// Never hardcode secrets: settings injected at runtime, persisted locally.
class MairaSettings {
  String baseUrl;
  String userId;
  String projectKey;
  String apiKey;
  String bearer;
  String gptProfileId;
  MairaSettings({
    this.baseUrl = 'https://api.recommender.gigalogy.com',
    this.userId = '',
    this.projectKey = '',
    this.apiKey = '',
    this.bearer = '',
    this.gptProfileId = '',
  });

  bool get configured => userId.isNotEmpty && (bearer.isNotEmpty || apiKey.isNotEmpty);

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl, 'userId': userId, 'projectKey': projectKey,
        'apiKey': apiKey, 'bearer': bearer, 'gptProfileId': gptProfileId,
      };
  static MairaSettings fromJson(Map<String, dynamic> j) => MairaSettings(
        baseUrl: '${j['baseUrl'] ?? 'https://api.recommender.gigalogy.com'}',
        userId: '${j['userId'] ?? ''}',
        projectKey: '${j['projectKey'] ?? ''}',
        apiKey: '${j['apiKey'] ?? ''}',
        bearer: '${j['bearer'] ?? ''}',
        gptProfileId: '${j['gptProfileId'] ?? ''}',
      );
}

class MairaResult {
  final bool ok;
  final String answer;
  final Map<String, dynamic>? parsed;
  final String? error;
  MairaResult({required this.ok, this.answer = '', this.parsed, this.error});
}

class MairaService {
  MairaSettings settings;
  bool _online = true;
  MairaService(this.settings);

  bool get isOnline => _online;
  void setOnline(bool v) => _online = v;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (settings.bearer.isNotEmpty) h['Authorization'] = 'Bearer ${settings.bearer}';
    if (settings.projectKey.isNotEmpty) h['project-key'] = settings.projectKey;
    if (settings.apiKey.isNotEmpty) h['api-key'] = settings.apiKey;
    return h;
  }

  /// Structured reasoning contract: requests JSON-only response.
  Future<MairaResult> reason({
    required String assessmentContext,
    required Map<String, dynamic> perception,
    required List<Map<String, dynamic>> memory,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_online) return MairaResult(ok: false, error: 'offline');
    if (!settings.configured) {
      return MairaResult(ok: false, error: 'Maira not configured');
    }
    final query = _buildReasonQuery(
        assessmentContext: assessmentContext,
        perception: perception,
        memory: memory);
    return ask(query: query, timeout: timeout);
  }

  String _buildReasonQuery({
    required String assessmentContext,
    required Map<String, dynamic> perception,
    required List<Map<String, dynamic>> memory,
  }) {
    return [
      'You are Asha, a calm assistive companion for a non-speaking patient.',
      'RULES: never diagnose; describe observations only. Keep speech SHORT (1-2 sentences).',
      'Respond with JSON ONLY, exactly: {"assessment": string, "confidence": number, "response": string, "next_action": {"tool": string, "response_options": [{"intent": string, "gesture": string}]}}',
      'CONTEXT: $assessmentContext',
      'PERCEPTION: ${jsonEncode(perception)}',
      'MEMORY: ${jsonEncode(memory)}',
    ].join('\n');
  }

  Future<MairaResult> ask({required String query, Duration timeout = const Duration(seconds: 30)}) async {
    if (!_online) return MairaResult(ok: false, error: 'offline');
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final uri = Uri.parse('${settings.baseUrl}/v1/maira/ask');
      final req = await client.postUrl(uri).timeout(timeout);
      _headers().forEach(req.headers.set);
      final body = {
        'user_id': settings.userId,
        'query': query,
        'conversation_type': 'question',
        'top_k': 5,
        'is_keyword_enabled': false,
        'language': 'en',
        if (settings.gptProfileId.isNotEmpty) 'gpt_profile_id': settings.gptProfileId,
        'conversation_metadata': {'source': 'neurobridge-asha', 'kind': 'asha-reasoning'},
      };
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(timeout);
      final text = await resp.transform(utf8.decoder).join().timeout(timeout);
      client.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return MairaResult(ok: false, error: 'Maira ${resp.statusCode}: ${text.substring(0, text.length.clamp(0, 300))}');
      }
      final payload = jsonDecode(text);
      final answer = extractAnswer(payload);
      return MairaResult(ok: true, answer: answer, parsed: tryParseJson(answer));
    } on TimeoutException {
      return MairaResult(ok: false, error: 'Maira request timed out');
    } catch (e) {
      return MairaResult(ok: false, error: e.toString());
    }
  }

  Future<MairaResult> chat(String message) => ask(query: message);

  /// Extract answer from {detail: {...}} envelope (mirrors maira.js).
  static String extractAnswer(dynamic payload) {
    if (payload == null) return '';
    dynamic detail = payload is Map && payload.containsKey('detail') ? payload['detail'] : payload;
    if (detail is String) return detail;
    if (detail is Map) {
      for (final k in ['answer', 'response', 'result', 'text', 'message', 'output', 'content', 'summary']) {
        if (detail[k] is String && (detail[k] as String).isNotEmpty) return detail[k];
      }
      try {
        return jsonEncode(detail);
      } catch (_) {
        return '$detail';
      }
    }
    return '$payload';
  }

  static Map<String, dynamic>? tryParseJson(String text) {
    var candidate = text.trim().replaceAll(RegExp(r'^```(?:json)?', caseSensitive: false), '').replaceAll(RegExp(r'```$'), '').trim();
    try {
      final parsed = jsonDecode(candidate);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      final start = candidate.indexOf('{');
      final end = candidate.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final inner = jsonDecode(candidate.substring(start, end + 1));
          if (inner is Map<String, dynamic>) return inner;
        } catch (_) {}
      }
      return null;
    }
  }

  Future<MairaResult> testConnection() => ask(query: 'Reply with exactly: maira-link-ok');
}
