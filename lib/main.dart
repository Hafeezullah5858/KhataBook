import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(KhataBookApp(store));
}

class AppStore extends ChangeNotifier {
  static const key = 'khatabook_v1';
  final businesses = <Map<String,dynamic>>[];
  final cars = <Map<String,dynamic>>[];
  final contacts = <Map<String,dynamic>>[];
  final tx = <Map<String,dynamic>>[];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(key); if (s == null) return;
    final d = jsonDecode(s) as Map<String,dynamic>;
    for (final x in d['businesses'] ?? []) businesses.add(Map<String,dynamic>.from(x));
    for (final x in d['cars'] ?? []) cars.add(Map<String,dynamic>.from(x));
    for (final x in d['contacts'] ?? []) contacts.add(Map<String,dynamic>.from(x));
    for (final x in d['tx'] ?? []) tx.add(Map<String,dynamic>.from(x));
  }
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode({'businesses':businesses,'cars':cars,'contacts':contacts,'tx':tx}));
  }
  Future<void> addBusiness(String name) async {
    businesses.add({'id':id(),'name':name}); await save(); notifyListeners();
  }
  Future<void> addCar(String name,String reg,String driver,double rent) async {
    cars.add({'id':id(),'name':name,'reg':reg,'driver':driver,'rent':rent}); await save(); notifyListeners();
  }
  Future<void> addContact(String name,String phone,String kind) async {
    contacts.add({'id':id(),'name':name,'phone':phone,'kind':kind}); await save(); notifyListeners();
  }
  Future<void> addTx(String type,double amount,String category,{String business='',String car='',String platform='',String contact='',String method='Cash',String note='',DateTime? date}) async {
    tx.add({'id':id(),'type':type,'amount':amount,'category':category,'business':business,'car':car,'platform':platform,'contact':contact,'method':method,'note':note,'date':DateFormat('yyyy-MM-dd').format(date ?? DateTime.now())});
    await save(); notifyListeners();
  }
  double total(String type)=>tx.where((x)=>x['type']==type).fold(0.0,(s,x)=>s+(x['amount'] as num).toDouble());
  double get income=>total('income'); double get expense=>total('expense'); double get profit=>income-expense;
  String bn(String i) {
    for (final x in businesses) {
      if (x['id'] == i) return x['name'].toString();
    }
    return 'Personal';
  }

  String cn(String i) {
    for (final x in cars) {
      if (x['id'] == i) return '${x['name']} (${x['reg']})';
    }
    return '-';
  }
  Future<void> clear() async {businesses.clear();cars.clear();contacts.clear();tx.clear();await save();notifyListeners();}
}
String id()=>DateTime.now().microsecondsSinceEpoch.toString();
String rs(double x)=>'Rs. ${NumberFormat('#,##0.##').format(x)}';

class KhataBookApp extends StatelessWidget {
  final AppStore store; const KhataBookApp(this.store,{super.key});
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:store,builder:(_,__)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'KhataBook',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:Colors.indigo)),
    home:Home(store),
  ));
}

class Home extends StatefulWidget { final AppStore store; const Home(this.store,{super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{
  int i=0; final titles=['Dashboard','Khata','Businesses','Cars & Rent','Reports'];
  @override Widget build(BuildContext c){
    final pages=[Dash(widget.store),TxPage(widget.store),Businesses(widget.store),Cars(widget.store),Reports(widget.store)];
    return Scaffold(appBar:AppBar(title:Text(titles[i]),actions:[IconButton(icon:const Icon(Icons.settings),onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Settings(widget.store))))]),
      body:pages[i],
      bottomNavigationBar:NavigationBar(selectedIndex:i,onDestinationSelected:(x)=>setState(()=>i=x),destinations:const[
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Home'),
        NavigationDestination(icon:Icon(Icons.menu_book),label:'Khata'),
        NavigationDestination(icon:Icon(Icons.business),label:'Business'),
        NavigationDestination(icon:Icon(Icons.directions_car),label:'Cars'),
        NavigationDestination(icon:Icon(Icons.bar_chart),label:'Reports')]),
      floatingActionButton:i==1?FloatingActionButton.extended(onPressed:()=>entry(c,widget.store),icon:const Icon(Icons.add),label:const Text('Entry')):null);
  }
}

class Dash extends StatelessWidget { final AppStore s; const Dash(this.s,{super.key});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('KhataBook',style:Theme.of(c).textTheme.headlineMedium),const Text('Business + Khata + Car Daily Rent + Driver Accounts'),const SizedBox(height:16),
    Row(children:[Expanded(child:Card(child:ListTile(title:const Text('Income'),subtitle:Text(rs(s.income)),leading:const Icon(Icons.trending_up)))),const SizedBox(width:8),Expanded(child:Card(child:ListTile(title:const Text('Expense'),subtitle:Text(rs(s.expense)),leading:const Icon(Icons.trending_down))))]),
    Card(child:ListTile(title:const Text('Net Profit'),subtitle:Text(rs(s.profit),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),leading:const Icon(Icons.account_balance_wallet))),
    const SizedBox(height:12),const Text('Quick Actions',style:TextStyle(fontWeight:FontWeight.bold)),Wrap(spacing:8,children:[
      Action('Income',Icons.add_circle,()=>entry(c,s,type:'income')),Action('Expense',Icons.remove_circle,()=>entry(c,s,type:'expense')),
      Action('Business',Icons.business,()=>business(c,s)),Action('Car',Icons.directions_car,()=>car(c,s)),Action('Khata Contact',Icons.person_add,()=>contact(c,s))]),
    const SizedBox(height:16),const Text('Recent Entries',style:TextStyle(fontWeight:FontWeight.bold)),
    ...s.tx.reversed.take(8).map((x)=>ListTile(leading:Icon(x['type']=='income'?Icons.add:Icons.remove),title:Text('${x['category']} • ${rs((x['amount'] as num).toDouble())}'),subtitle:Text('${x['date']} • ${x['platform'] ?? ''} • ${x['method']}')))
  ]);
}

