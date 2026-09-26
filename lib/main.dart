import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(KhataBookApp(store));
}

String id() => DateTime.now().microsecondsSinceEpoch.toString();
String rs(double x) => 'Rs. ${NumberFormat('#,##0.##').format(x)}';

class AppStore extends ChangeNotifier {
  static const key = 'khatabook_v2';
  final businesses = <Map<String, dynamic>>[];
  final cars = <Map<String, dynamic>>[];
  final contacts = <Map<String, dynamic>>[];
  final tx = <Map<String, dynamic>>[];
  final khataTx = <Map<String, dynamic>>[];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key) ?? p.getString('khatabook_v1');
    if (raw == null) return;
    final d = jsonDecode(raw) as Map<String, dynamic>;
    _loadList(businesses, d['businesses']);
    _loadList(cars, d['cars']);
    _loadList(contacts, d['contacts']);
    _loadList(tx, d['tx']);
    _loadList(khataTx, d['khataTx']);
  }

  void _loadList(List<Map<String, dynamic>> target, dynamic source) {
    if (source is List) {
      for (final x in source) {
        if (x is Map) target.add(Map<String, dynamic>.from(x));
      }
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode({
      'businesses': businesses,
      'cars': cars,
      'contacts': contacts,
      'tx': tx,
      'khataTx': khataTx,
    }));
  }

  Future<void> addBusiness(String name) async {
    businesses.add({'id': id(), 'name': name.trim(), 'created': DateTime.now().toIso8601String()});
    await save(); notifyListeners();
  }

  Future<void> addCar(String name, String reg, String driver, double rent) async {
    cars.add({'id': id(), 'name': name.trim(), 'reg': reg.trim(), 'driver': driver.trim(), 'rent': rent});
    await save(); notifyListeners();
  }

  Future<void> addContact(String name, String phone, String kind) async {
    contacts.add({'id': id(), 'name': name.trim(), 'phone': phone.trim(), 'kind': kind});
    await save(); notifyListeners();
  }

  Future<void> addTx(
    String type,
    double amount,
    String category, {
    String business = '',
    String car = '',
    String platform = '',
    String contact = '',
    String method = 'Cash',
    String note = '',
    DateTime? date,
  }) async {
    tx.add({
      'id': id(),
      'type': type,
      'amount': amount,
      'category': category,
      'business': business,
      'car': car,
      'platform': platform,
      'contact': contact,
      'method': method,
      'note': note,
      'date': DateFormat('yyyy-MM-dd').format(date ?? DateTime.now()),
    });
    await save(); notifyListeners();
  }

  Future<void> updateTx(String transactionId, Map<String, dynamic> values) async {
    final index = tx.indexWhere((x) => x['id'] == transactionId);
    if (index >= 0) {
      tx[index] = {...tx[index], ...values};
      await save(); notifyListeners();
    }
  }

  Future<void> deleteTx(String transactionId) async {
    tx.removeWhere((x) => x['id'] == transactionId);
    await save(); notifyListeners();
  }

  Future<void> addKhataTx(String contactId, String type, double amount, String note, DateTime date) async {
    khataTx.add({
      'id': id(), 'contact': contactId, 'type': type, 'amount': amount,
      'note': note, 'date': DateFormat('yyyy-MM-dd').format(date),
    });
    await save(); notifyListeners();
  }

  double khataBalance(String contactId) {
    var balance = 0.0;
    for (final x in khataTx.where((x) => x['contact'] == contactId)) {
      final amount = (x['amount'] as num).toDouble();
      balance += x['type'] == 'give' ? amount : -amount;
    }
    return balance;
  }

  double total(String type) => tx.where((x) => x['type'] == type).fold(0.0, (sum, x) => sum + (x['amount'] as num).toDouble());
  double get income => total('income');
  double get expense => total('expense');
  double get profit => income - expense;

  double monthTotal(String type) {
    final prefix = DateFormat('yyyy-MM').format(DateTime.now());
    return tx.where((x) => x['type'] == type && x['date'].toString().startsWith(prefix)).fold(0.0, (sum, x) => sum + (x['amount'] as num).toDouble());
  }

  String bn(String i) => businesses.where((x) => x['id'] == i).map((x) => x['name'].toString()).firstOrNull ?? 'Personal';
  String cn(String i) => cars.where((x) => x['id'] == i).map((x) => '${x['name']} (${x['reg']})').firstOrNull ?? '-';
  String contactName(String i) => contacts.where((x) => x['id'] == i).map((x) => x['name'].toString()).firstOrNull ?? '';

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'KhataBook', 'version': '2.0.0', 'exportedAt': DateTime.now().toIso8601String(),
    'businesses': businesses, 'cars': cars, 'contacts': contacts, 'tx': tx, 'khataTx': khataTx,
  });

  Future<void> clear() async {
    businesses.clear(); cars.clear(); contacts.clear(); tx.clear(); khataTx.clear();
    await save(); notifyListeners();
  }
}

