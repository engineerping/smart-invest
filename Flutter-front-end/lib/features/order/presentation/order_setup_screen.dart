// lib/features/order/presentation/order_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../domain/order_model.dart';

final orderSetupProvider = StateProvider<OrderSetupState>((ref) {
  return OrderSetupState();
});

class OrderSetupState {
  final String orderType;
  final String amount;

  OrderSetupState({
    this.orderType = 'ONE_TIME',
    this.amount = '',
  });

  OrderSetupState copyWith({String? orderType, String? amount}) {
    return OrderSetupState(
      orderType: orderType ?? this.orderType,
      amount: amount ?? this.amount,
    );
  }
}

class OrderSetupScreen extends ConsumerStatefulWidget {
  final String? fundId;

  const OrderSetupScreen({super.key, this.fundId});

  @override
  ConsumerState<OrderSetupScreen> createState() => _OrderSetupScreenState();
}

class _OrderSetupScreenState extends ConsumerState<OrderSetupScreen> {
  late String _fundId;
  String _orderType = 'ONE_TIME';
  String _amount = '';

  @override
  void initState() {
    super.initState();
    _fundId = widget.fundId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => context.go('/funds'),
        ),
        title: const Text(
          'Setup Order',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFundHeader(),
            const SizedBox(height: 24),
            _buildOrderTypeSelector(),
            const SizedBox(height: 24),
            _buildAmountInput(),
            const SizedBox(height: 16),
            _buildMgmtFeeInfo(),
            const SizedBox(height: 24),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFundHeader(),
              const SizedBox(height: 24),
              _buildOrderTypeSelector(),
              const SizedBox(height: 24),
              _buildAmountInput(),
              const SizedBox(height: 16),
              _buildMgmtFeeInfo(),
              const SizedBox(height: 24),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFundHeader() {
    return Text(
      _fundId.isNotEmpty ? 'Fund $_fundId' : 'Selected Fund',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildOrderTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderType = 'ONE_TIME'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _orderType == 'ONE_TIME'
                      ? const Color(0xFF1F2937)
                      : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Center(
                  child: Text(
                    'One-time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _orderType == 'ONE_TIME'
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderType = 'MONTHLY_PLAN'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _orderType == 'MONTHLY_PLAN'
                      ? const Color(0xFF1F2937)
                      : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Monthly Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _orderType == 'MONTHLY_PLAN'
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Investment Amount (HKD)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() => _amount = value),
          decoration: InputDecoration(
            hintText: 'Enter amount (min. 100)',
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixText: 'HKD ',
            prefixStyle: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFE8341A),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMgmtFeeInfo() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Management Fee',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          '--',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final amount = double.tryParse(_amount) ?? 0;
    final isValid = amount >= 100;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isValid ? _handleContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8341A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    final amt = double.tryParse(_amount);
    if (amt == null || amt < 100) return;

    final setupState = OrderSetupState(
      orderType: _orderType,
      amount: _amount,
    );

    context.go('/order/review', extra: {
      'fundId': _fundId,
      'orderType': _orderType,
      'amount': amt,
    });
  }
}