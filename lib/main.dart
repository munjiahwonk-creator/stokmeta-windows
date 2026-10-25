import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'processor.dart';

void main() => runApp(const StokMetaApp());

class StokMetaApp extends StatelessWidget {
  const StokMetaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stok Meta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF14B8A6),
          brightness: Brightness.dark,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final s = Settings();
  final keysC = TextEditingController();
  final modelC = TextEditingController();
  final baseC = TextEditingController();
  final scroll = ScrollController();
  final logs = <String>[];
  Processor? proc;
  bool loading = true;
  bool running = false;
  bool busy = false;
  int ok = 0, fail = 0, total = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await s.load();
    _fill();
    if (mounted) setState(() => loading = false);
  }

  void _fill() {
    keysC.text = s.keys;
    modelC.text = s.model;
    baseC.text = s.customBase;
  }

  void _pull() {
    s.keys = keysC.text;
    s.model = modelC.text.trim();
    s.customBase = baseC.text.trim();
  }

  Future<void> _persist() async {
    _pull();
    await s.save();
  }

  void _log(String t) {
    if (!mounted) return;
    setState(() {
      logs.add(t);
      if (logs.length > 3000) logs.removeRange(0, 1000);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> _changeProvider(String v) async {
    await _persist();
    s.provider = v;
    await s.loadProviderFields();
    _fill();
    if (mounted) setState(() {});
  }

  Future<void> _refreshModels() async {
    _pull();
    final keys = s.keyList;
    if (keys.isEmpty && s.provider != 'openrouter') {
      _log('✖ Isi API key dulu.');
      return;
    }
    setState(() => busy = true);
    try {
      final l = await fetchModels(s.provider, keys.isEmpty ? '' : keys.first);
      if (l.isEmpty) {
        _log('Tidak ada model yang cocok ditemukan.');
      } else {
        await s.saveModels(s.provider, l);
        _log('✔ ${l.length} model dimuat (hanya yang bisa membaca gambar).');
      }
    } catch (e) {
      _log('✖ Gagal memuat model: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _checkKeys() async {
    await _persist();
    setState(() => busy = true);
    try {
      await Processor(s, _log, (a, b, c) {}).checkKeys();
    } catch (e) {
      _log('✖ $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pickDir(bool input) async {
    final d = await FilePicker.platform.getDirectoryPath(
      dialogTitle: input ? 'Pilih folder SUMBER (foto/video asli)' : 'Pilih folder TUJUAN (hasil)',
    );
    if (d == null) return;
    setState(() {
      if (input) {
        s.inputDir = d;
      } else {
        s.outputDir = d;
      }
    });
    await _persist();
  }

  Future<void> _start() async {
    await _persist();
    if (s.inputDir.isEmpty || s.outputDir.isEmpty) {
      _log('✖ Pilih folder sumber dan folder tujuan dulu.');
      return;
    }
    if (p.equals(s.inputDir, s.outputDir)) {
      _log('✖ Folder sumber dan tujuan tidak boleh sama.');
      return;
    }
    final n = Processor.scanFolder(s.inputDir).length;
    if (n == 0) {
      _log('✖ Tidak ada foto/video di folder sumber.');
      return;
    }
    if (s.move) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Pindahkan file?'),
          content: Text(
            '$n file akan DIPINDAHKAN dari folder sumber ke folder tujuan, lalu metadata ditanam. '
            'Setelah itu tinggal satu salinan di folder tujuan.\n\nLanjutkan?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (yes != true) return;
    }
    setState(() {
      running = true;
      ok = 0;
      fail = 0;
      total = n;
      logs.clear();
    });
    proc = Processor(s, _log, (o, f, t) {
      if (mounted) {
        setState(() {
          ok = o;
          fail = f;
          total = t;
        });
      }
    });
    try {
      await proc!.run();
    } catch (e) {
      _log('✖ Error: $e');
    }
    if (mounted) setState(() => running = false);
  }

  void _stop() {
    proc?.stop();
    _log('Menghentikan setelah file ini selesai…');
  }

  // ------------------------------------------------------------ widget bantu

  T _pick<T>(List<T> l, T v) => l.contains(v) ? v : l.first;

  Widget _card(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _dd<T>(String label, T value, List<T> opts, String Function(T) text, void Function(T) on,
          {bool save = true}) =>
      DropdownButtonFormField<T>(
        value: _pick(opts, value),
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: [for (final o in opts) DropdownMenuItem<T>(value: o, child: Text(text(o)))],
        onChanged: (v) {
          if (v == null) return;
          setState(() => on(v));
          if (save) _persist();
        },
      );

  Widget _dirRow(String label, String path, bool input) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: running ? null : () => _pickDir(input),
              icon: const Icon(Icons.folder_open),
              label: Text(label),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                path.isEmpty ? 'Belum dipilih' : path,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ],
        ),
      );

  Widget _sw(String t, bool v, void Function(bool) on) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t),
        value: v,
        onChanged: running
            ? null
            : (x) {
                setState(() => on(x));
                _persist();
              },
      );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final info = providerOf(s.provider);
    final models = s.modelsFor(s.provider);
    final done = ok + fail;

    final left = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stok Meta', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Judul, keyword, dan kategori otomatis untuk Adobe Stock.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 14),
          _card('1. AI dan API key', [
            _dd<String>('Penyedia', s.provider, [for (final x in providers) x.id], (id) => providerOf(id).label,
                (v) => _changeProvider(v), save: false),
            const SizedBox(height: 10),
            TextField(
              controller: modelC,
              decoration: InputDecoration(
                labelText: 'Model (harus bisa membaca gambar)',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Pilih dari daftar',
                  enabled: models.isNotEmpty,
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (v) {
                    setState(() => modelC.text = v);
                    _persist();
                  },
                  itemBuilder: (_) => [
                    for (final m in models)
                      PopupMenuItem<String>(
                        value: m.id,
                        child: Text(m.note.isEmpty ? m.id : '${m.id}  —  ${m.note}'),
                      ),
                  ],
                ),
              ),
              onChanged: (_) => _persist(),
            ),
            if (s.provider == 'custom') ...[
              const SizedBox(height: 10),
              TextField(
                controller: baseC,
                decoration: const InputDecoration(
                  labelText: 'Alamat API (gaya OpenAI)',
                  hintText: 'https://api.contoh.com/v1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _persist(),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: keysC,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'API key (satu per baris, dipakai bergantian)',
                helperText: 'Ambil key di: ${info.keyHelp}',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _persist(),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: (busy || running) ? null : _refreshModels,
                icon: const Icon(Icons.refresh),
                label: const Text('Perbarui daftar model'),
              ),
              OutlinedButton.icon(
                onPressed: (busy || running) ? null : _checkKeys,
                icon: const Icon(Icons.vpn_key),
                label: const Text('Cek API key'),
              ),
            ]),
          ]),
          _card('2. Folder', [
            _dirRow('Folder sumber', s.inputDir, true),
            _dirRow('Folder tujuan', s.outputDir, false),
            _sw('Pindahkan file (bukan salin), tinggal satu di tujuan', s.move, (v) => s.move = v),
          ]),
          _card('3. Pengaturan', [
            _dd<int>('Ganti API key setiap … file', s.rotateEvery, const [1, 2, 3, 5], (v) => '$v file',
                (v) => s.rotateEvery = v),
            const SizedBox(height: 10),
            _dd<String>('Gaya judul', s.style, const ['Deskriptif', 'Singkat', 'SEO'], (v) => v,
                (v) => s.style = v),
            const SizedBox(height: 10),
            _dd<String>('Bahasa', s.language, const ['English', 'Indonesia'], (v) => v, (v) => s.language = v),
            const SizedBox(height: 10),
            _dd<int>('Jeda antar file', s.delaySec, const [0, 1, 3, 5, 7, 10, 15], (v) => '$v detik',
                (v) => s.delaySec = v),
            const SizedBox(height: 6),
            Text('Jumlah keyword: ${s.keywordCount}'),
            Slider(
              min: 10,
              max: 49,
              divisions: 39,
              value: s.keywordCount.clamp(10, 49).toDouble(),
              label: '${s.keywordCount}',
              onChanged: running ? null : (v) => setState(() => s.keywordCount = v.round()),
              onChangeEnd: (_) => _persist(),
            ),
            _sw('Ganti nama file sesuai judul', s.rename, (v) => s.rename = v),
            _sw('Tanam metadata ke JPG dan MP4', s.embed, (v) => s.embed = v),
            _sw('Buat metadata_adobe_stock.csv', s.csv, (v) => s.csv = v),
            _sw('Coba ulang bila error', s.retry, (v) => s.retry = v),
          ]),
          const SizedBox(height: 4),
          if (!running)
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: busy ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('MULAI PROSES', style: TextStyle(fontSize: 17)),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('STOP', style: TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );

    final right = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            total == 0 ? 'Belum berjalan' : 'Selesai $done dari $total  •  berhasil $ok  •  gagal $fail',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 10),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: logs.isEmpty
                  ? const Center(child: Text('Log proses akan tampil di sini.'))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => SelectableText(
                        logs[i],
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5, height: 1.4),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 900
            ? Row(children: [SizedBox(width: 470, child: left), Expanded(child: right)])
            : Column(children: [Expanded(flex: 3, child: left), Expanded(flex: 2, child: right)]),
      ),
    );
  }
}
