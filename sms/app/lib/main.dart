import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';

const ink = Color(0xFF4F46E5);
const bg = Color(0xFFF6F7FB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (_) {}
  await Api.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) {
    final t = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: ink), scaffoldBackgroundColor: bg);
    return MaterialApp(
      debugShowCheckedModeBanner: false, title: 'EduTrack',
      theme: t.copyWith(
        textTheme: GoogleFonts.interTextTheme(t.textTheme),
        appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: ink.withOpacity(.12)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      ),
      home: Api.token == null ? const Auth() : const Home(),
    );
  }
}

// ---------- shared widgets ----------
Widget card(Widget child, {EdgeInsets p = const EdgeInsets.all(16), VoidCallback? onTap}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: ink.withOpacity(.07), blurRadius: 16, offset: const Offset(0, 6))]),
    child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: p, child: child))));

Color riskColor(String r) => r == 'High' ? const Color(0xFFEF4444) : r == 'Medium' ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
Widget chip(String r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: riskColor(r).withOpacity(.12), borderRadius: BorderRadius.circular(20)),
    child: Text('$r risk', style: TextStyle(color: riskColor(r), fontSize: 12, fontWeight: FontWeight.w600)));
Widget avatar(Map s, [double r = 24]) {
  final u = (s['photo_url'] ?? '').toString();
  return CircleAvatar(radius: r, backgroundColor: ink.withOpacity(.1), backgroundImage: u.isEmpty ? null : NetworkImage(u),
      child: u.isEmpty ? Text('${s['name']}'[0], style: TextStyle(color: ink, fontWeight: FontWeight.bold, fontSize: r * .8)) : null);
}
Widget title(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 10), child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)));

Future guard(BuildContext c, Future Function() f) async {
  try { return await f(); } catch (e) {
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    return null;
  }
}

class Fetch extends StatefulWidget {
  final String path; final Widget Function(dynamic, VoidCallback) b;
  const Fetch(this.path, this.b, {super.key});
  @override State<Fetch> createState() => _FetchS();
}
class _FetchS extends State<Fetch> {
  late Future f = Api.call('GET', widget.path);
  void load() => setState(() => f = Api.call('GET', widget.path));
  @override void didUpdateWidget(Fetch o) { super.didUpdateWidget(o); if (o.path != widget.path) load(); }
  @override
  Widget build(BuildContext c) => FutureBuilder(future: f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) {
          final unauth = Api.token == null;
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey), const SizedBox(height: 12), Text('${s.error}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            unauth ? FilledButton(onPressed: () => Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Auth()), (_) => false), child: const Text('Sign in again'))
                   : OutlinedButton(onPressed: load, child: const Text('Retry'))])));
        }
        return widget.b(s.data, load);
      });
}

Future<List<String>?> ask(BuildContext c, String t, List<String> l) async {
  final cs = [for (final _ in l) TextEditingController()];
  final ok = await showDialog<bool>(context: c, builder: (_) => AlertDialog(
      title: Text(t),
      content: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < l.length; i++) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: cs[i], decoration: InputDecoration(labelText: l[i])))]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Save'))]));
  return ok == true ? [for (final x in cs) x.text.trim()] : null;
}

// ---------- auth ----------
class Auth extends StatefulWidget { const Auth({super.key}); @override State<Auth> createState() => _AuthS(); }
class _AuthS extends State<Auth> {
  final n = TextEditingController(), e = TextEditingController(), p = TextEditingController();
  bool reg = false, busy = false;
  Future submit() async {
    setState(() => busy = true);
    final d = await guard(context, () => Api.call('POST', reg ? '/auth/register' : '/auth/login', {'name': n.text, 'email': e.text, 'password': p.text}));
    if (!mounted) return;
    setState(() => busy = false);
    if (d != null) { await Api.save(d['token']); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home())); }
  }
  @override
  Widget build(BuildContext c) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        Container(width: 76, height: 76, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [ink, Color(0xFF818CF8)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 20),
        const Text('EduTrack', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        Text(reg ? 'Create your account' : 'Welcome back, sign in to continue', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 28),
        card(Column(children: [
          AnimatedSize(duration: const Duration(milliseconds: 250), child: reg ? Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: n, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)))) : const SizedBox()),
          TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 12),
          TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(reg ? 'Create account' : 'Sign in')),
        ]), p: const EdgeInsets.all(20)),
        TextButton(onPressed: () => setState(() => reg = !reg), child: Text(reg ? 'Already have an account? Sign in' : 'New here? Create an account')),
      ]))));
}