class Action extends StatelessWidget { final String t; final IconData icon; final VoidCallback f; const Action(this.t,this.icon,this.f,{super.key}); @override Widget build(BuildContext c)=>OutlinedButton.icon(onPressed:f,icon:Icon(icon),label:Text(t)); }

class TxPage extends StatelessWidget { final AppStore s; const TxPage(this.s,{super.key});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    Card(child:ListTile(title:Text('Income ${rs(s.income)}'),subtitle:Text('Expense ${rs(s.expense)} • Profit ${rs(s.profit)}'))),
    ...s.tx.reversed.map((x)=>Card(child:ListTile(title:Text('${x['category']} — ${rs((x['amount'] as num).toDouble())}'),subtitle:Text('${x['date']} • ${x['method']} • ${x['platform'] ?? ''}'))))
  ]);
}

class Businesses extends StatelessWidget { final AppStore s; const Businesses(this.s,{super.key});
  @override Widget build(BuildContext c)=>Scaffold(body:ListView(padding:const EdgeInsets.all(12),children:[
    ...s.businesses.map((b){final q=s.tx.where((x)=>x['business']==b['id']);final a=q.where((x)=>x['type']=='income').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());final e=q.where((x)=>x['type']=='expense').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());return Card(child:ListTile(title:Text(b['name']),subtitle:Text('Income ${rs(a)} • Expense ${rs(e)} • Profit ${rs(a-e)}')));})
  ]),floatingActionButton:FloatingActionButton(onPressed:()=>business(c,s),child:const Icon(Icons.add)));
}

class Cars extends StatelessWidget { final AppStore s; const Cars(this.s,{super.key});
  @override Widget build(BuildContext c)=>Scaffold(body:ListView(padding:const EdgeInsets.all(12),children:[
    ...s.cars.map((car){final q=s.tx.where((x)=>x['car']==car['id']);final a=q.where((x)=>x['type']=='income').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());final e=q.where((x)=>x['type']=='expense').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());return Card(child:ListTile(title:Text('${car['name']} • ${car['reg']}'),subtitle:Text('Driver: ${car['driver']} • Daily Rent ${rs((car['rent'] as num).toDouble())}\nIncome ${rs(a)} • Expenses ${rs(e)} • Net ${rs(a-e)}'),isThreeLine:true,trailing:IconButton(icon:const Icon(Icons.add),onPressed:()=>entry(c,s,car:car['id']))));})
  ]),floatingActionButton:FloatingActionButton(onPressed:()=>car(c,s),child:const Icon(Icons.add)));
}

class Reports extends StatelessWidget { final AppStore s; const Reports(this.s,{super.key});
  @override Widget build(BuildContext c){final m=DateFormat('yyyy-MM').format(DateTime.now());final q=s.tx.where((x)=>(x['date'] as String).startsWith(m));final a=q.where((x)=>x['type']=='income').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());final e=q.where((x)=>x['type']=='expense').fold(0.0,(v,x)=>v+(x['amount'] as num).toDouble());final p=<String,double>{};for(final x in q.where((x)=>x['type']=='income')){final k=(x['platform']??'').toString();if(k.isNotEmpty)p[k]=(p[k]??0)+(x['amount'] as num).toDouble();}return ListView(padding:const EdgeInsets.all(16),children:[Text('Monthly Report',style:Theme.of(c).textTheme.headlineSmall),Text(DateFormat('MMMM yyyy').format(DateTime.now())),Card(child:ListTile(title:const Text('Income'),subtitle:Text(rs(a)))),Card(child:ListTile(title:const Text('Expense'),subtitle:Text(rs(e)))),Card(child:ListTile(title:const Text('Profit'),subtitle:Text(rs(a-e)))),const Text('Platform Income',style:TextStyle(fontWeight:FontWeight.bold)),...p.entries.map((x)=>ListTile(title:Text(x.key),trailing:Text(rs(x.value))))]);}
}

