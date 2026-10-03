import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/video.dart';

/// In shop settings: add, watch, change or remove the shop's intro video.
class ShopVideoCard extends StatefulWidget {
  const ShopVideoCard({super.key, required this.shop, required this.onChanged});
  final Shop shop;
  final VoidCallback onChanged;

  @override
  State<ShopVideoCard> createState() => _ShopVideoCardState();
}

class _ShopVideoCardState extends State<ShopVideoCard> {
  late Future<int> _used = Api.videoChangesToday(widget.shop.id);
  String? _busy; // what is happening now, shown under a spinner

  Future<void> _upload() async {
    final messenger = ScaffoldMessenger.of(context);
    final PickedVideo? picked;
    setState(() => _busy = 'กำลังตรวจไฟล์...');
    try {
      picked = await pickVideo();
    } on FormatException catch (e) {
      setState(() => _busy = null);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (picked == null || !mounted) {
      setState(() => _busy = null);
      return;
    }
    setState(() => _busy = 'กำลังอัปโหลดวิดีโอ อย่าเพิ่งปิดหน้านี้...');
    final old = widget.shop.videoUrl;
    final ok = await guard(context, () async {
      final url = await Api.uploadVideo(picked!.bytes, picked.ext, picked.contentType);
      try {
        final left = await Api.setShopVideo(widget.shop.id, url);
        messenger.showSnackBar(SnackBar(content: Text('บันทึกวิดีโอแล้ว วันนี้เปลี่ยนได้อีก $left ครั้ง')));
      } catch (_) {
        await Api.deleteVideoFile(url); // over today's limit: do not keep the unused upload
        rethrow;
      }
    });
    if (ok && old != null) await Api.deleteVideoFile(old).catchError((_) {});
    if (!mounted) return;
    setState(() {
      _busy = null;
      _used = Api.videoChangesToday(widget.shop.id);
    });
    if (ok) widget.onChanged();
  }

  Future<void> _remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบวิดีโอแนะนำร้าน?'),
        content: const Text('ลูกค้าจะไม่เห็นวิดีโอนี้อีก การลบไม่นับเป็นการเปลี่ยนวิดีโอ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final old = widget.shop.videoUrl!;
    if (await guard(context, () => Api.setShopVideo(widget.shop.id, null), done: 'ลบวิดีโอแล้ว')) {
      await Api.deleteVideoFile(old).catchError((_) {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final limit = shop.videoChangesPerDay;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam),
                const SizedBox(width: 8),
                Text('วิดีโอแนะนำร้าน', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ยาวไม่เกิน ${Api.maxVideoSeconds} วินาที · ไฟล์ไม่เกิน 50 MB · เปลี่ยนได้วันละ $limit ครั้ง\n'
              'แนะนำถ่ายแนวตั้ง ความละเอียด 720p ให้เห็นอาหารและหน้าร้าน',
              style: theme.textTheme.bodySmall,
            ),
            FutureBuilder<int>(
              future: _used,
              builder: (context, snap) => snap.hasData
                  ? Text(
                      'วันนี้เปลี่ยนได้อีก ${(limit - snap.data!).clamp(0, limit)} ครั้ง',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            if (_busy != null)
              Row(
                children: [
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_busy!)),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (shop.videoUrl != null) WatchVideoButton(url: shop.videoUrl!, title: shop.name),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: Text(shop.videoUrl == null ? 'เพิ่มวิดีโอ' : 'เปลี่ยนวิดีโอ'),
                    onPressed: _upload,
                  ),
                  if (shop.videoUrl != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ลบ'),
                      onPressed: _remove,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