class KhataBookApp extends StatelessWidget {
  final AppStore store;
  const KhataBookApp(this.store, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KhataBook Pro',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF243B7A), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF7F8FC),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0, surfaceTintColor: Colors.white),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF243B7A), width: 1.5)),
          ),
        ),
        home: Home(store),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final AppStore store;
  const Home(this.store, {super.key});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  final titles = const ['Dashboard', 'Khata', 'Business', 'Cars & Rent', 'Reports'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(widget.store, onTab: (i) => setState(() => index = i)),
      KhataPage(widget.store),
      Businesses(widget.store),
      Cars(widget.store),
      Reports(widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/khatabook_logo.png', width: 34, height: 34)),
          const SizedBox(width: 10),
          Text(index == 0 ? 'KhataBook' : titles[index], style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => showSearch(context: context, delegate: GlobalSearch(widget.store))),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Settings(widget.store)))),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (x) => setState(() => index = x),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Khata'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Business'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Cars'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton.extended(onPressed: () => entryDialog(context, widget.store), icon: const Icon(Icons.add), label: const Text('Entry'))
          : null,
    );
  }
}

class Dashboard extends StatelessWidget {
  final AppStore s;
  final ValueChanged<int> onTab;
  const Dashboard(this.s, {required this.onTab, super.key});

  @override
  Widget build(BuildContext context) {
    final monthIncome = s.monthTotal('income');
    final monthExpense = s.monthTotal('expense');
    return RefreshIndicator(
      onRefresh: s.save,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          _HeroCard(s: s),
          const SizedBox(height: 14),
          _BrandWelcome(),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: StatCard(title: 'Income', value: s.income, icon: Icons.arrow_upward_rounded, positive: true)), const SizedBox(width: 10), Expanded(child: StatCard(title: 'Expense', value: s.expense, icon: Icons.arrow_downward_rounded))]),
          const SizedBox(height: 10),
          StatCard(title: 'Net Profit', value: s.profit, icon: Icons.account_balance_wallet_rounded, big: true, positive: s.profit >= 0),
          const SizedBox(height: 18),
          SectionTitle('This month'),
          Row(children: [Expanded(child: MiniCard('Income', monthIncome, Icons.calendar_month_outlined)), const SizedBox(width: 10), Expanded(child: MiniCard('Expense', monthExpense, Icons.receipt_long_outlined)), const SizedBox(width: 10), Expanded(child: MiniCard('Profit', monthIncome - monthExpense, Icons.insights_outlined))]),
          const SizedBox(height: 20),
          SectionTitle('Quick actions'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            QuickAction('Income', Icons.add_circle_outline, () => entryDialog(context, s, type: 'income')),
            QuickAction('Expense', Icons.remove_circle_outline, () => entryDialog(context, s, type: 'expense')),
            QuickAction('New Khata', Icons.person_add_alt_1_outlined, () => contactDialog(context, s)),
            QuickAction('Business', Icons.storefront_outlined, () => businessDialog(context, s)),
            QuickAction('Car', Icons.directions_car_outlined, () => carDialog(context, s)),
          ]),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [SectionTitle('Recent entries'), TextButton(onPressed: () => onTab(1), child: const Text('View all'))]),
          if (s.tx.isEmpty) const EmptyState(icon: Icons.receipt_long_outlined, title: 'No entries yet', subtitle: 'Add your first income or expense.'),
          ...s.tx.reversed.take(6).map((x) => TransactionTile(s: s, data: x)),
        ],
      ),
    );
  }
}


