import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic> _summary = {};
  
  // Filter variables
  DateTimeRange? _selectedDateRange;
  String? _selectedType; // 'all', 'credit', 'debit'
  String? _selectedStatus; // 'all', 'completed', 'pending', 'failed'
  
  final List<String> _typeOptions = ['All', 'Credit', 'Debit'];
  final List<String> _statusOptions = ['All', 'Completed', 'Pending', 'Failed'];
  
  late AnimationController _animationController;
  
  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  
  final ScrollController _scrollController = ScrollController();
  
  // Notifications
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadTransactions();
    _loadUnreadNotificationCount();
    _animationController.forward();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getUnreadNotificationsCount();
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _unreadNotificationCount = response['data']['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading unread notification count: $e');
    }
  }

  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    
    // Refresh unread count when coming back from notifications screen
    await _loadUnreadNotificationCount();
  }

  Future<void> _loadTransactions({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _transactions = [];
        _hasMore = true;
      });
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final startDate = _selectedDateRange?.start.toIso8601String().split('T').first;
      final endDate = _selectedDateRange?.end.toIso8601String().split('T').first;
      
      if (startDate != null && endDate != null) {
        print('Date filter: $startDate to $endDate');
      }
      
      final type = _selectedType != null && _selectedType != 'All' 
          ? _selectedType!.toLowerCase() 
          : null;
      final status = _selectedStatus != null && _selectedStatus != 'All' 
          ? _selectedStatus!.toLowerCase() 
          : null;
      
      final response = await authProvider.getWalletTransactions(
        type: type,
        status: status,
        perPage: 20,
        forceRefresh: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<Map<String, dynamic>> newTransactions = [];
        
        if (data is List) {
          newTransactions = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('transactions')) {
          newTransactions = List<Map<String, dynamic>>.from(data['transactions']);
          _summary = data['summary'] ?? {};
          final pagination = data['pagination'] ?? {};
          _lastPage = pagination['last_page'] ?? 1;
          _hasMore = _currentPage < _lastPage;
        }
        
        if (reset) {
          setState(() {
            _transactions = newTransactions;
          });
        } else {
          setState(() {
            _transactions.addAll(newTransactions);
          });
        }
      }
      
      if (reset) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (reset) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_hasMore || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    await _loadTransactions(reset: false);
  }

  void _resetFilters() {
    setState(() {
      _selectedDateRange = null;
      _selectedType = null;
      _selectedStatus = null;
    });
    _loadTransactions();
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.grey.shade900,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.grey.shade900,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadTransactions();
    }
  }

  void _showFilterBottomSheet() {
    String? tempType = _selectedType;
    String? tempStatus = _selectedStatus;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Filter Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // Transaction Type Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Type',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _typeOptions.map((type) {
                          final isSelected = tempType == (type == 'All' ? null : type.toLowerCase());
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(
                                label: type,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    tempType = type == 'All' ? null : type.toLowerCase();
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Status Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusOptions.map((status) {
                          final isSelected = tempStatus == (status == 'All' ? null : status.toLowerCase());
                          return _buildFilterChip(
                            label: status,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                tempStatus = status == 'All' ? null : status.toLowerCase();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _resetFilters();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedType = tempType;
                              _selectedStatus = tempStatus;
                            });
                            Navigator.pop(context);
                            _loadTransactions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _onNavBarTap(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VehiclesScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BookingsScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  void _navigateToTransactionDetail(Map<String, dynamic> transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          transaction: transaction,
        ),
      ),
    ).then((_) => _loadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade900),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none, color: Colors.grey.shade700),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _navigateToNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTransactions();
          await _loadUnreadNotificationCount();
        },
        color: Colors.black,
        child: Column(
          children: [
            // Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Date Range Button
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: _showDateRangePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDateRange == null
                                    ? 'Select Date Range'
                                    : '${_formatDate(_selectedDateRange!.start.toIso8601String())} - ${_formatDate(_selectedDateRange!.end.toIso8601String())}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedDateRange != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                  _loadTransactions();
                                },
                                child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter Button
                  GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_selectedType != null || _selectedStatus != null) 
                            ? Colors.black 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 20,
                            color: (_selectedType != null || _selectedStatus != null) 
                                ? Colors.white 
                                : Colors.grey.shade700,
                          ),
                          if (_selectedType != null || _selectedStatus != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Active Filters Row
            if (_selectedType != null || _selectedStatus != null || _selectedDateRange != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedType != null)
                        _buildActiveFilterChip(
                          label: 'Type: ${_selectedType![0].toUpperCase()}${_selectedType!.substring(1)}',
                          onRemove: () {
                            setState(() {
                              _selectedType = null;
                            });
                            _loadTransactions();
                          },
                        ),
                      if (_selectedStatus != null)
                        _buildActiveFilterChip(
                          label: 'Status: ${_selectedStatus![0].toUpperCase()}${_selectedStatus!.substring(1)}',
                          onRemove: () {
                            setState(() {
                              _selectedStatus = null;
                            });
                            _loadTransactions();
                          },
                        ),
                      if (_selectedDateRange != null)
                        _buildActiveFilterChip(
                          label: 'Date: ${_formatDate(_selectedDateRange!.start.toIso8601String())} - ${_formatDate(_selectedDateRange!.end.toIso8601String())}',
                          onRemove: () {
                            setState(() {
                              _selectedDateRange = null;
                            });
                            _loadTransactions();
                          },
                        ),
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Clear All',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade600, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Summary Stats
            if (_summary.isNotEmpty && _transactions.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Credits', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_summary['total_credits'] ?? 0}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Debits', style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_summary['total_debits'] ?? 0}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Change', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                            const SizedBox(height: 4),
                            Text(
                              '₹${(_summary['total_credits'] ?? 0) - (_summary['total_debits'] ?? 0)}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Transactions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.grey))
                  : _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _resetFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            final transaction = _transactions[index];
                            final isCredit = transaction['type'] == 'credit';
                            final amount = transaction['amount'] ?? 0;
                            final status = transaction['status'] ?? 'pending';
                            final statusColor = status == 'completed' 
                                ? Colors.green 
                                : status == 'pending' 
                                    ? Colors.orange 
                                    : Colors.red;
                            
                            return FadeInAnimation(
                              delay: (index % 10) * 0.05,
                              controller: _animationController,
                              child: GestureDetector(
                                onTap: () => _navigateToTransactionDetail(transaction),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isCredit 
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isCredit 
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 28,
                                          color: isCredit ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              transaction['reason'] ?? 'Transaction',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade900,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    transaction['created_at_formatted'] ?? _formatDate(transaction['created_at']),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    transaction['status_label'] ?? status,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isCredit ? '+' : '-'} ${transaction['formatted_amount'] ?? '₹$amount'}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isCredit ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (() {
                                              final refId = transaction['reference_id']?.toString();
                                              if (refId == null) return 'N/A';
                                              return refId.length > 12 ? '${refId.substring(0, 12)}...' : refId;
                                            })(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), label: 'Vehicles'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        currentIndex: 0,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// Fade-in Animation Widget
class FadeInAnimation extends StatelessWidget {
  final Widget child;
  final double delay;
  final AnimationController controller;

  const FadeInAnimation({
    super.key,
    required this.child,
    required this.delay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
      child: child,
    );
  }
}