import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/domain/attachment_filename.dart';

void main() {
  group('safeAttachmentFileName', () {
    test('an ordinary name comes through unchanged', () {
      expect(
        safeAttachmentFileName(
          'plan-week-3.pdf',
          fallbackId: 'att-1',
          mime: 'application/pdf',
        ),
        'plan-week-3.pdf',
      );
    });

    test('a Unix path traversal is reduced to its last segment', () {
      expect(
        safeAttachmentFileName(
          '../../etc/passwd',
          fallbackId: 'att-1',
          mime: 'application/octet-stream',
        ),
        'passwd',
      );
    });

    test('a Windows path traversal is reduced to its last segment', () {
      expect(
        safeAttachmentFileName(
          r'..\..\windows\system32\x.dll',
          fallbackId: 'att-1',
          mime: 'application/octet-stream',
        ),
        'x.dll',
      );
    });

    test('an absolute path is reduced to its last segment', () {
      expect(
        safeAttachmentFileName(
          '/absolute/path/report.pdf',
          fallbackId: 'att-1',
          mime: 'application/pdf',
        ),
        'report.pdf',
      );
    });

    test('a bare dot falls back', () {
      final result = safeAttachmentFileName(
        '.',
        fallbackId: 'att-1',
        mime: 'application/pdf',
      );
      expect(result, 'chat_doc_att-1.pdf');
    });

    test('a bare double-dot falls back', () {
      final result = safeAttachmentFileName(
        '..',
        fallbackId: 'att-1',
        mime: 'application/pdf',
      );
      expect(result, 'chat_doc_att-1.pdf');
    });

    test('an empty name falls back, using the id and the mime extension', () {
      expect(
        safeAttachmentFileName('', fallbackId: 'att-1', mime: 'application/pdf'),
        'chat_doc_att-1.pdf',
      );
    });

    test('a name that is only a Windows reserved device name falls back', () {
      expect(
        safeAttachmentFileName(
          'CON',
          fallbackId: 'att-1',
          mime: 'text/plain',
        ),
        'chat_doc_att-1.txt',
      );
    });

    test(
      'a reserved device name with an extension still falls back (case-insensitive)',
      () {
        expect(
          safeAttachmentFileName(
            'nul.txt',
            fallbackId: 'att-1',
            mime: 'text/plain',
          ),
          'chat_doc_att-1.txt',
        );
      },
    );

    test('trailing dots and spaces are stripped', () {
      expect(
        safeAttachmentFileName(
          'report.pdf. ',
          fallbackId: 'att-1',
          mime: 'application/pdf',
        ),
        'report.pdf',
      );
    });

    test('control characters are stripped', () {
      // Built with String.fromCharCode rather than a literal escape in the
      // source, so this file itself never has to carry a raw control byte.
      final nameWithControlChars =
          'evil${String.fromCharCode(0)}name${String.fromCharCode(0x1f)}.txt';
      expect(
        safeAttachmentFileName(
          nameWithControlChars,
          fallbackId: 'att-1',
          mime: 'text/plain',
        ),
        'evilname.txt',
      );
    });

    test('a very long name is truncated while keeping its extension', () {
      final longName = '${'a' * 300}.pdf';
      final result = safeAttachmentFileName(
        longName,
        fallbackId: 'att-1',
        mime: 'application/pdf',
      );
      expect(result.length, lessThanOrEqualTo(100));
      expect(result.endsWith('.pdf'), isTrue);
    });

    test('a traversal-shaped id in the fallback is sanitised too', () {
      final result = safeAttachmentFileName(
        '',
        fallbackId: '../../etc/passwd',
        mime: 'application/pdf',
      );
      // Every character the traversal needs (`.`, `/`) is stripped from the
      // fallback id — nothing here can walk back out of the directory this
      // is written under.
      expect(result, isNot(contains('/')));
      expect(result, isNot(contains('..')));
      expect(result, 'chat_doc_etcpasswd.pdf');
    });

    test('an unknown mime with no usable name falls back with no extension', () {
      final result = safeAttachmentFileName(
        '///',
        fallbackId: 'att-1',
        mime: 'application/octet-stream',
      );
      expect(result, 'chat_doc_att-1');
    });

    test('a table-mapped mime type yields its known extension', () {
      final result = safeAttachmentFileName(
        '',
        fallbackId: 'att-1',
        mime:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(result, 'chat_doc_att-1.docx');
    });

    test(
      'an unlisted vendor mime falls back to its stripped subtype as an extension',
      () {
        final result = safeAttachmentFileName(
          '',
          fallbackId: 'att-1',
          mime: 'application/vnd.something-custom+json',
        );
        expect(result, 'chat_doc_att-1.somethingcustom');
      },
    );
  });

  group('safeAttachmentIdSegment', () {
    test('an ordinary id passes through unchanged', () {
      expect(safeAttachmentIdSegment('att-1234-abcd'), 'att-1234-abcd');
    });

    test('a traversal-shaped id is stripped to its safe characters', () {
      expect(safeAttachmentIdSegment('../../etc/passwd'), 'etcpasswd');
    });

    test('an id with nothing safe in it falls back', () {
      expect(safeAttachmentIdSegment('///'), 'attachment');
    });

    test('a custom fallback is honoured', () {
      expect(safeAttachmentIdSegment('///', fallback: 'x'), 'x');
    });
  });
}
