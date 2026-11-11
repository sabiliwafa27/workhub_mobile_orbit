import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/whatsapp_colors.dart';
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
    ),
    InboxItemModel(
      id: 102,
      title: 'Penerimaan Logistic: PO-2026-0814 (Kedelai 10 Ton)',
      source: 'logistic_in',
      sourceLabel: 'Logistic In',
      status: 'assigned',
      createdAt: '09:15 AM',
      subtitle: 'Truk N 8920 UY tiba di loading bay 3.',
    ),
    InboxItemModel(
      id: 103,
      title: 'Persetujuan BBM Armada: Truk AG 8068 AO',
      source: 'fleet',
      sourceLabel: 'Fleet Approval',
      status: 'pending',
      createdAt: 'Yesterday',
      subtitle: 'Klaim struk Pertamina Rp 650.000.',
    ),
    InboxItemModel(
      id: 104,
      title: 'Revisi Sales Order: Toko Berkah Jaya (SO-08419)',
      source: 'sales_order',
      sourceLabel: 'Sales Order',
      status: 'pending_revision',
      createdAt: 'Yesterday',
      subtitle: 'Koreksi kuantiti kecap botol 135ml.',
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
      backgroundColor: WhatsAppColors.background,
      body: RefreshIndicator(
        color: WhatsAppColors.tealGreen,
        onRefresh: () async {
          await ref.read(inboxNotifierProvider.notifier).loadInbox();
        },
        child: Column(
          children: [
            // Source Filter Chips
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _sourceFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final source = _sourceFilters[index];
                  final isSelected = _selectedSource == source;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSource = source;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? WhatsAppColors.navIndicatorBg
                            : WhatsAppColors.chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? WhatsAppColors.tealGreen.withOpacity(0.3)
                              : WhatsAppColors.chipBorder,
                        ),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? WhatsAppColors.darkGreen
                              : WhatsAppColors.chipText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(color: WhatsAppColors.divider, height: 1),

            // Inbox List
            Expanded(
              child: ListView.separated(
                itemCount: filteredItems.length,
                separatorBuilder: (_, __) => const Divider(
                  color: WhatsAppColors.divider,
                  height: 1,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _buildInboxItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxItem(InboxItemModel item) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (item.source) {
      case 'guest_book':
        icon = Icons.badge_outlined;
        iconColor = Colors.orange.shade700;
        iconBg = Colors.orange.shade50;
        break;
      case 'logistic_in':
        icon = Icons.local_shipping_outlined;
        iconColor = Colors.blue.shade700;
        iconBg = Colors.blue.shade50;
        break;
      case 'fleet':
        icon = Icons.local_gas_station_outlined;
        iconColor = Colors.green.shade700;
        iconBg = Colors.green.shade50;
        break;
      case 'sales_order':
        icon = Icons.receipt_long_outlined;
        iconColor = Colors.purple.shade700;
        iconBg = Colors.purple.shade50;
        break;
      default:
        icon = Icons.task_alt_outlined;
        iconColor = WhatsAppColors.darkGreen;
        iconBg = WhatsAppColors.navIndicatorBg;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.sourceLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Text(
                      item.createdAt,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WhatsAppColors.timeText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: WhatsAppColors.titleText,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: WhatsAppColors.subtitleText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
