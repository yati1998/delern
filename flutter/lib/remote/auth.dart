import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:quiver/strings.dart';

enum SignInProvider {
  google,
}

@immutable
class User {
  final FirebaseUser _dataSource;
  const User._(this._dataSource) : assert(_dataSource != null);

  /// Unique ID of the user used in Firebase Database and across the app.
  String get uid => _dataSource.uid;

  /// Display name. Can be null, e.g. for anonymous user.
  String get displayName =>
      isBlank(_dataSource.displayName) ? null : _dataSource.displayName;

  /// Photo URL. Can be null.
  String get photoUrl =>
      isBlank(_dataSource.photoUrl) ? null : _dataSource.photoUrl;

  /// All providers (aka "linked accounts") for the current user. Empty for
  /// anonymously signed in.
  Iterable<SignInProvider> get providers => _dataSource.providerData
      .map((p) => _parseSignInProvider(p.providerId))
      .where((p) => p != null);

  bool get isAnonymous => _dataSource.isAnonymous;

  /// A human friendly string with user id. Usually presented under display name
  /// in navigation drawer. Example: `example@gmail.com [G]`, meaning that
  /// the user has linked their Google account.
  String get humanFriendlyIdentifier {
    String idString;
    // Surprisingly some of the properties can be empty strings instead of null.
    if (_dataSource.isEmailVerified && !isBlank(_dataSource.email)) {
      idString = _dataSource.email;
    } else if (!isBlank(_dataSource.phoneNumber)) {
      idString = _dataSource.phoneNumber;
    } else if (!isBlank(_dataSource.email)) {
      // Not null, but also not verified. Give a locale-independent hint.
      idString = '(${_dataSource.email})';
    } else {
      idString = '#${_dataSource.uid}';
    }

    if (_dataSource.providerData.length > 1) {
      // TODO(dotdoom): show linked accounts as icons in UI.
      const providerShortName = <SignInProvider, String>{
        // TODO(dotdoom): add more providers here #944.
        SignInProvider.google: 'G',
      };
      assert(providerShortName.length == SignInProvider.values.length);
      final providerShortNames = providers.map((p) => providerShortName[p]);
      idString += ' [${providerShortNames.join(',')}]';
    }

    return idString;
  }

  static SignInProvider _parseSignInProvider(String providerId) {
    switch (providerId) {
      // TODO(dotdoom): use GoogleAuthProvider.providerId once it's a const:
      //                https://github.com/flutter/plugins/pull/1292
      case 'google.com':
        return SignInProvider.google;
      case 'firebase':
        return null;
      // TODO(dotdoom): add more providers here #944.
    }
    return null;
  }
}

class Auth {
  static final instance = Auth._();
  Auth._() {
    // Even though this will be evaluated lazily, the initial trigger is
    // guaranteed by Firebase (per documentation).
    FirebaseAuth.instance.onAuthStateChanged.listen((firebaseUser) async {
      _authStateKnown = true;
      _setCurrentUser(firebaseUser);
    });
  }

  final _userChanged = StreamController<void>.broadcast();
  Stream<void> get onUserChanged => _userChanged.stream;

  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _authStateKnown = false;
  bool get authStateKnown => _authStateKnown;

  User _currentUser;
  User get currentUser => _currentUser;

  /// Sign in using a specified provider. If the user is currently signed in
  /// anonymously, try to preserve uid. This will work only if the user hasn't
  /// signed in with this provider before, throwing PlatformException otherwise.
  ///
  /// Some providers may skip through the account picker window if sign in has
  /// already happened (e.g. after a failed account linking). To give user a
  /// choice, we explicitly sign out. If you don't want this behavior, set
  /// [forceAccountPicker] to false.
  Future<void> signIn(SignInProvider provider,
      {forceAccountPicker = true}) async {
    FirebaseUser user;

    if (provider == null) {
      user = await FirebaseAuth.instance.signInAnonymously();
    } else {
      AuthCredential credential;
      switch (provider) {
        case SignInProvider.google:
          credential =
              await _getGoogleCredential(signOutFirst: forceAccountPicker);
          break;
        // TODO(dotdoom): handle other providers here (ex.: Facebook) #944.
      }

      user = await ((_currentUser == null)
          ? FirebaseAuth.instance.signInWithCredential(credential)
          : FirebaseAuth.instance.linkWithCredential(credential));

      // After `await`, `_currentUser` is set by `onAuthStateChanged` callback.
      if (await _updateProfileFromProviders(user)) {
        _setCurrentUser(await FirebaseAuth.instance.currentUser());
      }
    }
  }

  /// If user is already signed in, do nothing. If we have existing credential
  /// (e.g. user was signed in at the previous app run), use that credential to
  /// sign in without asking the user.
  Future<void> signInSilently() async {
    var firebaseUser = await FirebaseAuth.instance.currentUser();
    if (firebaseUser == null) {
      // TODO(dotdoom): chain other _getXXXCredential(silent: true) here #944.
      final credential = await _getGoogleCredential(silent: true);

      if (credential != null) {
        firebaseUser =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }
    }

    // After `await`, `_currentUser` is set by `onAuthStateChanged` callback.
    if (firebaseUser != null) {
      if (await _updateProfileFromProviders(firebaseUser)) {
        _setCurrentUser(await FirebaseAuth.instance.currentUser());
      }
    }
  }

  /// Sign out of Firebase, but without signing out of linked providers.
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<AuthCredential> _getGoogleCredential(
      {silent = false, signOutFirst = false}) async {
    assert(!(silent && signOutFirst),
        'Silent Sign In is meaningless if Sign Out is forced first');
    if (signOutFirst) {
      await _googleSignIn.signOut();
    }

    final account = await (silent
        ? _googleSignIn.signInSilently()
        : _googleSignIn.signIn());
    if (account == null) {
      return null;
    }
    final auth = await account.authentication;
    // NOTE: `auth` may contain an access token that is not valid at this point
    //       anymore, or will expire in a few seconds. There is no guarantee
    //       that the token is up to date. If this happens, further use of the
    //       token (e.g. `signInWithCredential`) will fail. To recover from
    //       this, we can force token re-generation when signIn fails, by using
    //       `await account.clearAuthCache()`. Note that `getCredential()` call
    //       below will never fail as it merely copies tokens into a different
    //       structure without validation.
    //       Another solution is to always call `clearAuthCache()`, but what are
    //       the side effects of it?
    return GoogleAuthProvider.getCredential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  void _setCurrentUser(FirebaseUser user) {
    _currentUser = user == null ? null : User._(user);
    _userChanged.add(null);
  }

  static Future<bool> _updateProfileFromProviders(FirebaseUser user) async {
    var update = UserUpdateInfo();

    var anyUpdates = false;
    for (final providerData in user.providerData) {
      if (isBlank(user.displayName) && !isBlank(providerData.displayName)) {
        update.displayName = providerData.displayName;
        print('Updating displayName from provider ${providerData.providerId}');
        anyUpdates = true;
      }
      if (isBlank(user.photoUrl) && !isBlank(providerData.photoUrl)) {
        update.photoUrl = providerData.photoUrl;
        print('Updating photoUrl from provider ${providerData.providerId}');
        anyUpdates = true;
      }
    }
    if (anyUpdates) {
      await user.updateProfile(update);
      // reload() does not change existing instance. The caller will have to get
      // currentUser() again: https://github.com/flutter/plugins/pull/533.
      await user.reload();
    }
    return anyUpdates;
  }
}
