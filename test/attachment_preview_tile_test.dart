import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/widgets/attachment_preview_tile.dart';

void main() {
  testWidgets('AttachmentPreviewTile shows image badge and opens dialog on tap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentPreviewTile(
            fileName: 'sample_photo.jpg',
            url: 'https://example.com/sample_photo.jpg',
            size: 2048576,
          ),
        ),
      ),
    );

    expect(find.text('sample_photo.jpg'), findsOneWidget);
    expect(find.text('IMAGE'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);

    // Tap the attachment tile
    await tester.tap(find.byType(AttachmentPreviewTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog should open
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    // Tap close button
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog should be dismissed
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('AttachmentPreviewTile shows document icon and size for non-image',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentPreviewTile(
            fileName: 'contract_document.pdf',
            url: 'https://example.com/contract_document.pdf',
            size: 512000,
          ),
        ),
      ),
    );

    expect(find.text('contract_document.pdf'), findsOneWidget);
    expect(find.text('500.0 KB'), findsOneWidget);
    expect(find.text('IMAGE'), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });
}
