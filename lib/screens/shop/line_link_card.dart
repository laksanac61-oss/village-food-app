import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../widgets/common.dart';

/// Our LINE Official Account ID (with @), for the add-friend link. Empty until the OA is set up.
const lineOaId = '';

/// In shop settings: link the owner's LINE, so an order still not accepted after 3 minutes also comes as
/// a LINE message. The app shows a 6-digit code; the shop sends it to our LINE OA.
class LineLinkCard extends StatefulWidget {
  const LineLinkCard({super.key});

  @override
  State<LineLinkCard> createState() => _LineLinkCardState();
}

class _LineLinkCardState extends State<LineLinkCard> {
  late Future<bool> _linked = Api.lineLinked();
  String? _code;

  void _refresh() => setState(() {
    _linked = Api.lineLinked();
    _code = null;
  });

  Future<void> _getCode() async {
    String? code;
    if (await guard(context, () async => code = await Api.lineLinkCode())) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: FutureBuilder<bool>(
        future: _linked,
        builder: (context, snap) {
          final linked = snap.data ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.chat, color: linked ? Colors.green : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('แจ้งเตือนทาง LINE', style: Theme.of(context).textTheme.titleMedium)),
                  if (linked) const Chip(label: Text('ผูกแล้ว'), visualDensity: VisualDensity.compact),
                ],
              ),
              const SizedBox(height: 4),
              const Text('ถ้ามีออเดอร์ที่ยังไม่กดรับเกิน 3 นาที ระบบจะส่งข้อความ LINE เตือนอีกทาง'),
              const SizedBox(height: 8),
              if (snap.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (linked)
                TextButton(
                  onPressed: () async {
                    if (await guard(context, Api.lineUnlink, done: 'ยกเลิกการผูก LINE แล้ว')) _refresh();
                  },
                  child: const Text('ยกเลิกการผูก LINE'),
                )
              else if (_code == null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.link),
                  label: const Text('ผูก LINE'),
                  onPressed: _getCode,
                )
              else ...[
                Text(
                  lineOaId.isEmpty
                      ? '1. แอดเพื่อน LINE OA ส่งอาหารบ้านดุง'
                      : '1. แอดเพื่อน LINE OA ส่งอาหารบ้านดุง ($lineOaId)',
                ),
                if (lineOaId.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('แอดเพื่อน'),
                    onPressed: () => launchUrl(
                      Uri.parse('https://line.me/R/ti/p/$lineOaId'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                const Text('2. ส่งรหัสนี้ในแชต LINE OA (ใช้ได้ 30 นาที)'),
                Row(
                  children: [
                    SelectableText(
                      _code!,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                    IconButton(
                      tooltip: 'คัดลอกรหัส',
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('คัดลอกรหัสแล้ว')));
                      },
                    ),
                  ],
                ),
                const Text('3. LINE ตอบว่าผูกเรียบร้อยแล้ว กดปุ่มด้านล่าง'),
                TextButton(onPressed: _refresh, child: const Text('ตรวจสอบอีกครั้ง')),
              ],
            ],
          );
        },
      ),
    ),
  );
}