class _BrandWelcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE7ECF3)),
      boxShadow: const [BoxShadow(color: Color(0x0A102A43), blurRadius: 18, offset: Offset(0, 7))],
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFFF5F8FC), borderRadius: BorderRadius.circular(15)), child: Image.asset('assets/khatabook_logo.png', width: 52, height: 52)),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KhataBook Pro', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
        SizedBox(height: 3),
        Text('Business • Khata • Cars • Reports', style: TextStyle(fontSize: 12, color: Color(0xFF627D98))),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFE9F8EF), borderRadius: BorderRadius.circular(12)), child: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16834B), fontSize: 11))),
    ]),
  );
}

class _HeroCard extends StatelessWidget {
  final AppStore s;
  const _HeroCard({required this.s});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF172554), Color(0xFF3155A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [BoxShadow(color: Color(0x24172554), blurRadius: 20, offset: Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 46, height: 46, padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/khatabook_logo.png'))), const SizedBox(width: 12), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('KHATABOOK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)), Text('Professional accounts', style: TextStyle(color: Colors.white70, fontSize: 12))])]),
      const SizedBox(height: 24),
      const Text('Current net position', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 4),
      Text(rs(s.profit), style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text('${s.tx.length} account entries • ${s.contacts.length} khata contacts', style: const TextStyle(color: Colors.white70)),
    ]),
  );
}

class StatCard extends StatelessWidget {
  final String title; final double value; final IconData icon; final bool positive; final bool big;
  const StatCard({required this.title, required this.value, required this.icon, this.positive = false, this.big = false, super.key});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: EdgeInsets.all(big ? 18 : 14), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (positive ? Colors.green : Colors.red).withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: positive ? Colors.green.shade700 : Colors.red.shade700)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)), const SizedBox(height: 3), Text(rs(value), style: TextStyle(fontSize: big ? 25 : 19, fontWeight: FontWeight.w900))]))])));
}

class MiniCard extends StatelessWidget {
  final String title; final double value; final IconData icon;
  const MiniCard(this.title, this.value, this.icon, {super.key});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 11)), const SizedBox(height: 2), Text(rs(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))])));
}

class SectionTitle extends StatelessWidget {
  final String text; const SectionTitle(this.text, {super.key});
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900));
}

class QuickAction extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback onTap;
  const QuickAction(this.title, this.icon, this.onTap, {super.key});
  @override Widget build(BuildContext context) => FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon), label: Text(title));
}

class TransactionTile extends StatelessWidget {
  final AppStore s; final Map<String, dynamic> data;
  const TransactionTile({required this.s, required this.data, super.key});
  @override
  Widget build(BuildContext context) {
    final income = data['type'] == 'income';
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: (income ? Colors.green : Colors.red).withOpacity(.10), child: Icon(income ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: income ? Colors.green.shade700 : Colors.red.shade700)),
      title: Text(data['category'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${data['date']} • ${data['method']}'),
      trailing: Text('${income ? '+' : '-'} ${rs((data['amount'] as num).toDouble())}', style: TextStyle(fontWeight: FontWeight.w900, color: income ? Colors.green.shade700 : Colors.red.shade700)),
      onTap: () => entryDialog(context, s, existing: data),
    ));
  }
}

