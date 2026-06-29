import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

const appTitle = 'السجل المالي الذكي';
const appVersion = 'V3';
const seed = Color(0xFF6D4C41);

class Entry {
  final String name;
  final double amount;
  final bool incoming;
  final String note;
  final DateTime date;
  const Entry(this.name, this.amount, this.incoming, this.note, this.date);
  String encode() => [name, amount.toString(), incoming ? '1' : '0', note, date.toIso8601String()].join('|||');
  static Entry decode(String raw) {
    final p = raw.split('|||');
    return Entry(
      p.isNotEmpty ? p[0] : 'اسم',
      p.length > 1 ? double.tryParse(p[1]) ?? 0 : 0,
      p.length > 2 ? p[2] == '1' : true,
      p.length > 3 ? p[3] : '',
      p.length > 4 ? DateTime.tryParse(p[4]) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: appTitle,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: seed), scaffoldBackgroundColor: const Color(0xFFF8F1EA), fontFamily: 'Arial'),
    home: const Directionality(textDirection: TextDirection.rtl, child: Home()),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  bool incoming = true;
  final name = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  final search = TextEditingController();
  List<Entry> rows = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final data = p.getStringList('ledger_v3') ?? [];
    setState(() => rows = data.map(Entry.decode).toList());
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('ledger_v3', rows.map((e) => e.encode()).toList());
  }

  double get totalIn => rows.where((e) => e.incoming).fold(0, (s, e) => s + e.amount);
  double get totalOut => rows.where((e) => !e.incoming).fold(0, (s, e) => s + e.amount);
  double get net => totalIn - totalOut;

  List<Entry> get visible {
    final q = search.text.trim();
    if (q.isEmpty) return rows;
    return rows.where((e) => e.name.contains(q) || e.note.contains(q)).toList();
  }

  void add() {
    final n = name.text.trim();
    final v = double.tryParse(amount.text.trim()) ?? 0;
    if (n.isEmpty || v <= 0) return;
    setState(() { rows.insert(0, Entry(n, v, incoming, note.text.trim(), DateTime.now())); name.clear(); amount.clear(); note.clear(); });
    save();
    SystemSound.play(SystemSoundType.click);
  }

  void removeEntry(Entry e) {
    final i = rows.indexOf(e);
    setState(() => rows.remove(e));
    save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم الحذف'), action: SnackBarAction(label: 'تراجع', onPressed: () { setState(() => rows.insert(i < 0 ? 0 : i, e)); save(); })));
  }

  void copyReport() {
    final text = StringBuffer()
      ..writeln('$appTitle $appVersion')
      ..writeln('الإجمالي الأول: ${totalIn.toStringAsFixed(2)}')
      ..writeln('الإجمالي الثاني: ${totalOut.toStringAsFixed(2)}')
      ..writeln('الصافي: ${net.toStringAsFixed(2)}')
      ..writeln('---');
    for (final e in rows) { text.writeln('${e.name} | ${e.incoming ? 'إضافة' : 'خصم'} | ${e.amount.toStringAsFixed(2)} | ${e.note}'); }
    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكشف')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [dashboard(), formPage(), report(), about()];
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: pages[tab])),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.add_rounded), label: 'إضافة'),
        NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'السجل'),
        NavigationDestination(icon: Icon(Icons.info_rounded), label: 'عن'),
      ]),
    );
  }

  Widget dashboard() => ListView(padding: const EdgeInsets.all(16), children: [hero(), const SizedBox(height: 12), Row(children: [Expanded(child: stat('إجمالي 1', totalIn, Icons.arrow_downward_rounded)), const SizedBox(width: 10), Expanded(child: stat('إجمالي 2', totalOut, Icons.arrow_upward_rounded))]), const SizedBox(height: 12), formCard(), const SizedBox(height: 12), header('آخر العمليات'), ...rows.take(4).map(tile)]);
  Widget formPage() => ListView(padding: const EdgeInsets.all(16), children: [header('إضافة عملية'), formCard()]);
  Widget report() => ListView(padding: const EdgeInsets.all(16), children: [header('السجل'), TextField(controller: search, onChanged: (_) => setState(() {}), decoration: input('بحث بالاسم أو الملاحظة', Icons.search_rounded)), const SizedBox(height: 12), FilledButton.icon(onPressed: copyReport, icon: const Icon(Icons.copy_all_rounded), label: const Text('نسخ كشف مختصر')), const SizedBox(height: 12), if (visible.isEmpty) card(const Center(child: Text('لا توجد عمليات'))), ...visible.map(tile)]);
  Widget about() => ListView(padding: const EdgeInsets.all(16), children: [header('عن التطبيق'), card(const Text('$appTitle V3\nواجهة أبسط، حفظ محلي، سجل قابل للبحث، نسخ كشف مختصر، وحذف مع تراجع.'))]);

  Widget hero() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4E342E), Color(0xFFA1887F)]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text(appTitle, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('الصافي: ${net.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text('${rows.length} عملية محفوظة', style: const TextStyle(color: Colors.white70))]));
  Widget formCard() => card(Column(children: [TextField(controller: name, decoration: input('الاسم', Icons.person_rounded)), const SizedBox(height: 8), TextField(controller: amount, keyboardType: TextInputType.number, decoration: input('المبلغ', Icons.payments_rounded)), const SizedBox(height: 8), TextField(controller: note, decoration: input('ملاحظة اختيارية', Icons.notes_rounded)), const SizedBox(height: 10), SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('إضافة 1')), ButtonSegment(value: false, label: Text('إضافة 2'))], selected: {incoming}, onSelectionChanged: (s) => setState(() => incoming = s.first)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: add, icon: const Icon(Icons.save_rounded), label: const Text('حفظ العملية')))]));
  Widget tile(Entry r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: card(ListTile(leading: CircleAvatar(child: Icon(r.incoming ? Icons.add_rounded : Icons.remove_rounded)), title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${r.incoming ? 'إضافة 1' : 'إضافة 2'} • ${r.note.isEmpty ? _date(r.date) : r.note}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(r.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900)), IconButton(onPressed: () => removeEntry(r), icon: const Icon(Icons.delete_outline_rounded))]))));
  Widget stat(String t, double v, IconData icon) => card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: seed), const SizedBox(height: 8), Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(t)]));
  Widget header(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)));
  InputDecoration input(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none));
  Widget card(Widget child) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 8))]), child: child);
  String _date(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
