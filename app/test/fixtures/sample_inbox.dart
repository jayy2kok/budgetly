import 'dart:convert';
import 'dart:io';

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

/// A real SMS captured from a physical device and persisted in
/// `test/fixtures/sample_inbox.json`.
///
/// See `test/fixtures/README.md` for provenance and regeneration steps.
class SampleInboxMessage {
  const SampleInboxMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.dateSent,
  });

  final int id;
  final String sender;
  final String body;
  final DateTime dateSent;

  factory SampleInboxMessage.fromJson(Map<String, dynamic> json) {
    return SampleInboxMessage(
      id: json['id'] as int,
      sender: json['sender'] as String,
      body: json['body'] as String,
      dateSent: DateTime.fromMillisecondsSinceEpoch(
        json['dateSent'] as int,
        isUtc: true,
      ),
    );
  }

  /// JSON map in the shape expected by [SmsMessage.fromJson].
  Map<String, dynamic> toSmsJson() => <String, dynamic>{
        '_id': id,
        'address': sender,
        'body': body,
        'date_sent': dateSent.millisecondsSinceEpoch,
      };

  /// Converts this fixture row into the plugin model used by
  /// `SmsInboxReader` / `SmsQuery`.
  SmsMessage toSmsMessage() => SmsMessage.fromJson(toSmsJson());
}

/// Parsed contents of `test/fixtures/sample_inbox.json`.
class SampleInbox {
  const SampleInbox({
    required this.description,
    required this.capturedAt,
    required this.device,
    required this.source,
    required this.messages,
  });

  final String description;
  final String capturedAt;
  final String device;
  final String source;
  final List<SampleInboxMessage> messages;

  /// Path relative to the Flutter package root (the working directory used by
  /// `flutter test`).
  static const String defaultPath = 'test/fixtures/sample_inbox.json';

  factory SampleInbox.fromJson(Map<String, dynamic> json) {
    final rawMessages =
        (json['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
    return SampleInbox(
      description: json['description'] as String? ?? '',
      capturedAt: json['capturedAt'] as String? ?? '',
      device: json['device'] as String? ?? '',
      source: json['source'] as String? ?? '',
      messages: rawMessages
          .map(SampleInboxMessage.fromJson)
          .toList(growable: false),
    );
  }

  /// Fixture rows as the `flutter_sms_inbox` model, ready to be stubbed into
  /// the SMS query channel.
  List<SmsMessage> toSmsMessages() =>
      messages.map((m) => m.toSmsMessage()).toList(growable: false);
}

/// Reads the checked-in real-inbox fixture.
///
/// [path] defaults to [SampleInbox.defaultPath]; pass an absolute path when
/// running tests from a different working directory.
SampleInbox loadSampleInbox({String path = SampleInbox.defaultPath}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Sample inbox fixture not found at ${file.absolute.path}. '
      'Run from the app/ package root or pass an explicit path.',
    );
  }
  return SampleInbox.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}
