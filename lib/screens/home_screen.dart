import 'package:flutter/material.dart';
import '../services/dpdc_api_service.dart';
import '../services/storage_service.dart';
import '../widgets/error_dialog.dart';
import 'balance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _customerIdController = TextEditingController();
  final DpdcApiService _apiService = DpdcApiService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  List<String> _savedIds = [];
  Map<String, String?> _idsWithLabels = {};
  String? _selectedSavedId;

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  Future<void> _loadSavedIds() async {
    final idsWithLabels = await _storageService.getSavedIdsWithLabels();
    setState(() {
      _idsWithLabels = idsWithLabels;
      _savedIds = idsWithLabels.keys.toList();
    });
  }

  Future<void> _checkBalance() async {
    final customerId = _customerIdController.text.trim();

    // Validate input
    if (customerId.isEmpty) {
      ErrorDialog.show(
        context,
        title: 'Invalid Input',
        message: 'Please enter a customer ID.',
      );
      return;
    }

    if (!DpdcApiService.validateCustomerId(customerId)) {
      ErrorDialog.show(
        context,
        title: 'Invalid Customer ID',
        message:
            'Customer ID must be numeric and between 8-12 digits long.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final balanceDetails =
          await _apiService.fetchBalanceDetails(customerId);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Navigate to balance screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BalanceScreen(
            balanceDetails: balanceDetails,
            customerId: customerId,
          ),
        ),
      ).then((_) {
        // Reload saved IDs when returning from balance screen
        _loadSavedIds();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ErrorDialog.show(
        context,
        title: 'Error',
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: _checkBalance,
      );
    }
  }

  void _selectSavedId(String? id) {
    if (id != null) {
      setState(() {
        _selectedSavedId = id;
        _customerIdController.text = id;
      });
    }
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 60),
                  _buildInputCard(),
                  const SizedBox(height: 24),
                  if (_savedIds.isNotEmpty) _buildSavedIdsSection(),
                  const SizedBox(height: 32),
                  _buildCheckButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.electric_bolt,
            size: 64,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'DPDC Balance Checker',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Check Your Electricity Balance',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputCard() {
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
            'Customer ID',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerIdController,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your customer ID',
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: _customerIdController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _customerIdController.clear();
                          _selectedSavedId = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                _selectedSavedId = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Example: 31719842',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedIdsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved Customer IDs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSavedId,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Select a saved ID'),
                ),
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                items: _savedIds.map((id) {
                  final label = _idsWithLabels[id];
                  return DropdownMenuItem(
                    value: id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        label != null && label.isNotEmpty
                            ? '$label ($id)'
                            : id,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _isLoading ? null : _selectSavedId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF97316), // Orange
            Color(0xFFEC4899), // Pink
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _checkBalance,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Check Balance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    super.dispose();
  }
}