class KhataPage extends StatefulWidget {
  final AppStore s; const KhataPage(this.s, {super.key});
  @override State<KhataPage> createState() => _KhataPageState();
}
class _KhataPageState extends State<KhataPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.s.contacts.where((c) => c['name'].toString().toLowerCase().contains(query.toLowerCase()) || c['phone'].toString().contains(query)).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
      TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customer, supplier or driver')),
      const SizedBox(height: 14),
      if (list.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, title: 'No khata contacts', subtitle: 'Create a contact to start tracking balances.'),
      ...list.map((c) => _ContactCard(s: widget.s, contact: c)),
    ]);
  }
}

class _ContactCard extends StatelessWidget {
  final AppStore s; final Map<String, dynamic> contact;
  const _ContactCard({required this.s, required this.contact});
  @override
  Widget build(BuildContext context) {
    final balance = s.khataBalance(contact['id'].toString());
    final owesUs = balance > 0;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(child: Text(contact['name'].toString().isEmpty ? '?' : contact['name'].toString()[0].toUpperCase())),
      title: Text(contact['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${contact['kind']} • ${contact['phone']}'),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(rs(balance.abs()), style: const TextStyle(fontWeight: FontWeight.w900)), Text(owesUs ? 'You will receive' : balance < 0 ? 'You will pay' : 'Settled', style: TextStyle(fontSize: 10, color: owesUs ? Colors.green.shade700 : Colors.red.shade700))]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KhataDetail(s, contact))),
    ));
  }
}

class KhataDetail extends StatelessWidget {
  final AppStore s; final Map<String, dynamic> contact;
  const KhataDetail(this.s, this.contact, {super.key});
  @override
  Widget build(BuildContext context) {
    final entries = s.khataTx.where((x) => x['contact'] == contact['id']).toList().reversed.toList();
    final balance = s.khataBalance(contact['id']);
    return Scaffold(appBar: AppBar(title: Text(contact['name'].toString())), body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF172554), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(contact['kind'].toString(), style: const TextStyle(color: Colors.white70)), const SizedBox(height: 6), Text(rs(balance.abs()), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(balance > 0 ? 'Amount to receive' : balance < 0 ? 'Amount to pay' : 'Settled', style: const TextStyle(color: Colors.white70))])),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: () => khataEntryDialog(context, s, contact, 'give'), icon: const Icon(Icons.arrow_downward), label: const Text('Give / Udhaar'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => khataEntryDialog(context, s, contact, 'take'), icon: const Icon(Icons.arrow_upward), label: const Text('Receive')))]),
      const SizedBox(height: 18),
      if (entries.isEmpty) const EmptyState(icon: Icons.receipt_long_outlined, title: 'No khata entries', subtitle: 'Add the first transaction for this contact.'),
      ...entries.map((x) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(x['type'] == 'give' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: x['type'] == 'give' ? Colors.red : Colors.green), title: Text(rs((x['amount'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${x['date']} • ${x['note'] ?? ''}')))),
    ]));
  }
}

class Businesses extends StatelessWidget {
  final AppStore s; const Businesses(this.s, {super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const SectionTitle('Your businesses'), FilledButton.icon(onPressed: () => businessDialog(context, s), icon: const Icon(Icons.add), label: const Text('Add'))]),
    const SizedBox(height: 14),
    if (s.businesses.isEmpty) const EmptyState(icon: Icons.storefront_outlined, title: 'No business added', subtitle: 'Create a business to separate its income and expenses.'),
    ...s.businesses.map((b) {
      final q = s.tx.where((x) => x['business'] == b['id']);
      final a = q.where((x) => x['type'] == 'income').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
      final e = q.where((x) => x['type'] == 'expense').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
      return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)), title: Text(b['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Income ${rs(a)} • Expense ${rs(e)}'), trailing: Text(rs(a - e), style: const TextStyle(fontWeight: FontWeight.w900))));
    }),
  ]);
}