// ---------- shell ----------
class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeS(); }
class _HomeS extends State<Home> {
  int i = 0;
  static const titles = ['Dashboard', 'Students', 'Attendance', 'Notices', 'Subjects'];
  Widget page() => [const Dash(), const Students(), const Attend(),
        const ListPage('/notices', ['Title', 'Message'], ['title', 'body'], Icons.campaign_rounded), const ListPage('/subjects', ['Subject name', 'Code'], ['name', 'code'], Icons.menu_book_rounded)][i];
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(titles[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24)), actions: [
          IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout_rounded), onPressed: () async { await Api.save(null); if (c.mounted) Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const Auth())); })]),
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey(i), child: page())),
        bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Subjects'),
        ]),
      );
}

// ---------- dashboard ----------
class Dash extends StatelessWidget {
  const Dash({super.key});
  Widget stat(IconData i, String v, String l, Color col) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: col.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: col, size: 20)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text(l, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))]),
      ]));
  @override
  Widget build(BuildContext c) => Fetch('/dashboard', (d, r) {
        final rk = Map<String, dynamic>.from(d['risk']);
        return RefreshIndicator(onRefresh: () async => r(), child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 600),
            builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch)),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.35, mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
                stat(Icons.people_rounded, '${d['students']}', 'Students', ink),
                stat(Icons.menu_book_rounded, '${d['subjects']}', 'Subjects', const Color(0xFF0EA5E9)),
                stat(Icons.event_available_rounded, '${d['attendance']}%', 'Avg attendance', const Color(0xFF10B981)),
                stat(Icons.grade_rounded, '${d['avg_marks']}%', 'Avg marks', const Color(0xFFF59E0B)),
              ]),
              const SizedBox(height: 12),
              title('Risk overview'),
              card(Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Row(children: [for (final k in ['Low', 'Medium', 'High']) if (rk[k] > 0) Expanded(flex: rk[k], child: Container(height: 14, color: riskColor(k)))])),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [for (final k in ['Low', 'Medium', 'High']) Column(children: [Text('${rk[k]}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: riskColor(k))), Text(k, style: TextStyle(color: Colors.grey.shade600))])]),
              ])),
              title('Latest notices'),
              for (final n in d['notices']) card(Row(children: [const Icon(Icons.campaign_rounded, color: ink), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n['title'], style: const TextStyle(fontWeight: FontWeight.w600)), Text(n['body'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600))]))])),
            ])));
      });
}

// ---------- students ----------
class Students extends StatefulWidget { const Students({super.key}); @override State<Students> createState() => _StudentsS(); }
class _StudentsS extends State<Students> {
  String q = ''; int v = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(backgroundColor: ink, foregroundColor: Colors.white, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add student'),
            onPressed: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => const StudentForm())); setState(() => v++); }),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: TextField(onChanged: (x) => setState(() => q = x), decoration: const InputDecoration(hintText: 'Search name, roll no or class', prefixIcon: Icon(Icons.search_rounded)))),
          Expanded(child: Fetch('/students?q=${Uri.encodeQueryComponent(q)}', key: ValueKey('$q$v'), (d, r) => (d as List).isEmpty
              ? const Center(child: Text('No students found'))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
                  for (final s in d) card(Row(children: [
                    avatar(s, 26), const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text('${s['roll_no']} • Class ${s['class_name']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))])),
                    chip(s['risk']),
                  ]), onTap: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => StudentDetail(s['id']))); setState(() => v++); }),
                ]))),
        ]),
      );
}

