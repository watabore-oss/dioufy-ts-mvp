import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/services/ticket_service.dart';

void main() {
  test('ticket signature verification', () {
    final payload = {'foo': 'bar', 'num': 123};
    final sig = TicketService.signPayload(payload);
    expect(TicketService.verify(payload, sig), isTrue);
    // tamper
    expect(TicketService.verify({'foo': 'baz'}, sig), isFalse);
  });

  test('encode/decode ticket', () {
    final payload = {'x': 1};
    final encoded = TicketService.encodeTicket(payload);
    final decoded = TicketService.decodeTicket(encoded);
    expect(decoded['payload'], payload);
    expect(
        TicketService.verify(decoded['payload'], decoded['signature']), isTrue);
  });
}
