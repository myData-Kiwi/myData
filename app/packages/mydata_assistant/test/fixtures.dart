import 'package:mydata_client/api.dart';
import 'package:mydata_core/mydata_core.dart' show expectedHostApiVersion;

const longBody =
    'Hi Rishita,\n\n'
    'Your dentist appointment is on Friday 20 March at 09:30 at Smile Dental, 14 Harbour Road.\n'
    'Please bring your insurance card and arrive ten minutes early to fill in the form.\n\n'
    'If that time does not suit you, call them before Thursday noon and they will move it.\n\n'
    'See you soon,\nTirth\n'
    'P.S. This line is here only to make the body long enough that any truncation would show.';

Map<String, dynamic> approvalJson({String status = 'pending', String? decidedBy, Object? result, String? error}) => {
  'id': 'ap_1',
  'tool': 'send_mail',
  'args': {'to': 'rishita@example.com', 'subject': 'Dentist on Friday', 'body': longBody},
  'summary': 'Send an email to rishita@example.com: Dentist on Friday',
  'caller': 'assistant',
  'context': {'conversation_id': 'c1'},
  'created_at': '2026-03-18T10:00:00+00:00',
  'decided_at': decidedBy == null ? null : '2026-03-18T10:01:00+00:00',
  'decided_by': decidedBy,
  'error': error,
  'result': result,
  'status': status,
};

ApprovalOut approval({String status = 'pending', String? decidedBy, Object? result, String? error}) =>
    ApprovalOut.fromJson(approvalJson(status: status, decidedBy: decidedBy, result: result, error: error))!;

/// The host's status with its conversation [epoch], in real mode or demo mode.
StatusOut hostAt({required int epoch, bool real = false}) => StatusOut.fromJson({
  'version': '0.1.0',
  'api_version': expectedHostApiVersion,
  'ready': true,
  'assistant_enabled': true,
  'uptime_seconds': 1.0,
  'memory': {'host_bytes': 1000},
  'agents_connected': 0,
  'today': real ? '2026-10-13' : '2026-03-18',
  'demo_date': !real,
  'theme': 'kiwi',
  'mode': real ? 'real' : 'demo',
  'conversation_epoch': epoch,
  'model': {
    'name': 'qwen3:14b',
    'state': 'ready',
    'loaded': true,
    'ollama_reachable': true,
    'ollama_started_by_host': false,
  },
})!;
