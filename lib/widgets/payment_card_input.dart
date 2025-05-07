import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/stripe_service.dart';
import '../services/payment_processor.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PaymentCardInput extends StatefulWidget {
  final Function(String paymentMethodId) onPaymentMethodCreated;
  
  const PaymentCardInput({
    super.key,
    required this.onPaymentMethodCreated,
  });

  @override
  State<PaymentCardInput> createState() => _PaymentCardInputState();
}

class _PaymentCardInputState extends State<PaymentCardInput> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _createPaymentMethod() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Format card information
      final cardNumber = _cardNumberController.text.replaceAll(' ', '');
      
      final expiryParts = _expiryController.text.split('/');
      if (expiryParts.length != 2) {
        throw Exception('Invalid expiry date format');
      }
      
      final expMonth = int.parse(expiryParts[0]);
      final expYear = int.parse('20${expiryParts[1]}'); // Convert 2-digit year to 4-digit
      
      final cvc = _cvcController.text;
      final name = _nameController.text;
      
      // Create card details
      final cardDetails = {
        'number': cardNumber,
        'exp_month': expMonth,
        'exp_year': expYear,
        'cvc': cvc,
      };
      
      print('Creating payment method with card details');
      
      try {
        // Use Stripe SDK to create payment method
        final paymentMethod = await Stripe.instance.createPaymentMethod(
          params: PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(
              billingDetails: BillingDetails(name: name),
            ),
          ),
        );
        
        print('Payment method created successfully: ${paymentMethod.id}');
        
        // Return the payment method ID to the parent widget
        widget.onPaymentMethodCreated(paymentMethod.id);
      } catch (stripeError) {
        print('Error creating payment method with Stripe SDK: $stripeError');
        
        // Try alternate approach with Stripe API directly
        try {
          // Get the API key
          final response = await http.post(
            Uri.parse('https://api.stripe.com/v1/payment_methods'),
            headers: {
              'Authorization': 'Bearer pk_test_51R00wJP1l4vbhTn5ncEmkHyXbk0Csb22wsmqYsYbAssUvPIsR3dldovfgPlqsZzcf3LtIhrOKqAVWITKfYR2fFx600KQdXd1p2',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'type': 'card',
              'card[number]': cardNumber,
              'card[exp_month]': expMonth.toString(),
              'card[exp_year]': expYear.toString(),
              'card[cvc]': cvc,
              'billing_details[name]': name,
            },
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final paymentMethodId = data['id'];
            print('Created payment method via API: $paymentMethodId');
            widget.onPaymentMethodCreated(paymentMethodId);
          } else {
            throw Exception('Failed to create payment method: ${response.body}');
          }
        } catch (apiError) {
          print('API error: $apiError');
          
          // For testing only - only use this in development
          if (kDebugMode) {
            print('Using test card token as fallback');
            widget.onPaymentMethodCreated('pm_card_visa');
          } else {
            throw Exception('Could not create payment method: $apiError');
          }
        }
      }
    } catch (e) {
      print('Error in payment card input: $e');
      setState(() {
        _errorMessage = 'Card processing error: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your payment information is securely processed by Stripe.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
            const SizedBox(height: 24),
            
            // Card number
            TextFormField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: '4242 4242 4242 4242',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter card number';
                }
                if (value.replaceAll(' ', '').length < 16) {
                  return 'Please enter a valid card number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Expiry and CVC
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date',
                      hintText: 'MM/YY',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 5) {
                        return 'Invalid format';
                      }
                      
                      final parts = value.split('/');
                      if (parts.length != 2) return 'Invalid format';
                      
                      final month = int.tryParse(parts[0]);
                      final year = int.tryParse(parts[1]);
                      
                      if (month == null || year == null) return 'Invalid format';
                      if (month < 1 || month > 12) return 'Invalid month';
                      
                      final now = DateTime.now();
                      final currentYear = now.year % 100; // Get last 2 digits
                      final currentMonth = now.month;
                      
                      if (year < currentYear) return 'Card expired';
                      if (year == currentYear && month < currentMonth) return 'Card expired';
                      
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      hintText: '123',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 3) {
                        return 'Invalid CVC';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cardholder name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                hintText: 'John Smith',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter cardholder name';
                }
                return null;
              },
            ),
            
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
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
            ],
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPaymentMethod,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6), // purple-600
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Payment Method'),
              ),
            ),
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Powered by ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'Stripe',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF635BFF), // Stripe purple
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write(' ');
      }
    }
    
    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i != text.length - 1) {
        buffer.write('/');
      }
    }
    
    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
} 