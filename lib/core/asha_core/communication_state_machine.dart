/// Communication dialogue state machine (§11).
/// IDLE → OBSERVING → PROMPTING → AWAITING_RESPONSE → CANDIDATE_DETECTED
/// → VERIFYING → CONFIRMED → EXECUTING_ACTION → ACTION_VERIFIED → RETURN_TO_IDLE
enum CommState {
  idle,
  observing,
  prompting,
  awaitingResponse,
  candidateDetected,
  verifying,
  confirmed,
  executingAction,
  actionVerified,
  returnToIdle,
}

class ResponseOption {
  final String intent;
  final String gesture; // e.g. triple_blink | smile
  ResponseOption(this.intent, this.gesture);
}

class CommSession {
  CommState state = CommState.idle;
  String question = '';
  List<ResponseOption> expected = [];
  String? candidateGesture;
  double candidateConfidence = 0;
  DateTime? promptAt;
  Duration timeout = const Duration(seconds: 20);
  int retryCount = 0;
  String? confirmedIntent;
  String? tool;
  Map<String, dynamic> toolArgs = {};

  bool get expired {
    if (promptAt == null) return false;
    return DateTime.now().difference(promptAt!) > timeout;
  }
}

class CommunicationStateMachine {
  final CommSession session = CommSession();
  final List<String> trace = [];

  void _move(CommState next, [String note = '']) {
    trace.add('${session.state.name} -> ${next.name} $note');
    if (trace.length > 200) trace.removeAt(0);
    session.state = next;
  }

  void observe() => _move(CommState.observing);
  void prompt(String question, List<ResponseOption> options, {Duration? timeout}) {
    session.question = question;
    session.expected = options;
    session.promptAt = DateTime.now();
    if (timeout != null) session.timeout = timeout;
    session.retryCount = 0;
    _move(CommState.prompting, question);
    _move(CommState.awaitingResponse);
  }

  void candidate(String gesture, double confidence) {
    session.candidateGesture = gesture;
    session.candidateConfidence = confidence;
    _move(CommState.candidateDetected, '$gesture ${confidence.toStringAsFixed(2)}');
    _move(CommState.verifying);
  }

  void confirm(String intent, {String? tool, Map<String, dynamic>? args}) {
    session.confirmedIntent = intent;
    session.tool = tool;
    session.toolArgs = args ?? {};
    _move(CommState.confirmed, intent);
  }

  void executing() => _move(CommState.executingAction);
  void actionVerified() {
    _move(CommState.actionVerified);
    _move(CommState.returnToIdle);
    _move(CommState.idle);
  }

  void reset([String reason = '']) {
    session.candidateGesture = null;
    session.confirmedIntent = null;
    _move(CommState.idle, reason);
  }
}