class Cars extends StatelessWidget {
  final AppStore s; const Cars(this.s, {super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const SectionTitle('Cars & daily rent'), FilledButton.icon(onPressed: () => carDialog(context, s), icon: const Icon(Icons.add), label: const Text('Add car'))]),
    const SizedBox(height: 14),
    if (s.cars.isEmpty) const EmptyState(icon: Icons.directions_car_outlined, title: 'No car added', subtitle: 'Add a car with its driver and daily rent.'),
    ...s.cars.map((car) {
      final q = s.tx.where((x) => x['car'] == car['id']);
      final a = q.where((x) => x['type'] == 'income').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
      final e = q.where((x) => x['type'] == 'expense').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
      return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Row(children: [const CircleAvatar(child: Icon(Icons.directions_car)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${car['name']} • ${car['reg']}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('Driver: ${car['driver']}')]))]), const Divider(height: 24), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Daily rent\n${rs((car['rent'] as num).toDouble())}'), Text('Income\n${rs(a)}'), Text('Expense\n${rs(e)}'), IconButton(onPressed: () => entryDialog(context, s, car: car['id']), icon: const Icon(Icons.add_circle))])])));
    }),
  ]);
}

class Reports extends StatelessWidget {
  final AppStore s; const Reports(this.s, {super.key});
  @override Widget build(BuildContext context) {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final q = s.tx.where((x) => x['date'].toString().startsWith(month)).toList();
    final income = q.where((x) => x['type'] == 'income').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
    final expense = q.where((x) => x['type'] == 'expense').fold(0.0, (v, x) => v + (x['amount'] as num).toDouble());
    final byMethod = <String, double>{};
    for (final x in q) { final m = x['method'].toString(); byMethod[m] = (byMethod[m] ?? 0) + (x['amount'] as num).toDouble(); }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4), const Text('Monthly business summary'), const SizedBox(height: 16),
      StatCard(title: 'Total income', value: income, icon: Icons.trending_up, positive: true), const SizedBox(height: 10),
      StatCard(title: 'Total expense', value: expense, icon: Icons.trending_down), const SizedBox(height: 10),
      StatCard(title: 'Monthly profit', value: income - expense, icon: Icons.insights, positive: income >= expense, big: true), const SizedBox(height: 22),
      const SectionTitle('Payment method activity'), const SizedBox(height: 8),
      ...byMethod.entries.map((x) => Card(child: ListTile(leading: const Icon(Icons.payments_outlined), title: Text(x.key), trailing: Text(rs(x.value), style: const TextStyle(fontWeight: FontWeight.w800))))),
    ]);
  }
}

class Settings extends StatelessWidget {
  final AppStore s; const Settings(this.s, {super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const Card(child: ListTile(leading: Icon(Icons.verified_user_outlined), title: Text('KhataBook Pro', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Version 2.0.0 • Professional local accounting'))),
    const SizedBox(height: 10),
    Card(child: Column(children: [ListTile(leading: const Icon(Icons.currency_rupee), title: const Text('Currency'), subtitle: const Text('Pakistani Rupee (PKR / Rs.)')), ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Backup data'), subtitle: const Text('Create a copy of your current data'), onTap: () async { await Clipboard.setData(ClipboardData(text: s.exportJson())); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup JSON copied. Paste it somewhere safe.'))); }), ListTile(leading: const Icon(Icons.security_outlined), title: const Text('Data security'), subtitle: const Text('Your current data is stored locally on this device.'))])),
    const SizedBox(height: 10),
    Card(child: ListTile(leading: Icon(Icons.delete_forever, color: Colors.red.shade700), title: const Text('Clear all data'), subtitle: const Text('Delete businesses, cars, contacts and entries'), onTap: () async { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Clear all data?'), content: const Text('This action cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))])); if (ok == true) await s.clear(); }))
  ]));
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const EmptyState({required this.icon, required this.title, required this.subtitle, super.key});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 45), child: Column(children: [Icon(icon, size: 52, color: Colors.grey.shade400), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))]));
}

