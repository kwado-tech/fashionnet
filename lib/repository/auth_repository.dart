import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

enum AuthStatus {
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated,
  SendingCode
}

class AuthRepository with ChangeNotifier {
  FirebaseAuth _auth;
  FirebaseUser _user;
  FirebaseUser _currentUser;

  AuthStatus _status = AuthStatus.Uninitialized;

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.onAuthStateChanged.listen(_onAuthStateChanged);
  }

  AuthStatus get status => _status;
  FirebaseUser get user => _user;

  String _verificationId = '';
  String _message = '';
  String _smsController = '';

  Future<bool> _verifyPhoneNumber({@required String phoneNumber}) async {
    final PhoneVerificationCompleted verificationCompleted =
        (AuthCredential phoneAuthCredential) {
      _auth.signInWithCredential(phoneAuthCredential);

      _message = 'Received phone auth credential: $phoneAuthCredential';
    };

    final PhoneVerificationFailed verificationFailed =
        (AuthException authException) {
      _message =
          'Phone number verification failed. Code: ${authException.code}. Message: ${authException.message}';
    };

    final PhoneCodeSent codeSent =
        (String verificationId, [int forceResendingToken]) async {
      _message = 'Please check your phone for the verification code.';

      _verificationId = verificationId;
    };

    final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
        (String verificationId) {
      _verificationId = verificationId;
      print('Code auto-retrieval time-out');
    };

    print(_message);

    try {
      _status = AuthStatus.SendingCode;
      notifyListeners();

      await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 5),
          verificationCompleted: verificationCompleted,
          verificationFailed: verificationFailed,
          codeSent: codeSent,
          codeAutoRetrievalTimeout: codeAutoRetrievalTimeout);

      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _signInWithPhoneNumber() async {
    try {
      _status = AuthStatus.Authenticating;
      notifyListeners();

      final AuthCredential credential = PhoneAuthProvider.getCredential(
        verificationId: _verificationId,
        smsCode: _smsController,
      );
      _user = await _auth.signInWithCredential(credential);
      _currentUser = await _auth.currentUser();
      assert(user.uid == _currentUser.uid);

      notifyListeners();

      if (user != null) {
        _message = 'Successfully signed in, uid: ' + user.uid;
      } else {
        _message = 'Sign in failed';
      }
      print(_message);

      return true;
    } catch (e) {
      _status = AuthStatus.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> _signout() {
    _auth.signOut();
    _status = AuthStatus.Unauthenticated;
    notifyListeners();

    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(FirebaseUser firebaseUser) async {
    if (_user == null) {
      _status = AuthStatus.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = AuthStatus.Authenticated;
    }

    notifyListeners();
  }
}
