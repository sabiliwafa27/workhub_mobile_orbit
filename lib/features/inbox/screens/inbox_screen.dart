import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../models/inbox_item_model.dart';
import '../providers/inbox_provider.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _selectedSource = 'All';

  final List<String> _sourceFilters = [
    'All',
    'Guest Book',
    'Logistic In',
    'Fleet Approval',
    'Sales Order',
    'Tasks',
  ];

  final List<InboxItemModel> _fallbackItems = [
    InboxItemModel(
      id: 101,
      title: 'Tamu Dinas: Bapak Wahyu (Dinas Pertanian)',
      source: 'guest_book',
      sourceLabel: 'Guest Book',
      status: 'pending_approval',
      createdAt: '10:45 AM',
      subtitle: 'Menunggu verifikasi security di pos gerbang utama.',
      moduleCode: 'guest_book',
      subjectKey: '101',
    ),
    InboxItemModel(
      id: 102,
      title: 'Penerimaan Logistic: PO-2026-0814 (Kedelai 10 Ton)',
      source: 'logistic_in',
      sourceLabel: 'Logistic In',
      status: 'assigned',
      createdAt: '09:15 AM',
      subtitle: 'Truk N 8920 UY tiba di loading bay 3.',
      moduleCode: 'logistic_in',
      subjectKey: '102',
    ),
    InboxItemModel(
      id: 103,
      title: 'Persetujuan BBM Armada: Truk AG 8068 AO',
      source: 'fleet',
      sourceLabel: 'Fleet Approval',
      status: 'pending',
      createdAt: 'Yesterday',
      subtitle: 'Klaim struk Pertamina Rp 650.000.',
      moduleCode: 'fleet',
      subjectKey: '103',
    ),
    InboxItemModel(
      id: 104,
      title: 'Revisi Sales Order: Toko Berkah Jaya (SO-08419)',
      source: 'sales_order',
      sourceLabel: 'Sales Order',
      status: 'pending_revision',
      createdAt: 'Yesterday',
      subtitle: 'Koreksi kuantiti kecap botol 135ml.',
      moduleCode: 'sales_order',
      subjectKey: '104',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(inboxNotifierProvider);
    final rawItems = inboxState.items.isNotEmpty ? inboxState.items : _fallbackItems;

    final filteredItems = _selectedSource == 'All'
        ? rawItems
        : rawItems.where((item) => item.sourceLabel.toLowerCase() == _selectedSource.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Unified Inbox',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OrbitColors.textNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: OrbitColors.textNavy),
            onPressed: () {
              ref.read(inboxNotifierProvider.notifier).loadInbox();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: OrbitColors.primaryNavy,
        onRefresh: () async {
          await ref.read(inboxNotifierProvider.notifier).loadInbox();
        },
        child: Column(
          children: [
            // Filter Pills
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _sourceFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final source = _sourceFilters[index];
                  final isSelected = _selectedSource == source;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSource = source),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? OrbitColors.pillDark : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? OrbitColors.pillDark : OrbitColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : OrbitColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Items List
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inbox_outlined, size: 48, color: OrbitColors.textMuted),
                          SizedBox(height: 12),
                          Text('No pending items in inbox', style: TextStyle(color: OrbitColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildInboxCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxCard(InboxItemModel item) {
    Color tagBg = OrbitColors.bubbleBlue;
    Color tagColor = OrbitColors.primaryNavy;

    if (item.source.contains('guest')) {
      tagBg = const Color(0xFFFEF3C7);
      tagColor = const Color(0xFFB45309);
    } else if (item.source.contains('logistic')) {
      tagBg = const Color(0xFFDCFCE7);
      tagColor = const Color(0xFF15803D);
    } else if (item.source.contains('fleet')) {
      tagBg = OrbitColors.coralIconBg;
      tagColor = OrbitColors.coralIcon;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.sourceLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tagColor,
                  ),
                ),
              ),
              Text(
                item.createdAt,
                style: const TextStyle(fontSize: 11, color: OrbitColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OrbitColors.textNavy,
            ),
          ),
          if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: OrbitColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(inboxNotifierProvider.notifier).completeItem(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item marked as completed.'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OrbitColors.kpiGreen,
                  side: const BorderSide(color: OrbitColors.kpiGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
