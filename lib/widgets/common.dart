import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Runs [action], showing any error as a snackbar. Returns true on success.
Future<bool> guard(BuildContext context, Future<void> Function() action, {String? done}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: ${_clean(e)}')));
    return false;
  }
}

String _clean(Object e) {
  final s = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  return m?.group(1) ?? s;
}

Future<Uint8List?> pickPhoto() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
  return f?.readAsBytes();
}

/// Loads [load] and rebuilds with the result; pull to refresh.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.reloadOn});

  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  final Stream<void>? reloadOn;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  void initState() {
    super.initState();
    widget.reloadOn?.listen((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('โหลดข้อมูลไม่สำเร็จ\n${snap.error}', textAlign: TextAlign.center),
              TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
            ],
          ),
        );
      }
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: widget.builder(context, snap.data as T, _reload),
      );
    },
  );
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 120),
      Center(
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      ),
    ],
  );
}