class StudentForm extends StatefulWidget { final Map? s; const StudentForm({super.key, this.s}); @override State<StudentForm> createState() => _FormS(); }
class _FormS extends State<StudentForm> {
  late final f = {for (final k in ['name', 'roll_no', 'class_name', 'email', 'phone']) k: TextEditingController(text: '${widget.s?[k] ?? ''}')};
  late String url = '${widget.s?['photo_url'] ?? ''}';
  bool up = false, busy = false;
  Future pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (x == null) return;
    setState(() => up = true);
    final u = await guard(context, () async {
      final ref = FirebaseStorage.instance.ref('students/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(x.path), SettableMetadata(contentType: 'image/jpeg'));
      return ref.getDownloadURL();
    });
    if (mounted) setState(() { up = false; if (u != null) url = u; });
  }
  Future save() async {
    setState(() => busy = true);
    final body = {for (final e in f.entries) e.key: e.value.text.trim(), 'photo_url': url};
    final ok = await guard(context, () => widget.s == null ? Api.call('POST', '/students', body) : Api.call('PUT', '/students/${widget.s!['id']}', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (ok != null) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext c) {
    const labels = {'name': 'Full name', 'roll_no': 'Roll number', 'class_name': 'Class', 'email': 'Email', 'phone': 'Phone'};
    return Scaffold(appBar: AppBar(title: Text(widget.s == null ? 'Add student' : 'Edit student', style: const TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: GestureDetector(onTap: up ? null : pick, child: Stack(children: [
            up ? const CircleAvatar(radius: 52, child: CircularProgressIndicator()) : avatar({'name': f['name']!.text.isEmpty ? '?' : f['name']!.text, 'photo_url': url}, 52),
            Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: ink, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18))),
          ]))),
          const SizedBox(height: 24),
          for (final e in labels.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: f[e.key], decoration: InputDecoration(labelText: e.value))),
          const SizedBox(height: 8),
          FilledButton(onPressed: busy || up ? null : save, child: Text(widget.s == null ? 'Add student' : 'Save changes')),
        ]));
  }
}