class GlobalSearch extends SearchDelegate<String> {
  final AppStore s; GlobalSearch(this.s);
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) {
    final q = query.toLowerCase();
    final txs = s.tx.where((x) => x.values.any((v) => v.toString().toLowerCase().contains(q))).toList();
    final contacts = s.contacts.where((x) => x.values.any((v) => v.toString().toLowerCase().contains(q))).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (contacts.isNotEmpty) const Padding(padding: EdgeInsets.all(8), child: SectionTitle('Khata contacts')),
      ...contacts.map((x) => ListTile(leading: const Icon(Icons.person_outline), title: Text(x['name'].toString()), subtitle: Text(x['phone'].toString()))),
      if (txs.isNotEmpty) const Padding(padding: EdgeInsets.all(8), child: SectionTitle('Entries')),
      ...txs.map((x) => ListTile(title: Text(x['category'].toString()), subtitle: Text(x['date'].toString()), trailing: Text(rs((x['amount'] as num).toDouble())))),
      if (contacts.isEmpty && txs.isEmpty) const EmptyState(icon: Icons.search_off, title: 'Nothing found', subtitle: 'Try another name, phone number or category.')
    ]);
  }
  @override Widget buildSuggestions(BuildContext context) => buildResults(context);
}

Future<void> businessDialog(BuildContext context, AppStore s) async {
  final name = TextEditingController();
  await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add business'), content: TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Business name', prefixIcon: Icon(Icons.storefront))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; await s.addBusiness(name.text); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))]));
}

Future<void> carDialog(BuildContext context, AppStore s) async {
  final n = TextEditingController(), r = TextEditingController(), d = TextEditingController(), rent = TextEditingController();
  await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add car'), content: SingleChildScrollView(child: Column(children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Car / Model')), const SizedBox(height: 10), TextField(controller: r, decoration: const InputDecoration(labelText: 'Registration number')), const SizedBox(height: 10), TextField(controller: d, decoration: const InputDecoration(labelText: 'Driver name')), const SizedBox(height: 10), TextField(controller: rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily rent (PKR)'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { await s.addCar(n.text, r.text, d.text, double.tryParse(rent.text) ?? 0); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))]));
}

Future<void> contactDialog(BuildContext context, AppStore s) async {
  final n = TextEditingController(), p = TextEditingController(); String kind = 'Customer';
  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, set) => AlertDialog(title: const Text('New khata contact'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: 10), TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')), const SizedBox(height: 10), DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'Type'), items: ['Customer', 'Supplier', 'Driver'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => set(() => kind = v ?? 'Customer'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (n.text.trim().isEmpty) return; await s.addContact(n.text, p.text, kind); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))])));
}

Future<void> khataEntryDialog(BuildContext context, AppStore s, Map<String, dynamic> contact, String type) async {
  final amount = TextEditingController(), note = TextEditingController(); DateTime date = DateTime.now();
  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, set) => AlertDialog(title: Text(type == 'give' ? 'Give / Udhaar' : 'Receive payment'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Contact: ${contact['name']}'), const SizedBox(height: 12), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (PKR)', prefixText: 'Rs. ')), const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')), const SizedBox(height: 8), TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (d != null) set(() => date = d); }, icon: const Icon(Icons.calendar_month), label: Text(DateFormat('dd MMM yyyy').format(date))) ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { final v = double.tryParse(amount.text) ?? 0; if (v <= 0) return; await s.addKhataTx(contact['id'].toString(), type, v, note.text.trim(), date); if (context.mounted) Navigator.pop(context); }, child: const Text('Save'))])));
}

