import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/whatsapp_colors.dart';
import '../models/inbox_item_model.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _selectedSource = 'All';

  final List<InboxItemModel> _inboxItems = [
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
    InboxItemModel(
      id: 105,
      title: 'Interview Calon Staff Logistik: Ahmad Firdaus',
      source: 'guest_book',
      sourceLabel: 'Guest Book',
      status: 'operator_accepted',
      createdAt: '2 days ago',
      subtitle: 'Ruang Meeting 2.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedSource == 'All'
        ? _inboxItems
        : _inboxItems.where((i) => i.source == _selectedSource || i.sourceLabel == _selectedSource).toList();

    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: Column(
        children: [
          // Source filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                _buildSourceChip('All'),
                const SizedBox(width: 8),
                _buildSourceChip('Guest Book', sourceKey: 'guest_book'),
                const SizedBox(width: 8),
                _buildSourceChip('Logistic In', sourceKey: 'logistic_in'),
                const SizedBox(width: 8),
                _buildSourceChip('Fleet Approval', sourceKey: 'fleet'),
                const SizedBox(width: 8),
                _buildSourceChip('Sales Order', sourceKey: 'sales_order'),
              ],
            ),
          ),
          const Divider(height: 1, color: WhatsAppColors.searchBarBg),

          // Inbox Items
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No items in this category',
                      style: TextStyle(color: WhatsAppColors.subtitleText),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 68, color: WhatsAppColors.searchBarBg),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildInboxRow(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String label, {String? sourceKey}) {
    final key = sourceKey ?? label;
    final isSelected = _selectedSource == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7FCE3) : WhatsAppColors.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? WhatsAppColors.primaryGreen : WhatsAppColors.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? WhatsAppColors.darkGreen : WhatsAppColors.chipText,
          ),
        ),
      ),
    );
  }

  Widget _buildInboxRow(InboxItemModel item) {
    IconData icon;
    Color iconColor;
    switch (item.source) {
      case 'guest_book':
        icon = Icons.badge_rounded;
        iconColor = Colors.teal;
        break;
      case 'logistic_in':
        icon = Icons.local_shipping_rounded;
        iconColor = Colors.blue;
        break;
      case 'fleet':
        icon = Icons.local_gas_station_rounded;
        iconColor = Colors.orange;
        break;
      case 'sales_order':
        icon = Icons.receipt_long_rounded;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.assignment_rounded;
        iconColor = Colors.grey;
    }

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.sourceLabel.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      Text(
                        item.createdAt,
                        style: const TextStyle(fontSize: 11, color: WhatsAppColors.timeText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
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
                      style: const TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
