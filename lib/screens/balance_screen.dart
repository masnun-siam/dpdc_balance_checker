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

class _BalanceScreenState extends State<BalanceScreen> {
  final StorageService _storageService = StorageService();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 32,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF97316), // Orange
            Color(0xFFEC4899), // Pink
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text(
            'Balance Remaining',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.balanceDetails.getFormattedBalance(),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.balanceDetails.connectionStatus.toLowerCase() ==
                          'active'
                      ? Icons.check_circle
                      : Icons.warning,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.balanceDetails.connectionStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            Icons.person,
            'Customer Name',
            widget.balanceDetails.customerName,
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.badge,
            'Account ID',
            widget.balanceDetails.accountId,
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.category,
            'Customer Class',
            widget.balanceDetails.customerClass,
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.account_circle,
            'Customer Type',
            widget.balanceDetails.customerType,
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.account_balance_wallet,
            'Account Type',
            widget.balanceDetails.accountType,
          ),
          if (widget.balanceDetails.mobileNumber != null) ...[
            _buildDivider(),
            _buildDetailRow(
              Icons.phone,
              'Mobile Number',
              widget.balanceDetails.mobileNumber!,
            ),
          ],
          if (widget.balanceDetails.emailId != null) ...[
            _buildDivider(),
            _buildDetailRow(
              Icons.email,
              'Email',
              widget.balanceDetails.emailId!,
            ),
          ],
          _buildDivider(),
          _buildDetailRow(
            Icons.payments,
            'Minimum Recharge',
            widget.balanceDetails.getFormattedMinRecharge(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3B82F6),
              size: 20,
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
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
    return Column(
      children: [
        if (!_isSaved)
          _buildActionButton(
            label: 'Save Customer ID',
            icon: Icons.bookmark_add,
            color: const Color(0xFF3B82F6),
            onTap: _saveCustomerId,
          ),
        if (!_isSaved) const SizedBox(height: 12),
        _buildActionButton(
          label: 'Share Details',
          icon: Icons.share,
          color: const Color(0xFF10B981),
          onTap: _shareBalance,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Check Another',
          icon: Icons.refresh,
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