Future<void> entryDialog(BuildContext context, AppStore s, {String type = 'income', String car = '', Map<String, dynamic>? existing}) async {
  String t = existing?['type']?.toString() ?? type;
  String business = existing?['business']?.toString() ?? '';
  String selectedCar = existing?['car']?.toString() ?? car;
  String platform = existing?['platform']?.toString() ?? '';
  String method = existing?['method']?.toString() ?? 'Cash';
  String contact = existing?['contact']?.toString() ?? '';
  DateTime date = existing == null ? DateTime.now() : DateTime.tryParse(existing['date'].toString()) ?? DateTime.now();
  final amount = TextEditingController(text: existing == null ? '' : existing['amount'].toString());
  final category = TextEditingController(text: existing?['category']?.toString() ?? '');
  final note = TextEditingController(text: existing?['note']?.toString() ?? '');
  final platforms = ['', 'inDrive', 'Yango', 'Uber', 'Other'];
  final methods = ['Cash', 'Bank', 'Easypaisa', 'JazzCash'];

  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, set) => AlertDialog(title: Text(existing == null ? 'New account entry' : 'Edit account entry'), content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(children: [
    SegmentedButton<String>(segments: const [ButtonSegment(value: 'income', label: Text('Income')), ButtonSegment(value: 'expense', label: Text('Expense'))], selected: {t}, onSelectionChanged: (v) => set(() => t = v.first)),
    const SizedBox(height: 12), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (PKR)', prefixText: 'Rs. ')),
    const SizedBox(height: 10), TextField(controller: category, decoration: const InputDecoration(labelText: 'Category / description')),
    const SizedBox(height: 10), DropdownButtonFormField<String>(value: business, decoration: const InputDecoration(labelText: 'Business'), items: [const DropdownMenuItem(value: '', child: Text('Personal / none')), ...s.businesses.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name'].toString())))], onChanged: (v) => set(() => business = v ?? '')),
    const SizedBox(height: 10), DropdownButtonFormField<String>(value: selectedCar, decoration: const InputDecoration(labelText: 'Car'), items: [const DropdownMenuItem(value: '', child: Text('No car')), ...s.cars.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text('${x['name']} (${x['reg']})')))], onChanged: (v) => set(() => selectedCar = v ?? '')),
    const SizedBox(height: 10), DropdownButtonFormField<String>(value: contact, decoration: const InputDecoration(labelText: 'Khata contact (optional)'), items: [const DropdownMenuItem(value: '', child: Text('No contact')), ...s.contacts.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name'].toString())))], onChanged: (v) => set(() => contact = v ?? '')),
    const SizedBox(height: 10), DropdownButtonFormField<String>(value: platform, decoration: const InputDecoration(labelText: 'Platform'), items: platforms.map((x) => DropdownMenuItem(value: x, child: Text(x.isEmpty ? 'None' : x))).toList(), onChanged: (v) => set(() => platform = v ?? '')),
    const SizedBox(height: 10), DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'Payment method'), items: methods.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => set(() => method = v ?? '')),
    const SizedBox(height: 4), TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (d != null) set(() => date = d); }, icon: const Icon(Icons.calendar_month_outlined), label: Text(DateFormat('dd MMM yyyy').format(date))),
    TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
  ]))), actions: [
    if (existing != null) TextButton(onPressed: () async { await s.deleteTx(existing['id'].toString()); if (context.mounted) Navigator.pop(context); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    FilledButton(onPressed: () async { final v = double.tryParse(amount.text) ?? 0; if (v <= 0 || category.text.trim().isEmpty) return; final values = {'type': t, 'amount': v, 'category': category.text.trim(), 'business': business, 'car': selectedCar, 'contact': contact, 'platform': platform, 'method': method, 'note': note.text.trim(), 'date': DateFormat('yyyy-MM-dd').format(date)}; if (existing == null) { await s.addTx(t, v, category.text.trim(), business: business, car: selectedCar, contact: contact, platform: platform, method: method, note: note.text.trim(), date: date); } else { await s.updateTx(existing['id'].toString(), values); } if (context.mounted) Navigator.pop(context); }, child: Text(existing == null ? 'Save entry' : 'Update')),
  ])));
}
