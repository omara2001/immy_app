import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/webhook_handler.dart';

class StripeWebhookRoute {
  Router get router {
    final router = Router();
    
    // Stripe webhook endpoint
    router.post('/webhook', (Request request) async {
      try {
        final payload = await request.readAsString();
        final signature = request.headers['stripe-signature'] ?? '';
        
        final result = await WebhookHandler.handleWebhook(payload, signature);
        
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Webhook error: $e');
        return Response(
          400,
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });
    
    return router;
  }
}