class StudentDetail extends StatelessWidget {
  final int id; const StudentDetail(this.id, {super.key});
  Future addMark(BuildContext c, Map d, VoidCallback r) async {
    final subs = await guard(c, () => Api.call('GET', '/subjects')) as List?;
    if (subs == null) return;
    if (subs.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Add a subject first'))); return; }
    int sub = subs[0]['id'];
    final ex = TextEditingController(text: 'Midterm'), sc = TextEditingController(), mx = TextEditingController(text: '100');
    final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (_, set) => AlertDialog(
        title: const Text('Add marks'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(value: sub, items: [for (final s in subs) DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))], onChanged: (v) => set(() => sub = v!)),
          const SizedBox(height: 10), TextField(controller: ex, decoration: const InputDecoration(labelText: 'Exam')),
          const SizedBox(height: 10), TextField(controller: sc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Score')),
          const SizedBox(height: 10), TextField(controller: mx, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Out of')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Save'))])));
    if (ok == true && c.mounted) { await guard(c, () => Api.call('POST', '/marks', {'student_id': id, 'subject_id': sub, 'exam': ex.text, 'score': sc.text, 'max_score': mx.text})); r(); }
  }
  @override
  Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Fetch('/students/$id', (d, r) => ListView(padding: const EdgeInsets.all(16), children: [
            card(Column(children: [
              avatar(d, 46), const SizedBox(height: 12),
              Text(d['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text('${d['roll_no']} • Class ${d['class_name']}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 10), chip(d['risk']), const SizedBox(height: 12),
              if ((d['email'] ?? '').toString().isNotEmpty) Text('✉  ${d['email']}'),
              if ((d['phone'] ?? '').toString().isNotEmpty) Text('☎  ${d['phone']}'),
            ]), p: const EdgeInsets.all(22)),
            Row(children: [
              Expanded(child: card(Column(children: [Text('${d['att']}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF10B981))), const Text('Attendance')]))),
              const SizedBox(width: 12),
              Expanded(child: card(Column(children: [Text('${d['avg_marks']}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))), const Text('Avg marks')]))),
            ]),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.edit_rounded), label: const Text('Edit'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => StudentForm(s: d))); r(); })),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: const Text('Delete student?'), content: const Text('This also removes their attendance and marks.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
                    if (ok == true && c.mounted) { final x = await guard(c, () => Api.call('DELETE', '/students/$id')); if (x != null && c.mounted) Navigator.pop(c); }
                  })),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [title('Marks'), TextButton.icon(onPressed: () => addMark(c, d, r), icon: const Icon(Icons.add_rounded), label: const Text('Add'))]),
            if ((d['marks'] as List).isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No marks recorded yet')),
            for (final m in d['marks']) card(Column(children: [
              Row(children: [Expanded(child: Text('${m['subject']} · ${m['exam']}', style: const TextStyle(fontWeight: FontWeight.w600))), Text('${double.parse('${m['score']}').toStringAsFixed(0)}/${double.parse('${m['max_score']}').toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(minHeight: 8, value: (double.parse('${m['score']}') / double.parse('${m['max_score']}')).clamp(0, 1), backgroundColor: ink.withOpacity(.1), color: ink)),
            ])),
          ])));
}

// ---------- attendance ----------
class Attend extends StatefulWidget { const Attend({super.key}); @override State<Attend> createState() => _AttendS(); }
class _AttendS extends State<Attend> {
  DateTime d = DateTime.now();
  String get ds => d.toIso8601String().substring(0, 10);
  @override
  Widget build(BuildContext c) => Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: card(Row(children: [
          const Icon(Icons.calendar_today_rounded, color: ink), const SizedBox(width: 12), Expanded(child: Text(ds, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          TextButton(onPressed: () async { final x = await showDatePicker(context: c, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime.now()); if (x != null) setState(() => d = x); }, child: const Text('Change')),
        ]))),
        Expanded(child: Fetch('/attendance?date=$ds', (data, r) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              for (final s in data) card(Row(children: [
                avatar(s, 22), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w600)), Text(s['roll_no'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                for (final st in ['present', 'absent']) Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(
                    label: Text(st == 'present' ? 'P' : 'A'), selected: s['status'] == st, selectedColor: (st == 'present' ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(.2),
                    onSelected: (_) async { final ok = await guard(c, () => Api.call('POST', '/attendance', {'student_id': s['id'], 'date': ds, 'status': st})); if (ok != null) setState(() => s['status'] = st); })),
              ]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ]))),
      ]);
}

// ---------- notices & subjects ----------
class ListPage extends StatefulWidget {
  final String path; final List<String> labels, ks; final IconData icon;
  const ListPage(this.path, this.labels, this.ks, this.icon, {super.key});
  @override State<ListPage> createState() => _ListS();
}
class _ListS extends State<ListPage> {
  int v = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(backgroundColor: ink, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Add'),
            onPressed: () async {
              final a = await ask(c, 'Add new', widget.labels);
              if (a == null || !c.mounted) return;
              await guard(c, () => Api.call('POST', widget.path, {widget.ks[0]: a[0], widget.ks[1]: a[1]}));
              setState(() => v++);
            }),
        body: Fetch(widget.path, key: ValueKey(v), (d, r) => (d as List).isEmpty
            ? const Center(child: Text('Nothing here yet'))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                for (final x in d) card(Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ink.withOpacity(.1), borderRadius: BorderRadius.circular(14)), child: Icon(widget.icon, color: ink)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x[widget.ks[0]]}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${x[widget.ks[1]]}', style: TextStyle(color: Colors.grey.shade600))])),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await guard(c, () => Api.call('DELETE', '${widget.path}/${x['id']}')); setState(() => v++); }),
                ])),
              ])),
      );
}
