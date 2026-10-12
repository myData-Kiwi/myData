import 'package:mydata_client/api.dart';

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
