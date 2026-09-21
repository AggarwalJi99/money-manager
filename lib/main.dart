import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinTrack',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
      ),
      home: const HomeScreen(),
    );
  }
}

class Bill {
  final String name;
  final double amount;
  final DateTime dueDate;
  final String vendor;
  final bool isPaid;

  Bill({
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.vendor,
    this.isPaid = false,
  });
}

class Transaction {
  final bool isIncome;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String? receiptPath; // original path
  final String? receiptData; // base64 image data for persistence

  Transaction({
    required this.isIncome,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.receiptPath,
    this.receiptData,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Transaction> transactions = [];
  final List<Bill> bills = [];

  String searchQuery = '';
  String transactionFilter = 'All';

  List<Transaction> get filteredTransactions {
    return transactions.where((transaction) {
      final matchesSearch =
          transaction.category.toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          transaction.note.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesType =
          transactionFilter == 'All' ||
          (transactionFilter == 'Income' && transaction.isIncome) ||
          (transactionFilter == 'Expense' && !transaction.isIncome);

      return matchesSearch && matchesType;
    }).toList();
  }

  double categoryExpenses(String category) {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              !t.isIncome &&
              t.category == category &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyIncome {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              t.isIncome &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyExpenses {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              !t.isIncome &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get balance {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        total += transaction.amount;
      } else {
        total -= transaction.amount;
      }
    }

    return total;
  }

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTransactions = prefs.getStringList('transactions') ?? [];

    final loadedTransactions = savedTransactions.map((item) {
      final data = jsonDecode(item) as Map<String, dynamic>;

      return Transaction(
        isIncome: data['isIncome'] as bool,
        amount: (data['amount'] as num).toDouble(),
        category: data['category'] as String,
        note: data['note'] as String,
        date: DateTime.parse(data['date'] as String),
        receiptPath: data['receiptPath'] as String?,
        receiptData: data['receiptData'] as String?,
      );
    }).toList();

    if (mounted) {
      setState(() {
        transactions
          ..clear()
          ..addAll(loadedTransactions);
      });
    }
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions = transactions.map((transaction) {
      return jsonEncode({
        'isIncome': transaction.isIncome,
        'amount': transaction.amount,
        'category': transaction.category,
        'note': transaction.note,
        'date': transaction.date.toIso8601String(),
        'receiptPath': transaction.receiptPath,
        'receiptData': transaction.receiptData,
      });
    }).toList();

    await prefs.setStringList('transactions', savedTransactions);
  }

  Future<void> addTransaction() async {
    final transaction = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );

    if (transaction != null) {
      setState(() {
        transactions.insert(0, transaction);
      });

      await saveTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FinTrack',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Balance',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${balance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_none, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Bills',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        if (bills.isEmpty)
  Text(
    'No upcoming bills',
    style: TextStyle(color: Colors.white60),
  )
else
  ...bills
      .where((bill) => !bill.isPaid)
      .take(3)
      .map(
        (bill) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            bill.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${bill.vendor} • Due ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
          ),
          trailing: Text(
            '₹${bill.amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'This Month',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Builder(
                builder: (context) {
                  final categories = [
                    'Food',
                    'Transport',
                    'Lifestyle',
                    'Bills',
                  ];

                  final total = categories.fold<double>(
                    0,
                    (sum, category) => sum + categoryExpenses(category),
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: categories.map((category) {
                      final amount = categoryExpenses(category);
                      final barHeight = total == 0
                          ? 0.0
                          : (amount / total) * 100;

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 28,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            Text(
              "Spending by Category",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...["Food", "Transport", "Lifestyle", "Bills"].map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      "₹${categoryExpenses(category).toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1B1D22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                for (final filter in ['All', 'Income', 'Expense'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: transactionFilter == filter,
                      onSelected: (_) {
                        setState(() {
                          transactionFilter = filter;
                        });
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            if (filteredTransactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1D22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              ...filteredTransactions
                  .take(5)
                  .map(
                    (transaction) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1D22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            transaction.isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (transaction.note.isNotEmpty)
                                  Text(
                                    transaction.note,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                if (transaction.receiptData != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('Receipt'),
                                              content: FutureBuilder(
                                                future: Future.value(
                                                  base64Decode(
                                                    transaction.receiptData!,
                                                  ),
                                                ),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const SizedBox(
                                                      height: 200,
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  }

                                                  if (!snapshot.hasData) {
                                                    return const Text(
                                                      'Unable to load receipt.',
                                                    );
                                                  }

                                                  return Image.memory(
                                                    snapshot.data!,
                                                    fit: BoxFit.contain,
                                                  );
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      icon: const Icon(Icons.receipt_long),
                                      label: const Text('View Receipt'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${transaction.isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Add Transaction'),
                          onTap: () {
                            Navigator.pop(context);
                            addTransaction();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_note),
                          title: const Text('Add Bill'),
                          onTap: () async {
                            Navigator.pop(context);

                            final bill = await Navigator.push<Bill>(
                              this.context,
                              MaterialPageRoute(
                                builder: (context) => const AddBillScreen(),
                              ),
                            );

                            if (!mounted) return;

                            if (bill != null) {
                              setState(() {
                                bills.insert(0, bill);
                              });

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Bill "${bill.name}" added successfully',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: const Icon(Icons.add),
          ),
    );
  }
}


class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isPaid = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _saveBill() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final vendor = _vendorController.text.trim();

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a bill name and valid amount'),
        ),
      );
      return;
    }

    final bill = Bill(
      name: name,
      amount: amount,
      dueDate: _dueDate,
      vendor: vendor,
      isPaid: _isPaid,
    );

    Navigator.pop(context, bill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bill'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Bill Name',
              hintText: 'e.g. Electricity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _vendorController,
            decoration: const InputDecoration(
              labelText: 'Vendor',
              hintText: 'e.g. CESC',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due Date'),
            subtitle: Text(
              '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
            ),
            trailing: OutlinedButton(
              onPressed: _selectDueDate,
              child: const Text('Change'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paid'),
            value: _isPaid,
            onChanged: (value) {
              setState(() {
                _isPaid = value;
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saveBill,
              child: const Text('Save Bill'),
            ),
          ),
        ],
      ),
    );
  }
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool isIncome = false;
  String category = 'Food';

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String? _receiptPath;
  String? _receiptData;

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptPath = picked.path;
        _receiptData = base64Encode(bytes);
      });
    }
  }

  final expenseCategories = ['Food', 'Transport', 'Lifestyle', 'Bills'];

  final incomeCategories = ['Salary', 'Other Income'];

  void saveTransaction() {
    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final transaction = Transaction(
      isIncome: isIncome,
      amount: amount,
      category: category,
      note: noteController.text.trim(),
      date: DateTime.now(),
      receiptPath: _receiptPath,
      receiptData: _receiptData,
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final categories = isIncome ? incomeCategories : expenseCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Expense'),
                    selected: !isIncome,
                    onSelected: (_) {
                      setState(() {
                        isIncome = false;
                        category = 'Food';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Income'),
                    selected: isIncome,
                    onSelected: (_) {
                      setState(() {
                        isIncome = true;
                        category = 'Salary';
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Text(
              'Amount',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),

            const SizedBox(height: 25),

            Text(
              'Note',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Optional note',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 35),

            Text(
              'Receipt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickReceipt,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Attach Receipt'),
                ),
                if (_receiptPath != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Text('Attached', style: TextStyle(color: Colors.green)),
                ],
              ],
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: saveTransaction,
                child: const Text(
                  'Save Transaction',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }
}
