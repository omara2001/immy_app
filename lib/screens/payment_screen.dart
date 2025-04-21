import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/stripe_service.dart';
import '../services/backend_api_service.dart';
import '../widgets/subscription_banner.dart';

class PaymentScreen extends StatefulWidget {
  final int serialId;
  final int userId;
  
  const PaymentScreen({
    super.key,
    required this.serialId,
    required this.userId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  CardFieldInputDetails? _cardFieldInputDetails;
  String? _customerId;
  List<PaymentMethod> _savedPaymentMethods = [];
  PaymentMethod? _selectedPaymentMethod;
  
  @override
  void initState() {
    super.initState();
    _initializePayment();
  }
  
  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get user details
      final users = await BackendApiService.executeQuery(
        'SELECT * FROM Users WHERE id = ?',
        [widget.userId]
      );
      
      if (users.isEmpty) {
        throw Exception('User not found');
      }
      
      final user = users.first;
      
      // Check if user has a Stripe customer ID
      if (user['stripe_customer_id'] != null) {
        _customerId = user['stripe_customer_id'];
        
        // Get saved payment methods
        final paymentMethods = await StripeService.getCustomerPaymentMethods(
          customerId: _customerId!,
        );
        
        setState(() {
          _savedPaymentMethods = paymentMethods.map((pm) {
            final card = pm['card'];
            return PaymentMethod(
              id: pm['id'],
              brand: card['brand'],
              last4: card['last4'],
              expiryMonth: card['exp_month'],
              expiryYear: card['exp_year'],
            );
          }).toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize payment: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // If using a new card
      if (_selectedPaymentMethod == null) {
        if (_cardFieldInputDetails == null || !_cardFieldInputDetails!.complete) {
          throw Exception('Please complete card details');
        }
        
        // Create a payment method
        final paymentMethod = await Stripe.instance.createPaymentMethod(
          params: PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(),
          ),
        );
        
        // Process payment
        final result = await StripeService.processPayment(
          userId: widget.userId,
          serialId: widget.serialId,
          amount: 7.99,
          currency: 'GBP',
          paymentMethodId: paymentMethod.id,
          customerId: _customerId,
        );
        
        // Handle additional actions if required
        if (result['requires_action'] == true) {
          final clientSecret = result['payment_intent_client_secret'];
          final paymentId = result['payment_id'];
          
          // Confirm payment with 3D Secure if needed
          final paymentIntent = await Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
          );
          
          // Update payment status
          await StripeService.updatePaymentStatus(
            paymentId: paymentId,
            paymentIntentId: paymentIntent.id,
          );
        }
      } else {
        // Process payment with saved payment method
        final result = await StripeService.processPayment(
          userId: widget.userId,
          serialId: widget.serialId,
          amount: 7.99,
          currency: 'GBP',
          paymentMethodId: _selectedPaymentMethod!.id,
          customerId: _customerId,
        );
        
        // Handle additional actions if required
        if (result['requires_action'] == true) {
          final clientSecret = result['payment_intent_client_secret'];
          final paymentId = result['payment_id'];
          
          // Confirm payment with 3D Secure if needed
          final paymentIntent = await Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
          );
          
          // Update payment status
          await StripeService.updatePaymentStatus(
            paymentId: paymentId,
            paymentIntentId: paymentIntent.id,
          );
        }
      }
      
      // Navigate back to payments page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SubscriptionBanner(isActive: false),
                  const SizedBox(height: 24),
                  
                  // Subscription details
                  const Text(
                    'Premium Monthly Subscription',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '£7.99',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        'per month',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280), // gray-500
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Subscription Benefits:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitItem('Unlimited conversations with Immy'),
                  _buildBenefitItem('Priority support'),
                  _buildBenefitItem('Advanced insights and analytics'),
                  _buildBenefitItem('Regular content updates'),
                  const SizedBox(height: 24),
                  
                  // Saved payment methods
                  if (_savedPaymentMethods.isNotEmpty) ...[
                    const Text(
                      'Saved Payment Methods',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _savedPaymentMethods.length,
                      (index) => _buildSavedPaymentMethodItem(
                        _savedPaymentMethods[index],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Or pay with a new card:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280), // gray-500
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Card input field
                  CardField(
                    onCardChanged: (details) {
                      setState(() {
                        _cardFieldInputDetails = details;
                        // Clear error message when user starts typing
                        if (_errorMessage?.contains('card details') ?? false) {
                          _errorMessage = null;
                        }
                        // Deselect saved payment method when entering new card
                        if (details?.complete == true) {
                          _selectedPaymentMethod = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _errorMessage != null 
                              ? Colors.red 
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _errorMessage != null 
                              ? Colors.red 
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      hintText: 'Card details',
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Payment button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6), // purple-600
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Subscribe Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Terms and conditions
                  const Center(
                    child: Text(
                      'By subscribing, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280), // gray-500
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF8B5CF6), // purple-600
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563), // gray-600
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSavedPaymentMethodItem(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod?.id == method.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = isSelected ? null : method;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.white, // purple-100 if selected
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE5E7EB), // purple-600 if selected, gray-200 otherwise
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.credit_card,
              color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280), // purple-600 if selected, gray-500 otherwise
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${method.brand.toUpperCase()} ending in ${method.last4}',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Expires ${method.expiryMonth}/${method.expiryYear}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280), // gray-500
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF8B5CF6), // purple-600
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethod {
  final String id;
  final String brand;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  
  PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
  });
}
