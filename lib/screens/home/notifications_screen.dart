import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/firebase_messaging_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allNotifications = [];
  int _unreadCount = 0;
  int _selectedIndex = 3;

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();

  // Stacking state
  final Set<String> _expandedCategories = {};

  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);

    _foregroundSubscription =
        FirebaseMessagingService().onForegroundMessage.listen((message) {
      if (mounted) {
        setState(() {
          final newNotification = {
            'id': DateTime.now().millisecondsSinceEpoch,
            'title': message.notification?.title ?? '',
            'message': message.notification?.body ?? '',
            'type': message.data['type'] ?? message.data['notification_type'],
            'category': message.data['category'],
            'description': message.data['description'],
            'image': message.data['image'],
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          };

          if (message.data['id'] != null) {
            newNotification['id'] =
                int.tryParse(message.data['id'].toString()) ??
                    newNotification['id'];
          }

          _allNotifications.insert(0, newNotification);
          _unreadCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _foregroundSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications({bool reset = true}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoadingMore = false;
        _isLoading = true;
      });
    }

    try {
      final apiService = ApiService();
      final response = await apiService.getNotifications(
        page: _currentPage,
        perPage: 20,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<Map<String, dynamic>> newNotifications = [];

        if (data is List) {
          newNotifications = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('notifications')) {
          final notifications = data['notifications'];
          if (notifications is List) {
            newNotifications =
                List<Map<String, dynamic>>.from(notifications);
          }
        }

        if (data is Map) {
          if (data['pagination'] != null &&
              data['pagination']['last_page'] != null) {
            _lastPage = data['pagination']['last_page'];
          } else if (data['last_page'] != null) {
            _lastPage = data['last_page'];
          }
          _hasMore = _currentPage < _lastPage;

          if (data['unread_count'] != null) {
            _unreadCount = data['unread_count'];
          }
        }

        if (reset) {
          _allNotifications = newNotifications;
        } else {
          _allNotifications.addAll(newNotifications);
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (reset) {
            _isLoading = false;
          } else {
            _isLoadingMore = false;
          }
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _loadNotifications(reset: false);
  }

  Future<void> _markAsRead(int notificationId) async {
    final apiService = ApiService();
    try {
      final response =
          await apiService.markNotificationAsRead(notificationId);
      if (response['success'] == true) {
        setState(() {
          final index =
              _allNotifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            _allNotifications[index]['is_read'] = true;
          }
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        });
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final apiService = ApiService();
    try {
      final response = await apiService.markAllNotificationsAsRead();
      if (response['success'] == true) {
        setState(() {
          for (var notification in _allNotifications) {
            notification['is_read'] = true;
          }
          _unreadCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  void _deleteNotificationOptimistic(Map<String, dynamic> notification) {
    final notificationId = notification['id'];
    final originalIndex = _allNotifications.indexOf(notification);
    if (originalIndex == -1) return;

    setState(() {
      _allNotifications.removeAt(originalIndex);
      if (notification['is_read'] == false) {
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      }
    });

    bool undoClicked = false;
    final apiService = ApiService();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.blue.shade200,
          onPressed: () {
            undoClicked = true;
            if (mounted) {
              setState(() {
                _allNotifications.insert(
                    originalIndex.clamp(0, _allNotifications.length),
                    notification);
                if (notification['is_read'] == false) {
                  _unreadCount++;
                }
              });
            }
          },
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(const Duration(seconds: 5), () async {
      if (!undoClicked) {
        try {
          await apiService.deleteNotification(notificationId);
        } catch (e) {
          debugPrint('Error deleting notification on server: $e');
        }
      }
    });
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = ApiService();
    try {
      final response = await apiService.deleteAllNotifications();
      if (response['success'] == true) {
        setState(() {
          _allNotifications.clear();
          _unreadCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  void _onNavBarTap(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const HomeScreen()));
    } else if (index == 1) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const VehiclesScreen()));
    } else if (index == 2) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const BookingsScreen()));
    } else if (index == 3) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()));
    }
  }

  String _formatWalletAmount(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return amount.toString();
    }
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  IconData _getCategoryIcon(String? category, String? type) {
    final cat = (category ?? type ?? '').toLowerCase();
    if (cat.contains('rental')) return Icons.directions_car;
    if (cat.contains('payment') || cat.contains('wallet'))
      return Icons.account_balance_wallet;
    if (cat.contains('verification')) return Icons.verified_user;
    if (cat.contains('promotion') || cat.contains('bonus'))
      return Icons.card_giftcard;
    if (cat.contains('system')) return Icons.settings;
    return Icons.notifications;
  }

  Color _getCategoryColor(String? category, String? type) {
    final cat = (category ?? type ?? '').toLowerCase();
    if (cat.contains('rental')) return Colors.blue;
    if (cat.contains('payment') || cat.contains('wallet')) return Colors.green;
    if (cat.contains('verification')) return Colors.orange;
    if (cat.contains('promotion') || cat.contains('bonus')) return Colors.purple;
    if (cat.contains('system')) return Colors.grey.shade700;
    return Colors.black;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedNotifications {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var notification in _allNotifications) {
      final category =
          (notification['category'] ?? notification['type'] ?? 'General')
              .toString();
      groups.putIfAbsent(category, () => []).add(notification);
    }
    return groups;
  }

  // ─────────────────────────────────────────────────────────────
  // Stack builder — properly layered peek cards
  // ─────────────────────────────────────────────────────────────
  Widget _buildNotificationStack(
      String category, List<Map<String, dynamic>> items) {
    final isExpanded = _expandedCategories.contains(category);

    // Header label
    Widget sectionHeader({bool showLess = false}) => Padding(
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
              if (showLess)
                GestureDetector(
                  onTap: () =>
                      setState(() => _expandedCategories.remove(category)),
                  child: Text(
                    'Show less',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
            ],
          ),
        );

    // Expanded: show all cards normally
    if (isExpanded || items.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(showLess: isExpanded && items.length > 1),
          ...items.map((n) => _buildNotificationCard(n)),
        ],
      );
    }

    // ── Collapsed stack ──────────────────────────────────────
    // We use a fixed peek height for shadow cards so they don't
    // need to know the dynamic height of the top card.
    const double peekHeight = 12.0; // how much each layer peeks below
    const double scaleStep = 0.04; // each layer shrinks a bit
    final int extraCards = (items.length - 1).clamp(0, 2); // max 2 shadows

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(),
        GestureDetector(
          onTap: () =>
              setState(() => _expandedCategories.add(category)),
          child: Padding(
            // Bottom padding so the peeking cards don't clip the next section
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: peekHeight * extraCards + 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Shadow cards drawn bottom-first (furthest at the back)
                for (int i = extraCards; i >= 1; i--)
                  Positioned(
                    left: i * 6.0,
                    right: i * 6.0,
                    bottom: -(i * peekHeight),
                    child: Transform.scale(
                      scale: 1.0 - (i * scaleStep),
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: peekHeight + 8,
                        decoration: BoxDecoration(
                          color: i == 1
                              ? Colors.grey.shade200
                              : Colors.grey.shade300,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Top (real) card — drawn last so it sits on top
                _buildNotificationCard(
                  items.first,
                  isStacked: true,
                  hiddenCount: items.length - 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Single notification card
  // NOTE: images are intentionally NOT shown in the list.
  //       They appear only in the detail bottom sheet.
  // ─────────────────────────────────────────────────────────────
  Widget _buildNotificationCard(
    Map<String, dynamic> notification, {
    bool isStacked = false,
    int hiddenCount = 0,
  }) {
    final isRead = notification['is_read'] == true;
    final type = notification['type'] as String?;
    final category = notification['category'] as String?;
    final description = notification['description'] as String?;

    final icon = _getCategoryIcon(category, type);
    final color = _getCategoryColor(category, type);

    Widget cardContent = Container(
      // No horizontal margin here when stacked — the parent Padding handles it
      margin: isStacked
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? Colors.grey.shade200
              : Colors.blue.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + unread dot
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (!isRead) ...[
                const SizedBox(height: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 16),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w700,
                          color: isRead ? Colors.grey.shade800 : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      notification['created_at_human'] ??
                          _formatRelativeTime(notification['created_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notification['message'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isRead
                        ? Colors.grey.shade600
                        : Colors.grey.shade800,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description snippet (non-stacked only)
                if (!isStacked &&
                    description != null &&
                    description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // "X more" badge when stacked
                if (isStacked && hiddenCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+$hiddenCount more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Stacked top card — tap to expand, no swipe
    if (isStacked) return cardContent;

    // Normal card — swipe to delete, tap to view detail
    return Slidable(
      key: ValueKey(notification['id']),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteNotificationOptimistic(notification),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markAsRead(notification['id']);
          _showNotificationDetails(notification);
        },
        child: cardContent,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final walletAmount = authProvider.user?.walletBalance ?? 0;
    final groups = _groupedNotifications;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leadingWidth: 120,
        title: const Text(
          'Notification Center',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const WalletScreen())),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text(
                  '₹${_formatWalletAmount(walletAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_allNotifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
              onSelected: (value) {
                if (value == 'delete_all') {
                  _deleteAllNotifications();
                } else if (value == 'refresh') {
                  _loadNotifications();
                } else if (value == 'mark_all_read' && _unreadCount > 0) {
                  _markAllAsRead();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ]),
                ),
                if (_unreadCount > 0)
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(children: [
                      Icon(Icons.mark_email_read, size: 20),
                      SizedBox(width: 12),
                      Text('Mark all as read'),
                    ]),
                  ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(children: [
                    Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete All', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black))
          : _allNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You're all caught up!",
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  color: Colors.black,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount:
                        groups.keys.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == groups.keys.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
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

                      final category = groups.keys.elementAt(index);
                      final items = groups[category]!;
                      return _buildNotificationStack(category, items);
                    },
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined), label: 'Vehicles'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined), label: 'Bookings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Detail bottom sheet — image lives HERE, not in the list
  // ─────────────────────────────────────────────────────────────
  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image shown ONLY in detail view
                    if (notification['image'] != null &&
                        notification['image'].toString().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          notification['image'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        if (notification['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              notification['category'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        Text(
                          notification['created_at_human'] ??
                              _formatRelativeTime(notification['created_at']),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notification['title'] ?? 'Notification',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notification['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    if (notification['description'] != null &&
                        notification['description']
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        notification['description'],
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}