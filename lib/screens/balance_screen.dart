import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/balance_details.dart';
import '../services/storage_service.dart';
import '../widgets/error_dialog.dart';

class BalanceScreen extends StatefulWidget {
  final BalanceDetails balanceDetails;
  final String customerId;

  const BalanceScreen({
    super.key,
    required this.balanceDetails,
    required this.customerId,
  });

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen>
    with TickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  bool _isSaved = false;

  late AnimationController _fadeController;
  late AnimationController _balanceScaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _balanceScaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _balanceScaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _balanceScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _balanceScaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Start animations
    _fadeController.forward();
    _balanceScaleController.forward();
  }

  Future<void> _checkIfSaved() async {
    final saved = await _storageService.isIdSaved(widget.customerId);
    setState(() {
      _isSaved = saved;
    });
  }

  Future<void> _saveCustomerId() async {
    final labelController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Save Customer ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer ID: ${widget.customerId}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                labelText: 'Label (Optional)',
                hintText: 'e.g., Home, Office',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await _storageService.saveCustomerId(
          widget.customerId,
          label: labelController.text.trim().isEmpty
              ? null
              : labelController.text.trim(),
        );

        setState(() {
          _isSaved = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer ID saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorDialog.show(
            context,
            title: 'Error',
            message: 'Failed to save customer ID.',
          );
        }
      }
    }
  }

  void _shareBalance() {
    final details = widget.balanceDetails;
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final text = '''
DPDC Balance Details
-------------------
Customer: ${details.customerName}
Account ID: ${details.accountId}
Balance: ${details.getFormattedBalance()}
Connection Status: ${details.connectionStatus}
Customer Type: ${details.customerType}
Customer Class: ${details.customerClass}
Account Type: ${details.accountType}
${details.mobileNumber != null ? 'Mobile: ${details.mobileNumber}\n' : ''}${details.emailId != null ? 'Email: ${details.emailId}\n' : ''}Minimum Recharge: ${details.getFormattedMinRecharge()}

Checked on: $dateStr
''';

    Share.share(text, subject: 'DPDC Balance Details');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6), // Blue
              Color(0xFF8B5CF6), // Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 20),
                        _buildDetailsCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const Spacer(),
            ScaleTransition(
              scale: _balanceScaleAnimation,
              child: Hero(
                tag: 'app_icon',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 56), // Balance for back button
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return ScaleTransition(
      scale: _balanceScaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Hero(
          tag: 'balance_card',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF97316), // Orange
                    Color(0xFFEC4899), // Pink
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                    spreadRadius: -5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Balance Remaining',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      widget.balanceDetails.getFormattedBalance(),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.balanceDetails.connectionStatus
                                        .toLowerCase() ==
                                    'active'
                                ? Colors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.balanceDetails.connectionStatus
                                        .toLowerCase() ==
                                    'active'
                                ? Icons.check
                                : Icons.priority_high,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.balanceDetails.connectionStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final details = [
      {'icon': Icons.person, 'label': 'Customer Name', 'value': widget.balanceDetails.customerName},
      {'icon': Icons.badge, 'label': 'Account ID', 'value': widget.balanceDetails.accountId},
      {'icon': Icons.category, 'label': 'Customer Class', 'value': widget.balanceDetails.customerClass},
      {'icon': Icons.account_circle, 'label': 'Customer Type', 'value': widget.balanceDetails.customerType},
      {'icon': Icons.account_balance_wallet, 'label': 'Account Type', 'value': widget.balanceDetails.accountType},
      if (widget.balanceDetails.mobileNumber != null)
        {'icon': Icons.phone, 'label': 'Mobile Number', 'value': widget.balanceDetails.mobileNumber!},
      if (widget.balanceDetails.emailId != null)
        {'icon': Icons.email, 'label': 'Email', 'value': widget.balanceDetails.emailId!},
      {'icon': Icons.payments, 'label': 'Minimum Recharge', 'value': widget.balanceDetails.getFormattedMinRecharge()},
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _fadeController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
        )),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: -5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.2),
                          const Color(0xFF8B5CF6).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...List.generate(details.length, (index) {
                final detail = details[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(20 * (1 - value), 0),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      if (index > 0) _buildDivider(),
                      _buildDetailRow(
                        detail['icon'] as IconData,
                        detail['label'] as String,
                        detail['value'] as String,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.15),
                  const Color(0xFF8B5CF6).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3B82F6),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildActionButtons() {
    final buttons = [
      if (!_isSaved)
        {
          'label': 'Save Customer ID',
          'icon': Icons.bookmark_add,
          'color': const Color(0xFF3B82F6),
          'onTap': _saveCustomerId
        },
      {
        'label': 'Share Details',
        'icon': Icons.share,
        'color': const Color(0xFF10B981),
        'onTap': _shareBalance
      },
      {
        'label': 'Check Another',
        'icon': Icons.refresh,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.pop(context)
      },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: List.generate(buttons.length, (index) {
          final button = buttons[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 150)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                if (index > 0) const SizedBox(height: 14),
                _buildActionButton(
                  label: button['label'] as String,
                  icon: button['icon'] as IconData,
                  color: button['color'] as Color,
                  onTap: button['onTap'] as VoidCallback,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _balanceScaleController.dispose();
    super.dispose();
  }
}
