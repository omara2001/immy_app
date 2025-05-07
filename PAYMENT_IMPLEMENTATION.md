# Immy App Payment Implementation

This document provides an overview of the payment processing implementation in the Immy App.

## Overview

The payment system is built with Stripe integration and includes:

- Processing subscriptions and one-time payments
- Managing payment methods
- Tracking payment history
- Handling webhooks for server-side events
- Syncing payment data between Stripe and the local database

## Architecture

The payment system uses a layered architecture:

1. **UI Layer** - Payment screens and widgets that interact with users
2. **Service Layer** - Services that handle business logic and API calls
3. **Database Layer** - Local storage for payment and subscription data

### Key Components

#### PaymentProcessor

The `PaymentProcessor` class serves as the main entry point for payment operations. It provides a simple interface for the UI layer and delegates implementation details to specialized services.

Key features:
- Processing payments using Stripe Payment Sheet
- Managing payment methods
- Handling subscriptions
- Syncing payment data

#### StripeService

The `StripeService` handles direct communication with the Stripe API for server-side operations:
- Creating customers
- Managing payment intents
- Processing subscriptions
- Retrieving payment data

#### StripeSyncService

The `StripeSyncService` ensures data consistency between Stripe and the local database:
- Syncing payment records
- Syncing subscription data
- Handling payment verification

#### WebhookHandler

The `WebhookHandler` processes webhook events from Stripe to update the database:
- Payment success/failure events
- Subscription lifecycle events
- Invoice events

## Database Schema

The payment system uses the following tables:

### Payments Table
```sql
CREATE TABLE Payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  serial_id INT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  currency VARCHAR(10) NOT NULL,
  payment_status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  stripe_payment_id VARCHAR(255),
  stripe_payment_method_id VARCHAR(255),
  FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
  FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE
);
```

### Subscriptions Table
```sql
CREATE TABLE Subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  serial_id INT NOT NULL,
  start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  end_date TIMESTAMP NOT NULL,
  status VARCHAR(50) DEFAULT 'active',
  stripe_subscription_id VARCHAR(255),
  stripe_price_id VARCHAR(255),
  FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
  FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE
);
```

## Payment Flow

### Subscription Flow

1. User initiates subscription process
2. App retrieves or creates a Stripe customer
3. Creates a payment intent with subscription metadata
4. Presents the Stripe Payment Sheet UI
5. Processes payment and creates subscription records
6. Updates UI to reflect subscription status

### Payment Method Management

1. User selects to add/update payment method
2. App creates a Setup Intent with Stripe
3. Presents the Stripe Payment Sheet UI for card entry
4. Attaches payment method to customer
5. Updates UI to show saved payment methods

## Webhook Handling

Stripe webhooks are processed to ensure data consistency even if the app is offline:

1. Server receives webhook event from Stripe
2. Validates webhook signature
3. Processes event based on type (payment_intent.succeeded, customer.subscription.updated, etc.)
4. Updates database records accordingly
5. Responds to Stripe with success/failure

## Error Handling

The payment system implements comprehensive error handling:

1. Network errors with graceful fallbacks
2. Stripe API errors with user-friendly messages
3. Database synchronization errors with retry mechanisms
4. Validation errors with clear feedback

## Testing

For testing purposes, the app includes:

1. Mock payment implementation for development
2. Stripe test mode for integration testing
3. Demo mode for UI demonstrations

## Security Considerations

1. API keys are never exposed in client-side code
2. Payment processing uses Stripe's secure Payment Sheet
3. Sensitive payment data never passes through the app's servers

## Integration Points

The payment system integrates with:

1. User authentication system
2. Device serial number management
3. Backend database service

## Future Enhancements

1. Support for additional payment methods
2. Advanced subscription management (upgrading, downgrading)
3. Proration for subscription changes
4. Multi-currency support
5. Detailed analytics and reporting 