class Settings extends StatelessWidget { final AppStore s; const Settings(this.s,{super.key}); @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Settings')),body:ListView(children:[
  const ListTile(title:Text('Currency'),subtitle:Text('PKR / Rs.')),const ListTile(title:Text('Version'),subtitle:Text('1.0.0+1')),
  ListTile(title:const Text('Local Backup'),subtitle:const Text('Data is stored on this device in v1.0'),leading:const Icon(Icons.storage)),
  ListTile(title:const Text('Clear all local data'),leading:const Icon(Icons.delete_forever),onTap:()async{final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:const Text('Delete all data?'),content:const Text('This cannot be undone.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]));if(ok==true)await s.clear();})
]));}

Future<void> business(BuildContext c,AppStore s)async{final x=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('New Business'),content:TextField(controller:x,decoration:const InputDecoration(labelText:'Business name')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{if(x.text.trim().isNotEmpty)await s.addBusiness(x.text.trim());if(c.mounted)Navigator.pop(c);},child:const Text('Save'))]));}
Future<void> car(BuildContext c,AppStore s)async{final n=TextEditingController(),r=TextEditingController(),d=TextEditingController(),z=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Add Car'),content:SingleChildScrollView(child:Column(children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Car / Model')),TextField(controller:r,decoration:const InputDecoration(labelText:'Registration')),TextField(controller:d,decoration:const InputDecoration(labelText:'Driver')),TextField(controller:z,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Daily Rent PKR'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{await s.addCar(n.text,r.text,d.text,double.tryParse(z.text)??0);if(c.mounted)Navigator.pop(c);},child:const Text('Save'))]));}
Future<void> contact(BuildContext c,AppStore s)async{final n=TextEditingController(),p=TextEditingController();String k='Customer';await showDialog(context:c,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('Khata Contact'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Name')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone')),DropdownButton<String>(value:k,items:['Customer','Supplier','Driver'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>set(()=>k=x!))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{await s.addContact(n.text,p.text,k);if(c.mounted)Navigator.pop(c);},child:const Text('Save'))])));}
Future<void> entry(BuildContext c,AppStore s,{String type='income',String car=''})async{
  String t=type,b='',ca=car,pl='',method='Cash';final a=TextEditingController(),cat=TextEditingController(),note=TextEditingController();
  final plats=['','inDrive','Yango','Ola/Uber','Other'];final methods=['Cash','Bank','Easypaisa','JazzCash'];
  await showDialog(context:c,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('Account Entry'),content:SingleChildScrollView(child:Column(children:[
    SegmentedButton<String>(segments:const[ButtonSegment(value:'income',label:Text('Income')),ButtonSegment(value:'expense',label:Text('Expense'))],selected:{t},onSelectionChanged:(v)=>set(()=>t=v.first)),
    TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount PKR')),TextField(controller:cat,decoration:const InputDecoration(labelText:'Category')),
    DropdownButtonFormField<String>(value:b,decoration:const InputDecoration(labelText:'Business'),items:[const DropdownMenuItem(value:'',child:Text('Personal / None')),...s.businesses.map((x)=>DropdownMenuItem(value:x['id'],child:Text(x['name'])))],onChanged:(v)=>set(()=>b=v??'')),
    DropdownButtonFormField<String>(value:ca,decoration:const InputDecoration(labelText:'Car'),items:[const DropdownMenuItem(value:'',child:Text('No Car')),...s.cars.map((x)=>DropdownMenuItem(value:x['id'],child:Text('${x['name']} (${x['reg']})')))],onChanged:(v)=>set(()=>ca=v??'')),
    DropdownButtonFormField<String>(value:pl,decoration:const InputDecoration(labelText:'Platform'),items:plats.map((x)=>DropdownMenuItem(value:x,child:Text(x.isEmpty?'None':x))).toList(),onChanged:(v)=>set(()=>pl=v??'')),
    DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment Method'),items:methods.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>set(()=>method=v??'')),
    TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{final v=double.tryParse(a.text)??0;if(v<=0||cat.text.trim().isEmpty)return;await s.addTx(t,v,cat.text.trim(),business:b,car:ca,platform:pl,method:method,note:note.text.trim());if(c.mounted)Navigator.pop(c);},child:const Text('Save'))])));
}
