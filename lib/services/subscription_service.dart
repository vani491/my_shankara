import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../constants/subscription_constants.dart';

/// In-app purchase for the monthly MyShankara membership.
///
/// A singleton [ChangeNotifier] (like [AppState]). Call [init] once at app
/// start so the purchase stream is being listened to before any transaction
/// can be delivered, and [dispose] when the app goes away.
///
/// The free trial is NOT a store trial — it is our own Firestore
/// `trialStartDate` logic. Nothing here is ever triggered by trial expiry; a
/// purchase only starts when the user calls [buy].
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Timer? _restoreTimer;
  Timer? _purchaseTimeout;
  bool _initialized = false;
  bool _restoreInFlight = false;
  bool _restoredSomething = false;

  bool _storeAvailable = false;
  bool _isLoadingProducts = false;
  bool _isPurchasing = false;
  bool _isMember = false;
  ProductDetails? _productDetails;
  String? _errorMessage;

  /// False when the store can't be reached (e.g. simulator, no Play Services).
  bool get storeAvailable => _storeAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  ProductDetails? get productDetails => _productDetails;

  /// True from the tap on "Begin Membership" / "Restore" until the store
  /// reports a final result (purchased, restored, error or canceled).
  bool get isPurchasing => _isPurchasing;

  /// Latest user-facing problem, or null. Cleared by [clearError] and by
  /// starting a new purchase / restore.
  String? get errorMessage => _errorMessage;

  /// True once a purchase / restore was confirmed in this session.
  bool get isMember => _isMember;

  /// Localized price string from the store (e.g. "₹199.00"), or null while
  /// loading / unavailable. Never hardcode a price.
  String? get price => _productDetails?.price;

  String get productId => defaultTargetPlatform == TargetPlatform.iOS
      ? SubscriptionConstants.iosProductId
      : SubscriptionConstants.androidProductId;

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Only iOS and Android have a store; other platforms stay inert.
  bool get _platformSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_initialized || !_platformSupported) return;
    _initialized = true;

    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) {
          debugPrint('SubscriptionService: purchaseStream error: $e');
          _failPurchase('Something went wrong with the store. Please try again.');
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: could not listen to purchases: $e');
    }

    await loadProducts();
  }

  /// Checks the store and loads the product for this platform. Never throws:
  /// a missing product (e.g. Android before the Play product exists) just
  /// leaves [productDetails] null.
  Future<void> loadProducts() async {
    if (!_platformSupported) return;
    _isLoadingProducts = true;
    notifyListeners();

    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        final response = await _iap.queryProductDetails({productId});
        if (response.error != null) {
          debugPrint(
              'SubscriptionService: product query error: ${response.error}');
        }
        _productDetails = _pickProduct(response.productDetails);
      } else {
        _productDetails = null;
      }
    } catch (e) {
      debugPrint('SubscriptionService: loadProducts failed: $e');
      _productDetails = null;
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Google Play returns one [ProductDetails] per base plan / offer of a
  /// subscription, in no guaranteed order. Our trial is our own, so we want the
  /// plain base plan (no `offerId`) — otherwise a Play intro offer could be
  /// picked and the price would show as "Free". iOS returns a single entry.
  ProductDetails? _pickProduct(List<ProductDetails> products) {
    if (products.isEmpty) return null;
    for (final product in products) {
      if (product is GooglePlayProductDetails) {
        final index = product.subscriptionIndex;
        final offers = product.productDetails.subscriptionOfferDetails;
        if (index != null && offers != null && offers[index].offerId == null) {
          return product;
        }
      }
    }
    return products.first;
  }

  /// Starts the purchase sheet. Only ever called from an explicit user tap.
  Future<void> buy() async {
    if (_isPurchasing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _errorMessage = 'Please sign in to begin your membership.';
      notifyListeners();
      return;
    }

    if (_productDetails == null && !_isLoadingProducts) {
      await loadProducts();
    }
    final product = _productDetails;
    if (!_storeAvailable || product == null) {
      _errorMessage =
          'Membership is not available right now. Please try again later.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _isPurchasing = true;
    _armPurchaseTimeout();
    notifyListeners();

    try {
      final PurchaseParam param;
      if (product is GooglePlayProductDetails) {
        // Play subscriptions need the token of the chosen offer.
        param = GooglePlayPurchaseParam(
          productDetails: product,
          applicationUserName: user.uid,
          offerToken: product.offerToken,
        );
      } else {
        param = PurchaseParam(
          productDetails: product,
          applicationUserName: user.uid,
        );
      }
      // Subscriptions are non-consumable from the plugin's point of view.
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _failPurchase("Couldn't start the purchase. Please try again.");
      }
    } catch (e) {
      debugPrint('SubscriptionService: buy failed: $e');
      _failPurchase("Couldn't start the purchase. Please try again.");
    }
  }

  /// Re-delivers the user's previous purchases (reinstall / new device) through
  /// the purchase stream as `restored` events.
  Future<void> restorePurchases() async {
    if (_isPurchasing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _errorMessage = 'Please sign in to restore your purchases.';
      notifyListeners();
      return;
    }
    if (!_platformSupported || !_storeAvailable) {
      _errorMessage = 'The store is not available right now.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _isPurchasing = true;
    _restoreInFlight = true;
    _restoredSomething = false;
    _armPurchaseTimeout();
    notifyListeners();

    try {
      await _iap.restorePurchases(applicationUserName: user.uid);
    } catch (e) {
      debugPrint('SubscriptionService: restore failed: $e');
      _restoreInFlight = false;
      _failPurchase("Couldn't restore purchases. Please try again.");
      return;
    }

    // When the user has nothing to restore the store sends no event at all, so
    // give it a moment and then report that instead of spinning forever.
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 8), () {
      if (!_restoreInFlight) return;
      _restoreInFlight = false;
      if (!_restoredSomething) {
        _failPurchase('No previous membership was found for this account.');
      }
    });
  }

  /// Safety net: if the store never reports a final result (sheet dismissed
  /// without an event, lost callback), re-enable the buttons after 2 minutes.
  void _armPurchaseTimeout() {
    _purchaseTimeout?.cancel();
    _purchaseTimeout = Timer(const Duration(minutes: 2), () {
      if (!_isPurchasing) return;
      debugPrint('SubscriptionService: purchase timed out — resetting state');
      _restoreTimer?.cancel();
      _restoreInFlight = false;
      _isPurchasing = false;
      notifyListeners();
    });
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Purchase stream ───────────────────────────────────────────────────────

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // Android reports a closed sheet or a failed launch with an EMPTY
      // productID, so it would be skipped as "not ours" below and the button
      // would stay disabled. End the purchase here instead.
      if (purchase.productID.isEmpty && _isPurchasing) {
        if (purchase.status == PurchaseStatus.canceled) {
          _failPurchase('Purchase cancelled.');
        } else if (purchase.status == PurchaseStatus.error) {
          debugPrint('SubscriptionService: purchase error: ${purchase.error}');
          _failPurchase(
              'The purchase could not be completed. You have not been charged.');
        }
      }

      if (purchase.productID != productId) {
        // Not ours — but a pending transaction must still be completed.
        if (purchase.pendingCompletePurchase) {
          await _complete(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isPurchasing = true;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _onEntitled(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('SubscriptionService: purchase error: ${purchase.error}');
          _failPurchase(
              'The purchase could not be completed. You have not been charged.');
          break;

        case PurchaseStatus.canceled:
          _failPurchase('Purchase cancelled.');
          break;
      }

      // Always finish the transaction, whatever happened above — otherwise the
      // store keeps redelivering it (and Google Play refunds unacknowledged
      // purchases after 3 days).
      if (purchase.pendingCompletePurchase) {
        await _complete(purchase);
      }
    }
  }

  Future<void> _onEntitled(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.restored) {
      _restoredSomething = true;
    }
    _restoreTimer?.cancel();
    _restoreInFlight = false;

    try {
      await _grantEntitlement(purchase);
      _isMember = true;
      _errorMessage = null;
    } catch (e) {
      debugPrint('SubscriptionService: granting entitlement failed: $e');
      _errorMessage = "Your purchase went through, but we couldn't update your "
          'account. Please tap Restore Purchases.';
    } finally {
      _purchaseTimeout?.cancel();
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('SubscriptionService: completePurchase failed: $e');
    }
  }

  void _failPurchase(String message) {
    _purchaseTimeout?.cancel();
    _restoreTimer?.cancel();
    _restoreInFlight = false;
    _isPurchasing = false;
    _errorMessage = message;
    notifyListeners();
  }

  /// The single place that turns a store purchase into app access.
  ///
  /// TODO: replace with server-side receipt verification. Today the client
  /// writes its own entitlement, which a modified app could fake, and nothing
  /// ever expires `subscription_status` when a subscription lapses or is
  /// cancelled. A backend should verify the receipt / purchase token, write
  /// these fields (plus an expiry) and reset the status when the paid period
  /// ends.
  Future<void> _grantEntitlement(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('No signed-in user to grant the entitlement to.');
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'subscription_status': 'active',
      'subscription_product_id': purchase.productID,
      'subscription_platform': _platformName,
      'subscription_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _purchaseTimeout?.cancel();
    _restoreTimer?.cancel();
    _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
    super.dispose();
  }
}
