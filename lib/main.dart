import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://vsgukztbxfpantickqic.supabase.co');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_pnvRgD0j6tJuNMWuFlpV2g_B1uxLWCn');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WalletPage(),
    );
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double balance = 0;
  double totalDeposits = 0;
  double totalWithdrawals = 0;
  double totalLoans = 0;
  List<Map<String, dynamic>> records = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      double bal = 0;
      double dep = 0;
      double wit = 0;
      double loa = 0;

      for (final item in data) {
        final type = item['type'] as String;
        final amount = (item['amount'] as num).toDouble();

        if (type == 'إيداع') {
          bal += amount;
          dep += amount;
        } else if (type == 'سحب') {
          bal -= amount;
          wit += amount;
        } else if (type == 'سلفة') {
          bal -= amount;
          loa += amount;
        } else if (type == 'استرداد سلفة') {
          bal += amount;
          loa -= amount;
        }
      }

      setState(() {
        balance = bal;
        totalDeposits = dep;
        totalWithdrawals = wit;
        totalLoans = loa;
        records = data.cast<Map<String, dynamic>>();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> addTransaction(String type, double amount,
      {String? note}) async {
    final response = await supabase.from('transactions').insert({
      'type': type,
      'amount': amount,
      'note': note ?? '',
    }).select();

    final inserted = (response as List<dynamic>).first as Map<String, dynamic>;

    setState(() {
      if (type == 'إيداع') {
        balance += amount;
        totalDeposits += amount;
      } else if (type == 'سحب') {
        balance -= amount;
        totalWithdrawals += amount;
      } else if (type == 'سلفة') {
        balance -= amount;
        totalLoans += amount;
      } else if (type == 'استرداد سلفة') {
        balance += amount;
        totalLoans -= amount;
      }

      records.insert(0, inserted);
    });
  }

  Future<void> deleteTransaction(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    await supabase.from('transactions').delete().eq('id', id);

    setState(() {
      final type = item['type'] as String;
      final amount = (item['amount'] as num).toDouble();

      if (type == 'إيداع') {
        balance -= amount;
        totalDeposits -= amount;
      } else if (type == 'سحب') {
        balance += amount;
        totalWithdrawals -= amount;
      } else if (type == 'سلفة') {
        balance += amount;
        totalLoans -= amount;
      } else if (type == 'استرداد سلفة') {
        balance -= amount;
        totalLoans += amount;
      }

      records.removeWhere((r) => r['id'] == id);
    });
  }

  Future<bool> confirmDelete(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف ${item['type']} بقيمة ${item['amount']} ريال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void showTransactionDialog() {
    String selectedType = 'إيداع';
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('عملية جديدة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'إيداع', child: Text('إيداع')),
                      DropdownMenuItem(value: 'سحب', child: Text('سحب')),
                      DropdownMenuItem(value: 'سلفة', child: Text('سلفة')),
                      DropdownMenuItem(
                          value: 'استرداد سلفة',
                          child: Text('استرداد سلفة')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: selectedType == 'سلفة'
                          ? 'اسم الشخص (اختياري)'
                          : 'ملاحظة (اختياري)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount =
                        double.tryParse(amountController.text) ?? 0;
                    if (amount > 0) {
                      addTransaction(selectedType, amount,
                          note: noteController.text);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رصيدي'),
        centerTitle: true,
      ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton(
              onPressed: showTransactionDialog,
              child: const Icon(Icons.add),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                balanceCard(),
                statsRow(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'سجل العمليات',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('لا توجد عمليات بعد'))
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final item = records[index];
                            return transactionTile(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'الرصيد الحالي',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(2)} ريال',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget statsRow() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: statCard('إيداعات', totalDeposits, Colors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: statCard('سحوبات', totalWithdrawals, Colors.red),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: statCard('سلف', totalLoans, Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget statCard(String label, double amount, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget transactionTile(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final amount = (item['amount'] as num).toDouble();
    final note = (item['note'] ?? '') as String;
    final createdAt = item['created_at'] as String?;

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'إيداع':
      case 'استرداد سلفة':
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        break;
      case 'سحب':
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        break;
      case 'سلفة':
        icon = Icons.arrow_upward;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.circle;
        iconColor = Colors.grey;
    }

    String subtitle;
    if (note.isNotEmpty) {
      subtitle = note;
    } else if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        subtitle = DateFormat('yyyy/MM/dd HH:mm').format(date);
      } catch (_) {
        subtitle = '';
      }
    } else {
      subtitle = '';
    }

    return Dismissible(
      key: ValueKey(item['id'] ?? DateTime.now().millisecondsSinceEpoch),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDelete(item),
      onDismissed: (_) => deleteTransaction(item),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13))
            : null,
        trailing: Text(
          '${amount.toStringAsFixed(2)} ريال',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: type == 'إيداع' || type == 'استرداد سلفة'
                ? Colors.green
                : Colors.red,
          ),
        ),
      ),
    );
  }
}
